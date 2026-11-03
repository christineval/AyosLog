import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../maintenance/data/maintenance_repository.dart';
import '../domain/prediction_models.dart';
import '../domain/prediction_repository.dart';
import '../domain/prediction_usecases.dart';

class DriftPredictionRepository implements PredictionRepository {
  const DriftPredictionRepository(this.db);
  final AppDatabase db;
  TaskRule _rule(StoredTaskRule r) => TaskRule(
      id: r.id,
      name: r.taskName,
      component: r.component,
      metric: TrackingMetric.values.byName(r.metric),
      source: RuleSource.values.byName(r.source),
      usageInterval: r.usageInterval,
      daysInterval: r.daysInterval,
      manufacturerUsageLimit: r.manufacturerUsageLimit,
      manufacturerDaysLimit: r.manufacturerDaysLimit,
      manufacturerReference: r.manufacturerReference);
  DateTime _seconds(DateTime date) => DateTime.fromMillisecondsSinceEpoch(
      (date.millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: date.isUtc);
  @override
  Stream<PredictionHistory> watchHistory(String assetId) => db
      .customSelect('SELECT 1', readsFrom: {
        db.assets,
        db.serviceEvents,
        db.usageReadings,
        db.taskRules,
        db.taskUsageReadings
      })
      .watch()
      .asyncMap((_) => db.transaction(() async {
            final asset = await (db.select(db.assets)
                  ..where((a) => a.id.equals(assetId)))
                .getSingleOrNull();
            if (asset == null) {
              throw const PredictionValidationException('Asset not found.');
            }
            final services = await (db.select(db.serviceEvents)
                  ..where((e) =>
                      e.assetId.equals(assetId) & e.voided.equals(false)))
                .get();
            final mileage = await (db.select(db.usageReadings)
                  ..where((r) => r.assetId.equals(assetId)))
                .get();
            final rules = await (db.select(db.taskRules)
                  ..where((r) => r.assetId.equals(assetId)))
                .get();
            final usage = await (db.select(db.taskUsageReadings)
                  ..where((r) => r.assetId.equals(assetId)))
                .get();
            return PredictionHistory(
                isCar: asset.isCar,
                category: asset.category,
                services: services
                    .where((r) =>
                        normalizeTask(r.maintenanceTask ?? '').isNotEmpty &&
                        !rules.any((rule) =>
                            rule.id == r.taskRuleId &&
                            rule.component.startsWith('forecast:')))
                    .map((r) => ServiceSample(
                        task: r.maintenanceTask!,
                        component: r.component,
                        taskId: r.taskRuleId,
                        kind: r.kind,
                        cost: r.cost,
                        performedAt: r.performedAt,
                        odometerKm: r.odometerKm,
                        usageValue: r.usageValue))
                    .toList(),
                readings: mileage
                    .map((r) => MileageReading(
                        km: r.odometerKm, recordedAt: r.recordedAt))
                    .toList(),
                rules: rules
                    .where((r) => !r.component.startsWith('forecast:'))
                    .map(_rule)
                    .toList(),
                usage: usage
                    .map((r) => TaskUsageReading(
                        taskId: r.taskRuleId,
                        recordedAt: r.recordedAt,
                        value: r.value,
                        condition: r.condition == null
                            ? null
                            : ObservedCondition.values.byName(r.condition!),
                        notes: r.notes))
                    .toList());
          }));
  Future<Asset> _requireActiveAsset(String assetId) async {
    final asset = await (db.select(db.assets)
          ..where((a) => a.id.equals(assetId)))
        .getSingleOrNull();
    if (asset == null || asset.archived) {
      throw const PredictionValidationException(
          'This asset is unavailable or archived.');
    }
    return asset;
  }

  Future<TaskRule> _requireRule(String assetId, String id) async {
    final stored = await (db.select(db.taskRules)
          ..where((r) => r.id.equals(id) & r.assetId.equals(assetId)))
        .getSingleOrNull();
    if (stored == null) {
      throw const PredictionValidationException(
          'The task must belong to this asset.');
    }
    return _rule(stored);
  }

  @override
  Future<void> saveRule(String assetId, TaskRule rule,
          {bool markAsCar = false}) =>
      db.transaction(() async {
        validateRule(rule);
        final asset = await _requireActiveAsset(assetId);
        if (markAsCar &&
            !['vehicle', 'car'].contains(asset.category.toLowerCase())) {
          throw const PredictionValidationException(
              'Only a vehicle can be marked as a car.');
        }
        if (rule.metric == TrackingMetric.kilometres &&
            !asset.isCar &&
            !markAsCar) {
          throw const PredictionValidationException(
              'Mark this vehicle as a car to enable mileage tracking.');
        }
        final existing = rule.id.isEmpty
            ? await (db.select(db.taskRules)
                  ..where((r) =>
                      r.assetId.equals(assetId) &
                      r.taskKey.equals(normalizeTask(rule.name)) &
                      r.component.equals(normalizeTask(rule.component))))
                .getSingleOrNull()
            : await (db.select(db.taskRules)
                  ..where(
                      (r) => r.assetId.equals(assetId) & r.id.equals(rule.id)))
                .getSingleOrNull();
        if (rule.id.isNotEmpty && existing == null) {
          throw const PredictionValidationException(
              'Task not found for this asset.');
        }
        if (existing != null &&
            (existing.metric != rule.metric.name ||
                existing.taskKey != normalizeTask(rule.name) ||
                existing.component != normalizeTask(rule.component))) {
          throw const PredictionValidationException(
              'Keep an existing task’s name, component and unit. Create another task for a different counter.');
        }
        if (markAsCar && !asset.isCar) {
          await (db.update(db.assets)..where((a) => a.id.equals(assetId)))
              .write(const AssetsCompanion(isCar: Value(true)));
        }
        await db.into(db.taskRules).insertOnConflictUpdate(
            TaskRulesCompanion.insert(
                id: existing?.id ?? const Uuid().v4(),
                assetId: assetId,
                taskName: rule.name.trim(),
                taskKey: normalizeTask(rule.name),
                component: Value(normalizeTask(rule.component)),
                metric: rule.metric.name,
                source: rule.source.name,
                usageInterval: Value(rule.usageInterval),
                daysInterval: Value(rule.daysInterval),
                manufacturerUsageLimit: Value(rule.manufacturerUsageLimit),
                manufacturerDaysLimit: Value(rule.manufacturerDaysLimit),
                manufacturerReference:
                    Value(rule.manufacturerReference?.trim())));
      });
  Future<void> _insertMileage(String assetId, MileageReading reading) async {
    reading = MileageReading(
        km: reading.km, recordedAt: _seconds(reading.recordedAt));
    final existing = await (db.select(db.usageReadings)
          ..where((r) => r.assetId.equals(assetId)))
        .get();
    validateReading(reading, DateTime.now(),
        existing: existing
            .map((r) =>
                MileageReading(km: r.odometerKm, recordedAt: r.recordedAt))
            .toList());
    if (existing.any((r) =>
        r.recordedAt.isAtSameMomentAs(reading.recordedAt) &&
        r.odometerKm == reading.km)) {
      return;
    }
    await db.into(db.usageReadings).insert(UsageReadingsCompanion.insert(
        id: const Uuid().v4(),
        assetId: assetId,
        odometerKm: reading.km,
        recordedAt: reading.recordedAt));
  }

  @override
  Future<void> addReading(String assetId, MileageReading reading) =>
      db.transaction(() async {
        final asset = await _requireActiveAsset(assetId);
        if (!asset.isCar) {
          throw const PredictionValidationException(
              'Mileage tracking is only enabled for cars.');
        }
        await _insertMileage(assetId, reading);
      });
  Future<void> _insertUsage(
      String assetId, TaskRule rule, TaskUsageReading reading) async {
    final date = _seconds(reading.recordedAt);
    validateTaskReading(reading, rule, DateTime.now());
    final existing = await (db.select(db.taskUsageReadings)
          ..where(
              (r) => r.assetId.equals(assetId) & r.taskRuleId.equals(rule.id)))
        .get();
    if (reading.value != null) {
      validateCounter(
          reading.value!,
          date,
          existing
              .where((r) => r.value != null)
              .map((r) => (r.value!, r.recordedAt))
              .toList());
      if (rule.metric == TrackingMetric.kilometres) {
        await _insertMileage(assetId,
            MileageReading(km: reading.value!.toInt(), recordedAt: date));
      }
    }
    if (existing.any((r) =>
        r.recordedAt.isAtSameMomentAs(date) &&
        r.value == reading.value &&
        r.condition == reading.condition?.name &&
        r.notes == reading.notes.trim())) {
      return;
    }
    await db.into(db.taskUsageReadings).insert(
        TaskUsageReadingsCompanion.insert(
            id: const Uuid().v4(),
            assetId: assetId,
            taskRuleId: rule.id,
            value: Value(reading.value),
            condition: Value(reading.condition?.name),
            notes: Value(reading.notes.trim()),
            recordedAt: date));
  }

  @override
  Future<void> addTaskReading(String assetId, TaskUsageReading reading) =>
      db.transaction(() async {
        final asset = await _requireActiveAsset(assetId);
        final rule = await _requireRule(assetId, reading.taskId);
        if (rule.metric == TrackingMetric.kilometres && !asset.isCar) {
          throw const PredictionValidationException(
              'Mileage is only available for cars.');
        }
        await _insertUsage(assetId, rule, reading);
      });
  @override
  Future<void> recordService(ServiceDraft draft) => db.transaction(() async {
        final asset = await _requireActiveAsset(draft.assetId);
        TaskRule? rule;
        if (draft.taskId != null) {
          rule = await _requireRule(draft.assetId, draft.taskId!);
        }
        if (draft.planId != null) {
          final plan = await (db.select(db.maintenancePlans)
                ..where((p) => p.id.equals(draft.planId!)))
              .getSingleOrNull();
          if (plan == null || plan.assetId != draft.assetId) {
            throw const PredictionValidationException(
                'The linked plan must belong to this asset.');
          }
        }
        if ((draft.odometerKm != null ||
                rule?.metric == TrackingMetric.kilometres) &&
            !asset.isCar) {
          throw const PredictionValidationException(
              'Mileage is only available for cars.');
        }
        final usage = draft.usageValue ?? draft.odometerKm?.toDouble();
        if (draft.usageValue != null && rule == null) {
          final unit = switch (asset.category) {
            'vehicle' => 'km',
            'air_conditioner' => 'hours',
            'water_filter' => 'L',
            'washing_machine' => 'cycles',
            _ => ''
          };
          if (unit.isEmpty ||
              draft.usageUnit != unit ||
              !draft.usageValue!.isFinite ||
              draft.usageValue! < 0 ||
              draft.usageValue! > 1e12 ||
              unit == 'cycles' && draft.usageValue! % 1 != 0) {
            throw const PredictionValidationException(
                'Enter a valid service reading in this asset’s unit.');
          }
        }
        if (usage != null && rule != null && rule.metric.numeric) {
          await _insertUsage(
              draft.assetId,
              rule,
              TaskUsageReading(
                  taskId: rule.id,
                  recordedAt: draft.performedAt,
                  value: usage));
        } else if (draft.odometerKm != null) {
          await _insertMileage(
              draft.assetId,
              MileageReading(
                  km: draft.odometerKm!, recordedAt: draft.performedAt));
        }
        final task = (rule?.name ?? draft.task ?? '')
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ');
        await MaintenanceRepository(db).record(
            assetId: draft.assetId,
            planId: draft.planId,
            description: draft.description.trim(),
            performedBy: draft.performedBy.trim(),
            kind: draft.kind,
            cost: draft.cost,
            performedAt: draft.performedAt,
            receiptPath: draft.receiptPath,
            maintenanceTask: task.isEmpty ? null : task,
            odometerKm: rule?.metric == TrackingMetric.kilometres
                ? usage?.toInt()
                : draft.odometerKm,
            taskRuleId: rule?.id,
            component: rule?.component ?? normalizeTask(draft.component),
            usageValue: usage,
            usageUnit: rule?.metric.unit ?? draft.usageUnit,
            batteryReplaced: draft.batteryReplaced);
      });
}
