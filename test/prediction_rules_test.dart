import 'package:ayoslog/features/predictions/domain/prediction_models.dart';
import 'package:ayoslog/features/predictions/domain/prediction_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 31);
  ServiceSample service(int km, int day,
          {String task = 'Engine oil', double cost = 500}) =>
      ServiceSample(
          task: task,
          cost: cost,
          performedAt: DateTime(2026, 9, day),
          odometerKm: km);
  PredictionReport predict(List<ServiceSample> services,
          {int current = 9450, List<MileageReading>? readings}) =>
      const BuildMaintenanceRecommendations()(
          PredictionHistory(
              isCar: true,
              rules: const [
                TaskRule(
                    id: 'oil',
                    name: 'Engine oil',
                    metric: TrackingMetric.kilometres)
              ],
              services: services,
              readings: readings ??
                  [
                    MileageReading(km: 8000, recordedAt: DateTime(2026, 9, 21)),
                    MileageReading(km: current, recordedAt: now),
                  ]),
          now);

  test('Three services reproduce the 550 km example using real intervals', () {
    final result =
        predict([service(4000, 1), service(6000, 11), service(8000, 21)])
            .recommendations
            .single;
    expect(result.intervalKm, 2000);
    expect(result.targetKm, 10000);
    expect(result.remainingKm, 550);
    expect(result.sampleCount, 3);
    expect(result.usageDue, now.add(const Duration(days: 7)));
    expect(result.calendarDue, DateTime(2026, 10, 1));
    expect(result.kmPerDay, closeTo(5450 / 60, .001));
  });
  test('Averages unequal gaps and normalizes task spacing/case', () {
    final result = predict([
      service(3000, 1, task: ' engine  OIL '),
      service(5000, 11),
      service(8000, 21, task: 'ENGINE OIL')
    ]).recommendations.single;
    expect(result.intervalKm, 2500);
    expect(result.targetKm, 10500);
    expect(result.remainingKm, 1050);
  });
  test('Different tasks never contribute intervals or cost baselines', () {
    final results = predict([
      service(4000, 1),
      service(6000, 11),
      service(8000, 21),
      service(8200, 22, task: 'Tires', cost: 5000)
    ]).recommendations;
    expect(results.length, 2);
    expect(
        results
            .firstWhere((r) => normalizeTask(r.task) == 'engine oil')
            .targetKm,
        10000);
    expect(results.firstWhere((r) => r.task == 'Tires').targetKm, isNull);
  });

  test(
      'Three complete services after an unmeasured service recover an estimate',
      () {
    final result = predict([
      ServiceSample(
          task: 'Engine oil', cost: 500, performedAt: DateTime(2026, 8)),
      service(4000, 1),
      service(6000, 11),
      service(8000, 21),
    ]).recommendations.single;
    expect(result.targetKm, 10000);
    expect(result.sampleCount, 3);
  });
  test(
      'Insufficient, missing, or non-increasing mileage does not produce targets',
      () {
    for (final samples in [
      [service(4000, 1), service(6000, 11)],
      [service(4000, 1), service(4000, 11), service(6000, 21)],
      [service(4000, 1), service(3000, 11), service(6000, 21)],
      [
        service(4000, 1),
        ServiceSample(
            task: 'Engine oil', cost: 500, performedAt: DateTime(2026, 9, 11)),
        service(6000, 21)
      ],
    ]) {
      expect(predict(samples).recommendations.single.targetKm, isNull);
    }
  });
  test(
      'Service readings remain usable as dated readings without a newer update',
      () {
    final samples = [service(4000, 1), service(6000, 11), service(8000, 21)];
    expect(predict(samples, readings: []).recommendations.single.remainingKm,
        2000);
    expect(
        predict(samples, readings: [
          MileageReading(km: 7000, recordedAt: DateTime(2026, 9, 15))
        ]).recommendations.single.remainingKm,
        2000);
  });
  test('Due/overdue mileage stays signed and never predicts a future due date',
      () {
    final samples = [service(4000, 1), service(6000, 11), service(8000, 21)];
    final due = predict(samples, current: 10000).recommendations.single;
    final overdue = predict(samples, current: 10500).recommendations.single;
    expect(due.remainingKm, 0);
    expect(overdue.remainingKm, -500);
    expect(overdue.usageDue, isNull);
  });
  test('Date estimate requires seven days of positive use in 90-day window',
      () {
    const rule = TaskRule(
        id: 'oil',
        name: 'Engine oil',
        metric: TrackingMetric.kilometres,
        source: RuleSource.user,
        usageInterval: 2000);
    final samples = [
      ServiceSample(
          task: 'Engine oil',
          taskId: 'oil',
          cost: 100,
          performedAt: now.subtract(const Duration(days: 6)),
          usageValue: 8000)
    ];
    for (final readings in [
      [MileageReading(km: 9450, recordedAt: now)],
      [
        MileageReading(
            km: 9000, recordedAt: now.subtract(const Duration(days: 6))),
        MileageReading(km: 9450, recordedAt: now)
      ],
      [
        MileageReading(
            km: 9450, recordedAt: now.subtract(const Duration(days: 10))),
        MileageReading(km: 9450, recordedAt: now)
      ],
      [
        MileageReading(
            km: 8000, recordedAt: now.subtract(const Duration(days: 100))),
        MileageReading(km: 9450, recordedAt: now)
      ],
    ]) {
      expect(
          const BuildMaintenanceRecommendations()(
                  PredictionHistory(
                      isCar: true,
                      services: samples,
                      readings: readings,
                      rules: [rule]),
                  now)
              .recommendations
              .single
              .usageDue,
          isNull);
    }
  });
  test(
      'Cost flag uses three earlier positive costs and strictly greater than 50%',
      () {
    for (final (latest, flagged) in [
      (150.0, false),
      (151.0, true),
      (0.0, false)
    ]) {
      final r = predict([
        service(2000, 1, cost: 100),
        service(4000, 5, cost: 100),
        service(6000, 11, cost: 100),
        service(8000, 21, cost: latest)
      ]).recommendations.single;
      expect(r.highCost, flagged);
      expect(r.baselineCost, 100);
      expect(r.costSampleCount, 3);
    }
    expect(
        predict([
          service(4000, 1, cost: 0),
          service(6000, 11, cost: 100),
          service(8000, 21, cost: 1000)
        ]).recommendations.single.highCost,
        isFalse);
  });
  test('Future service/usage and unnamed tasks are ignored', () {
    final r = predict([
      service(4000, 1),
      ServiceSample(
          task: 'Engine oil',
          cost: 9000,
          odometerKm: 8000,
          performedAt: now.add(const Duration(days: 2))),
      service(5000, 2, task: '  ')
    ]);
    expect(r.recommendations.single.sampleCount, 1);
  });
  test(
      'Mileage validation accepts consistent backfill and rejects conflicting/future values',
      () {
    final existing = [
      MileageReading(
          km: 100, recordedAt: now.subtract(const Duration(days: 10))),
      MileageReading(km: 200, recordedAt: now)
    ];
    validateReading(
        MileageReading(
            km: 150, recordedAt: now.subtract(const Duration(days: 5))),
        now,
        existing: existing);
    for (final reading in [
      MileageReading(km: 50, recordedAt: now.subtract(const Duration(days: 5))),
      MileageReading(
          km: 250, recordedAt: now.subtract(const Duration(days: 5))),
      MileageReading(km: 201, recordedAt: now),
      MileageReading(km: -1, recordedAt: now),
      MileageReading(km: 210, recordedAt: now.add(const Duration(days: 1))),
    ]) {
      expect(() => validateReading(reading, now, existing: existing),
          throwsA(isA<PredictionValidationException>()));
    }
    expect(parseMileage('0'), 0);
    for (final input in ['1.2', '-1', 'NaN', '99999999999999999999999999']) {
      expect(() => parseMileage(input),
          throwsA(isA<PredictionValidationException>()));
    }
  });
}
