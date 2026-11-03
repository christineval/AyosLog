import 'dart:io';
import 'package:ayoslog/core/database/app_database.dart';
import 'package:ayoslog/core/providers.dart';
import 'package:ayoslog/core/theme/app_theme.dart';
import 'package:ayoslog/features/assets/presentation/views/asset_detail_page.dart';
import 'package:ayoslog/features/predictions/data/drift_prediction_repository.dart';
import 'package:ayoslog/features/predictions/domain/prediction_models.dart';
import 'package:ayoslog/features/predictions/domain/prediction_usecases.dart';
import 'package:ayoslog/features/predictions/presentation/views/add_mileage_page.dart';
import 'package:ayoslog/shared/widgets/app_field.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void registerMultiUsageTests() {
  testWidgets(
      'Non-car hours, manufacturer caps and condition observations persist',
      (tester) async {
    final directory =
        await Directory.systemTemp.createTemp('ayoslog_multi_usage_');
    final file = File('${directory.path}/test.sqlite');
    var db = AppDatabase.forExecutor(NativeDatabase(file));
    final router = GoRouter(initialLocation: '/assets/a', routes: [
      GoRoute(
          path: '/assets/a',
          pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey, child: const AssetDetailPage(assetId: 'a'))),
      GoRoute(
          path: '/assets/a/usage/new',
          pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: AddMileagePage(
                  assetId: 'a', taskId: state.uri.queryParameters['task']))),
    ]);
    Future<void> reveal(Finder target) async {
      if (target.evaluate().isNotEmpty) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(target.hitTestable(), 180,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
    }

    try {
      final now = DateTime.now();
      await db.into(db.assets).insert(AssetsCompanion.insert(
          id: 'a',
          name: 'Test generator',
          category: 'appliance',
          createdAt: now));
      final repo = DriftPredictionRepository(db);
      await SaveTaskRule(repo)(
          'a',
          const TaskRule(
              name: 'Routine service',
              metric: TrackingMetric.hours,
              source: RuleSource.user,
              usageInterval: 100,
              daysInterval: 60,
              manufacturerUsageLimit: 80,
              manufacturerDaysLimit: 30,
              manufacturerReference: 'Test fixture manual reference'));
      await SaveTaskRule(repo)(
          'a',
          const TaskRule(
              name: 'Filter check',
              metric: TrackingMetric.condition,
              source: RuleSource.user));
      final task = (await repo.watchHistory('a').first)
          .rules
          .firstWhere((r) => r.metric == TrackingMetric.hours);
      await RecordPredictiveService(repo)(ServiceDraft(
          assetId: 'a',
          taskId: task.id,
          description: 'Serviced',
          kind: 'routine',
          cost: 100,
          usageValue: 300,
          performedAt: now.subtract(const Duration(days: 10))));
      await tester.pumpWidget(ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(
              theme: AppTheme.light(), routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('Maintenance reminders').hitTestable(), 160,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maintenance reminders'));
      await tester.pumpAndSettle();
      await reveal(find.text('Update total'));
      expect(find.text('Update distance'), findsNothing);
      await tester.tap(find.text('Update total'));
      await tester.pumpAndSettle();
      final usageField = find.descendant(
          of: find.byWidgetPredicate(
              (w) => w is AppField && w.label == 'Total hours used'),
          matching: find.byType(TextFormField));
      await tester.enterText(usageField, '350');
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pumpAndSettle();
      await reveal(find.text('Save reading'));
      await tester.tap(find.text('Save reading'));
      await tester.pumpAndSettle();
      expect(find.text('~30 hours remaining'), findsOneWidget);
      expect(find.text('Your product manual calls for an earlier limit.'),
          findsOneWidget);
      await reveal(find.text('Add a check'));
      await tester.tap(find.text('Add a check'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextField, 'Looks normal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Needs attention').hitTestable());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Visible debris');
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pumpAndSettle();
      await reveal(find.text('Save reading'));
      await tester.tap(find.text('Save reading'));
      await tester.pumpAndSettle();
      expect(find.text('Needs attention — reported by you'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await db.close();
      db = AppDatabase.forExecutor(NativeDatabase(file));
      final history =
          await DriftPredictionRepository(db).watchHistory('a').first;
      final report =
          const BuildMaintenanceRecommendations()(history, DateTime.now());
      expect(history.isCar, isFalse);
      expect(history.readings, isEmpty);
      expect(
          report.recommendations
              .firstWhere((r) => r.metric == TrackingMetric.hours)
              .remainingValue,
          30);
      expect(
          report.recommendations
              .firstWhere((r) => r.metric == TrackingMetric.condition)
              .condition,
          ObservedCondition.attention);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}
