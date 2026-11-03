import 'dart:math' as math;
import 'forecast_models.dart';

double median(List<double> values) {
  final sorted = [...values]..sort();
  final n = sorted.length;
  return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
}

double canonicalValue(double value, String unit) => switch (unit) {
      'mi' => value * 1.609344,
      '°F' => (value - 32) * 5 / 9,
      'km' ||
      '°C' ||
      'hours' ||
      'L' ||
      'cycles' ||
      'percent' ||
      'units' =>
        value,
      _ => throw const ForecastValidation('Unsupported unit.'),
    };

void validateForecastTask(ForecastTask t, DateTime now) {
  if (t.name.trim().isEmpty ||
      t.name.length > 80 ||
      t.assetId.isEmpty ||
      t.baselineAt.isAfter(now) ||
      !t.baseline.isFinite ||
      t.baseline < 0 ||
      t.baseline > 1e12 ||
      t.warningDays < 0 ||
      t.warningDays > 36500 ||
      t.freshnessDays < 1 ||
      t.freshnessDays > 36500 ||
      !t.warningFraction.isFinite ||
      t.warningFraction < 0 ||
      t.warningFraction > 1) {
    throw const ForecastValidation(
        'Check the name, baseline date, reading and warning settings.');
  }
  if ((t.interval != null &&
          (!t.interval!.isFinite || t.interval! <= 0 || t.interval! > 1e12)) ||
      (t.intervalDays != null &&
          (t.intervalDays! <= 0 || t.intervalDays! > 36500)) ||
      (t.dailyRate != null &&
          (!t.dailyRate!.isFinite || t.dailyRate! < 0 || t.dailyRate! > 1e9))) {
    throw const ForecastValidation(
        'Intervals must be positive; estimated use cannot be negative.');
  }
  if (t.source == PlanSource.manufacturer && t.reference.trim().isEmpty) {
    throw const ForecastValidation(
        'Add the model, manual page or link for this plan.');
  }
  if (t.metric.counter && t.interval == null && t.intervalDays == null ||
      t.method == UsageMethod.calendar && t.intervalDays == null) {
    throw const ForecastValidation(
        'Enter a usage interval or a number of days.');
  }
  if (t.method == UsageMethod.estimated &&
      (t.dailyRate == null || !t.metric.counter)) {
    throw const ForecastValidation(
        'Enter estimated daily usage for this counter.');
  }
  if ((t.metric == ForecastMetric.cycles &&
          t.interval != null &&
          t.interval! % 1 != 0) ||
      t.metric == ForecastMetric.custom && t.customUnit.trim().isEmpty ||
      (t.minimum == null) != (t.maximum == null) ||
      t.minimum != null &&
          (!t.minimum!.isFinite ||
              !t.maximum!.isFinite ||
              t.minimum! >= t.maximum!)) {
    throw const ForecastValidation(
        'Use whole cycles, name custom units, and check the expected range.');
  }
  final metric = switch (t.subtype) {
    AssetSubtype.vehicle => ForecastMetric.distance,
    AssetSubtype.airConditioner => ForecastMetric.hours,
    AssetSubtype.waterFilter => ForecastMetric.litres,
    AssetSubtype.washingMachine => ForecastMetric.cycles,
    AssetSubtype.refrigerator => ForecastMetric.temperature,
    AssetSubtype.laptop => ForecastMetric.battery,
    AssetSubtype.custom => t.metric,
  };
  if (t.metric != metric ||
      t.method == UsageMethod.counter && !t.metric.counter ||
      t.method == UsageMethod.trend && t.metric.counter ||
      t.subtype == AssetSubtype.vehicle && t.method == UsageMethod.estimated) {
    throw const ForecastValidation(
        'Choose a measurement method compatible with this asset.');
  }
}

class PredictionEngine {
  const PredictionEngine();
  ForecastPrediction calculate(
      ForecastTask task, List<Observation> observations, DateTime now) {
    final ordered = observations
        .where((r) =>
            !r.deleted &&
            r.taskId == task.id &&
            r.assetId == task.assetId &&
            !r.at.isBefore(task.trendSince ?? task.baselineAt) &&
            !r.at.isAfter(now))
        .toList()
      ..sort((a, b) {
        final c = a.at.compareTo(b.at);
        return c == 0 ? a.id.compareTo(b.id) : c;
      });
    final rationale = <String>[
      task.source == PlanSource.manufacturer
          ? 'User-entered manufacturer plan: ${task.reference}'
          : 'Owner-defined maintenance plan.',
      'Baseline: ${task.baselineKnown ? '${task.baseline} ${task.unit}' : 'counter not recorded'} at ${task.baselineAt.toUtc().toIso8601String()}.',
      'Rule-based planning support; not a diagnosis or trained machine learning.',
    ];
    if (!task.baselineKnown) {
      rationale.add(
          'The latest service has no counter reading. Correct it to establish a usage target; calendar limits still apply.');
    }
    ForecastPrediction invalid(String reason) => ForecastPrediction(
        task: task,
        state: ForecastState.invalid,
        reliability: Reliability.insufficient,
        calculatedAt: now,
        inputs: ordered,
        rationale: [...rationale, reason]);
    try {
      validateForecastTask(task, now);
    } on ForecastValidation catch (e) {
      return invalid(e.message);
    }
    final byTime = <int, Observation>{};
    for (final r in ordered.where((r) => r.values['reading'] != null)) {
      final key = r.at.millisecondsSinceEpoch;
      if (byTime.containsKey(key) &&
          byTime[key]!.values['reading'] != r.values['reading']) {
        return invalid(
            'Conflicting readings at the same time. Correct the history.');
      }
      byTime[key] = r;
    }
    var points = byTime.values.toList();
    // Counter replacement starts a new rate segment. Retain consumed usage as
    // an offset so replacing a meter never erases use since the last service.
    var offset = 0.0;
    var previous = task.baseline;
    var segmentStart = 0;
    final adjusted = <double>[];
    for (var i = 0; i < points.length; i++) {
      final raw = points[i].values['reading']!;
      if (!raw.isFinite) return invalid('A reading is not a finite number.');
      if (task.metric.counter &&
          (i > 0 || task.baselineKnown) &&
          raw < previous &&
          !points[i].reset) {
        return invalid(
            'Counter decreased. Record a meter reset or correct the reading.');
      }
      if (task.metric.counter && points[i].reset) {
        offset += previous - raw;
        segmentStart = i;
      }
      adjusted.add(raw + offset);
      previous = raw;
    }
    final numeric = task.method == UsageMethod.estimated
        ? ordered.where((r) => r.values.containsKey('daily_rate')).toList()
        : points;
    final latest = numeric.isEmpty ? null : numeric.last;
    final freshnessAt = latest?.at ??
        (task.method == UsageMethod.estimated ? task.baselineAt : null);
    final stale = freshnessAt != null &&
        now.difference(freshnessAt).inSeconds / 86400 > task.freshnessDays;
    DateTime? calendar = task.intervalDays == null
        ? null
        : task.baselineAt.add(Duration(days: task.intervalDays!));
    double? current = adjusted.isEmpty ? null : adjusted.last;
    double? rate;
    final rates = <double>[];
    if (task.method == UsageMethod.counter) {
      for (var i = math.max(1, segmentStart + 1); i < points.length; i++) {
        final days =
            points[i].at.difference(points[i - 1].at).inMilliseconds / 86400000;
        final delta = adjusted[i] - adjusted[i - 1];
        if (days > 0 &&
            delta >= 0 &&
            now.difference(points[i].at).inDays <= 90) {
          rates.add(delta / days);
        }
      }
      if (rates.isNotEmpty) {
        final candidate = median(rates);
        if (candidate > 0) rate = candidate;
      }
    }
    DateTime? anchor = points.isEmpty ? null : points.last.at;
    if (task.method == UsageMethod.estimated) {
      // Each estimated-rate check-in starts a new segment, never rewriting
      // historical usage with the most recent rate.
      var at = task.baselineAt;
      var runningRate = task.dailyRate!;
      current = task.baseline;
      for (final r
          in ordered.where((r) => r.values.containsKey('daily_rate'))) {
        current = current! +
            runningRate * r.at.difference(at).inMilliseconds / 86400000;
        at = r.at;
        runningRate = r.values['daily_rate']!;
      }
      current =
          current! + runningRate * now.difference(at).inMilliseconds / 86400000;
      if (runningRate > 0) rate = runningRate;
      anchor = now;
      rationale.add(
          'Estimated use accumulated between dated usage estimates; no device sensor is connected.');
    }
    final target =
        task.baselineKnown && task.metric.counter && task.interval != null
            ? task.baseline + task.interval!
            : null;
    final remaining =
        current == null || target == null ? null : target - current;
    final progress = current == null || target == null
        ? null
        : ((current - task.baseline) / task.interval!).clamp(0.0, 1.0);
    DateTime? usageDue;
    if (remaining != null && rate != null && anchor != null) {
      final days = math.max(0.0, remaining / rate);
      if (days <= 36500) usageDue = anchor.add(Duration(days: days.ceil()));
    }
    DateTime? due = calendar;
    if (usageDue != null && (due == null || usageDue.isBefore(due))) {
      due = usageDue;
    }
    if (calendar != null) {
      rationale.add(
          'Calendar limit applies independently; the earlier applicable limit wins.');
    }
    if (rate != null) {
      rationale.add(
          '${rate.toStringAsFixed(3)} ${task.unit}/day; ${rates.length} chronological rate pairs. Date anchored to ${anchor!.toUtc().toIso8601String()}.');
    }
    final alerts = <String>[];
    double? trend;
    final trendWindows = <int, double>{};
    final distinctDates = points
        .map((r) => r.at.toUtc().toIso8601String().substring(0, 10))
        .toSet();
    if (!task.metric.counter &&
        points.length >= 3 &&
        distinctDates.length >= 3) {
      final days =
          points.last.at.difference(points.first.at).inMilliseconds / 86400000;
      if (days > 0) trend = (adjusted.last - adjusted.first) / days;
      if (task.metric == ForecastMetric.temperature &&
          task.minimum != null &&
          adjusted
                  .where((v) => v < task.minimum! || v > task.maximum!)
                  .length >=
              2) {
        alerts.add(
            'Review repeated unusual temperatures against your configured range.');
      }
      if (task.metric == ForecastMetric.battery && trend != null && trend < 0) {
        alerts.add(
            'Battery health readings are decreasing. Review manufacturer diagnostics; no failure date is predicted.');
      }
    }
    if (task.metric == ForecastMetric.battery && points.length >= 3) {
      for (final window in [30, 60, 90]) {
        final recent = points
            .where((r) =>
                !r.at.isBefore(points.last.at.subtract(Duration(days: window))))
            .toList();
        if (recent.length >= 3) {
          final span =
              recent.last.at.difference(recent.first.at).inMilliseconds /
                  86400000;
          if (span >= window * .8) {
            trendWindows[window] = (recent.last.values['reading']! -
                    recent.first.values['reading']!) /
                span;
          }
        }
      }
    }
    const reviewValues = {
      'unusual',
      'weaker',
      'dirty',
      'worn',
      'yes',
      'reduced',
      'high',
      'often'
    };
    final recentConditions = ordered
        .where((r) => now.difference(r.at).inDays <= task.freshnessDays)
        .toList();
    final signalKeys =
        recentConditions.expand((r) => r.conditions.keys).toSet();
    for (final key in signalKeys) {
      final count = recentConditions
          .where((r) => reviewValues.contains(r.conditions[key]))
          .length;
      final immediate = key == 'leak' ||
          key == 'warning_lights' ||
          key == 'taste_or_odor_change';
      if (count >= (immediate ? 1 : 2)) {
        alerts.add(
            'Review ${key.replaceAll('_', ' ')} ($count reported checks). This is an observation, not a confirmed fault.');
      }
    }
    final overdue =
        remaining != null && remaining <= 0 || due != null && !due.isAfter(now);
    final soon = remaining != null &&
            task.interval != null &&
            remaining <= task.interval! * task.warningFraction ||
        due != null &&
            due.difference(now).inMilliseconds / 86400000 <= task.warningDays;
    final state = overdue
        ? ForecastState.overdue
        : soon
            ? ForecastState.dueSoon
            : alerts.isNotEmpty
                ? ForecastState.conditionAlert
                : stale
                    ? ForecastState.stale
                    : usageDue != null
                        ? ForecastState.estimated
                        : calendar != null
                            ? ForecastState.scheduled
                            : ForecastState.insufficientData;
    final consistent = rate != null &&
        rates.length >= 3 &&
        rates.every((r) => (r - rate!).abs() / rate <= .5);
    final reliability = rate == null
        ? Reliability.insufficient
        : consistent && !stale
            ? Reliability.moderate
            : Reliability.limited;
    if (stale) {
      rationale.add(
          'Last check-in is older than the configured ${task.freshnessDays}-day freshness limit.');
    }
    if (rate == null && task.metric.counter) {
      rationale.add(
          'No positive rate: remaining use can be shown, but no usage date is invented.');
    }
    return ForecastPrediction(
        task: task,
        state: state,
        reliability: reliability,
        calculatedAt: now,
        inputs: ordered,
        rationale: rationale,
        dueAt: due,
        usageDue: usageDue,
        calendarDue: calendar,
        target: target,
        current: current,
        remaining: remaining,
        progress: progress,
        rate: rate,
        ratePairs: rates.length,
        latestAt: freshnessAt,
        stale: stale,
        alerts: alerts,
        trend: trend,
        trendWindows: trendWindows);
  }
}
