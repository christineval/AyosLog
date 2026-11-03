import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
part 'app_database.g.dart';

class Assets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  TextColumn get category => text()();
  TextColumn get brand => text().withDefault(const Constant(''))();
  TextColumn get model => text().withDefault(const Constant(''))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  BoolColumn get isCar => boolean().withDefault(const Constant(false))();
  TextColumn get assetSubtype => text().nullable()();
  TextColumn get legacyCategory => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StoredAssetProfile')
class AssetProfiles extends Table {
  TextColumn get assetId => text().references(Assets, #id)();
  TextColumn get category => text()();
  TextColumn get detailsJson => text()();
  @override
  Set<Column> get primaryKey => {assetId, category};
}

class MaintenancePlans extends Table {
  TextColumn get id => text()();
  TextColumn get assetId => text().references(Assets, #id)();
  TextColumn get title => text()();
  IntColumn get intervalMonths => integer()();
  DateTimeColumn get nextDue => dateTime()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get reminderDays => integer().withDefault(const Constant(7))();
  @override
  Set<Column> get primaryKey => {id};
}

class ServiceEvents extends Table {
  TextColumn get id => text()();
  TextColumn get assetId => text().references(Assets, #id)();
  TextColumn get planId =>
      text().nullable().references(MaintenancePlans, #id)();
  TextColumn get kind => text()();
  TextColumn get description => text()();
  RealColumn get cost => real().withDefault(const Constant(0))();
  DateTimeColumn get performedAt => dateTime()();
  TextColumn get receiptPath => text().nullable()();
  TextColumn get maintenanceTask => text().nullable()();
  IntColumn get odometerKm => integer().nullable()();
  TextColumn get taskRuleId => text().nullable().references(TaskRules, #id)();
  TextColumn get component => text().withDefault(const Constant(''))();
  RealColumn get usageValue => real().nullable()();
  TextColumn get usageUnit => text().withDefault(const Constant(''))();
  TextColumn get performedBy => text().withDefault(const Constant(''))();
  BoolColumn get voided => boolean().withDefault(const Constant(false))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  BoolColumn get batteryReplaced =>
      boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class UsageReadings extends Table {
  TextColumn get id => text()();
  TextColumn get assetId => text().references(Assets, #id)();
  IntColumn get odometerKm => integer()();
  DateTimeColumn get recordedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StoredTaskRule')
class TaskRules extends Table {
  TextColumn get id => text()();
  TextColumn get assetId => text().references(Assets, #id)();
  TextColumn get taskName => text()();
  TextColumn get taskKey => text()();
  TextColumn get component => text().withDefault(const Constant(''))();
  TextColumn get metric => text()();
  TextColumn get source => text()();
  RealColumn get usageInterval => real().nullable()();
  IntColumn get daysInterval => integer().nullable()();
  RealColumn get manufacturerUsageLimit => real().nullable()();
  IntColumn get manufacturerDaysLimit => integer().nullable()();
  TextColumn get manufacturerReference => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
        {assetId, taskKey, component}
      ];
}

@DataClassName('StoredTaskUsageReading')
class TaskUsageReadings extends Table {
  TextColumn get id => text()();
  TextColumn get assetId => text().references(Assets, #id)();
  TextColumn get taskRuleId => text().references(TaskRules, #id)();
  RealColumn get value => real().nullable()();
  TextColumn get condition => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get recordedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class ForecastPolicies extends Table {
  TextColumn get taskId => text().references(TaskRules, #id)();
  TextColumn get assetId => text().references(Assets, #id)();
  TextColumn get policyJson => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  @override
  Set<Column> get primaryKey => {taskId};
}

class ForecastEntries extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(TaskRules, #id)();
  TextColumn get assetId => text().references(Assets, #id)();
  DateTimeColumn get observedAt => dateTime()();
  TextColumn get source => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get counterReset => boolean().withDefault(const Constant(false))();
  BoolColumn get outlierConfirmed =>
      boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class ForecastMeasures extends Table {
  TextColumn get entryId => text().references(ForecastEntries, #id)();
  TextColumn get metricKey => text()();
  RealColumn get numericValue => real()();
  TextColumn get canonicalUnit => text()();
  @override
  Set<Column> get primaryKey => {entryId, metricKey};
}

class ForecastSignals extends Table {
  TextColumn get entryId => text().references(ForecastEntries, #id)();
  TextColumn get conditionKey => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {entryId, conditionKey};
}

class ForecastAudits extends Table {
  TextColumn get id => text()();
  TextColumn get assetId => text().references(Assets, #id)();
  TextColumn get taskId => text().references(TaskRules, #id)();
  TextColumn get recordId => text()();
  TextColumn get action => text()();
  TextColumn get beforeJson => text().nullable()();
  TextColumn get afterJson => text().nullable()();
  TextColumn get actor => text().withDefault(const Constant('local_owner'))();
  DateTimeColumn get changedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class ForecastSnapshots extends Table {
  TextColumn get taskId => text().references(TaskRules, #id)();
  TextColumn get algorithmVersion => text()();
  TextColumn get inputHash => text()();
  TextColumn get snapshotJson => text()();
  DateTimeColumn get calculatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {taskId};
}

@DriftDatabase(tables: [
  Assets,
  AssetProfiles,
  MaintenancePlans,
  ServiceEvents,
  UsageReadings,
  TaskRules,
  TaskUsageReadings,
  ForecastPolicies,
  ForecastEntries,
  ForecastMeasures,
  ForecastSignals,
  ForecastAudits,
  ForecastSnapshots
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'ayoslog'));
  AppDatabase.forExecutor(super.executor);
  @override
  int get schemaVersion => 8;
  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(serviceEvents, serviceEvents.maintenanceTask);
          await m.addColumn(serviceEvents, serviceEvents.odometerKm);
          await m.createTable(usageReadings);
        }
        if (from < 3) {
          await m.addColumn(assets, assets.isCar);
          await m.createTable(taskRules);
          await m.addColumn(serviceEvents, serviceEvents.taskRuleId);
          await m.addColumn(serviceEvents, serviceEvents.component);
          await m.addColumn(serviceEvents, serviceEvents.usageValue);
          await m.createTable(taskUsageReadings);
        }
        if (from < 4) {
          await m.addColumn(serviceEvents, serviceEvents.performedBy);
        }
        if (from < 5) {
          await m.addColumn(assets, assets.assetSubtype);
          await m.addColumn(serviceEvents, serviceEvents.voided);
          await m.addColumn(serviceEvents, serviceEvents.revision);
          await m.addColumn(serviceEvents, serviceEvents.batteryReplaced);
          await m.createTable(forecastPolicies);
          await m.createTable(forecastEntries);
          await m.createTable(forecastMeasures);
          await m.createTable(forecastSignals);
          await m.createTable(forecastAudits);
          await m.createTable(forecastSnapshots);
        }
        if (from < 6) {
          await m.addColumn(assets, assets.legacyCategory);
          // Keep ambiguous broad categories for user correction; never guess
          // a refrigerator from an asset name or model.
          await customStatement(
              "UPDATE assets SET legacy_category = category WHERE category NOT IN ('vehicle','air_conditioner','refrigerator','laptop','water_filter','washing_machine','custom')");
          await customStatement(
              "UPDATE assets SET category = CASE WHEN category IN ('vehicle','air_conditioner','refrigerator','laptop','water_filter','washing_machine','custom') THEN category WHEN category = 'car' THEN 'vehicle' WHEN asset_subtype = 'airConditioner' THEN 'air_conditioner' WHEN asset_subtype = 'refrigerator' THEN 'refrigerator' WHEN asset_subtype = 'laptop' THEN 'laptop' WHEN asset_subtype = 'waterFilter' THEN 'water_filter' WHEN asset_subtype = 'washingMachine' THEN 'washing_machine' WHEN asset_subtype = 'vehicle' THEN 'vehicle' ELSE 'custom' END");
        }
        if (from < 7) {
          await m.createTable(assetProfiles);
          // Some early v5/v6 installations predate the final service columns.
          // Inspect the physical schema instead of trusting only user_version.
          final columns =
              (await customSelect('PRAGMA table_info(service_events)').get())
                  .map((r) => r.read<String>('name'))
                  .toSet();
          for (final column in [
            serviceEvents.usageUnit,
            serviceEvents.batteryReplaced,
            serviceEvents.voided,
            serviceEvents.revision,
            serviceEvents.performedBy,
            serviceEvents.component
          ]) {
            if (!columns.contains(column.$name)) {
              await m.addColumn(serviceEvents, column);
            }
          }
          await customStatement(
              "UPDATE service_events SET battery_replaced=COALESCE(battery_replaced,0), voided=COALESCE(voided,0), revision=COALESCE(revision,1), performed_by=COALESCE(performed_by,''), component=COALESCE(component,''), usage_unit=COALESCE(usage_unit,'')");
        }
        if (from < 8) {
          final names =
              (await customSelect('PRAGMA table_info(maintenance_plans)').get())
                  .map((r) => r.read<String>('name'))
                  .toSet();
          if (!names.contains('reminder_days')) {
            await m.addColumn(maintenancePlans, maintenancePlans.reminderDays);
          }
        }
      }, beforeOpen: (d) async {
        await customStatement('PRAGMA foreign_keys = ON');
      });
}
