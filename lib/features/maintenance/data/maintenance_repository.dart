import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../domain/maintenance_rules.dart';
import '../domain/maintenance_schedule.dart';
import '../../predictions/data/forecast_local_store.dart';
import '../domain/receipt_store.dart';
import 'local_receipt_store.dart';

class MaintenanceRepository implements MaintenanceScheduleRepository {
  const MaintenanceRepository(this.db,
      {this.receipts = const LocalReceiptStore()});
  final AppDatabase db;
  final ReceiptStore receipts;
  @override
  Future<void> saveSchedule(MaintenanceScheduleDraft draft) =>
      db.transaction(() async {
        final a = await (db.select(db.assets)
              ..where((a) => a.id.equals(draft.assetId)))
            .getSingleOrNull();
        if (a == null || a.archived) {
          throw StateError('This asset is missing or archived.');
        }
        final existing = await (db.select(db.maintenancePlans)
              ..where((p) => p.id.equals(draft.id)))
            .getSingleOrNull();
        if (existing != null && existing.assetId != draft.assetId) {
          throw StateError('The plan must belong to this asset.');
        }
        await db.into(db.maintenancePlans).insertOnConflictUpdate(
            MaintenancePlansCompanion.insert(
                id: draft.id,
                assetId: draft.assetId,
                title: draft.title.trim(),
                intervalMonths: draft.intervalMonths,
                nextDue: draft.firstDue,
                reminderDays: Value(draft.reminderDays)));
      });
  Stream<List<MaintenancePlan>> watchPlans() =>
      db.select(db.maintenancePlans).watch();
  Stream<List<ServiceEvent>> watchEvents(String assetId) =>
      (db.select(db.serviceEvents)
            ..where((e) => e.assetId.equals(assetId) & e.voided.equals(false))
            ..orderBy([(e) => OrderingTerm.desc(e.performedAt)]))
          .watch();
  Future<void> createPlan(
      {required String assetId,
      required String title,
      required int intervalMonths,
      required DateTime nextDue}) async {
    if (intervalMonths <= 0) throw ArgumentError('Invalid interval');
    await db.into(db.maintenancePlans).insert(MaintenancePlansCompanion.insert(
        id: const Uuid().v4(),
        assetId: assetId,
        title: title,
        intervalMonths: intervalMonths,
        nextDue: nextDue));
  }

  Future<void> record(
      {required String assetId,
      String? planId,
      required String description,
      required String kind,
      required double cost,
      required DateTime performedAt,
      String? receiptPath,
      String? maintenanceTask,
      int? odometerKm,
      String? taskRuleId,
      String component = '',
      double? usageValue,
      String performedBy = '',
      String? recordId,
      bool batteryReplaced = false,
      String usageUnit = ''}) async {
    if (cost < 0) throw ArgumentError('Cost must be nonnegative');
    final retainedReceipt = await receipts.retain(receiptPath);
    await db.transaction(() async {
      await db.into(db.serviceEvents).insert(ServiceEventsCompanion.insert(
          id: recordId ?? const Uuid().v4(),
          assetId: assetId,
          planId: Value(planId),
          description: description,
          kind: kind,
          cost: Value(cost),
          performedAt: performedAt,
          receiptPath: Value(retainedReceipt),
          maintenanceTask: Value(maintenanceTask),
          odometerKm: Value(odometerKm),
          taskRuleId: Value(taskRuleId),
          component: Value(component),
          usageValue: Value(usageValue),
          usageUnit: Value(usageUnit),
          performedBy: Value(performedBy),
          batteryReplaced: Value(batteryReplaced)));
      if (planId != null) {
        final p = await (db.select(db.maintenancePlans)
              ..where((x) => x.id.equals(planId)))
            .getSingleOrNull();
        if (p != null) {
          await (db.update(db.maintenancePlans)
                ..where((x) => x.id.equals(planId)))
              .write(MaintenancePlansCompanion(
                  nextDue: Value(nextDueDate(performedAt, p.intervalMonths))));
        }
      }
      await ForecastLocalStore(db).recalculate(assetId);
    });
  }
}
