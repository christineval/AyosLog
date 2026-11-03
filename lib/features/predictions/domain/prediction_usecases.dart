import 'prediction_models.dart';
import 'prediction_repository.dart';

double? parseUsage(String input, TrackingMetric metric) {
  final text = input.trim();
  if (text.isEmpty) return null;
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) {
    throw const PredictionValidationException(
        'Enter a nonnegative number without separators.');
  }
  final value = double.tryParse(text);
  if (value == null ||
      !value.isFinite ||
      value > (metric == TrackingMetric.kilometres ? 9999999 : 1e12) ||
      (metric.whole && value != value.roundToDouble())) {
    throw PredictionValidationException(metric.whole
        ? 'Enter a whole-number reading within the supported range.'
        : 'Enter a valid usage reading.');
  }
  return value;
}

int? parseMileage(String input) =>
    parseUsage(input, TrackingMetric.kilometres)?.toInt();
void validateReading(MileageReading reading, DateTime now,
    {List<MileageReading> existing = const []}) {
  if (reading.km < 0 ||
      reading.km > 9999999 ||
      reading.recordedAt.isAfter(now)) {
    throw const PredictionValidationException(
        'Enter valid mileage dated today or earlier.');
  }
  validateCounter(reading.km.toDouble(), reading.recordedAt,
      existing.map((r) => (r.km.toDouble(), r.recordedAt)).toList());
}

void validateCounter(
    double value, DateTime date, List<(double, DateTime)> existing) {
  for (final (other, at) in existing) {
    if ((at.isBefore(date) && other > value) ||
        (at.isAfter(date) && other < value) ||
        (at.isAtSameMomentAs(date) && other != value)) {
      throw const PredictionValidationException(
          'Usage must fit between the earlier and later readings for this task.');
    }
  }
}

void validateRule(TaskRule rule) {
  if (normalizeTask(rule.name).isEmpty ||
      rule.name.trim().length > 80 ||
      rule.component.trim().length > 80) {
    throw const PredictionValidationException(
        'Enter a task name and keep task/component names within 80 characters.');
  }
  for (final value in [rule.usageInterval, rule.manufacturerUsageLimit]) {
    if (value != null &&
        (!value.isFinite ||
            value <= 0 ||
            value > 1e12 ||
            !rule.metric.numeric ||
            (rule.metric.whole && value != value.roundToDouble()))) {
      throw const PredictionValidationException(
          'Usage intervals must be positive and match the selected unit.');
    }
  }
  for (final days in [rule.daysInterval, rule.manufacturerDaysLimit]) {
    if (days != null && (days <= 0 || days > 36500)) {
      throw const PredictionValidationException(
          'Enter an interval from 1 to 36,500 days.');
    }
  }
  final hasManual =
      rule.manufacturerUsageLimit != null || rule.manufacturerDaysLimit != null;
  if ((hasManual || rule.source == RuleSource.manufacturer) &&
      (rule.manufacturerReference ?? '').trim().isEmpty) {
    throw const PredictionValidationException(
        'Add the model, manual page or link for these instructions.');
  }
  if (rule.source == RuleSource.manufacturer && !hasManual) {
    throw const PredictionValidationException(
        'Enter how often the product manual says to do this job.');
  }
  if (rule.source == RuleSource.user &&
      rule.metric != TrackingMetric.condition &&
      rule.usageInterval == null &&
      rule.daysInterval == null) {
    throw const PredictionValidationException(
        'Enter how many days or how much use should pass before the next reminder.');
  }
  if (rule.metric == TrackingMetric.condition &&
      rule.source == RuleSource.history) {
    throw const PredictionValidationException(
        'For checks, choose your own timing or the product manual.');
  }
}

void validateTaskReading(
    TaskUsageReading reading, TaskRule rule, DateTime now) {
  if (reading.recordedAt.isAfter(now) || reading.notes.length > 1000) {
    throw const PredictionValidationException(
        'Use a date today or earlier and notes within 1,000 characters.');
  }
  if (rule.metric == TrackingMetric.condition) {
    if (reading.condition == null || reading.value != null) {
      throw const PredictionValidationException(
          'Choose an observed condition.');
    }
  } else if (rule.metric.numeric) {
    if (reading.value == null ||
        reading.condition != null ||
        reading.value! < 0) {
      throw const PredictionValidationException(
          'Enter a cumulative usage reading.');
    }
    parseUsage(
        reading.value!.toStringAsFixed(rule.metric.whole ? 0 : 6), rule.metric);
    if (!reading.value!.isFinite ||
        (rule.metric.whole &&
            reading.value != reading.value!.roundToDouble()) ||
        reading.value! >
            (rule.metric == TrackingMetric.kilometres ? 9999999 : 1e12)) {
      throw const PredictionValidationException(
          'Enter a valid reading for the selected unit.');
    }
  } else {
    throw const PredictionValidationException(
        'Time-based tasks do not need a usage counter.');
  }
}

class SaveTaskRule {
  const SaveTaskRule(this.repository);
  final PredictionRepository repository;
  Future<void> call(String assetId, TaskRule rule, {bool markAsCar = false}) {
    validateRule(rule);
    return repository.saveRule(assetId, rule, markAsCar: markAsCar);
  }
}

class AddTaskUsage {
  const AddTaskUsage(this.repository);
  final PredictionRepository repository;
  Future<void> call(String assetId, TaskUsageReading reading) =>
      repository.addTaskReading(assetId, reading);
}

class AddMileageReading {
  const AddMileageReading(this.repository);
  final PredictionRepository repository;
  Future<void> call(String assetId, MileageReading reading) {
    validateReading(reading, DateTime.now());
    return repository.addReading(assetId, reading);
  }
}

class RecordPredictiveService {
  const RecordPredictiveService(this.repository);
  final PredictionRepository repository;
  Future<void> call(ServiceDraft draft) {
    if (draft.performedBy.trim().length > 80) {
      throw const PredictionValidationException(
          'Use 80 characters or fewer for who performed the service.');
    }
    if (draft.description.trim().isEmpty ||
        !draft.cost.isFinite ||
        draft.cost < 0 ||
        draft.performedAt.isAfter(DateTime.now())) {
      throw const PredictionValidationException(
          'Enter service notes, a valid cost, and a service date today or earlier.');
    }
    if (normalizeTask(draft.task ?? '').length > 80 ||
        draft.component.trim().length > 80) {
      throw const PredictionValidationException(
          'Keep task/component names within 80 characters.');
    }
    if (draft.odometerKm != null) {
      if (normalizeTask(draft.task ?? '').isEmpty) {
        throw const PredictionValidationException(
            'Name the maintenance task for this mileage.');
      }
      validateReading(
          MileageReading(km: draft.odometerKm!, recordedAt: draft.performedAt),
          DateTime.now());
    }
    if (draft.usageValue != null &&
        ((draft.taskId == null &&
                !['km', 'hours', 'L', 'cycles'].contains(draft.usageUnit)) ||
            !draft.usageValue!.isFinite ||
            draft.usageValue! < 0)) {
      throw const PredictionValidationException(
          'Choose a configured task for a valid usage reading.');
    }
    return repository.recordService(draft);
  }
}

class BuildMaintenanceRecommendations {
  const BuildMaintenanceRecommendations();
  PredictionReport call(PredictionHistory history, DateTime now) {
    final all = history.services
        .where((s) => !s.performedAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.performedAt.compareTo(b.performedAt));
    final recommendations = <MaintenanceRecommendation>[];
    bool matches(ServiceSample s, TaskRule r) =>
        s.taskId == r.id ||
        (s.taskId == null &&
            normalizeTask(s.task) == normalizeTask(r.name) &&
            normalizeTask(s.component) == normalizeTask(r.component));
    for (final rule in history.rules) {
      final services = all.where((s) => matches(s, rule)).toList();
      recommendations.add(_build(rule, services, history, now));
    }
    final unconfigured = <String, List<ServiceSample>>{};
    for (final s in all) {
      if (normalizeTask(s.task).isNotEmpty &&
          !history.rules.any((r) => matches(s, r))) {
        (unconfigured[
                '${normalizeTask(s.component)}|${normalizeTask(s.task)}'] ??= [])
            .add(s);
      }
    }
    for (final group in unconfigured.values) {
      final last = group.last;
      final costs = _costs(group);
      recommendations.add(MaintenanceRecommendation(
          task: last.component.isEmpty
              ? last.task
              : '${last.component} · ${last.task}',
          sampleCount: 0,
          unconfiguredName: last.task,
          unconfiguredComponent: last.component,
          reason:
              'Choose a tracking method for this task. Existing service records are preserved.',
          latestCost: costs.$1,
          baselineCost: costs.$2,
          costSampleCount: costs.$3));
    }
    recommendations.sort((a, b) {
      if (a.condition == ObservedCondition.attention &&
          b.condition != ObservedCondition.attention) {
        return -1;
      }
      if (b.condition == ObservedCondition.attention &&
          a.condition != ObservedCondition.attention) {
        return 1;
      }
      if (a.estimatedDue != null && b.estimatedDue != null) {
        return a.estimatedDue!.compareTo(b.estimatedDue!);
      }
      return a.task.compareTo(b.task);
    });
    final legacy = history.readings
        .where((r) => !r.recordedAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return PredictionReport(
        recommendations: recommendations,
        current: legacy.isEmpty ? null : legacy.last,
        rules: history.rules,
        isCar: history.isCar,
        category: history.category);
  }

  (double?, double?, int) _costs(List<ServiceSample> services) {
    if (services.isEmpty) return (null, null, 0);
    final last = services.last;
    final prior = services
        .take(services.length - 1)
        .where((s) =>
            s.kind.toLowerCase() == last.kind.toLowerCase() &&
            s.cost.isFinite &&
            s.cost > 0)
        .toList();
    final baseline = prior.length < 3
        ? null
        : prior.fold<double>(0, (sum, s) => sum + s.cost / prior.length);
    return (
      last.cost > 0 && last.cost.isFinite ? last.cost : null,
      baseline,
      prior.length
    );
  }

  MaintenanceRecommendation _build(TaskRule rule, List<ServiceSample> services,
      PredictionHistory history, DateTime now) {
    final costs = _costs(services);
    final scheduled = services.where((s) => s.scheduled).toList();
    final last = scheduled.isEmpty ? null : scheduled.last;
    double? value(ServiceSample s) {
      if (!rule.metric.numeric) return null;
      if (s.taskId == rule.id) {
        return s.usageValue ??
            (rule.metric == TrackingMetric.kilometres
                ? s.odometerKm?.toDouble()
                : null);
      }
      return rule.metric == TrackingMetric.kilometres
          ? s.odometerKm?.toDouble()
          : null;
    }

    final sequence = scheduled
        .skip(scheduled.lastIndexWhere((s) => value(s) == null) + 1)
        .toList();
    final observed = history.usage
        .where((r) => r.taskId == rule.id && !r.recordedAt.isAfter(now))
        .toList();
    final points = <(double, DateTime)>[
      if (rule.metric.numeric)
        for (final r in observed)
          if (r.value != null) (r.value!, r.recordedAt),
      for (final s in scheduled)
        if (value(s) != null) (value(s)!, s.performedAt),
      if (rule.metric == TrackingMetric.kilometres && history.isCar)
        for (final r in history.readings)
          if (!r.recordedAt.isAfter(now)) (r.km.toDouble(), r.recordedAt),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final current = points.isEmpty ? null : points.last;
    final latestCompletion =
        services.isEmpty ? null : services.last.performedAt;
    final conditions = observed
        .where((r) =>
            r.condition != null &&
            (latestCompletion == null ||
                !r.recordedAt.isBefore(latestCompletion)))
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final condition = conditions.isEmpty ? null : conditions.last;
    double? interval =
        rule.source == RuleSource.user ? rule.usageInterval : null;
    double? days =
        rule.source == RuleSource.user ? rule.daysInterval?.toDouble() : null;
    var reason = rule.source.label;
    final sampleCount =
        rule.metric.numeric ? sequence.length : scheduled.length;
    if (rule.source == RuleSource.history) {
      if (scheduled.length >= 3) {
        final gaps = [
          for (var i = 1; i < scheduled.length; i++)
            scheduled[i]
                    .performedAt
                    .difference(scheduled[i - 1].performedAt)
                    .inSeconds /
                86400
        ];
        if (gaps.every((g) => g > 0)) {
          days = gaps.reduce((a, b) => a + b) / gaps.length;
        }
      }
      if (rule.metric.numeric && sequence.length >= 3) {
        final gaps = [
          for (var i = 1; i < sequence.length; i++)
            value(sequence[i])! - value(sequence[i - 1])!
        ];
        if (gaps.every((g) => g > 0)) {
          interval = gaps.reduce((a, b) => a + b) / gaps.length;
        }
      }
      reason =
          'Based on ${scheduled.length} routine jobs or checks; ${sequence.length} include recorded usage. Repairs are kept out. At least 3 routine records are needed to estimate your usual timing.';
    }
    var limited = false;
    if (rule.manufacturerUsageLimit != null &&
        (interval == null || rule.manufacturerUsageLimit! < interval)) {
      interval = rule.manufacturerUsageLimit;
      limited = true;
    }
    if (rule.manufacturerDaysLimit != null &&
        (days == null || rule.manufacturerDaysLimit! < days)) {
      days = rule.manufacturerDaysLimit!.toDouble();
      limited = true;
    }
    if (rule.metric == TrackingMetric.kilometres && !history.isCar) {
      return MaintenanceRecommendation(
          task: rule.displayName,
          rule: rule,
          sampleCount: sampleCount,
          reason:
              'Mileage tracking is available only for assets explicitly marked as cars.',
          latestCost: costs.$1,
          baselineCost: costs.$2,
          costSampleCount: costs.$3);
    }
    final lastValue = last == null ? null : value(last);
    final target = interval != null && lastValue != null
        ? lastValue + (rule.metric.whole ? interval.roundToDouble() : interval)
        : null;
    final remaining = target != null &&
            current != null &&
            last != null &&
            !current.$2.isBefore(last.performedAt) &&
            current.$1 >= lastValue!
        ? target - current.$1
        : null;
    DateTime? calendar, usageDue;
    if (last != null && days != null && days <= 36500) {
      calendar = last.performedAt.add(Duration(days: days.ceil()));
    }
    double? rate;
    if (current != null) {
      final recent = points
          .where((p) =>
              !p.$2.isBefore(current.$2.subtract(const Duration(days: 90))))
          .toList();
      if (recent.length >= 2) {
        final span = current.$2.difference(recent.first.$2).inSeconds / 86400;
        final distance = current.$1 - recent.first.$1;
        final increasing = [
          for (var i = 1; i < recent.length; i++)
            recent[i].$1 >= recent[i - 1].$1
        ].every((ok) => ok);
        if (span >= 7 && distance > 0 && increasing) {
          rate = distance / span;
        }
      }
      if (remaining != null &&
          remaining > 0 &&
          rate != null &&
          remaining / rate <= 36500) {
        usageDue = current.$2.add(Duration(days: (remaining / rate).ceil()));
      }
    }
    DateTime? due = calendar;
    if (usageDue != null && (due == null || usageDue.isBefore(due))) {
      due = usageDue;
    }
    if (last == null) {
      reason =
          'Record when you last did this routine job or check so the app knows where to start. $reason';
    }
    if (rule.metric == TrackingMetric.condition) {
      reason =
          'Condition is a user observation, not an automatic diagnosis. ${condition == null ? 'Record a new check after the latest service.' : ''}';
    }
    return MaintenanceRecommendation(
        task: rule.displayName,
        rule: rule,
        sampleCount: sampleCount,
        reason: reason,
        currentValue: current?.$1,
        currentDate: rule.metric == TrackingMetric.condition
            ? condition?.recordedAt
            : current?.$2,
        lastValue: lastValue,
        targetValue: target,
        remainingValue: remaining,
        intervalValue: interval,
        estimatedDue: due,
        usageDue: usageDue,
        calendarDue: calendar,
        perDay: rate,
        manufacturerLimitApplied: limited,
        condition: condition?.condition,
        conditionNotes: condition?.notes ?? '',
        latestCost: costs.$1,
        baselineCost: costs.$2,
        costSampleCount: costs.$3);
  }
}
