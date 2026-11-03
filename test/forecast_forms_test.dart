import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayoslog/features/predictions/domain/category_templates.dart';
import 'package:ayoslog/features/predictions/domain/forecast_models.dart';
import 'package:ayoslog/features/predictions/domain/forecast_engine.dart';
import 'package:ayoslog/features/predictions/domain/forecast_repository.dart';
import 'package:ayoslog/features/predictions/domain/forecast_usecases.dart';
import 'package:ayoslog/features/predictions/domain/cost_insights.dart';
import 'package:ayoslog/features/predictions/presentation/viewmodels/forecast_viewmodels.dart';
import 'helpers/fake_forecast_repository.dart';

void main() {
  final now = DateTime.utc(2025, 3);
  test('calendar limit survives an omitted completion counter and leap day',
      () {
    final base = fixtureForecastTask(AssetSubtype.vehicle);
    final t = ForecastTask.fromJson({
      ...base.toJson(),
      'baselineAt': DateTime.utc(2024, 2, 1).toIso8601String(),
      'intervalDays': 2
    });
    final data = ForecastData(assets: const [
      ForecastAsset('a', 'Bike', 'vehicle', false, null)
    ], tasks: [
      t
    ], completions: [
      ForecastCompletion(
          id: 's',
          assetId: 'a',
          taskId: 't',
          at: DateTime.utc(2024, 2, 28),
          description: 'Service without counter',
          cost: 0)
    ]);
    final p = const CalculateInsights()(data, DateTime.utc(2024, 3, 2))
        .single
        .prediction!;
    expect(p.calendarDue, DateTime.utc(2024, 3, 1));
    expect(p.state, ForecastState.overdue);
    expect(p.target, isNull);
    expect(p.task.baselineKnown, false);
  });
  for (final subtype in AssetSubtype.values) {
    test('${subtype.name}: template required fields, units and conditions', () {
      final t = fixtureForecastTask(subtype);
      final template = categoryTemplates[subtype]!;
      final values = <String, String>{
        for (final f in template.readings)
          f.id: f.type == CategoryFieldType.choice
              ? f.options.first
              : f.id == 'reading' && subtype == AssetSubtype.refrigerator
                  ? '4'
                  : '50'
      };
      final o =
          buildObservation(task: t, id: 'r', values: values, at: now, now: now);
      expect(o.values, isNotEmpty);
      expect(o.conditions.values.every((v) => v == 'unknown'), true);
      for (final f in template.readings
          .where((f) => f.required && f.type == CategoryFieldType.number)) {
        expect(
            () => buildObservation(
                task: t,
                id: 'r',
                values: {...values, f.id: ''},
                at: now,
                now: now),
            throwsA(isA<ForecastValidation>()));
      }
      expect(
          validateCategoryFields(template.readings, {
            for (final f in template.readings)
              f.id: f.type == CategoryFieldType.number ? 'Infinity' : 'wrong'
          }),
          isNotEmpty);
    });
  }
  test('estimated method fields and formula conversions', () {
    expect(
        estimatedDailyRate(AssetSubtype.airConditioner,
            {'hours_per_day': '8', 'days_per_week': '7'}),
        8);
    expect(
        estimatedDailyRate(
            AssetSubtype.washingMachine, {'cycles_per_week': '7'}),
        1);
    expect(
        estimatedDailyRate(AssetSubtype.waterFilter, {'litres_per_day': '12'}),
        12);
    final t = fixtureForecastTask(AssetSubtype.airConditioner,
        method: UsageMethod.estimated);
    expect(
        () => buildObservation(
            task: t,
            id: 'r',
            values: {'hours_per_day': '8'},
            at: now,
            now: now),
        throwsA(isA<ForecastValidation>()));
    final zero = buildObservation(
        task: t,
        id: 'r',
        values: {'hours_per_day': '0', 'days_per_week': '0'},
        at: now,
        now: now);
    expect(zero.values['daily_rate'], 0);
  });
  test(
      'outlier confirmation, battery at least one measurement and unknown reports',
      () {
    final fridge = fixtureForecastTask(AssetSubtype.refrigerator);
    expect(
        () => buildObservation(
            task: fridge,
            id: 'r',
            values: {'reading': '90', 'unit': '°C'},
            at: now,
            now: now),
        throwsA(isA<ForecastValidation>()));
    expect(
        buildObservation(
                task: fridge,
                id: 'r',
                values: {'reading': '90', 'unit': '°C'},
                at: now,
                now: now,
                confirmed: true)
            .values['reading'],
        90);
    final laptop = fixtureForecastTask(AssetSubtype.laptop);
    expect(
        () => buildObservation(
            task: laptop, id: 'r', values: {}, at: now, now: now),
        throwsA(isA<ForecastValidation>()));
    expect(
        buildObservation(
                task: laptop,
                id: 'r',
                values: {'cycle_count': '80'},
                at: now,
                now: now)
            .values['cycle_count'],
        80);
    expect(
        () => buildObservation(
            task: laptop,
            id: 'r',
            values: {},
            at: now,
            now: now,
            conditionsOnly: true),
        throwsA(isA<ForecastValidation>()));
    expect(
        buildObservation(
                task: laptop,
                id: 'r',
                values: {'overheating': 'often'},
                at: now,
                now: now,
                conditionsOnly: true)
            .values,
        isEmpty);
  });
  test('plan sources, dimensions, days, precision and freshness validation',
      () {
    final good = fixtureForecastTask(AssetSubtype.vehicle);
    final bad = [
      {'interval': 0},
      {'interval': double.infinity},
      {'baseline': -1},
      {'intervalDays': 0},
      {'warningDays': -1},
      {'freshnessDays': 0},
      {'source': 'manufacturer', 'reference': ''},
      {'method': 'estimated'},
      {'metric': 'temperature'},
      {'minimum': 0},
      {'warningFraction': 2},
    ];
    for (final delta in bad) {
      expect(
          () => validateForecastTask(
              ForecastTask.fromJson({...good.toJson(), ...delta}), now),
          throwsA(isA<ForecastValidation>()),
          reason: '$delta');
    }
    final miles = buildForecastTask(
        id: 't',
        assetId: 'a',
        name: 'Oil',
        subtype: AssetSubtype.vehicle,
        method: UsageMethod.counter,
        baselineAt: DateTime.utc(2025),
        source: PlanSource.owner,
        reference: '',
        now: now,
        values: {
          'unit': 'mi',
          'baseline': '1000',
          'interval': '100',
          'warning_days': '7',
          'freshness_days': '30'
        });
    expect(miles.baseline, 1609.344);
    expect(miles.interval, 160.9344);
  });
  test('viewmodel duplicate guard, failure retry and loading/error lifecycle',
      () async {
    final repo = FakeForecastRepository(const ForecastData());
    final vm = ForecastFormViewModel(repo);
    addTearDown(vm.dispose);
    repo.gate = Completer<void>();
    final first = vm.complete(ForecastCompletion(
        id: 's',
        assetId: 'a',
        taskId: 't',
        at: DateTime.utc(2025),
        description: 'Work',
        cost: 0));
    expect(vm.state.isLoading, true);
    expect(
        await vm.complete(ForecastCompletion(
            id: 's',
            assetId: 'a',
            taskId: 't',
            at: DateTime.utc(2025),
            description: 'Work',
            cost: 0)),
        false);
    expect(repo.writes, 1);
    repo.gate!.complete();
    expect(await first, true);
    expect(vm.state.hasError, false);
    expect(
        await vm.complete(ForecastCompletion(
            id: 's',
            assetId: 'a',
            taskId: 't',
            at: DateTime.utc(2025),
            description: '',
            cost: -1)),
        false);
    expect(vm.state.hasError, true);
    repo.gate = null;
    expect(
        await vm.complete(ForecastCompletion(
            id: 's2',
            assetId: 'a',
            taskId: 't',
            at: DateTime.utc(2025),
            description: 'Work',
            cost: 0)),
        true);
    final insight = InsightsViewModel(repo, clock: () => now);
    addTearDown(insight.dispose);
    expect(insight.state.isLoading, true);
    await Future<void>.delayed(Duration.zero);
    expect(insight.state.hasValue, true);
  });
  test('cost sample gates, task isolation, 90-day total and robust deviation',
      () {
    ForecastCompletion c(String id, double cost, {String task = 't'}) =>
        ForecastCompletion(
            id: id,
            assetId: 'a',
            taskId: task,
            at: now,
            description: 'Work',
            cost: cost);
    final samples = [
      c('1', 100),
      c('2', 100),
      c('3', 100),
      c('4', 300),
      c('5', 10000, task: 'other')
    ];
    final summary = calculateCostInsights(samples, 'a', 't', now);
    expect(summary.samples, 4);
    expect(summary.total, 600);
    expect(summary.monthlyAverage, 200);
    expect(summary.medianCost, 100);
    expect(summary.unusual, true);
    expect(
        calculateCostInsights(samples.take(3).toList(), 'a', 't', now).unusual,
        false);
  });
  test(
      'battery trend resets only on actual replacement, calendar service remains independent',
      () {
    final t = fixtureForecastTask(AssetSubtype.laptop);
    final readings = [
      for (var i = 0; i < 4; i++)
        Observation(
            id: 'r$i',
            assetId: 'a',
            taskId: 't',
            at: DateTime.utc(2025, 1, 1 + i * 10),
            values: {'reading': 95.0 - i})
    ];
    ForecastData data(bool replaced) => ForecastData(
        assets: const [
          ForecastAsset('a', 'Laptop', 'electronics', false, null)
        ],
        tasks: [t],
        observations: readings,
        completions: [
          ForecastCompletion(
              id: 's',
              assetId: 'a',
              taskId: 't',
              at: DateTime.utc(2025, 1, 21),
              description: 'Service',
              cost: 0,
              batteryReplaced: replaced)
        ]);
    final unchanged =
        const CalculateInsights()(data(false), now).single.prediction!;
    expect(unchanged.inputs.length, 4);
    expect(unchanged.trendWindows[30], closeTo(-.1, .00001));
    final replaced =
        const CalculateInsights()(data(true), now).single.prediction!;
    expect(replaced.inputs.length, 2);
    expect(replaced.trend, isNull);
  });
}
