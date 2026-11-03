import 'dart:io';
import 'package:ayoslog/core/database/app_database.dart';
import 'package:ayoslog/features/predictions/data/drift_prediction_repository.dart';
import 'package:ayoslog/features/predictions/domain/prediction_models.dart';
import 'package:ayoslog/features/predictions/domain/prediction_usecases.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _LegacyDatabase extends AppDatabase {
  _LegacyDatabase(super.executor) : super.forExecutor();
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (_) async {
        await customStatement(
            'CREATE TABLE assets (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL, brand TEXT NOT NULL DEFAULT \'\', model TEXT NOT NULL DEFAULT \'\', archived INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)');
        await customStatement(
            'CREATE TABLE maintenance_plans (id TEXT NOT NULL PRIMARY KEY, asset_id TEXT NOT NULL REFERENCES assets(id), title TEXT NOT NULL, interval_months INTEGER NOT NULL, next_due INTEGER NOT NULL, active INTEGER NOT NULL DEFAULT 1)');
        await customStatement(
            'CREATE TABLE service_events (id TEXT NOT NULL PRIMARY KEY, asset_id TEXT NOT NULL REFERENCES assets(id), plan_id TEXT REFERENCES maintenance_plans(id), kind TEXT NOT NULL, description TEXT NOT NULL, cost REAL NOT NULL DEFAULT 0, performed_at INTEGER NOT NULL, receipt_path TEXT)');
      });
}

class _VersionTwoDatabase extends _LegacyDatabase {
  _VersionTwoDatabase(super.executor);
  @override
  int get schemaVersion => 2;
  @override
  MigrationStrategy get migration {
    final legacy = super.migration;
    return MigrationStrategy(onCreate: (m) async {
      await legacy.onCreate(m);
      await customStatement(
          'ALTER TABLE service_events ADD COLUMN maintenance_task TEXT');
      await customStatement(
          'ALTER TABLE service_events ADD COLUMN odometer_km INTEGER');
      await customStatement(
          'CREATE TABLE usage_readings (id TEXT NOT NULL PRIMARY KEY, asset_id TEXT NOT NULL REFERENCES assets(id), odometer_km INTEGER NOT NULL, recorded_at INTEGER NOT NULL)');
    });
  }
}

void main() {
  test('v3 service history survives adding performed-by metadata', () async {
    final directory = await Directory.systemTemp.createTemp('ayoslog_v3_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/legacy.sqlite');
    final old = _VersionTwoDatabase(NativeDatabase(file));
    await old.customStatement(
        "INSERT INTO assets (id, name, category, created_at) VALUES ('a', 'Generator', 'appliance', 1700000000)");
    await old.customStatement(
        "INSERT INTO service_events (id, asset_id, kind, description, cost, performed_at) VALUES ('s', 'a', 'routine', 'Existing service', 500, 1700000000)");
    // Build the exact added v3 structures, then mark the fixture as v3.
    await old.customStatement(
        'ALTER TABLE assets ADD COLUMN is_car INTEGER NOT NULL DEFAULT 0');
    await old.customStatement(
        "CREATE TABLE task_rules (id TEXT NOT NULL PRIMARY KEY, asset_id TEXT NOT NULL REFERENCES assets(id), task_name TEXT NOT NULL, task_key TEXT NOT NULL, component TEXT NOT NULL DEFAULT '', metric TEXT NOT NULL, source TEXT NOT NULL, usage_interval REAL, days_interval INTEGER, manufacturer_usage_limit REAL, manufacturer_days_limit INTEGER, manufacturer_reference TEXT)");
    await old.customStatement(
        'ALTER TABLE service_events ADD COLUMN task_rule_id TEXT REFERENCES task_rules(id)');
    await old.customStatement(
        "ALTER TABLE service_events ADD COLUMN component TEXT NOT NULL DEFAULT ''");
    await old.customStatement(
        'ALTER TABLE service_events ADD COLUMN usage_value REAL');
    await old.customStatement(
        "CREATE TABLE task_usage_readings (id TEXT NOT NULL PRIMARY KEY, asset_id TEXT NOT NULL REFERENCES assets(id), task_rule_id TEXT NOT NULL REFERENCES task_rules(id), value REAL, condition TEXT, notes TEXT NOT NULL DEFAULT '', recorded_at INTEGER NOT NULL)");
    await old.customStatement('PRAGMA user_version = 3');
    await old.close();
    final db = AppDatabase.forExecutor(NativeDatabase(file));
    expect((await db.select(db.serviceEvents).get()).single.performedBy, '');
    await RecordPredictiveService(DriftPredictionRepository(db))(ServiceDraft(
        assetId: 'a',
        description: 'New service',
        kind: 'routine',
        cost: 450,
        performedAt: DateTime(2025),
        performedBy: 'MotoCare'));
    await db.close();
    final restarted = AppDatabase.forExecutor(NativeDatabase(file));
    addTearDown(restarted.close);
    final rows = await restarted.select(restarted.serviceEvents).get();
    expect(rows.length, 2);
    expect(rows.where((r) => r.description == 'Existing service').single.cost,
        500);
    expect(rows.where((r) => r.description == 'New service').single.performedBy,
        'MotoCare');
  });
  test(
      'v2 mileage is preserved without classifying assets or inventing a tracking method',
      () async {
    final directory = await Directory.systemTemp.createTemp('ayoslog_v2_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/legacy.sqlite');
    final old = _VersionTwoDatabase(NativeDatabase(file));
    await old.customStatement(
        "INSERT INTO assets VALUES ('a', 'Vehicle', 'vehicle', '', '', 0, 1700000000)");
    await old.customStatement(
        "INSERT INTO service_events (id, asset_id, kind, description, cost, performed_at, maintenance_task, odometer_km) VALUES ('s', 'a', 'routine', 'Oil', 500, 1700000000, 'Engine oil', 8000)");
    await old.customStatement(
        "INSERT INTO usage_readings VALUES ('r', 'a', 9450, 1701000000)");
    await old.close();
    final db = AppDatabase.forExecutor(NativeDatabase(file));
    final repo = DriftPredictionRepository(db);
    var history = await repo.watchHistory('a').first;
    expect(history.isCar, isFalse);
    expect(history.rules, isEmpty);
    expect(history.services.single.odometerKm, 8000);
    expect(history.readings.single.km, 9450);
    expect(
        const BuildMaintenanceRecommendations()(history, DateTime.now())
            .recommendations
            .single
            .targetValue,
        isNull);
    await SaveTaskRule(repo)(
        'a',
        const TaskRule(
            name: 'Engine oil',
            metric: TrackingMetric.kilometres,
            source: RuleSource.user,
            usageInterval: 2000),
        markAsCar: true);
    history = await repo.watchHistory('a').first;
    expect(
        const BuildMaintenanceRecommendations()(history, DateTime.now())
            .recommendations
            .single
            .remainingKm,
        550);
    await db.close();
    final reopened = AppDatabase.forExecutor(NativeDatabase(file));
    addTearDown(reopened.close);
    final persisted =
        await DriftPredictionRepository(reopened).watchHistory('a').first;
    expect(persisted.isCar, isTrue);
    expect(persisted.rules.single.usageInterval, 2000);
  });

  test(
      'Non-car counters and observations persist and cannot share another task or asset',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    for (final id in ['a', 'b']) {
      await db.into(db.assets).insert(AssetsCompanion.insert(
          id: id, name: id, category: 'appliance', createdAt: DateTime(2025)));
    }
    final repo = DriftPredictionRepository(db);
    await expectLater(
        SaveTaskRule(repo)(
            'a', const TaskRule(name: 'Oil', metric: TrackingMetric.kilometres),
            markAsCar: true),
        throwsA(isA<PredictionValidationException>()));
    await SaveTaskRule(repo)(
        'a',
        const TaskRule(
            name: 'Clean',
            component: 'Filter',
            metric: TrackingMetric.hours,
            source: RuleSource.user,
            usageInterval: 100));
    await SaveTaskRule(repo)(
        'a',
        const TaskRule(
            name: 'Inspect',
            metric: TrackingMetric.condition,
            source: RuleSource.user));
    var history = await repo.watchHistory('a').first;
    final hours =
        history.rules.firstWhere((r) => r.metric == TrackingMetric.hours);
    final condition =
        history.rules.firstWhere((r) => r.metric == TrackingMetric.condition);
    await repo.addTaskReading(
        'a',
        TaskUsageReading(
            taskId: hours.id, value: 100.5, recordedAt: DateTime(2025, 1)));
    await repo.addTaskReading(
        'a',
        TaskUsageReading(
            taskId: hours.id, value: 200, recordedAt: DateTime(2025, 3)));
    await expectLater(
        repo.addTaskReading(
            'a',
            TaskUsageReading(
                taskId: hours.id, value: 250, recordedAt: DateTime(2025, 2))),
        throwsA(isA<PredictionValidationException>()));
    await expectLater(
        repo.addTaskReading(
            'b',
            TaskUsageReading(
                taskId: hours.id, value: 500, recordedAt: DateTime(2025, 4))),
        throwsA(isA<PredictionValidationException>()));
    await repo.addTaskReading(
        'a',
        TaskUsageReading(
            taskId: condition.id,
            condition: ObservedCondition.attention,
            notes: 'Debris',
            recordedAt: DateTime(2025, 4)));
    history = await repo.watchHistory('a').first;
    expect(history.usage.length, 3);
    expect(history.readings, isEmpty);
    expect(
        history.usage.where((r) => r.condition != null).single.notes, 'Debris');
    await expectLater(
        SaveTaskRule(repo)(
            'a',
            TaskRule(
                id: hours.id,
                name: hours.name,
                component: hours.component,
                metric: TrackingMetric.cycles)),
        throwsA(isA<PredictionValidationException>()));
    expect((await repo.watchHistory('b').first).usage, isEmpty);
  });

  test('Generic service and usage rollback together when the insert fails',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.assets).insert(AssetsCompanion.insert(
        id: 'a',
        name: 'Generator',
        category: 'appliance',
        createdAt: DateTime(2025)));
    final repo = DriftPredictionRepository(db);
    await SaveTaskRule(repo)(
        'a',
        const TaskRule(
            name: 'Clean',
            metric: TrackingMetric.hours,
            source: RuleSource.user,
            usageInterval: 100));
    final task = (await repo.watchHistory('a').first).rules.single;
    await db.customStatement(
        "CREATE TRIGGER reject_service BEFORE INSERT ON service_events BEGIN SELECT RAISE(ABORT, 'test failure'); END");
    await expectLater(
        RecordPredictiveService(repo)(ServiceDraft(
            assetId: 'a',
            taskId: task.id,
            description: 'Cleaned',
            kind: 'routine',
            cost: 100,
            usageValue: 50,
            performedAt: DateTime(2025, 2))),
        throwsA(anything));
    expect(await db.select(db.taskUsageReadings).get(), isEmpty);
    expect(await db.select(db.serviceEvents).get(), isEmpty);
  });
  Future<void> asset(AppDatabase db, String id) async {
    await db.into(db.assets).insert(AssetsCompanion.insert(
        id: id,
        name: id,
        category: 'vehicle',
        isCar: const Value(true),
        createdAt: DateTime(2025)));
  }

  ServiceDraft draft({int km = 1000, String? planId}) => ServiceDraft(
      assetId: 'a',
      task: 'Engine oil',
      odometerKm: km,
      description: 'Oil replaced',
      kind: 'routine',
      cost: 500,
      performedAt: DateTime(2025, 2),
      planId: planId);

  test(
      'v1 migration preserves assets, plans and services; readings survive restart',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('ayoslog_migration_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/test.sqlite');
    final old = _LegacyDatabase(NativeDatabase(file));
    await old.customStatement(
        "INSERT INTO assets VALUES ('a', 'Car', 'vehicle', '', '', 0, 1700000000)");
    await old.customStatement(
        "INSERT INTO maintenance_plans VALUES ('p', 'a', 'Oil', 3, 1700000000, 1)");
    await old.customStatement(
        "INSERT INTO service_events VALUES ('s', 'a', 'p', 'routine', 'Old service', 300, 1700000000, '/old.jpg')");
    await old.close();
    final upgraded = AppDatabase.forExecutor(NativeDatabase(file));
    expect((await upgraded.select(upgraded.assets).get()).single.name, 'Car');
    expect((await upgraded.select(upgraded.maintenancePlans).get()).single.id,
        'p');
    final service =
        (await upgraded.select(upgraded.serviceEvents).get()).single;
    expect(service.description, 'Old service');
    expect(service.receiptPath, '/old.jpg');
    expect(service.maintenanceTask, isNull);
    expect(service.odometerKm, isNull);
    expect(
        (await upgraded.select(upgraded.assets).get()).single.isCar, isFalse);
    await SaveTaskRule(DriftPredictionRepository(upgraded))('a',
        const TaskRule(name: 'Engine oil', metric: TrackingMetric.kilometres),
        markAsCar: true);
    await DriftPredictionRepository(upgraded)
        .addReading('a', MileageReading(km: 9450, recordedAt: DateTime(2025)));
    await upgraded.close();
    final restarted = AppDatabase.forExecutor(NativeDatabase(file));
    addTearDown(restarted.close);
    expect(
        (await DriftPredictionRepository(restarted).watchHistory('a').first)
            .readings
            .single
            .km,
        9450);
    expect((await restarted.select(restarted.serviceEvents).get()).single.cost,
        300);
  });

  test('Mileage is asset-scoped and backdated values fit surrounding readings',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await asset(db, 'a');
    await asset(db, 'b');
    final repo = DriftPredictionRepository(db);
    await repo.addReading(
        'a', MileageReading(km: 1000, recordedAt: DateTime(2025, 1)));
    await repo.addReading(
        'a', MileageReading(km: 2000, recordedAt: DateTime(2025, 3)));
    await repo.addReading(
        'a', MileageReading(km: 1500, recordedAt: DateTime(2025, 2)));
    await repo.addReading(
        'b', MileageReading(km: 10, recordedAt: DateTime(2025, 4)));
    await expectLater(
        repo.addReading(
            'a', MileageReading(km: 500, recordedAt: DateTime(2025, 2))),
        throwsA(isA<PredictionValidationException>()));
    expect((await repo.watchHistory('a').first).readings.length, 3);
    expect((await repo.watchHistory('b').first).readings.single.km, 10);
  });

  test(
      'Service, mileage and recurrence commit together; archiving keeps history',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await asset(db, 'a');
    await db.into(db.maintenancePlans).insert(MaintenancePlansCompanion.insert(
        id: 'p',
        assetId: 'a',
        title: 'Oil',
        intervalMonths: 3,
        nextDue: DateTime(2025, 2)));
    final repo = DriftPredictionRepository(db);
    await RecordPredictiveService(repo)(draft(planId: 'p'));
    final history = await repo.watchHistory('a').first;
    expect(history.services.single.odometerKm, 1000);
    expect(history.readings.single.km, 1000);
    expect((await db.select(db.maintenancePlans).get()).single.nextDue,
        DateTime(2025, 5));
    await (db.update(db.assets)..where((a) => a.id.equals('a')))
        .write(const AssetsCompanion(archived: Value(true)));
    expect((await repo.watchHistory('a').first).services.length, 1);
    await expectLater(
        repo.addReading(
            'a', MileageReading(km: 2000, recordedAt: DateTime(2025, 3))),
        throwsA(isA<PredictionValidationException>()));
    expect((await db.select(db.serviceEvents).get()).length, 1);
  });

  test('Failed service insert rolls back its reading and recurrence', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await asset(db, 'a');
    await db.into(db.maintenancePlans).insert(MaintenancePlansCompanion.insert(
        id: 'p',
        assetId: 'a',
        title: 'Oil',
        intervalMonths: 3,
        nextDue: DateTime(2025, 2)));
    await db.customStatement(
        "CREATE TRIGGER reject_service BEFORE INSERT ON service_events BEGIN SELECT RAISE(ABORT, 'test failure'); END");
    await expectLater(
        RecordPredictiveService(DriftPredictionRepository(db))(
            draft(planId: 'p')),
        throwsA(anything));
    expect(await db.select(db.usageReadings).get(), isEmpty);
    expect(await db.select(db.serviceEvents).get(), isEmpty);
    expect((await db.select(db.maintenancePlans).get()).single.nextDue,
        DateTime(2025, 2));
  });

  test('Cross-asset plans and invalid costs are rejected', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await asset(db, 'a');
    await asset(db, 'b');
    await db.into(db.maintenancePlans).insert(MaintenancePlansCompanion.insert(
        id: 'p',
        assetId: 'b',
        title: 'Oil',
        intervalMonths: 3,
        nextDue: DateTime(2025, 2)));
    final save = RecordPredictiveService(DriftPredictionRepository(db));
    await expectLater(save(draft(planId: 'p')),
        throwsA(isA<PredictionValidationException>()));
    expect(await db.select(db.serviceEvents).get(), isEmpty);
    expect(await db.select(db.usageReadings).get(), isEmpty);
    expect(
        () => save(ServiceDraft(
            assetId: 'a',
            description: 'Oil',
            kind: 'routine',
            cost: double.nan,
            performedAt: DateTime(2025))),
        throwsA(isA<PredictionValidationException>()));
  });
}
