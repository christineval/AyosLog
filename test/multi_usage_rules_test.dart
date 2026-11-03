import 'package:ayoslog/features/predictions/domain/prediction_models.dart';
import 'package:ayoslog/features/predictions/domain/prediction_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 31);
  ServiceSample service(double value, int daysAgo,
          {String id = 't',
          String component = '',
          String kind = 'routine',
          double cost = 100}) =>
      ServiceSample(
          task: 'Maintenance',
          taskId: id,
          component: component,
          kind: kind,
          cost: cost,
          usageValue: value,
          performedAt: now.subtract(Duration(days: daysAgo)));
  MaintenanceRecommendation calculate(TaskRule rule,
          {List<ServiceSample>? services,
          List<TaskUsageReading>? readings,
          bool isCar = false}) =>
      const BuildMaintenanceRecommendations()(
              PredictionHistory(
                  isCar: isCar,
                  rules: [rule],
                  readings: [],
                  services: services ??
                      [service(100, 50), service(200, 30), service(300, 10)],
                  usage: readings ??
                      [
                        TaskUsageReading(
                            taskId: 't', value: 350, recordedAt: now)
                      ]),
              now)
          .recommendations
          .first;

  for (final metric in [
    TrackingMetric.hours,
    TrackingMetric.cycles,
    TrackingMetric.pages,
    TrackingMetric.litres
  ]) {
    test('${metric.label} learns its own usage interval without mileage', () {
      final r =
          calculate(TaskRule(id: 't', name: 'Maintenance', metric: metric));
      expect(r.targetValue, 400);
      expect(r.remainingValue, 50);
      expect(r.remainingKm, isNull);
      expect(r.metric, metric);
    });
  }
  test('Mileage is suppressed until the asset is explicitly a car', () {
    final r = calculate(const TaskRule(
        id: 't', name: 'Maintenance', metric: TrackingMetric.kilometres));
    expect(r.targetValue, isNull);
    expect(r.reason, contains('cars'));
  });
  test('Elapsed-time history works without any usage readings', () {
    final r = calculate(
        const TaskRule(
            id: 't', name: 'Maintenance', metric: TrackingMetric.time),
        readings: []);
    expect(r.calendarDue, now.add(const Duration(days: 10)));
    expect(r.currentValue, isNull);
    expect(r.remainingValue, isNull);
  });
  test(
      'Configured user interval needs one baseline, not three historical services',
      () {
    final r = calculate(
        const TaskRule(
            id: 't',
            name: 'Maintenance',
            metric: TrackingMetric.hours,
            source: RuleSource.user,
            usageInterval: 100,
            daysInterval: 30),
        services: [service(300, 10)]);
    expect(r.targetValue, 400);
    expect(r.calendarDue, now.add(const Duration(days: 20)));
    expect(r.rule!.source, RuleSource.user);
  });
  test('User/history estimates cannot exceed entered manufacturer limits', () {
    for (final source in [
      RuleSource.user,
      RuleSource.history,
      RuleSource.manufacturer
    ]) {
      final r = calculate(TaskRule(
          id: 't',
          name: 'Maintenance',
          metric: TrackingMetric.hours,
          source: source,
          usageInterval: 200,
          daysInterval: 60,
          manufacturerUsageLimit: 80,
          manufacturerDaysLimit: 15,
          manufacturerReference: 'Exact model manual'));
      expect(r.targetValue, 380);
      expect(r.remainingValue, 30);
      expect(r.calendarDue, now.add(const Duration(days: 5)));
      expect(r.estimatedDue, r.calendarDue);
      expect(r.manufacturerLimitApplied, isTrue);
    }
  });
  test('The earlier usage projection wins over a later time limit', () {
    final r = calculate(
        const TaskRule(
            id: 't',
            name: 'Maintenance',
            metric: TrackingMetric.hours,
            source: RuleSource.user,
            usageInterval: 60,
            daysInterval: 100),
        services: [service(300, 10)],
        readings: [TaskUsageReading(taskId: 't', value: 350, recordedAt: now)]);
    expect(r.usageDue, now.add(const Duration(days: 2)));
    expect(r.estimatedDue, r.usageDue);
  });
  test('Repairs do not teach routine intervals or contaminate cost baselines',
      () {
    final r = calculate(
        const TaskRule(
            id: 't', name: 'Maintenance', metric: TrackingMetric.hours),
        services: [
          service(100, 50),
          service(200, 30),
          service(300, 10),
          service(340, 1, kind: 'repair', cost: 10000)
        ]);
    expect(r.targetValue, 400);
    expect(r.highCost, isFalse);
    expect(r.costSampleCount, 0);
  });
  test('Different components, task IDs, and counters stay separate', () {
    final history = PredictionHistory(readings: [], rules: const [
      TaskRule(
          id: 't',
          name: 'Maintenance',
          component: 'Drum',
          metric: TrackingMetric.cycles),
      TaskRule(
          id: 'p',
          name: 'Maintenance',
          component: 'Filter',
          metric: TrackingMetric.hours),
    ], services: [
      service(100, 50),
      service(200, 30),
      service(300, 10)
    ], usage: [
      TaskUsageReading(taskId: 't', value: 350, recordedAt: now),
      TaskUsageReading(taskId: 'p', value: 5000, recordedAt: now),
    ]);
    final result = const BuildMaintenanceRecommendations()(history, now);
    expect(
        result.recommendations
            .firstWhere((r) => r.rule!.id == 't')
            .remainingValue,
        50);
    expect(
        result.recommendations.firstWhere((r) => r.rule!.id == 'p').targetValue,
        isNull);
  });
  test('Condition checks report observations, not predicted failure', () {
    final r = calculate(
        const TaskRule(
            id: 't',
            name: 'Maintenance',
            metric: TrackingMetric.condition,
            source: RuleSource.user),
        readings: [
          TaskUsageReading(
              taskId: 't',
              recordedAt: now,
              condition: ObservedCondition.attention,
              notes: 'Visible debris')
        ]);
    expect(r.condition, ObservedCondition.attention);
    expect(r.conditionNotes, 'Visible debris');
    expect(r.targetValue, isNull);
    expect(r.reason, contains('not an automatic diagnosis'));
  });
  test('Old observations must be renewed after completing maintenance', () {
    final r = calculate(
        const TaskRule(
            id: 't',
            name: 'Maintenance',
            metric: TrackingMetric.condition,
            source: RuleSource.user),
        readings: [
          TaskUsageReading(
              taskId: 't',
              recordedAt: now.subtract(const Duration(days: 20)),
              condition: ObservedCondition.attention)
        ]);
    expect(r.condition, isNull);
  });
  test(
      'Invalid intervals, units and unverifiable manufacturer inputs require correction',
      () {
    for (final rule in [
      const TaskRule(
          name: 'Clean',
          metric: TrackingMetric.cycles,
          source: RuleSource.user,
          usageInterval: 1.5),
      const TaskRule(
          name: 'Clean',
          metric: TrackingMetric.hours,
          source: RuleSource.user,
          usageInterval: -1),
      const TaskRule(
          name: 'Clean',
          metric: TrackingMetric.time,
          source: RuleSource.manufacturer,
          manufacturerDaysLimit: 90),
      const TaskRule(name: 'Check', metric: TrackingMetric.condition),
    ]) {
      expect(() => validateRule(rule),
          throwsA(isA<PredictionValidationException>()));
    }
    expect(parseUsage('1.5', TrackingMetric.hours), 1.5);
    expect(() => parseUsage('1.5', TrackingMetric.pages),
        throwsA(isA<PredictionValidationException>()));
    expect(
        () => validateTaskReading(
            TaskUsageReading(taskId: 't', recordedAt: now, value: 1.5),
            const TaskRule(name: 'Print', metric: TrackingMetric.pages),
            now),
        throwsA(isA<PredictionValidationException>()));
  });
  test(
      'Unconfigured legacy services are retained without a made-up usage method',
      () {
    final report = const BuildMaintenanceRecommendations()(
        PredictionHistory(readings: [], services: [
          ServiceSample(
              task: 'Old task', cost: 100, performedAt: now, odometerKm: 1000),
        ]),
        now);
    expect(report.recommendations.single.rule, isNull);
    expect(report.recommendations.single.unconfiguredName, 'Old task');
    expect(report.recommendations.single.targetValue, isNull);
  });
}
