class PredictionValidationException implements Exception {
  const PredictionValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

String normalizeTask(String task) =>
    task.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

enum TrackingMetric {
  time('Days since service', 'days'),
  kilometres('Distance driven (car)', 'km'),
  hours('Hours used', 'hours'),
  cycles('Number of uses', 'uses'),
  pages('Pages printed', 'pages'),
  litres('Litres filtered', 'L'),
  condition('How it looks or works', '');

  const TrackingMetric(this.label, this.unit);
  final String label, unit;
  bool get numeric => this != time && this != condition;
  bool get whole => this == kilometres || this == cycles || this == pages;
  String get totalLabel => switch (this) {
        time => 'Days since service',
        kilometres => 'Dashboard distance (km)',
        hours => 'Total hours used',
        cycles => 'Total uses so far',
        pages => 'Total pages printed',
        litres => 'Total litres filtered',
        condition => 'What do you notice?',
      };
  String get serviceLabel => this == kilometres
      ? 'Dashboard distance at service (km)'
      : 'Total $unit at service';
  String get explanation => switch (this) {
        time => 'Use the number of days since you last did this job.',
        kilometres => 'For cars: enter the distance shown on the dashboard.',
        hours =>
          'For machines such as generators: record the total hours it has run.',
        cycles =>
          'One use means one complete run, such as one wash. Keep adding uses to the total.',
        pages => 'Record the total number of pages the printer has printed.',
        litres => 'Record the total litres filtered or processed.',
        condition =>
          'Record what you notice, such as dust, a leak or unusual noise. No sensor is needed.',
      };
}

enum RuleSource {
  history('My past service records'),
  user('My own timing'),
  manufacturer('The product manual');

  const RuleSource(this.label);
  final String label;
}

enum ObservedCondition { good, watch, attention }

class TaskRule {
  const TaskRule(
      {this.id = '',
      required this.name,
      this.component = '',
      required this.metric,
      this.source = RuleSource.history,
      this.usageInterval,
      this.daysInterval,
      this.manufacturerUsageLimit,
      this.manufacturerDaysLimit,
      this.manufacturerReference});
  final String id, name, component;
  final TrackingMetric metric;
  final RuleSource source;
  final double? usageInterval, manufacturerUsageLimit;
  final int? daysInterval, manufacturerDaysLimit;
  final String? manufacturerReference;
  String get displayName => component.isEmpty ? name : '$component · $name';
}

class TaskUsageReading {
  const TaskUsageReading(
      {required this.taskId,
      required this.recordedAt,
      this.value,
      this.condition,
      this.notes = ''});
  final String taskId, notes;
  final DateTime recordedAt;
  final double? value;
  final ObservedCondition? condition;
}

// Retained for lossless access to v2 odometer records.
class MileageReading {
  const MileageReading({required this.km, required this.recordedAt});
  final int km;
  final DateTime recordedAt;
}

class ServiceSample {
  const ServiceSample(
      {required this.task,
      required this.cost,
      required this.performedAt,
      this.odometerKm,
      this.taskId,
      this.usageValue,
      this.component = '',
      this.kind = 'routine'});
  final String task, component, kind;
  final String? taskId;
  final double cost;
  final DateTime performedAt;
  final int? odometerKm;
  final double? usageValue;
  bool get scheduled => ['routine', 'inspection'].contains(kind.toLowerCase());
}

class PredictionHistory {
  const PredictionHistory(
      {required this.services,
      required this.readings,
      this.rules = const [],
      this.usage = const [],
      this.isCar = false,
      this.category = ''});
  final List<ServiceSample> services;
  final List<MileageReading> readings;
  final List<TaskRule> rules;
  final List<TaskUsageReading> usage;
  final bool isCar;
  final String category;
}

class ServiceDraft {
  const ServiceDraft(
      {required this.assetId,
      required this.description,
      required this.kind,
      required this.cost,
      required this.performedAt,
      this.planId,
      this.receiptPath,
      this.task,
      this.odometerKm,
      this.taskId,
      this.usageValue,
      this.component = '',
      this.performedBy = '',
      this.usageUnit = '',
      this.batteryReplaced = false});
  final String assetId, description, kind, component, performedBy;
  final String usageUnit;
  final bool batteryReplaced;
  final String? planId, receiptPath, task, taskId;
  final int? odometerKm;
  final double? usageValue;
  final double cost;
  final DateTime performedAt;
}

class MaintenanceRecommendation {
  const MaintenanceRecommendation(
      {required this.task,
      required this.sampleCount,
      required this.reason,
      this.rule,
      this.unconfiguredName,
      this.unconfiguredComponent = '',
      this.currentValue,
      this.currentDate,
      this.lastValue,
      this.targetValue,
      this.remainingValue,
      this.intervalValue,
      this.estimatedDue,
      this.usageDue,
      this.calendarDue,
      this.perDay,
      this.manufacturerLimitApplied = false,
      this.condition,
      this.conditionNotes = '',
      this.latestCost,
      this.baselineCost,
      this.costSampleCount = 0});
  final String task, reason, conditionNotes;
  final TaskRule? rule;
  final String? unconfiguredName;
  final String unconfiguredComponent;
  final int sampleCount, costSampleCount;
  final double? currentValue,
      lastValue,
      targetValue,
      remainingValue,
      intervalValue,
      perDay;
  final DateTime? currentDate, estimatedDue, usageDue, calendarDue;
  final bool manufacturerLimitApplied;
  final ObservedCondition? condition;
  final double? latestCost, baselineCost;
  TrackingMetric? get metric => rule?.metric;
  bool get highCost =>
      baselineCost != null &&
      latestCost != null &&
      latestCost! > baselineCost! * 1.5;
  double? get costIncreasePercent =>
      highCost ? (latestCost! / baselineCost! - 1) * 100 : null;
  int? get lastServiceKm =>
      metric == TrackingMetric.kilometres ? lastValue?.round() : null;
  int? get targetKm =>
      metric == TrackingMetric.kilometres ? targetValue?.round() : null;
  int? get remainingKm =>
      metric == TrackingMetric.kilometres ? remainingValue?.round() : null;
  double? get intervalKm =>
      metric == TrackingMetric.kilometres ? intervalValue : null;
  double? get kmPerDay => metric == TrackingMetric.kilometres ? perDay : null;
}

class PredictionReport {
  const PredictionReport(
      {required this.recommendations,
      this.current,
      this.rules = const [],
      this.isCar = false,
      this.category = ''});
  final List<MaintenanceRecommendation> recommendations;
  final MileageReading? current;
  final List<TaskRule> rules;
  final bool isCar;
  final String category;
}
