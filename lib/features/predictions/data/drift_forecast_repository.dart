import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../maintenance/data/maintenance_repository.dart';
import '../../maintenance/data/local_receipt_store.dart';
import '../../maintenance/domain/maintenance_rules.dart';
import '../domain/category_templates.dart';
import '../domain/forecast_models.dart';
import '../domain/forecast_engine.dart';
import '../domain/forecast_repository.dart';
import 'forecast_local_store.dart';

class DriftForecastRepository implements ForecastRepository {
  const DriftForecastRepository(this.db);
  final AppDatabase db;
  ForecastLocalStore get store => ForecastLocalStore(db);
  @override
  Stream<ForecastData> watch() => db
      .customSelect('SELECT 1', readsFrom: {
        db.assets,
        db.assetProfiles,
        db.taskRules,
        db.forecastPolicies,
        db.forecastEntries,
        db.forecastMeasures,
        db.forecastSignals,
        db.forecastAudits,
        db.serviceEvents
      })
      .watch()
      .asyncMap((_) => db.transaction(store.read));

  Future<void> _active(String assetId) async {
    final a = await (db.select(db.assets)..where((a) => a.id.equals(assetId)))
        .getSingleOrNull();
    if (a == null || a.archived) {
      throw const ForecastValidation('This asset is missing or archived.');
    }
  }

  Future<ForecastTask> _task(String assetId, String taskId) async {
    await _active(assetId);
    final data = await store.read();
    final found =
        data.tasks.where((t) => t.id == taskId && t.assetId == assetId);
    if (found.isEmpty) {
      throw const ForecastValidation(
          'This maintenance plan does not belong to this asset.');
    }
    return found.first;
  }

  Future<void> _audit(String asset, String task, String id, String action,
      Object? before, Object? after) async {
    await db.into(db.forecastAudits).insert(ForecastAuditsCompanion.insert(
        id: const Uuid().v4(),
        assetId: asset,
        taskId: task,
        recordId: id,
        action: action,
        beforeJson: Value(before == null ? null : jsonEncode(before)),
        afterJson: Value(after == null ? null : jsonEncode(after)),
        changedAt: DateTime.now().toUtc()));
  }

  @override
  Future<void> saveTask(ForecastTask task) => db.transaction(() async {
        validateForecastTask(task, DateTime.now().toUtc());
        final setupErrors = validateCategoryFields(
            categoryTemplates[task.subtype]!.setup, task.setup);
        if (setupErrors.isNotEmpty) {
          throw ForecastValidation(setupErrors.values.first);
        }
        await _active(task.assetId);
        final asset = await (db.select(db.assets)
              ..where((a) => a.id.equals(task.assetId)))
            .getSingle();
        if (!subtypesForCategory(asset.category).contains(task.subtype)) {
          throw const ForecastValidation(
              'The plan type must match the asset category. Change the asset category first.');
        }
        final before = (await store.read())
            .tasks
            .where((t) => t.id == task.id)
            .firstOrNull;
        if (before != null &&
            (before.assetId != task.assetId ||
                before.version != task.version)) {
          throw const ForecastValidation(
              'The plan changed. Reopen it before saving.');
        }
        if (before != null &&
            (before.metric != task.metric ||
                before.method != task.method ||
                before.subtype != task.subtype ||
                before.unit != task.unit)) {
          throw const ForecastValidation(
              'Create a separate plan to change its measurement or usage method.');
        }
        final updated = ForecastTask.fromJson({
          ...task.toJson(),
          'version': before == null ? 1 : before.version + 1
        });
        final legacyMetric = switch (task.metric) {
          ForecastMetric.distance => 'kilometres',
          ForecastMetric.hours => 'hours',
          ForecastMetric.litres => 'litres',
          ForecastMetric.cycles => 'cycles',
          _ => 'condition',
        };
        await db.into(db.taskRules).insertOnConflictUpdate(
            TaskRulesCompanion.insert(
                id: task.id,
                assetId: task.assetId,
                taskName: task.name.trim(),
                taskKey: task.name.trim().toLowerCase(),
                component: Value('forecast:${task.id}'),
                metric: legacyMetric,
                source: task.source == PlanSource.manufacturer
                    ? 'manufacturer'
                    : 'user',
                usageInterval: Value(
                    task.source == PlanSource.owner ? task.interval : null),
                daysInterval: Value(
                    task.source == PlanSource.owner ? task.intervalDays : null),
                manufacturerUsageLimit: Value(
                    task.source == PlanSource.manufacturer
                        ? task.interval
                        : null),
                manufacturerDaysLimit: Value(
                    task.source == PlanSource.manufacturer
                        ? task.intervalDays
                        : null),
                manufacturerReference:
                    Value(task.reference.isEmpty ? null : task.reference)));
        await db.into(db.forecastPolicies).insertOnConflictUpdate(
            ForecastPoliciesCompanion.insert(
                taskId: task.id,
                assetId: task.assetId,
                policyJson: jsonEncode(updated.toJson()),
                version: Value(updated.version)));
        await (db.update(db.assets)..where((a) => a.id.equals(task.assetId)))
            .write(AssetsCompanion(assetSubtype: Value(task.subtype.name)));
        await _audit(task.assetId, task.id, task.id, 'plan_saved',
            before?.toJson(), updated.toJson());
        await store.recalculate(task.assetId);
      });

  @override
  Future<void> saveObservation(Observation observation) =>
      db.transaction(() async {
        final task = await _task(observation.assetId, observation.taskId);
        final data = await store.read();
        final before =
            data.observations.where((o) => o.id == observation.id).firstOrNull;
        if (before != null &&
            (before.assetId != observation.assetId ||
                before.taskId != observation.taskId ||
                before.version != observation.version ||
                before.deleted)) {
          throw const ForecastValidation(
              'The reading changed. Reopen history before correcting it.');
        }
        final checked = buildObservation(
            task: task,
            id: observation.id,
            values: {
              for (final e in observation.values.entries)
                e.key: e.value.toString(),
              ...observation.conditions,
              'unit': task.unit
            },
            at: DateTime.fromMillisecondsSinceEpoch(
                (observation.at.millisecondsSinceEpoch ~/ 1000) * 1000,
                isUtc: true),
            now: DateTime.now().toUtc(),
            source: observation.source,
            notes: observation.notes,
            reset: observation.reset,
            confirmed: observation.confirmed,
            version: before == null ? 1 : before.version + 1,
            conditionsOnly: observation.values.isEmpty);
        final others =
            data.observations.where((o) => o.id != checked.id).toList();
        if (task.subtype == AssetSubtype.laptop &&
            checked.values.containsKey('cycle_count')) {
          final replacements = data.completions
              .where(
                  (c) => c.taskId == task.id && !c.voided && c.batteryReplaced)
              .toList()
            ..sort((a, b) => a.at.compareTo(b.at));
          final previous = replacements
              .where((c) => !c.at.isAfter(checked.at))
              .lastOrNull
              ?.at;
          final next = replacements
              .where((c) => c.at.isAfter(checked.at))
              .firstOrNull
              ?.at;
          final cycles = [...others, checked]
              .where((o) =>
                  o.taskId == task.id &&
                  !o.deleted &&
                  o.values.containsKey('cycle_count') &&
                  (previous == null || !o.at.isBefore(previous)) &&
                  (next == null || o.at.isBefore(next)))
              .toList()
            ..sort((a, b) => a.at.compareTo(b.at));
          for (var i = 1; i < cycles.length; i++) {
            if (cycles[i].values['cycle_count']! <
                cycles[i - 1].values['cycle_count']!) {
              throw const ForecastValidation(
                  'Charge cycle count decreased. Correct the reading or record a battery replacement first.');
            }
          }
        }
        final result = const PredictionEngine()
            .calculate(task, [...others, checked], DateTime.now().toUtc());
        if (result.state == ForecastState.invalid) {
          throw ForecastValidation(result.rationale.last);
        }
        final prev = others
            .where((o) =>
                o.taskId == task.id &&
                !o.deleted &&
                o.at.isBefore(checked.at) &&
                o.values['reading'] != null)
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
        if (task.metric == ForecastMetric.distance &&
            !checked.reset &&
            !checked.confirmed &&
            prev.isNotEmpty &&
            checked.values['reading'] != null) {
          final days =
              checked.at.difference(prev.last.at).inMilliseconds / 86400000;
          if (days > 0 &&
              (checked.values['reading']! - prev.last.values['reading']!) /
                      days >
                  2000) {
            throw const ForecastValidation(
                'Confirm this unusually large odometer increase before saving.');
          }
        }
        await db.into(db.forecastEntries).insertOnConflictUpdate(
            ForecastEntriesCompanion.insert(
                id: checked.id,
                taskId: checked.taskId,
                assetId: checked.assetId,
                observedAt: checked.at.toUtc(),
                source: checked.source.name,
                notes: Value(checked.notes),
                counterReset: Value(checked.reset),
                outlierConfirmed: Value(checked.confirmed),
                version: Value(checked.version)));
        await (db.delete(db.forecastMeasures)
              ..where((m) => m.entryId.equals(checked.id)))
            .go();
        await (db.delete(db.forecastSignals)
              ..where((m) => m.entryId.equals(checked.id)))
            .go();
        for (final e in checked.values.entries) {
          await db
              .into(db.forecastMeasures)
              .insert(ForecastMeasuresCompanion.insert(
                  entryId: checked.id,
                  metricKey: e.key,
                  numericValue: e.value,
                  canonicalUnit: e.key == 'reading'
                      ? task.unit
                      : e.key == 'daily_rate'
                          ? '${task.unit}/day'
                          : e.key));
        }
        for (final e in checked.conditions.entries) {
          await db.into(db.forecastSignals).insert(
              ForecastSignalsCompanion.insert(
                  entryId: checked.id, conditionKey: e.key, value: e.value));
        }
        await _audit(
            checked.assetId,
            checked.taskId,
            checked.id,
            before == null ? 'reading_added' : 'reading_corrected',
            before?.toJson(),
            checked.toJson());
        await store.recalculate(checked.assetId);
      });
  @override
  Future<void> deleteObservation(
          String assetId, String taskId, String id, int version) =>
      db.transaction(() async {
        await _task(assetId, taskId);
        final before = (await store.read())
            .observations
            .where(
                (r) => r.id == id && r.taskId == taskId && r.assetId == assetId)
            .firstOrNull;
        if (before == null || before.version != version || before.deleted) {
          throw const ForecastValidation(
              'The reading changed. Reload history.');
        }
        await (db.update(db.forecastEntries)..where((r) => r.id.equals(id)))
            .write(ForecastEntriesCompanion(
                deletedAt: Value(DateTime.now().toUtc()),
                version: Value(version + 1)));
        await _audit(
            assetId, taskId, id, 'reading_deleted', before.toJson(), null);
        await store.recalculate(assetId);
      });
  @override
  Future<void> complete(ForecastCompletion c) => db.transaction(() async {
        final task = await _task(c.assetId, c.taskId);
        if (!c.cost.isFinite ||
            c.cost < 0 ||
            c.description.trim().isEmpty ||
            c.description.length > 1000 ||
            c.at.isAfter(DateTime.now()) ||
            c.at.isBefore(task.baselineAt)) {
          throw const ForecastValidation(
              'Check the service date, work and cost.');
        }
        if (!c.voided &&
            task.method == UsageMethod.counter &&
            task.metric.counter &&
            ((c.value == null && task.subtype == AssetSubtype.vehicle) ||
                c.value != null &&
                    (!c.value!.isFinite ||
                        c.value! < 0 ||
                        c.value! > 1e12 ||
                        task.metric == ForecastMetric.cycles &&
                            c.value! % 1 != 0))) {
          throw const ForecastValidation(
              'Enter the actual cumulative counter at service.');
        }
        final before = await (db.select(db.serviceEvents)
              ..where((e) => e.id.equals(c.id)))
            .getSingleOrNull();
        if (before != null &&
            (before.assetId != c.assetId ||
                before.taskRuleId != c.taskId ||
                before.revision != c.version ||
                before.voided)) {
          throw const ForecastValidation(
              'This service changed or belongs to another task. Reload history.');
        }
        if (before == null && c.voided) {
          throw const ForecastValidation('Service not found.');
        }
        if (before == null) {
          await MaintenanceRepository(db).record(
              assetId: c.assetId,
              description: c.description.trim(),
              kind: c.kind,
              cost: c.cost,
              performedAt: c.at.toUtc(),
              taskRuleId: c.taskId,
              maintenanceTask: task.name,
              usageValue: c.value,
              batteryReplaced: c.batteryReplaced,
              receiptPath: c.receiptPath,
              performedBy: c.performedBy,
              usageUnit: task.unit,
              recordId: c.id);
        } else {
          final retained = before.receiptPath == c.receiptPath
              ? before.receiptPath
              : await const LocalReceiptStore().retain(c.receiptPath);
          await (db.update(db.serviceEvents)..where((e) => e.id.equals(c.id)))
              .write(ServiceEventsCompanion(
                  description: Value(c.description.trim()),
                  kind: Value(c.kind),
                  performedBy: Value(c.performedBy),
                  receiptPath: Value(retained),
                  usageUnit: Value(task.unit),
                  cost: Value(c.cost),
                  performedAt: Value(c.at.toUtc()),
                  usageValue: Value(c.value),
                  voided: Value(c.voided),
                  batteryReplaced: Value(c.batteryReplaced),
                  revision: Value(before.revision + 1)));
        }
        await _audit(
            c.assetId,
            c.taskId,
            c.id,
            c.voided
                ? 'service_cancelled'
                : before == null
                    ? 'service_completed'
                    : 'service_corrected',
            before?.toJson(),
            {
              'date': c.at.toUtc().toIso8601String(),
              'value': c.value,
              'cost': c.cost,
              'description': c.description,
              'batteryReplaced': c.batteryReplaced
            });
        if (before?.planId != null) {
          final plan = await (db.select(db.maintenancePlans)
                ..where((p) =>
                    p.id.equals(before!.planId!) & p.assetId.equals(c.assetId)))
              .getSingleOrNull();
          if (plan != null) {
            final active = await (db.select(db.serviceEvents)
                  ..where(
                      (e) => e.planId.equals(plan.id) & e.voided.equals(false))
                  ..orderBy([(e) => OrderingTerm.desc(e.performedAt)]))
                .get();
            final at =
                active.isEmpty ? task.baselineAt : active.first.performedAt;
            await (db.update(db.maintenancePlans)
                  ..where((p) => p.id.equals(plan.id)))
                .write(MaintenancePlansCompanion(
                    nextDue: Value(nextDueDate(at, plan.intervalMonths))));
          }
        }
        await store.recalculate(c.assetId);
      });
}
