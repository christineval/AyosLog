import 'dart:io';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ayoslog/core/database/app_database.dart' as storage;
import 'package:ayoslog/core/providers.dart';
import 'package:ayoslog/core/theme/app_theme.dart';
import 'package:ayoslog/features/assets/domain/entities/asset.dart';
import 'package:ayoslog/features/assets/domain/entities/asset_category.dart';
import 'package:ayoslog/features/assets/domain/usecases/create_asset.dart';
import 'package:ayoslog/features/assets/data/repositories/drift_asset_repository.dart';
import 'package:ayoslog/features/assets/presentation/views/add_asset_page.dart';
import 'package:ayoslog/features/assets/presentation/views/asset_category_page.dart';
import 'package:ayoslog/features/assets/presentation/views/asset_detail_page.dart';
import 'package:ayoslog/features/maintenance/data/drift_service_history_repository.dart';
import 'package:ayoslog/features/maintenance/data/maintenance_repository.dart';
import 'package:ayoslog/features/maintenance/domain/category_service_fields.dart';
import 'package:ayoslog/features/maintenance/domain/service_history.dart';
import 'package:ayoslog/features/predictions/domain/forecast_models.dart';
import 'package:ayoslog/features/predictions/domain/prediction_models.dart';
import 'package:ayoslog/features/predictions/domain/prediction_usecases.dart';
import 'package:ayoslog/features/predictions/data/drift_prediction_repository.dart';
import 'package:ayoslog/shared/widgets/app_dropdown.dart';
import 'package:ayoslog/shared/widgets/upcoming_maintenance_card.dart';
import 'helpers/fake_asset_repository.dart';
import 'helpers/fake_prediction_repository.dart';
import 'helpers/fake_service_history_repository.dart';

class _EarlyV6 extends storage.AppDatabase {
  _EarlyV6(super.executor, this.nullable) : super.forExecutor();
  final bool nullable;
  @override
  int get schemaVersion => 6;
  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (m) async {
        await m.createAll();
        await customStatement('DROP TABLE asset_profiles');
        await customStatement(
            'ALTER TABLE service_events DROP COLUMN usage_unit');
        await customStatement(
            'ALTER TABLE service_events DROP COLUMN battery_replaced');
        if (nullable) {
          await customStatement(
              'ALTER TABLE service_events ADD COLUMN battery_replaced INTEGER');
        }
      });
}

void main() {
  for (final nullable in [false, true]) {
    test(
        'early v6 ${nullable ? 'null' : 'missing'} battery flag: service loading and category change recover',
        () async {
      final dir = await Directory.systemTemp.createTemp('ayoslog_repair_');
      final file = File('${dir.path}/test.sqlite');
      final old = _EarlyV6(NativeDatabase(file), nullable);
      await old.customStatement(
          "INSERT INTO assets(id,name,category,created_at) VALUES ('a','Bike','vehicle',1700000000)");
      await old.customStatement(
          "INSERT INTO service_events(id,asset_id,kind,description,cost,performed_at,receipt_path) VALUES ('s','a','routine','Existing work',450,1700000000,'old.jpg')");
      await old.close();
      final db = storage.AppDatabase.forExecutor(NativeDatabase(file));
      try {
        final service =
            (await DriftServiceHistoryRepository(db).watchRecords('a').first)
                .single;
        expect(service.cost, 450);
        expect(service.receiptPath, 'old.jpg');
        await DriftAssetRepository(db).changeCategory('a', 'air_conditioner',
            setup: const {'ac_type': 'split'});
        expect((await DriftAssetRepository(db).findById('a'))!.setup['ac_type'],
            'split');
        expect((await db.select(db.serviceEvents).get()).single.batteryReplaced,
            false);
        await MaintenanceRepository(db).record(
            assetId: 'a',
            description: 'New work',
            kind: 'routine',
            cost: 0,
            performedAt: DateTime(2025));
        expect(
            (await DriftServiceHistoryRepository(db).watchRecords('a').first)
                .length,
            2);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    });
  }
  test('setup metadata validates and survives reopening and switching category',
      () async {
    final dir = await Directory.systemTemp.createTemp('ayoslog_setup_');
    final file = File('${dir.path}/test.sqlite');
    var db = storage.AppDatabase.forExecutor(NativeDatabase(file));
    final id = await CreateAsset(DriftAssetRepository(db))(
        name: 'Bike',
        category: 'vehicle',
        setup: const {
          'vehicle_type': 'motorcycle',
          'make_model': 'Honda Click'
        });
    await db.close();
    db = storage.AppDatabase.forExecutor(NativeDatabase(file));
    try {
      final repo = DriftAssetRepository(db);
      expect((await repo.findById(id))!.setup['make_model'], 'Honda Click');
      await repo.changeCategory(id, 'air_conditioner',
          setup: const {'ac_type': 'window'});
      final changed = (await repo.findById(id))!;
      expect(changed.setup['ac_type'], 'window');
      expect(changed.profiles['vehicle']!['vehicle_type'], 'motorcycle');
      expect(() => CreateAsset(repo)(name: 'Laptop', category: 'laptop'),
          throwsArgumentError);
      expect(() => validateAssetSetup('water_filter', {'household_size': '-1'}),
          throwsArgumentError);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });
  test(
      'motorcycle completion reading saves without falsely classifying it as a car',
      () async {
    final db = storage.AppDatabase.forExecutor(NativeDatabase.memory());
    try {
      final id = await CreateAsset(DriftAssetRepository(db))(
          name: 'Bike',
          category: 'vehicle',
          setup: const {'vehicle_type': 'motorcycle'});
      final reading = parseCategoryServiceReading(
          'vehicle', {'service_value': '1000', 'distance_unit': 'mi'});
      expect(reading.value, 1609.344);
      await RecordPredictiveService(DriftPredictionRepository(db))(ServiceDraft(
          assetId: id,
          description: 'Oil replaced',
          kind: 'routine',
          cost: 500,
          performedAt: DateTime(2025),
          task: 'Oil change',
          usageValue: reading.value,
          usageUnit: reading.unit));
      final saved =
          (await DriftServiceHistoryRepository(db).watchRecords(id).first)
              .single;
      expect(saved.usageValue, 1609.344);
      expect(saved.usageUnit, 'km');
      expect((await db.select(db.assets).get()).single.isCar, false);
      expect(
          () => parseCategoryServiceReading(
              'washing_machine', {'service_value': '2.5'}),
          throwsA(isA<ForecastValidation>()));
    } finally {
      await db.close();
    }
  });
  for (final dark in [false, true]) {
    testWidgets(
        'all asset setup fields follow category in ${dark ? 'dark' : 'light'}',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: const AddAssetPage())));
      await tester.pumpAndSettle();
      for (final category in AssetCategory.values) {
        final dropdown = tester
            .widgetList<AppDropdown<String>>(find.byType(AppDropdown<String>))
            .firstWhere((w) => w.label == 'Category');
        dropdown.onSelected(category.key);
        await tester.pumpAndSettle();
        for (final field in assetSetupFields(category.key)) {
          expect(find.text(field.label), findsOneWidget, reason: category.key);
        }
        expect(tester.takeException(), isNull);
      }
    });
    testWidgets(
        'returning from category editing refreshes without Future setState assertion in ${dark ? 'dark' : 'light'}',
        (tester) async {
      final asset = Asset(
          id: 'a',
          name: 'Bike',
          category: 'vehicle',
          createdAt: DateTime(2025));
      final router = GoRouter(initialLocation: '/assets/a', routes: [
        GoRoute(
            path: '/assets/:id',
            builder: (_, s) =>
                AssetDetailPage(assetId: s.pathParameters['id']!)),
        GoRoute(
            path: '/assets/:id/category',
            builder: (_, s) =>
                AssetCategoryPage(assetId: s.pathParameters['id']!)),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            assetRepositoryProvider
                .overrideWithValue(FakeAssetRepository([asset])),
            plansProvider.overrideWith((ref) => Stream.value([])),
            predictionRepositoryProvider
                .overrideWithValue(FakePredictionRepository()),
            serviceHistoryRepositoryProvider.overrideWithValue(
                FakeServiceHistoryRepository(const <ServiceRecord>[]))
          ],
          child: MaterialApp.router(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Change asset category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save category'));
      await tester.pumpAndSettle();
      expect(find.text('Asset details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'upcoming card uses asset heading and service/date underneath in ${dark ? 'dark' : 'light'}',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: Scaffold(
              body: UpcomingMaintenanceCard(
                  assetName: 'Honda Click',
                  serviceType: 'Oil change',
                  date: DateTime(2026, 11, 9),
                  label: 'Scheduled',
                  status: 'healthy',
                  onTap: () {}))));
      expect(tester.getTopLeft(find.text('Honda Click')).dy,
          lessThan(tester.getTopLeft(find.textContaining('Oil change ·')).dy));
      expect(tester.takeException(), isNull);
    });
  }
}
