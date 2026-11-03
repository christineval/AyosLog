import 'package:flutter_test/flutter_test.dart';
import 'package:ayoslog/features/predictions/domain/forecast_models.dart';
import 'package:ayoslog/features/predictions/domain/forecast_engine.dart';
import 'package:ayoslog/features/predictions/domain/category_templates.dart';

final start = DateTime.utc(2026, 1, 1);
ForecastTask task(
        {AssetSubtype subtype = AssetSubtype.vehicle,
        ForecastMetric metric = ForecastMetric.distance,
        UsageMethod method = UsageMethod.counter,
        double baseline = 8000,
        double? interval = 2000,
        int? days,
        double? daily,
        double? min,
        double? max,
        int freshness = 30}) =>
    ForecastTask(
        id: 't',
        assetId: 'a',
        name: 'Maintenance',
        subtype: subtype,
        metric: metric,
        method: method,
        baselineAt: start,
        baseline: baseline,
        interval: interval,
        intervalDays: days,
        dailyRate: daily,
        minimum: min,
        maximum: max,
        freshnessDays: freshness,
        customUnit: 'units');
Observation reading(double value, int day,
        {String? id,
        bool reset = false,
        Map<String, String> conditions = const {}}) =>
    Observation(
        id: id ?? '$day',
        assetId: 'a',
        taskId: 't',
        at: start.add(Duration(days: day)),
        values: {'reading': value},
        reset: reset,
        conditions: conditions);
const engine = PredictionEngine();
void main() {
  test('vehicle 8000 to 9450: 550km remaining, 30km/day, latest-date anchor',
      () {
    final p = engine.calculate(task(), [reading(9240, 0), reading(9450, 7)],
        start.add(const Duration(days: 8)));
    expect(p.remaining, 550);
    expect(p.target, 10000);
    expect(p.rate, 30);
    expect(p.usageDue, start.add(const Duration(days: 26)));
    expect(p.state, ForecastState.estimated);
    expect(p.reliability, Reliability.limited);
  });
  test(
      'median pair rates resists one large increment; zero intervals are included',
      () {
    final p = engine.calculate(
        task(interval: 100000),
        [
          reading(8000, 0),
          reading(8010, 1),
          reading(9010, 2),
          reading(9020, 3)
        ],
        start.add(const Duration(days: 3)));
    expect(p.rate, 10);
    expect(p.reliability, Reliability.limited);
    final q = engine.calculate(
        task(),
        [
          reading(8000, 0),
          reading(8030, 1),
          reading(8060, 2),
          reading(8090, 3)
        ],
        start.add(const Duration(days: 3)));
    expect(q.reliability, Reliability.moderate);
    expect(q.ratePairs, 3);
  });
  test('AC 8 hours/day for 35 days: 280 hours, 20 left, three rounded days',
      () {
    final p = engine.calculate(
        task(
            subtype: AssetSubtype.airConditioner,
            metric: ForecastMetric.hours,
            method: UsageMethod.estimated,
            baseline: 0,
            interval: 300,
            daily: 8),
        [],
        start.add(const Duration(days: 35)));
    expect(p.current, 280);
    expect(p.remaining, 20);
    expect(p.dueAt, start.add(const Duration(days: 38)));
  });
  test('filter capacity, earlier calendar limit and washer weekly conversion',
      () {
    final p = engine.calculate(
        task(
            subtype: AssetSubtype.waterFilter,
            metric: ForecastMetric.litres,
            method: UsageMethod.estimated,
            baseline: 0,
            interval: 2000,
            daily: 12,
            days: 90),
        [],
        start.add(const Duration(days: 45)));
    expect(p.current, 540);
    expect(p.remaining, 1460);
    expect(p.usageDue, start.add(const Duration(days: 167)));
    expect(p.dueAt, start.add(const Duration(days: 90)));
    final rate = estimatedDailyRate(
        AssetSubtype.washingMachine, {'cycles_per_week': '7'});
    final q = engine.calculate(
        task(
            subtype: AssetSubtype.washingMachine,
            metric: ForecastMetric.cycles,
            method: UsageMethod.estimated,
            baseline: 0,
            interval: 50,
            daily: rate),
        [],
        start.add(const Duration(days: 35)));
    expect(q.remaining, 15);
    expect(q.dueAt, start.add(const Duration(days: 50)));
  });
  test('usage changes only affect the period after the dated estimate', () {
    final t = task(
        subtype: AssetSubtype.airConditioner,
        metric: ForecastMetric.hours,
        method: UsageMethod.estimated,
        baseline: 0,
        interval: 1000,
        daily: 8);
    final r = Observation(
        id: 'r',
        assetId: 'a',
        taskId: 't',
        at: start.add(const Duration(days: 10)),
        values: const {'daily_rate': 4});
    expect(
        engine.calculate(t, [r], start.add(const Duration(days: 20))).current,
        120);
  });
  test('all forecast states and hard limits remain visible with stale data',
      () {
    expect(engine.calculate(task(), [], start).state,
        ForecastState.insufficientData);
    expect(engine.calculate(task(days: 100), [], start).state,
        ForecastState.scheduled);
    expect(
        engine
            .calculate(
                task(), [reading(9900, 1)], start.add(const Duration(days: 1)))
            .state,
        ForecastState.dueSoon);
    final p = engine.calculate(
        task(), [reading(10001, 1)], start.add(const Duration(days: 90)));
    expect(p.state, ForecastState.overdue);
    expect(p.stale, true);
    expect(
        engine
            .calculate(
                task(), [reading(8100, 1)], start.add(const Duration(days: 90)))
            .state,
        ForecastState.stale);
    expect(
        engine
            .calculate(task(days: 7), [], start.add(const Duration(days: 7)))
            .state,
        ForecastState.overdue);
    expect(const AssetInsight('a', 'A', 'vehicle', null).state,
        ForecastState.notConfigured);
  });
  test('zero rate, equal dates, conflicts, ordering and regression', () {
    final now = start.add(const Duration(days: 5));
    expect(
        engine
            .calculate(task(), [reading(8000, 0), reading(8000, 1)], now)
            .usageDue,
        isNull);
    expect(
        engine
            .calculate(
                task(), [reading(8000, 0), reading(8000, 0, id: 'copy')], now)
            .rate,
        isNull);
    expect(
        engine
            .calculate(
                task(), [reading(8000, 0), reading(8100, 0, id: 'copy')], now)
            .state,
        ForecastState.invalid);
    expect(
        engine
            .calculate(task(), [reading(8200, 2), reading(8100, 1)], now)
            .rate,
        100);
    expect(
        engine
            .calculate(task(), [reading(8200, 1), reading(8100, 2)], now)
            .state,
        ForecastState.invalid);
  });
  test('explicit reset retains used distance and restarts rate evidence', () {
    final p = engine.calculate(
        task(),
        [reading(9000, 1), reading(0, 2, reset: true), reading(100, 3)],
        start.add(const Duration(days: 3)));
    expect(p.current, 9100);
    expect(p.remaining, 900);
    expect(p.rate, 100);
  });
  test(
      'temperature trend requires three separate dates and repeated configured outliers',
      () {
    final t = task(
        subtype: AssetSubtype.refrigerator,
        metric: ForecastMetric.temperature,
        method: UsageMethod.trend,
        baseline: 0,
        interval: null,
        min: 0,
        max: 6);
    final p = engine.calculate(t, [reading(4, 0), reading(7, 1), reading(8, 2)],
        start.add(const Duration(days: 2)));
    expect(p.trend, 2);
    expect(p.state, ForecastState.conditionAlert);
    expect(p.dueAt, isNull);
    expect(
        engine
            .calculate(t, [reading(7, 0), reading(8, 1)],
                start.add(const Duration(days: 1)))
            .alerts,
        isEmpty);
    final noBounds = task(
        subtype: AssetSubtype.refrigerator,
        metric: ForecastMetric.temperature,
        method: UsageMethod.trend,
        baseline: 0,
        interval: null);
    expect(
        engine
            .calculate(noBounds, [reading(4, 0), reading(7, 1), reading(8, 2)],
                start.add(const Duration(days: 2)))
            .alerts,
        isEmpty);
  });
  test(
      'laptop reports downward trend without a failure date; conditions independent',
      () {
    final t = task(
        subtype: AssetSubtype.laptop,
        metric: ForecastMetric.battery,
        method: UsageMethod.trend,
        baseline: 0,
        interval: null,
        days: 365);
    final p = engine.calculate(
        t,
        [reading(95, 0), reading(94, 30), reading(92, 60)],
        start.add(const Duration(days: 60)));
    expect(p.trend, closeTo(-.05, .00001));
    expect(p.alerts, isNotEmpty);
    expect(p.usageDue, isNull);
    final q = engine.calculate(
        task(days: 1),
        [
          reading(8200, 1, conditions: {'warning_lights': 'yes'})
        ],
        start.add(const Duration(days: 2)));
    expect(q.state, ForecastState.overdue);
    expect(q.alerts, isNotEmpty);
  });
  test('conversions and canonical form validation', () {
    expect(canonicalValue(100, 'mi'), 160.9344);
    expect(canonicalValue(32, '°F'), 0);
    expect(
        () => canonicalValue(1, 'gallon'), throwsA(isA<ForecastValidation>()));
    final t = task();
    final r = buildObservation(
        task: t,
        id: 'r',
        values: {'reading': '10000', 'unit': 'mi'},
        at: start,
        now: start);
    expect(r.values['reading'], 16093.44);
    expect(
        () => buildObservation(
            task: t,
            id: 'r',
            values: {'reading': '-1', 'unit': 'km'},
            at: start,
            now: start),
        throwsA(isA<ForecastValidation>()));
    expect(
        () => buildObservation(
            task: t,
            id: 'r',
            values: {'reading': 'NaN', 'unit': 'km'},
            at: start,
            now: start),
        throwsA(isA<ForecastValidation>()));
    expect(
        () => buildObservation(
            task: t,
            id: 'r',
            values: {'reading': '9000', 'unit': 'km'},
            at: start.add(const Duration(days: 1)),
            now: start),
        throwsA(isA<ForecastValidation>()));
    expect(
        () => buildObservation(
            task: t,
            id: 'r',
            values: {'reading': '0', 'unit': 'km'},
            at: start,
            now: start,
            reset: true),
        throwsA(isA<ForecastValidation>()));
  });
  test('plan, category and range validation', () {
    expect(() => validateForecastTask(task(interval: -1), start),
        throwsA(isA<ForecastValidation>()));
    expect(
        () => validateForecastTask(
            task(
                subtype: AssetSubtype.refrigerator,
                metric: ForecastMetric.temperature,
                method: UsageMethod.trend,
                interval: null,
                min: 8,
                max: 4),
            start),
        throwsA(isA<ForecastValidation>()));
    expect(
        validateCategoryFields(
            categoryTemplates[AssetSubtype.airConditioner]!.estimates,
            {'hours_per_day': '25', 'days_per_week': '8'}).length,
        2);
    expect(
        validateCategoryFields(categoryTemplates[AssetSubtype.laptop]!.readings,
            {'reading': '101'}),
        isNotEmpty);
    expect(
        validateCategoryFields(
            categoryTemplates[AssetSubtype.washingMachine]!.readings,
            {'reading': '1.5'}),
        isNotEmpty);
  });
  test('service baseline only uses observations on/after actual completion',
      () {
    final revised =
        task().withBaseline(start.add(const Duration(days: 10)), 9500);
    final p = engine.calculate(revised, [reading(9400, 9), reading(9600, 11)],
        start.add(const Duration(days: 11)));
    expect(p.target, 11500);
    expect(p.remaining, 1900);
    expect(p.inputs.length, 1);
    expect(
        p.inputHash,
        engine
            .calculate(revised, [reading(9400, 9), reading(9600, 11)],
                start.add(const Duration(days: 12)))
            .inputHash);
  });
}
