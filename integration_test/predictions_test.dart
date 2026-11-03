import 'dart:io';
import 'package:ayoslog/core/database/app_database.dart';
import 'package:ayoslog/core/providers.dart';
import 'package:ayoslog/core/theme/app_theme.dart';
import 'package:ayoslog/features/assets/presentation/views/asset_detail_page.dart';
import 'package:ayoslog/features/maintenance/presentation/views/add_service_page.dart';
import 'package:ayoslog/features/predictions/data/drift_prediction_repository.dart';
import 'package:ayoslog/features/predictions/domain/prediction_models.dart';
import 'package:ayoslog/features/predictions/domain/prediction_usecases.dart';
import 'package:ayoslog/features/predictions/presentation/views/add_mileage_page.dart';
import 'package:ayoslog/shared/widgets/app_field.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'multi_usage_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerMultiUsageTests();
  testWidgets(
      'Mileage input refreshes prediction; service cost and data survive restart',
      (tester) async {
    // Isolated fixture: never create illustrative records in the user's database.
    final directory =
        await Directory.systemTemp.createTemp('ayoslog_prediction_');
    final file = File('${directory.path}/test.sqlite');
    var db = AppDatabase.forExecutor(NativeDatabase(file));
    final router = GoRouter(initialLocation: '/assets/test', routes: [
      GoRoute(
          path: '/assets/test',
          pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AssetDetailPage(assetId: 'test'))),
      GoRoute(
          path: '/assets/test/usage/new',
          pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AddMileagePage(assetId: 'test'))),
      GoRoute(
          path: '/assets/test/service/new',
          pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AddServicePage(assetId: 'test'))),
    ]);
    try {
      final now = DateTime.now();
      await db.into(db.assets).insert(AssetsCompanion.insert(
          id: 'test',
          name: 'Test car',
          category: 'vehicle',
          isCar: const Value(true),
          createdAt: now));
      final save = RecordPredictiveService(DriftPredictionRepository(db));
      await SaveTaskRule(DriftPredictionRepository(db))(
          'test',
          const TaskRule(
              name: 'Engine oil', metric: TrackingMetric.kilometres));
      for (var i = 0; i < 3; i++) {
        await save(ServiceDraft(
            assetId: 'test',
            description: 'Oil replaced',
            kind: 'routine',
            cost: 500,
            task: 'Engine oil',
            odometerKm: 4000 + i * 2000,
            performedAt: now.subtract(Duration(days: 50 - i * 20))));
      }
      await tester.pumpWidget(ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(
              theme: AppTheme.dark(), routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('Maintenance reminders').hitTestable(), 160,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maintenance reminders'));
      await tester.pumpAndSettle();
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
          find.text('Update distance').hitTestable(), 200,
          scrollable: list);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update distance'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '9450');
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save reading'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save reading'));
      await tester.pumpAndSettle();
      expect(find.text('~550 km remaining'), findsOneWidget);

      // Exercise the real service form and its ViewModel/repository path.
      router.push('/assets/test/service/new');
      await tester.pumpAndSettle();
      Finder field(String label) => find.descendant(
          of: find.byWidgetPredicate(
              (widget) => widget is AppField && widget.label == label),
          matching: find.byType(TextFormField));
      Future<void> fill(String label, String value) async {
        await tester.scrollUntilVisible(field(label).hitTestable(), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.enterText(field(label), value);
      }

      await fill('What was done?', 'Engine oil replaced');
      await fill('Service cost (PHP)', '1000');
      await tester
          .ensureVisible(find.text('Link a maintenance reminder (optional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link a maintenance reminder (optional)'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.widgetWithText(TextField, 'No saved job').hitTestable(), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextField, 'No saved job'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Engine oil').hitTestable());
      await tester.pumpAndSettle();
      await fill('Dashboard distance at service (km)', '9450');
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('Save service record').hitTestable(), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save service record'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Higher cost than usual:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await db.close();
      db = AppDatabase.forExecutor(NativeDatabase(file));
      final report = const BuildMaintenanceRecommendations()(
          await DriftPredictionRepository(db).watchHistory('test').first,
          DateTime.now());
      expect(report.current!.km, 9450);
      expect(report.recommendations.single.sampleCount, 4);
      expect(report.recommendations.single.highCost, isTrue);
      expect(report.recommendations.single.targetKm, 11267);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}
