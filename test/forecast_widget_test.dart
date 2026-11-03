import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayoslog/core/theme/app_theme.dart';
import 'package:ayoslog/features/predictions/domain/forecast_models.dart';
import 'package:ayoslog/features/predictions/domain/forecast_repository.dart';
import 'package:ayoslog/features/predictions/presentation/forecast_providers.dart';
import 'package:ayoslog/features/predictions/presentation/views/insights_page.dart';
import 'package:ayoslog/features/predictions/presentation/views/forecast_forms.dart';
import 'package:ayoslog/features/predictions/presentation/views/forecast_history_page.dart';
import 'package:ayoslog/shared/widgets/app_field.dart';
import 'helpers/fake_forecast_repository.dart';
import 'helpers/fake_prediction_repository.dart';
import 'package:ayoslog/core/providers.dart';

void main() {
  Future<void> render(
      WidgetTester tester, Widget page, FakeForecastRepository repo,
      {bool dark = false, bool large = false}) async {
    await tester.binding
        .setSurfaceSize(large ? const Size(320, 640) : const Size(384, 832));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          forecastRepositoryProvider.overrideWithValue(repo),
          predictionRepositoryProvider
              .overrideWithValue(FakePredictionRepository())
        ],
        child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(large ? 2 : 1),
                    viewInsets: large
                        ? const EdgeInsets.only(bottom: 200)
                        : EdgeInsets.zero),
                child: child!),
            home: page)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  ForecastData data(AssetSubtype subtype) => ForecastData(assets: [
        ForecastAsset(
            'a',
            'My asset',
            switch (subtype) {
              AssetSubtype.airConditioner => 'air_conditioner',
              AssetSubtype.washingMachine => 'washing_machine',
              AssetSubtype.waterFilter => 'water_filter',
              _ => subtype.name
            },
            false,
            subtype)
      ], tasks: [
        fixtureForecastTask(subtype)
      ]);
  for (final dark in [false, true]) {
    for (final subtype in AssetSubtype.values) {
      testWidgets(
          '${subtype.name} applicable fields in ${dark ? 'dark' : 'light'}',
          (tester) async {
        await render(
            tester,
            const ForecastCheckInPage(assetId: 'a', taskId: 't'),
            FakeForecastRepository(data(subtype)),
            dark: dark);
        final labels = tester
            .widgetList<AppField>(find.byType(AppField))
            .map((f) => f.label)
            .toList();
        expect(
            labels,
            contains(switch (subtype) {
              AssetSubtype.vehicle => 'Odometer',
              AssetSubtype.airConditioner => 'Total operating hours',
              AssetSubtype.waterFilter => 'Cumulative meter litres',
              AssetSubtype.washingMachine => 'Lifetime wash counter',
              AssetSubtype.refrigerator => 'Internal temperature',
              AssetSubtype.laptop => 'Battery health (%)',
              AssetSubtype.custom => 'Total reading'
            }));
        if (subtype != AssetSubtype.vehicle) {
          expect(labels, isNot(contains('Odometer')));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    for (final entry in <String, Widget>{
      'dashboard': const InsightsPage(),
      'details': const AssetPredictionPage(assetId: 'a', taskId: 't'),
      'plan': const ForecastPlanPage(assetId: 'a', taskId: 't'),
      'history': const ForecastHistoryPage(assetId: 'a', taskId: 't'),
      'service': const ForecastServicePage(assetId: 'a', taskId: 't')
    }.entries) {
      testWidgets(
          '${entry.key} large text and keyboard in ${dark ? 'dark' : 'light'}',
          (tester) async {
        await render(tester, entry.value,
            FakeForecastRepository(data(AssetSubtype.vehicle)),
            dark: dark, large: true);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets('loading, failed read, retry and missing asset states',
      (tester) async {
    await render(tester, const InsightsPage(),
        FakeForecastRepository(const ForecastData(), loading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await render(
        tester,
        const InsightsPage(),
        FakeForecastRepository(const ForecastData(),
            error: StateError('offline disk')));
    expect(find.text('Could not load local insights. Retry'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await render(tester, const InsightsPage(),
        FakeForecastRepository(const ForecastData()));
    expect(find.text('No assets yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('invalid reading keeps the draft and does not write',
      (tester) async {
    final repo = FakeForecastRepository(data(AssetSubtype.vehicle));
    await render(
        tester, const ForecastCheckInPage(assetId: 'a', taskId: 't'), repo);
    final odometer = tester
        .widgetList<AppField>(find.byType(AppField))
        .firstWhere((f) => f.label == 'Odometer');
    odometer.controller!.text = '-10';
    await tester.tap(find.text('Save observation'));
    await tester.pump();
    expect(repo.writes, 0);
    expect(odometer.controller!.text, '-10');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
