import 'dart:convert';
import '../../../core/database/app_database.dart' hide ForecastAudit;
import '../domain/forecast_models.dart';
import '../domain/forecast_repository.dart';
import '../domain/forecast_usecases.dart';

/// Shared by observation writes and the existing service transaction.
class ForecastLocalStore {
  const ForecastLocalStore(this.db);
  final AppDatabase db;
  Future<ForecastData> read() async {
    final assets = await db.select(db.assets).get();
    final profiles = await db.select(db.assetProfiles).get();
    final policies = await db.select(db.forecastPolicies).get();
    final rules = await db.select(db.taskRules).get();
    final entries = await db.select(db.forecastEntries).get();
    final measures = await db.select(db.forecastMeasures).get();
    final signals = await db.select(db.forecastSignals).get();
    final events = await db.select(db.serviceEvents).get();
    final audits = await db.select(db.forecastAudits).get();
    final tasks = policies.map((p) {
      final rule =
          rules.firstWhere((r) => r.id == p.taskId && r.assetId == p.assetId);
      final json = Map<String, dynamic>.from(jsonDecode(p.policyJson) as Map);
      // Existing task-rule editor remains authoritative for interval changes.
      json['interval'] = rule.manufacturerUsageLimit ?? rule.usageInterval;
      if (rule.manufacturerUsageLimit != null && rule.usageInterval != null) {
        json['interval'] = rule.manufacturerUsageLimit! < rule.usageInterval!
            ? rule.manufacturerUsageLimit
            : rule.usageInterval;
      }
      json['intervalDays'] = rule.manufacturerDaysLimit ?? rule.daysInterval;
      if (rule.manufacturerDaysLimit != null && rule.daysInterval != null) {
        json['intervalDays'] = rule.manufacturerDaysLimit! < rule.daysInterval!
            ? rule.manufacturerDaysLimit
            : rule.daysInterval;
      }
      return ForecastTask.fromJson(json);
    }).toList();
    return ForecastData(
        assets: assets
            .map((a) => ForecastAsset(
                a.id,
                a.name,
                a.category,
                a.archived,
                a.assetSubtype == null
                    ? null
                    : AssetSubtype.values
                        .where((s) => s.name == a.assetSubtype)
                        .firstOrNull,
                _profile(profiles
                    .where((p) => p.assetId == a.id && p.category == a.category)
                    .firstOrNull
                    ?.detailsJson)))
            .toList(),
        tasks: tasks,
        observations: entries
            .map((e) => Observation(
                    id: e.id,
                    assetId: e.assetId,
                    taskId: e.taskId,
                    at: e.observedAt.toUtc(),
                    source: EvidenceSource.values.byName(e.source),
                    notes: e.notes,
                    reset: e.counterReset,
                    confirmed: e.outlierConfirmed,
                    version: e.version,
                    deleted: e.deletedAt != null,
                    values: {
                      for (final m in measures.where((m) => m.entryId == e.id))
                        m.metricKey: m.numericValue
                    },
                    conditions: {
                      for (final s in signals.where((s) => s.entryId == e.id))
                        s.conditionKey: s.value
                    }))
            .toList(),
        completions: events
            .where((e) =>
                tasks.any((t) => t.id == e.taskRuleId) &&
                ['routine', 'inspection'].contains(e.kind))
            .map((e) => ForecastCompletion(
                id: e.id,
                assetId: e.assetId,
                taskId: e.taskRuleId!,
                at: e.performedAt.toUtc(),
                description: e.description,
                receiptPath: e.receiptPath,
                kind: e.kind,
                performedBy: e.performedBy,
                cost: e.cost,
                value: e.usageValue ?? e.odometerKm?.toDouble(),
                voided: e.voided,
                batteryReplaced: e.batteryReplaced,
                version: e.revision))
            .toList(),
        audit: audits
            .map((a) => ForecastAudit(a.recordId, a.taskId, a.action,
                a.changedAt.toUtc(), a.beforeJson, a.afterJson))
            .toList());
  }

  Map<String, String> _profile(String? json) {
    if (json == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(json) as Map);
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  Future<void> recalculate(String assetId, {DateTime? now}) async {
    final data = await read();
    final insights =
        const CalculateInsights()(data, now ?? DateTime.now().toUtc());
    for (final item in insights
        .where((i) => i.assetId == assetId && i.prediction != null)) {
      final p = item.prediction!;
      await db.into(db.forecastSnapshots).insertOnConflictUpdate(
          ForecastSnapshotsCompanion.insert(
              taskId: p.task.id,
              algorithmVersion: ForecastPrediction.algorithm,
              inputHash: p.inputHash,
              snapshotJson: jsonEncode(p.toJson()),
              calculatedAt: p.calculatedAt.toUtc()));
    }
  }
}
