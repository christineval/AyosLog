import 'package:flutter_test/flutter_test.dart';
import 'package:ayoslog/features/predictions/domain/forecast_models.dart';
import 'package:ayoslog/features/predictions/domain/forecast_engine.dart';
import 'package:ayoslog/features/predictions/domain/maintenance_insight.dart';

final start = DateTime.utc(2026, 1, 1);
const build = BuildMaintenanceInsight();
ForecastTask task(AssetSubtype subtype, ForecastMetric metric,
        {UsageMethod method = UsageMethod.counter,
        double baseline = 0,
        double? interval = 2000,
        double? daily,
        int? days}) =>
    ForecastTask(
        id: 't',
        assetId: 'a',
        name: 'My maintenance task',
        subtype: subtype,
        metric: metric,
        method: method,
        baselineAt: start,
        baseline: baseline,
        interval: interval,
        dailyRate: daily,
        intervalDays: days,
        freshnessDays: 60,
        customUnit: 'pages');
Observation reading(double value, int day) => Observation(
    id: '$day',
    assetId: 'a',
    taskId: 't',
    at: start.add(Duration(days: day)),
    values: {'reading': value});
MaintenanceInsight insight(ForecastTask t, List<Observation> rows, int day) =>
    build.forecast(AssetInsight(
        'a',
        'My asset',
        t.subtype.name,
        const PredictionEngine()
            .calculate(t, rows, start.add(Duration(days: day)))));

void main() {
  test('vehicle evidence, progress and window come from actual readings', () {
    final s = insight(
        task(AssetSubtype.vehicle, ForecastMetric.distance, baseline: 8000),
        [reading(9240, 0), reading(9450, 7)],
        7);
    expect(s.progress, .725);
    expect(s.progressLabel, '1,450 / 2,000 km since service');
    expect(s.remainingLabel, '550 km left');
    expect(s.headline, 'About 19 days');
    expect(s.window, contains('2–3 weeks'));
    expect(s.evidence, contains('Estimated weekly usage: 210 km'));
    expect(s.actionLabel, 'Record odometer reading');
    expect(s.reliability, contains('2 relevant dated readings'));
  });
  test('every category uses its own measurement and action', () {
    final cases = <AssetSubtype, (ForecastMetric, String)>{
      AssetSubtype.airConditioner: (
        ForecastMetric.hours,
        'Record operating usage'
      ),
      AssetSubtype.waterFilter: (ForecastMetric.litres, 'Record water usage'),
      AssetSubtype.washingMachine: (
        ForecastMetric.cycles,
        'Record wash cycles'
      ),
      AssetSubtype.custom: (ForecastMetric.custom, 'Record usage reading'),
      AssetSubtype.refrigerator: (
        ForecastMetric.temperature,
        'Record temperature reading'
      ),
      AssetSubtype.laptop: (ForecastMetric.battery, 'Record battery health'),
    };
    for (final e in cases.entries) {
      final condition = !e.value.$1.counter;
      final s = insight(
          task(e.key, e.value.$1,
              method: condition ? UsageMethod.trend : UsageMethod.counter,
              interval: condition ? null : 2000),
          [reading(10, 0), reading(11, 1)],
          1);
      expect(s.actionLabel, e.value.$2, reason: e.key.name);
      if (condition) {
        expect(s.isCondition, isTrue);
        expect(s.progress, isNull);
        expect(s.window, isNull);
        expect(s.headline, isNot(contains('days')));
      }
    }
  });
  test('calendar cap takes precedence over a later usage forecast', () {
    final s = insight(
        task(AssetSubtype.waterFilter, ForecastMetric.litres,
            method: UsageMethod.estimated, daily: 12, days: 90),
        [],
        45);
    expect(s.windowTitle, 'Calendar service limit');
    expect(s.headline, '45 days');
    expect(s.window, isNot(contains('weeks')));
    expect(s.reliability, contains('reported usage estimate'));
  });
  test('calendar-only plans are labelled scheduled', () {
    final s = insight(
        task(AssetSubtype.custom, ForecastMetric.calendar,
            method: UsageMethod.calendar, interval: null, days: 30),
        [],
        5);
    expect(s.isScheduled, isTrue);
    expect(s.progress, isNull);
    expect(s.action, InsightAction.service);
    expect(s.reliability, contains('scheduled reminder'));
  });
  test('zero-rate and stale readings do not produce a service window', () {
    final t = task(AssetSubtype.vehicle, ForecastMetric.distance);
    final zero = insight(t, [reading(100, 0), reading(100, 1)], 1);
    expect(zero.window, isNull);
    expect(zero.headline, '1,900 km left');
    final stale = insight(t, [reading(100, 0), reading(200, 1)], 80);
    expect(stale.window, isNull);
    expect(stale.headline, 'Planning date reached');
  });
  test('unconfigured assets invite a plan without example predictions', () {
    final s = build.empty('other', 'My refrigerator', 'refrigerator');
    expect(s.assetId, 'other');
    expect(s.action, InsightAction.plan);
    expect(s.progress, isNull);
    expect(s.window, isNull);
    expect(s.evidence, isEmpty);
  });
}
