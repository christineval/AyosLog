import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ayoslog/core/database/app_database.dart';
import 'package:ayoslog/core/providers.dart';
import 'package:ayoslog/core/router/app_router.dart';
import 'package:ayoslog/core/theme/app_theme.dart';
import 'package:ayoslog/features/assets/domain/usecases/create_asset.dart';
import 'package:ayoslog/features/assets/data/repositories/drift_asset_repository.dart';
import 'package:ayoslog/features/maintenance/data/maintenance_repository.dart';
import 'package:ayoslog/features/maintenance/data/drift_service_history_repository.dart';
import 'package:ayoslog/shared/widgets/app_dropdown.dart';
import 'package:ayoslog/shared/widgets/app_field.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'category forms, service history and linked completion on Android',
      (tester) async {
    // Isolated memory database: never changes the phone owner's saved assets.
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftAssetRepository(db);
    final id = await CreateAsset(repo)(
        name: 'QA Motorcycle',
        category: 'vehicle',
        setup: const {'vehicle_type': 'motorcycle', 'make_model': 'QA model'});
    await MaintenanceRepository(db).record(
        assetId: id,
        description: 'Earlier brake check',
        maintenanceTask: 'Brake inspection',
        kind: 'inspection',
        cost: 350,
        performedAt: DateTime(2025));
    appRouter.go('/assets/$id');
    await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
            theme: AppTheme.light(), routerConfig: appRouter)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Brake inspection'), findsWidgets);

    Future<void> choose(String label, String value) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final field = tester
          .widgetList<AppDropdown<String>>(find.byType(AppDropdown<String>))
          .firstWhere((w) => w.label == label);
      field.onSelected(value);
      await tester.pumpAndSettle();
    }

    Future<void> enter(String label, String value) async {
      final parent =
          find.byWidgetPredicate((w) => w is AppField && w.label == label);
      await Scrollable.ensureVisible(tester.element(parent), alignment: .3);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(of: parent, matching: find.byType(TextField)), value);
    }

    Future<void> save(String label) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.byTooltip('Change asset category'));
    await tester.pumpAndSettle();
    await choose('Category', 'air_conditioner');
    await choose('Air conditioner type', 'split');
    await save('Save category');
    expect(find.text('Asset details'), findsOneWidget);
    expect((await repo.findById(id))!.setup['ac_type'], 'split');
    expect(
        (await DriftServiceHistoryRepository(db).watchRecords(id).first).length,
        1);

    appRouter.push('/assets/new');
    await tester.pumpAndSettle();
    await choose('Category', 'water_filter');
    await enter('Asset name', 'QA Water Filter');
    await enter('Filter model (optional)', 'QA model');
    await enter('Household size (optional)', '3');
    await save('Continue');
    expect(find.text('Set maintenance plan'), findsOneWidget);
    await save('Skip');
    final filter = (await repo.watchAssets().first)
        .firstWhere((a) => a.name == 'QA Water Filter');
    expect(filter.setup['household_size'], '3');
    appRouter.push('/assets/${filter.id}/schedules/new');
    await tester.pumpAndSettle();
    await choose('Maintenance task', 'Cartridge replacement');
    // Owner-defined illustrative test interval, never a manufacturer schedule.
    await enter('Rated filter capacity (L)', '2000');
    await enter('Counter at last service', '0');
    await save('Save maintenance plan');
    final policy = (await db.select(db.forecastPolicies).get()).single;
    appRouter.push('/assets/${filter.id}/service/new');
    await tester.pumpAndSettle();
    await choose('Maintenance plan (optional)', policy.taskId);
    await enter('Meter litres at replacement (optional)', '100');
    await enter('What was done?', 'Cartridge replaced');
    await enter('Service cost (PHP)', '450');
    await save('Save service record');
    final events =
        await DriftServiceHistoryRepository(db).watchRecords(filter.id).first;
    expect(events.single.usageValue, 100);
    expect(events.single.usageUnit, 'L');
    final snapshot = jsonDecode(
            (await db.select(db.forecastSnapshots).get()).single.snapshotJson)
        as Map;
    expect(snapshot['target'], 2100);
    expect((await repo.findById(filter.id))!.setup['filter_model'], 'QA model');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
