import 'forecast_models.dart';
import 'prediction_models.dart';

enum InsightTone { normal, review, overdue, neutral }

enum InsightOrigin { forecast, legacy, unconfigured }

enum InsightAction { plan, reading, condition, service }

class MaintenanceInsight {
  const MaintenanceInsight(
      {required this.assetId,
      required this.assetName,
      required this.category,
      required this.title,
      required this.subtitle,
      required this.headline,
      required this.explanation,
      required this.evidence,
      required this.reliability,
      required this.actionLabel,
      this.taskId,
      this.origin = InsightOrigin.forecast,
      this.tone = InsightTone.normal,
      this.status = 'Estimated',
      this.progress,
      this.progressLabel,
      this.remainingLabel,
      this.windowTitle,
      this.window,
      this.prediction,
      this.alerts = const [],
      this.isCondition = false,
      this.isScheduled = false,
      this.action = InsightAction.reading});
  final String assetId,
      assetName,
      category,
      title,
      subtitle,
      headline,
      explanation,
      reliability,
      actionLabel,
      status;
  final String? taskId, progressLabel, remainingLabel, windowTitle, window;
  final InsightOrigin origin;
  final InsightTone tone;
  final double? progress;
  final List<String> evidence, alerts;
  final ForecastPrediction? prediction;
  final bool isCondition;
  final bool isScheduled;
  final InsightAction action;
}

String insightNumber(num n) {
  final parts = n.toStringAsFixed(n % 1 == 0 ? 0 : 1).split('.');
  final whole = parts.first
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return parts.length == 1 ? whole : '$whole.${parts.last}';
}

String insightDate(DateTime d) =>
    d.toLocal().toIso8601String().split('T').first;

class BuildMaintenanceInsight {
  const BuildMaintenanceInsight();
  MaintenanceInsight empty(String assetId, String name, String category) =>
      MaintenanceInsight(
          assetId: assetId,
          assetName: name,
          category: category,
          title: 'Maintenance plan',
          subtitle: 'Set up maintenance tracking',
          headline: 'Set a maintenance plan',
          explanation:
              'Choose a task and enter timing from your own plan or product manual.',
          evidence: const [],
          reliability:
              'A forecast needs a configured plan and relevant recorded data.',
          actionLabel: 'Set maintenance plan',
          origin: InsightOrigin.unconfigured,
          tone: InsightTone.neutral,
          status: 'Set up',
          action: InsightAction.plan);

  MaintenanceInsight forecast(AssetInsight item) {
    final p = item.prediction;
    if (p == null) return empty(item.assetId, item.assetName, item.category);
    final t = p.task, now = p.calculatedAt;
    final condition = t.metric == ForecastMetric.temperature ||
        t.metric == ForecastMetric.battery;
    final actualCounter = t.metric.counter && t.method != UsageMethod.calendar;
    final consumed =
        p.current == null || !t.baselineKnown ? null : p.current! - t.baseline;
    final evidence = <String>[];
    if (t.baselineKnown && actualCounter) {
      evidence
          .add('Last service reading: ${insightNumber(t.baseline)} ${t.unit}');
    }
    evidence.add('Last service / starting date: ${insightDate(t.baselineAt)}');
    if (p.current != null) {
      evidence.add(
          '${t.method == UsageMethod.estimated ? 'Estimated total' : p.inputs.any((r) => r.reset) ? 'Tracked total adjusted for meter reset' : 'Latest recorded reading'}: ${insightNumber(p.current!)} ${t.unit}');
    }
    if (p.rate != null) {
      evidence.add(
          'Estimated weekly usage: ${insightNumber(p.rate! * 7)} ${t.unit}');
    }
    if (t.interval != null) {
      evidence
          .add('Configured interval: ${insightNumber(t.interval!)} ${t.unit}');
    }
    if (t.intervalDays != null) {
      evidence.add('Configured calendar limit: ${t.intervalDays} days');
    }
    if (t.minimum != null) {
      evidence.add(
          'Configured temperature range: ${insightNumber(t.minimum!)}–${insightNumber(t.maximum!)} ${t.unit}');
    }
    if (p.trend != null) {
      evidence.add(
          'Recorded trend: ${p.trend!.toStringAsFixed(3)} ${t.unit}/day across dated readings');
    }
    if (p.latestAt != null) {
      evidence.add('Last relevant reading: ${insightDate(p.latestAt!)}');
    }
    evidence.add(t.source == PlanSource.owner
        ? 'Interval source: your own plan'
        : 'Manual reference supplied by you: ${t.reference}');
    final days = p.dueAt?.difference(now).inMilliseconds;
    final dueDays = days == null ? null : (days / 86400000).ceil();
    final usageDate = p.usageDue != null && p.dueAt == p.usageDue && !p.stale;
    String headline, explanation;
    if (condition) {
      headline = p.current == null
          ? 'Add a condition reading'
          : t.metric == ForecastMetric.battery
              ? '${insightNumber(p.current!)}% recorded health'
              : '${insightNumber(p.current!)} ${t.unit} recorded';
      explanation = t.metric == ForecastMetric.battery
          ? 'Battery health and cycle history support a condition review. No battery failure date is predicted.'
          : 'Review measured temperatures and reported conditions against your configured range.';
    } else if (p.state == ForecastState.invalid) {
      headline = 'Correct the recorded data';
      explanation = p.rationale.last;
    } else if (p.stale) {
      headline = p.state == ForecastState.overdue
          ? 'Planning date reached'
          : 'Update your reading';
      explanation =
          'The latest reading is old. Record current usage to refresh the estimate.';
    } else if (dueDays != null) {
      headline = dueDays < 0
          ? '${-dueDays} days past the planning date'
          : dueDays == 0
              ? 'Due today'
              : '${usageDate ? 'About ' : ''}$dueDays days';
      explanation = usageDate
          ? 'Based on recorded ${_measure(t.subtype)} and recent usage.'
          : 'Based on your configured calendar limit.';
    } else if (p.remaining != null) {
      headline =
          '${insightNumber(p.remaining!.abs())} ${t.unit} ${p.remaining! < 0 ? 'past target' : 'left'}';
      explanation =
          'Add dated usage readings to estimate when this threshold may be reached.';
    } else {
      headline = 'More information needed';
      explanation = 'Record the last service baseline and relevant check-ins.';
    }
    final inputCount = p.inputs
        .where((r) =>
            r.values.containsKey('reading') ||
            r.values.containsKey('daily_rate'))
        .length;
    final reliability = t.method == UsageMethod.calendar
        ? 'Based on the configured date and calendar interval. This is a scheduled reminder, not a usage forecast.'
        : t.method == UsageMethod.estimated
            ? 'Based on your reported usage estimate and service date. This is not device-reported usage.'
            : condition
                ? 'Based on $inputCount dated measurement${inputCount == 1 ? '' : 's'}. Trends describe recorded changes, not failure probability.'
                : 'Based on $inputCount relevant dated reading${inputCount == 1 ? '' : 's'}. ${p.reliability == Reliability.moderate ? 'Several consistent readings support this estimate.' : 'Additional readings can improve the usage estimate.'}';
    final tone = p.state == ForecastState.overdue
        ? InsightTone.overdue
        : p.alerts.isNotEmpty || p.state == ForecastState.dueSoon
            ? InsightTone.review
            : p.state == ForecastState.invalid ||
                    p.stale ||
                    p.state == ForecastState.insufficientData
                ? InsightTone.neutral
                : InsightTone.normal;
    final sourceSummary = t.subtype == AssetSubtype.airConditioner &&
            t.method == UsageMethod.estimated &&
            consumed != null
        ? '${insightNumber(consumed)} estimated operating hours and ${now.difference(t.baselineAt).inDays} days since the recorded baseline.'
        : explanation;
    return MaintenanceInsight(
        assetId: item.assetId,
        assetName: item.assetName,
        category: item.category,
        taskId: t.id,
        title: t.name,
        subtitle: condition
            ? t.name
            : actualCounter
                ? 'Estimated ${t.name.toLowerCase()} threshold'
                : t.name,
        headline: headline,
        explanation: sourceSummary,
        evidence: evidence,
        reliability: reliability,
        actionLabel: t.method == UsageMethod.calendar
            ? 'Record completed maintenance'
            : _action(t.subtype),
        status: p.state == ForecastState.dueSoon
            ? 'Soon'
            : p.alerts.isNotEmpty && p.state != ForecastState.overdue
                ? 'Review'
                : p.state.label,
        tone: tone,
        progress: actualCounter ? p.progress : null,
        progressLabel: actualCounter && consumed != null && t.interval != null
            ? '${insightNumber(consumed)} / ${insightNumber(t.interval!)} ${t.unit} since service'
            : null,
        remainingLabel: p.remaining == null
            ? null
            : '${insightNumber(p.remaining!.abs())} ${t.unit} ${p.remaining! < 0 ? 'past target' : 'left'}',
        windowTitle: usageDate
            ? 'Estimated service window'
            : p.calendarDue != null
                ? 'Calendar service limit'
                : null,
        window: usageDate && dueDays != null
            ? _window(dueDays)
            : p.calendarDue != null
                ? '${insightDate(p.calendarDue!)} — the earlier applicable limit wins.'
                : null,
        prediction: p,
        alerts: p.alerts,
        isCondition: condition,
        isScheduled: t.method == UsageMethod.calendar,
        action: t.method == UsageMethod.calendar
            ? InsightAction.service
            : InsightAction.reading);
  }

  MaintenanceInsight legacy(String assetId, String name, String category,
      MaintenanceRecommendation r, DateTime now) {
    final rule = r.rule;
    if (rule == null) return empty(assetId, name, category);
    final unit = rule.metric.unit;
    final overdue = r.remainingValue != null && r.remainingValue! <= 0 ||
        r.estimatedDue != null && !r.estimatedDue!.isAfter(now);
    final soon = !overdue &&
        (r.estimatedDue != null &&
                r.estimatedDue!.difference(now).inDays <= 7 ||
            r.remainingValue != null &&
                r.intervalValue != null &&
                r.remainingValue! <= r.intervalValue! * .1);
    final review = r.condition == ObservedCondition.attention ||
        r.condition == ObservedCondition.watch;
    final days = r.estimatedDue?.difference(now).inMilliseconds;
    final dueDays = days == null ? null : (days / 86400000).ceil();
    final numeric = rule.metric.numeric;
    final evidence = <String>[
      if (r.lastValue != null)
        'Last service reading: ${insightNumber(r.lastValue!)} $unit',
      if (r.currentValue != null)
        'Latest recorded usage: ${insightNumber(r.currentValue!)} $unit',
      if (r.perDay != null)
        'Estimated weekly usage: ${insightNumber(r.perDay! * 7)} $unit',
      if (r.intervalValue != null)
        'Configured / history-derived interval: ${insightNumber(r.intervalValue!)} $unit',
      if (r.currentDate != null) 'Last reading: ${insightDate(r.currentDate!)}',
      r.reason,
    ];
    return MaintenanceInsight(
        assetId: assetId,
        assetName: name,
        category: category,
        taskId: rule.id,
        title: r.task,
        subtitle: r.task,
        origin: InsightOrigin.legacy,
        tone: overdue
            ? InsightTone.overdue
            : soon || review
                ? InsightTone.review
                : InsightTone.normal,
        status: overdue
            ? 'Overdue'
            : review
                ? 'Review'
                : soon
                    ? 'Soon'
                    : r.estimatedDue != null
                        ? 'Estimated'
                        : 'Add data',
        headline: dueDays != null
            ? (dueDays <= 0 ? 'Planning date reached' : 'About $dueDays days')
            : r.remainingValue != null
                ? '${insightNumber(r.remainingValue!.abs())} $unit ${overdue ? 'past target' : 'left'}'
                : review
                    ? 'Review reported condition'
                    : 'More information needed',
        explanation: rule.metric == TrackingMetric.condition
            ? 'Based on your reported condition. This is not an automatic diagnosis.'
            : r.reason,
        evidence: evidence,
        reliability:
            'Based on saved service history and reported usage. This is a rule-based estimate, not a calibrated probability.',
        actionLabel: rule.metric == TrackingMetric.time
            ? 'Record completed maintenance'
            : rule.metric == TrackingMetric.condition
                ? 'Record a condition check'
                : rule.metric == TrackingMetric.kilometres
                    ? 'Record odometer reading'
                    : 'Record usage reading',
        progress: numeric &&
                r.currentValue != null &&
                r.lastValue != null &&
                r.intervalValue != null &&
                r.intervalValue! > 0
            ? ((r.currentValue! - r.lastValue!) / r.intervalValue!)
                .clamp(0.0, 1.0)
            : null,
        progressLabel: numeric &&
                r.currentValue != null &&
                r.lastValue != null &&
                r.intervalValue != null
            ? '${insightNumber(r.currentValue! - r.lastValue!)} / ${insightNumber(r.intervalValue!)} $unit since service'
            : null,
        remainingLabel: r.remainingValue == null
            ? null
            : '${insightNumber(r.remainingValue!.abs())} $unit ${r.remainingValue! < 0 ? 'past target' : 'left'}',
        windowTitle: r.usageDue != null && r.estimatedDue == r.usageDue
            ? 'Estimated service window'
            : r.calendarDue != null
                ? 'Calendar service limit'
                : null,
        window: r.usageDue != null &&
                r.estimatedDue == r.usageDue &&
                dueDays != null
            ? _window(dueDays)
            : r.calendarDue == null
                ? null
                : insightDate(r.calendarDue!),
        isCondition: rule.metric == TrackingMetric.condition,
        isScheduled: rule.metric == TrackingMetric.time &&
            rule.source != RuleSource.history,
        action: rule.metric == TrackingMetric.time
            ? InsightAction.service
            : rule.metric == TrackingMetric.condition
                ? InsightAction.condition
                : InsightAction.reading,
        alerts: [
          if (review)
            r.conditionNotes.isEmpty
                ? 'Review the condition reported for this asset.'
                : r.conditionNotes,
          if (r.highCost)
            'Latest cost is unusually high against this task’s own earlier service costs (${r.costSampleCount} comparable records). Review the receipt; this is not a failure warning.'
        ]);
  }

  String _measure(AssetSubtype s) => switch (s) {
        AssetSubtype.vehicle => 'distance',
        AssetSubtype.airConditioner => 'operating hours',
        AssetSubtype.waterFilter => 'water consumption',
        AssetSubtype.washingMachine => 'wash cycles',
        _ => 'usage'
      };
  String _action(AssetSubtype s) => switch (s) {
        AssetSubtype.vehicle => 'Record odometer reading',
        AssetSubtype.airConditioner => 'Record operating usage',
        AssetSubtype.waterFilter => 'Record water usage',
        AssetSubtype.washingMachine => 'Record wash cycles',
        AssetSubtype.refrigerator => 'Record temperature reading',
        AssetSubtype.laptop => 'Record battery health',
        AssetSubtype.custom => 'Record usage reading'
      };
  String _window(int days) {
    if (days <= 0) {
      return 'The estimated window has been reached. Record current usage or a completed service.';
    }
    if (days < 14) {
      return 'Approximately $days day${days == 1 ? '' : 's'}, if recent usage continues.';
    }
    final low = days ~/ 7, high = (days / 7).ceil();
    return 'Approximately ${low == high ? '$low' : '$low–$high'} weeks, if recent usage continues. Rounded planning window, not a confidence interval.';
  }
}
