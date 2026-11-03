import 'dart:async';
import 'package:ayoslog/core/providers.dart';
import 'package:ayoslog/core/theme/app_theme.dart';
import 'package:ayoslog/features/predictions/domain/prediction_models.dart';
import 'package:ayoslog/features/predictions/domain/prediction_usecases.dart';
import 'package:ayoslog/features/predictions/presentation/viewmodels/prediction_viewmodels.dart';
import 'package:ayoslog/features/predictions/presentation/views/add_mileage_page.dart';
import 'package:ayoslog/features/predictions/presentation/views/prediction_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_prediction_repository.dart';

void main() {
  final now = DateTime.now();
  final history = PredictionHistory(
    isCar: true,
    rules: const [
      TaskRule(id: 'oil', name: 'Engine oil', metric: TrackingMetric.kilometres)
    ],
    services: [
      for (var i = 0; i < 4; i++)
        ServiceSample(
            task: 'Engine oil',
            cost: i == 3 ? 1000 : 500,
            odometerKm: 2000 + i * 2000,
            performedAt: now.subtract(Duration(days: 70 - i * 20)))
    ],
    readings: [
      MileageReading(
          km: 8000, recordedAt: now.subtract(const Duration(days: 10))),
      MileageReading(km: 9450, recordedAt: now)
    ],
  );
  Future<void> panel(WidgetTester tester, FakePredictionRepository repo,
          {bool dark = false, double scale = 1}) =>
      tester.pumpWidget(ProviderScope(
        overrides: [predictionRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const Scaffold(
                body: SingleChildScrollView(
                    child: Padding(
                        padding: EdgeInsets.all(22),
                        child: PredictionPanel(
                            assetId: 'a', assetName: 'Honda Click 125'))))),
      ));

  for (final dark in [false, true]) {
    testWidgets(
        'Prediction, explanation and cost flag render in ${dark ? 'dark' : 'light'} at large text',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await panel(tester, FakePredictionRepository(history: history),
          dark: dark, scale: 2);
      await tester.pumpAndSettle();
      expect(find.text('~550 km remaining'), findsOneWidget);
      expect(find.text('Estimated target: 10,000 km'), findsOneWidget);
      expect(find.textContaining('Higher cost than usual:'), findsOneWidget);
      expect(find.textContaining('not a diagnosis'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'Empty predictions explain missing history in ${dark ? 'dark' : 'light'}',
        (tester) async {
      await panel(tester, FakePredictionRepository(), dark: dark);
      await tester.pumpAndSettle();
      expect(find.text('No maintenance reminders yet'), findsOneWidget);
      expect(find.text('Add maintenance reminder'), findsOneWidget);
      expect(find.text('Update distance'), findsNothing);
      expect(find.text('~550 km remaining'), findsNothing);
    });
  }

  testWidgets('Loading, failure and retry states are explicit', (tester) async {
    final stream = StreamController<PredictionHistory>();
    addTearDown(stream.close);
    var attempts = 0;
    final repo = FakePredictionRepository(onWatch: () {
      attempts++;
      return attempts == 1 ? stream.stream : Stream.value(history);
    });
    await panel(tester, repo);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    stream.addError(Exception('offline database'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load recommendations.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('~550 km remaining'), findsOneWidget);
  });

  testWidgets('Odometer form validates input and displays repository failures',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var writes = 0;
    final repo = FakePredictionRepository(
        history: history,
        onSaveTaskReading: (_, __) async {
          writes++;
          throw const PredictionValidationException(
              'Mileage must fit between existing readings.');
        });
    await tester.pumpWidget(ProviderScope(
        overrides: [predictionRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
            theme: AppTheme.dark(), home: const AddMileagePage(assetId: 'a'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the total.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '-1');
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a nonnegative number without separators.'),
        findsOneWidget);
    expect(writes, 0);
    await tester.enterText(find.byType(TextFormField).first, '9450');
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Mileage must fit between existing readings.'),
        findsOneWidget);
  });

  test('ViewModel blocks duplicate submits and permits retry after failure',
      () async {
    final pending = Completer<void>();
    var writes = 0;
    final repo = FakePredictionRepository(onSaveReading: (_, __) {
      writes++;
      return pending.future;
    });
    final vm = PredictionFormViewModel(
        AddMileageReading(repo), RecordPredictiveService(repo));
    addTearDown(vm.dispose);
    final reading = MileageReading(km: 1000, recordedAt: now);
    final first = vm.saveReading('a', reading);
    expect(vm.state.isLoading, isTrue);
    expect(await vm.saveReading('a', reading), isFalse);
    expect(writes, 1);
    pending.completeError(const PredictionValidationException('Try again'));
    expect(await first, isFalse);
    expect(vm.state.hasError, isTrue);
  });
}
