import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayoslog/core/database/app_database.dart' hide ForecastAudit;
import 'package:ayoslog/features/predictions/data/drift_forecast_repository.dart';
import 'package:ayoslog/features/predictions/domain/forecast_models.dart';
import 'package:ayoslog/features/predictions/domain/forecast_repository.dart';
import 'package:ayoslog/features/predictions/domain/forecast_usecases.dart';
import 'package:ayoslog/features/maintenance/data/maintenance_repository.dart';

final date = DateTime.utc(2025);
ForecastTask plan(
        {String id = 't',
        String asset = 'a',
        UsageMethod method = UsageMethod.counter}) =>
    ForecastTask(
        id: id,
        assetId: asset,
        name: 'Oil change',
        subtype: AssetSubtype.vehicle,
        metric: ForecastMetric.distance,
        method: method,
        baselineAt: date,
        baseline: 8000,
        interval: 2000);
Observation point(String id, int day, double value, {int version = 1}) =>
    Observation(
        id: id,
        assetId: 'a',
        taskId: 't',
        at: date.add(Duration(days: day)),
        values: {'reading': value},
        version: version);

void main() {
  late AppDatabase db;
  late DriftForecastRepository repo;
  setUp(() async {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    repo = DriftForecastRepository(db);
    for (final id in ['a', 'b']) {
      await db.into(db.assets).insert(AssetsCompanion.insert(
          id: id, name: id, category: 'vehicle', createdAt: date));
    }
  });
  tearDown(() async => db.close());
  test('whole-second timestamps reject conflicting readings atomically',
      () async {
    await repo.saveTask(plan());
    await repo.saveObservation(Observation(
        id: 'r1',
        assetId: 'a',
        taskId: 't',
        at: date.add(const Duration(days: 1, milliseconds: 100)),
        values: const {'reading': 8100}));
    await expectLater(
        repo.saveObservation(Observation(
            id: 'r2',
            assetId: 'a',
            taskId: 't',
            at: date.add(const Duration(days: 1, milliseconds: 900)),
            values: const {'reading': 8200})),
        throwsA(isA<ForecastValidation>()));
    expect((await repo.watch().first).observations.length, 1);
  });
  test('battery replacement persists and permits a new charge-cycle segment',
      () async {
    await (db.update(db.assets)..where((a) => a.id.equals('a')))
        .write(const AssetsCompanion(category: Value('laptop')));
    await repo.saveTask(ForecastTask(
        id: 't',
        assetId: 'a',
        name: 'Battery check',
        subtype: AssetSubtype.laptop,
        metric: ForecastMetric.battery,
        method: UsageMethod.trend,
        baselineAt: date,
        setup: const {'device_type': 'laptop'}));
    Observation cycles(String id, int day, double value) => Observation(
        id: id,
        assetId: 'a',
        taskId: 't',
        at: date.add(Duration(days: day)),
        values: {'cycle_count': value});
    await repo.saveObservation(cycles('r1', 1, 80));
    await expectLater(repo.saveObservation(cycles('r2', 2, 10)),
        throwsA(isA<ForecastValidation>()));
    await repo.complete(ForecastCompletion(
        id: 's',
        assetId: 'a',
        taskId: 't',
        at: date.add(const Duration(days: 2)),
        description: 'Battery replaced',
        cost: 1000,
        batteryReplaced: true));
    await repo.saveObservation(cycles('r2', 3, 10));
    expect((await repo.watch().first).completions.single.batteryReplaced, true);
  });
  test(
      'policy, canonical readings, corrections, tombstone and audit are durable',
      () async {
    await repo.saveTask(plan());
    await repo.saveObservation(point('r', 1, 8200));
    await repo.saveObservation(point('r', 1, 8250));
    final data = await repo.watch().first;
    expect(data.observations.single.version, 2);
    expect(data.observations.single.values['reading'], 8250);
    expect(
        data.audit.where((a) => a.action == 'reading_corrected').single.before,
        contains('8200'));
    await expectLater(repo.saveObservation(point('r', 1, 8300)),
        throwsA(isA<ForecastValidation>()));
    await repo.deleteObservation('a', 't', 'r', 2);
    expect((await repo.watch().first).observations.single.deleted, true);
    final snapshot = (await db.select(db.forecastSnapshots).get()).single;
    expect(snapshot.algorithmVersion, 'rules_v1');
    expect((jsonDecode(snapshot.snapshotJson) as Map)['inputs'], isEmpty);
  });
  test(
      'chronology validates backdated corrections; cross-asset writes rejected',
      () async {
    await repo.saveTask(plan());
    await repo.saveObservation(point('r1', 1, 8100));
    await repo.saveObservation(point('r3', 3, 8300));
    await repo.saveObservation(point('r2', 2, 8200));
    await expectLater(repo.saveObservation(point('r2', 2, 8400)),
        throwsA(isA<ForecastValidation>()));
    await expectLater(
        repo.saveObservation(Observation(
            id: 'x',
            assetId: 'b',
            taskId: 't',
            at: date,
            values: const {'reading': 9000})),
        throwsA(isA<ForecastValidation>()));
    expect((await repo.watch().first).observations.length, 3);
  });
  test(
      'only chosen task resets; service correction/cancellation recompute baseline',
      () async {
    await repo.saveTask(plan());
    await repo.saveTask(plan(id: 'other'));
    await repo.saveObservation(point('r', 20, 9600));
    final c = ForecastCompletion(
        id: 's',
        assetId: 'a',
        taskId: 't',
        at: date.add(const Duration(days: 10)),
        description: 'Oil replaced',
        cost: 450,
        value: 9500);
    await repo.complete(c);
    var result = const CalculateInsights()(
        await repo.watch().first, date.add(const Duration(days: 20)));
    expect(
        result
            .firstWhere((i) => i.prediction?.task.id == 't')
            .prediction!
            .target,
        11500);
    expect(
        result
            .firstWhere((i) => i.prediction?.task.id == 'other')
            .prediction!
            .target,
        10000);
    await repo.complete(ForecastCompletion(
        id: 's',
        assetId: 'a',
        taskId: 't',
        at: c.at,
        description: c.description,
        cost: 500,
        value: 9400));
    result = const CalculateInsights()(
        await repo.watch().first, date.add(const Duration(days: 20)));
    expect(
        result
            .firstWhere((i) => i.prediction?.task.id == 't')
            .prediction!
            .target,
        11400);
    await repo.complete(ForecastCompletion(
        id: 's',
        assetId: 'a',
        taskId: 't',
        at: c.at,
        description: c.description,
        cost: 500,
        value: 9400,
        version: 2,
        voided: true));
    result = const CalculateInsights()(
        await repo.watch().first, date.add(const Duration(days: 20)));
    expect(
        result
            .firstWhere((i) => i.prediction?.task.id == 't')
            .prediction!
            .target,
        10000);
    expect((await db.select(db.serviceEvents).get()).single.voided, true);
    expect(
        (await repo.watch().first)
            .audit
            .where((a) => a.action.startsWith('service_'))
            .length,
        3);
  });
  test(
      'existing record transaction updates linked recurrence and snapshot together',
      () async {
    await repo.saveTask(plan());
    await db.into(db.maintenancePlans).insert(MaintenancePlansCompanion.insert(
        id: 'p', assetId: 'a', title: 'Oil', intervalMonths: 3, nextDue: date));
    await MaintenanceRepository(db).record(
        assetId: 'a',
        planId: 'p',
        taskRuleId: 't',
        description: 'Replaced',
        kind: 'routine',
        cost: 400,
        performedAt: date.add(const Duration(days: 10)),
        usageValue: 9500);
    final snapshot = jsonDecode(
            (await db.select(db.forecastSnapshots).get()).single.snapshotJson)
        as Map;
    expect(snapshot['target'], 11500);
    expect(
        (await db.select(db.maintenancePlans).get()).single.nextDue.month, 4);
    await db.customStatement(
        "CREATE TRIGGER reject_snapshot BEFORE INSERT ON forecast_snapshots BEGIN SELECT RAISE(ABORT, 'test failure'); END");
    await expectLater(
        repo.complete(ForecastCompletion(
            id: 'bad',
            assetId: 'a',
            taskId: 't',
            at: date.add(const Duration(days: 12)),
            description: 'Work',
            cost: 100,
            value: 9550)),
        throwsA(anything));
    expect((await db.select(db.serviceEvents).get()).length, 1);
    expect((await repo.watch().first).audit.where((a) => a.recordId == 'bad'),
        isEmpty);
  });
  test(
      'failed observation snapshot rolls back evidence and audit; archive retains history',
      () async {
    await repo.saveTask(plan());
    await db.customStatement(
        "CREATE TRIGGER reject_snapshot BEFORE INSERT ON forecast_snapshots BEGIN SELECT RAISE(ABORT, 'test failure'); END");
    await expectLater(
        repo.saveObservation(point('bad', 1, 8200)), throwsA(anything));
    expect(await db.select(db.forecastEntries).get(), isEmpty);
    await db.customStatement('DROP TRIGGER reject_snapshot');
    await repo.saveObservation(point('ok', 1, 8200));
    await (db.update(db.assets)..where((a) => a.id.equals('a')))
        .write(const AssetsCompanion(archived: Value(true)));
    await expectLater(repo.saveObservation(point('x', 2, 8300)),
        throwsA(isA<ForecastValidation>()));
    expect((await repo.watch().first).observations.length, 1);
  });
  test('offline file reopen preserves sources and evidence snapshot', () async {
    final dir = await Directory.systemTemp.createTemp('ayoslog_forecast_');
    final file = File('${dir.path}/local.sqlite');
    final local = AppDatabase.forExecutor(NativeDatabase(file));
    await local.into(local.assets).insert(AssetsCompanion.insert(
        id: 'a', name: 'Bike', category: 'vehicle', createdAt: date));
    await DriftForecastRepository(local).saveTask(plan());
    await DriftForecastRepository(local).saveObservation(point('r', 1, 8200));
    await local.close();
    final reopened = AppDatabase.forExecutor(NativeDatabase(file));
    try {
      final data = await DriftForecastRepository(reopened).watch().first;
      expect(data.tasks.single.metric, ForecastMetric.distance);
      expect(data.observations.single.values['reading'], 8200);
      expect(
          (await reopened.select(reopened.forecastSnapshots).get())
              .single
              .inputHash,
          hasLength(8));
    } finally {
      await reopened.close();
      await dir.delete(recursive: true);
    }
  });
}
