import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../domain/service_history.dart';
import '../../predictions/domain/prediction_models.dart';

class DriftServiceHistoryRepository implements ServiceHistoryRepository {
  const DriftServiceHistoryRepository(this.db);
  final AppDatabase db;
  @override
  Stream<List<ServiceRecord>> watchRecords(String assetId) => db
      .customSelect('SELECT 1',
          readsFrom: {db.serviceEvents, db.assets, db.taskRules})
      .watch()
      .asyncMap((_) => db.transaction(() async {
            final asset = await (db.select(db.assets)
                  ..where((a) => a.id.equals(assetId)))
                .getSingleOrNull();
            final events = await (db.select(db.serviceEvents)
                  ..where(
                      (e) => e.assetId.equals(assetId) & e.voided.equals(false))
                  ..orderBy([(e) => OrderingTerm.desc(e.performedAt)]))
                .get();
            final rules = await (db.select(db.taskRules)
                  ..where((r) => r.assetId.equals(assetId)))
                .get();
            return events.map((e) {
              var unit = e.usageUnit.isNotEmpty
                  ? e.usageUnit
                  : e.odometerKm == null
                      ? ''
                      : 'km';
              for (final rule in rules) {
                if (unit.isEmpty && rule.id == e.taskRuleId) {
                  unit = TrackingMetric.values
                          .where((m) => m.name == rule.metric)
                          .firstOrNull
                          ?.unit ??
                      '';
                }
              }
              return ServiceRecord(
                  id: e.id,
                  assetId: e.assetId,
                  assetName: asset?.name ?? 'Asset',
                  description: e.description,
                  kind: e.kind,
                  cost: e.cost,
                  performedAt: e.performedAt,
                  task: e.maintenanceTask ?? '',
                  component: e.component,
                  performedBy: e.performedBy,
                  receiptPath: e.receiptPath,
                  usageValue: e.usageValue ?? e.odometerKm?.toDouble(),
                  usageUnit: unit);
            }).toList();
          }));
}
