import 'package:ayoslog/core/providers.dart';
import 'package:ayoslog/core/theme/app_theme.dart';
import 'package:ayoslog/features/predictions/domain/prediction_models.dart';
import 'package:ayoslog/features/predictions/presentation/views/prediction_panel.dart';
import 'package:ayoslog/features/predictions/presentation/views/task_rule_page.dart';
import 'package:ayoslog/shared/widgets/app_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers/fake_prediction_repository.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
        'Non-car task can save hours and a referenced manufacturer cap in ${dark ? 'dark' : 'light'}',
        (tester) async {
      TaskRule? saved;
      final repo = FakePredictionRepository(
          history: const PredictionHistory(
              services: [], readings: [], category: 'appliance'),
          onSaveRule: (_, rule, markAsCar) async {
            saved = rule;
            expect(markAsCar, isFalse);
          });
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
                body: TextButton(
                    onPressed: () => context.push('/task'),
                    child: const Text('Configure task')))),
        GoRoute(
            path: '/task',
            builder: (_, __) => const TaskRulePage(assetId: 'a')),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [predictionRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              routerConfig: router)));
      await tester.tap(find.text('Configure task'));
      await tester.pumpAndSettle();
      Finder field(String label) => find.descendant(
          of: find.byWidgetPredicate((w) => w is AppField && w.label == label),
          matching: find.byType(TextFormField));
      Future<void> reveal(Finder finder) async {
        await tester.scrollUntilVisible(finder.hitTestable(), 150,
            scrollable: find
                .descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable))
                .first);
        await tester.pumpAndSettle();
      }

      await tester.enterText(field('What needs to be done?'), 'Cleaning');
      await tester.enterText(field('Which part? (optional)'), 'Filter');
      await reveal(find.widgetWithText(TextField, 'Days since service'));
      await tester.tap(find.widgetWithText(TextField, 'Days since service'));
      await tester.pumpAndSettle();
      expect(find.text('Distance driven (car)').hitTestable(), findsNothing);
      await tester.tap(find.text('Hours used').hitTestable());
      await tester.pumpAndSettle();
      await reveal(field('Repeat every (hours)'));
      await tester.enterText(field('Repeat every (hours)'), '100');
      await reveal(find.text('Use limits from the product manual'));
      await tester.tap(find.text('Use limits from the product manual'));
      await tester.pumpAndSettle();
      await reveal(field('Manual: repeat every (hours)'));
      await tester.enterText(field('Manual: repeat every (hours)'), '80');
      await reveal(field('Manual: repeat every (days)'));
      await tester.enterText(field('Manual: repeat every (days)'), '30');
      await reveal(field('Manual page, model or link'));
      await tester.enterText(
          field('Manual page, model or link'), 'Test model manual, section 4');
      await reveal(find.text('Save reminder'));
      await tester.tap(find.text('Save reminder'));
      await tester.pumpAndSettle();
      expect(saved!.metric, TrackingMetric.hours);
      expect(saved!.source, RuleSource.user);
      expect(saved!.usageInterval, 100);
      expect(saved!.manufacturerUsageLimit, 80);
      expect(saved!.manufacturerDaysLimit, 30);
      expect(find.text('Configure task'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'Condition card labels attention as a user observation in ${dark ? 'dark' : 'light'}',
        (tester) async {
      final history =
          PredictionHistory(services: [], readings: [], rules: const [
        TaskRule(
            id: 'c',
            name: 'Inspect filter',
            metric: TrackingMetric.condition,
            source: RuleSource.user)
      ], usage: [
        TaskUsageReading(
            taskId: 'c',
            recordedAt: DateTime.now(),
            condition: ObservedCondition.attention,
            notes: 'Visible dust')
      ]);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            predictionRepositoryProvider
                .overrideWithValue(FakePredictionRepository(history: history))
          ],
          child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: const Scaffold(
                  body: SingleChildScrollView(
                      child: PredictionPanel(
                          assetId: 'a', assetName: 'Air conditioner'))))));
      await tester.pumpAndSettle();
      expect(find.text('Needs attention — reported by you'), findsOneWidget);
      expect(find.text('Visible dust'), findsOneWidget);
      expect(find.text('Update distance'), findsNothing);
      expect(find.textContaining('not an automatic diagnosis'), findsOneWidget);
    });
  }
}
