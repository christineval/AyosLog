import 'dart:convert';

enum AssetSubtype {
  vehicle('Vehicle / motorcycle'),
  airConditioner('Air conditioner'),
  waterFilter('Water filter'),
  washingMachine('Washing machine'),
  refrigerator('Refrigerator / freezer'),
  laptop('Laptop / electronics'),
  custom('Other / custom');

  const AssetSubtype(this.label);
  final String label;
}

enum ForecastMetric {
  distance('km', true),
  hours('hours', true),
  litres('L', true),
  cycles('cycles', true),
  temperature('°C', false),
  battery('percent', false),
  custom('units', true),
  calendar('days', false);

  const ForecastMetric(this.unit, this.counter);
  final String unit;
  final bool counter;
}

enum UsageMethod { counter, estimated, trend, calendar }

enum EvidenceSource { manual, imported }

enum PlanSource { owner, manufacturer }

enum ForecastState {
  notConfigured('Set up a plan'),
  insufficientData('Not enough data'),
  scheduled('Scheduled'),
  estimated('Estimated'),
  dueSoon('Due soon'),
  overdue('Overdue'),
  conditionAlert('Review needed'),
  stale('Update reading'),
  invalid('Correct readings');

  const ForecastState(this.label);
  final String label;
}

enum Reliability { insufficient, limited, moderate }

class ForecastValidation implements Exception {
  const ForecastValidation(this.message);
  final String message;
  @override
  String toString() => message;
}

class ForecastTask {
  const ForecastTask(
      {required this.id,
      required this.assetId,
      required this.name,
      required this.subtype,
      required this.metric,
      required this.method,
      required this.baselineAt,
      this.baseline = 0,
      this.baselineKnown = true,
      this.interval,
      this.intervalDays,
      this.dailyRate,
      this.minimum,
      this.maximum,
      this.source = PlanSource.owner,
      this.reference = '',
      this.warningDays = 7,
      this.warningFraction = .1,
      this.freshnessDays = 30,
      this.customUnit = '',
      this.version = 1,
      this.setup = const {},
      this.trendSince});
  final String id, assetId, name, reference, customUnit;
  final AssetSubtype subtype;
  final ForecastMetric metric;
  final UsageMethod method;
  final DateTime baselineAt;
  final DateTime? trendSince;
  final double baseline;
  final bool baselineKnown;
  final double? interval, dailyRate, minimum, maximum;
  final int? intervalDays;
  final PlanSource source;
  final int warningDays, freshnessDays, version;
  final double warningFraction;
  final Map<String, String> setup;
  String get unit => metric == ForecastMetric.custom ? customUnit : metric.unit;
  Map<String, dynamic> toJson() => {
        'id': id,
        'assetId': assetId,
        'name': name,
        'subtype': subtype.name,
        'metric': metric.name,
        'method': method.name,
        'baselineAt': baselineAt.toUtc().toIso8601String(),
        'trendSince': trendSince?.toUtc().toIso8601String(),
        'baseline': baseline,
        'baselineKnown': baselineKnown,
        'interval': interval,
        'intervalDays': intervalDays,
        'dailyRate': dailyRate,
        'minimum': minimum,
        'maximum': maximum,
        'source': source.name,
        'reference': reference,
        'warningDays': warningDays,
        'warningFraction': warningFraction,
        'freshnessDays': freshnessDays,
        'customUnit': customUnit,
        'version': version,
        'setup': setup,
      };
  factory ForecastTask.fromJson(Map<String, dynamic> j) => ForecastTask(
      id: j['id'] as String,
      assetId: j['assetId'] as String,
      name: j['name'] as String,
      subtype: AssetSubtype.values.byName(j['subtype']),
      metric: ForecastMetric.values.byName(j['metric']),
      method: UsageMethod.values.byName(j['method']),
      baselineAt: DateTime.parse(j['baselineAt']).toUtc(),
      trendSince: j['trendSince'] == null
          ? null
          : DateTime.parse(j['trendSince']).toUtc(),
      baseline: (j['baseline'] as num).toDouble(),
      baselineKnown: j['baselineKnown'] as bool? ?? true,
      interval: (j['interval'] as num?)?.toDouble(),
      intervalDays: j['intervalDays'],
      dailyRate: (j['dailyRate'] as num?)?.toDouble(),
      minimum: (j['minimum'] as num?)?.toDouble(),
      maximum: (j['maximum'] as num?)?.toDouble(),
      source: PlanSource.values.byName(j['source']),
      reference: j['reference'],
      warningDays: j['warningDays'],
      warningFraction: (j['warningFraction'] as num).toDouble(),
      freshnessDays: j['freshnessDays'],
      customUnit: j['customUnit'],
      version: j['version'],
      setup: Map<String, String>.from(j['setup'] as Map? ?? {}));
  ForecastTask withBaseline(DateTime at, double value) =>
      ForecastTask.fromJson({
        ...toJson(),
        'baselineAt': at.toUtc().toIso8601String(),
        'baseline': value
      });
}

class Observation {
  const Observation(
      {required this.id,
      required this.assetId,
      required this.taskId,
      required this.at,
      this.values = const {},
      this.conditions = const {},
      this.source = EvidenceSource.manual,
      this.notes = '',
      this.reset = false,
      this.confirmed = false,
      this.version = 1,
      this.deleted = false});
  final String id, assetId, taskId, notes;
  final DateTime at;

  /// Keys and canonical units are defined by CategoryTemplates.
  final Map<String, double> values;
  final Map<String, String> conditions;
  final EvidenceSource source;
  final bool reset, confirmed, deleted;
  final int version;
  Map<String, dynamic> toJson() => {
        'id': id,
        'assetId': assetId,
        'taskId': taskId,
        'at': at.toUtc().toIso8601String(),
        'values': values,
        'conditions': conditions,
        'source': source.name,
        'notes': notes,
        'reset': reset,
        'confirmed': confirmed,
        'version': version,
        'deleted': deleted
      };
}

class ForecastPrediction {
  const ForecastPrediction(
      {required this.task,
      required this.state,
      required this.reliability,
      required this.calculatedAt,
      required this.inputs,
      required this.rationale,
      this.dueAt,
      this.usageDue,
      this.calendarDue,
      this.target,
      this.remaining,
      this.current,
      this.progress,
      this.rate,
      this.latestAt,
      this.stale = false,
      this.alerts = const [],
      this.trend,
      this.ratePairs = 0,
      this.trendWindows = const {}});
  static const algorithm = 'rules_v1';
  final ForecastTask task;
  final ForecastState state;
  final Reliability reliability;
  final DateTime calculatedAt;
  final DateTime? dueAt, usageDue, calendarDue, latestAt;
  final double? target, remaining, current, progress, rate, trend;
  final bool stale;
  final int ratePairs;
  final Map<int, double> trendWindows;
  final List<Observation> inputs;
  final List<String> rationale, alerts;
  Map<String, dynamic> toJson() => {
        'algorithm': algorithm,
        'task': task.toJson(),
        'state': state.name,
        'reliability': reliability.name,
        'calculatedAt': calculatedAt.toUtc().toIso8601String(),
        'dueAt': dueAt?.toUtc().toIso8601String(),
        'usageDue': usageDue?.toUtc().toIso8601String(),
        'calendarDue': calendarDue?.toUtc().toIso8601String(),
        'target': target,
        'remaining': remaining,
        'current': current,
        'rate': rate,
        'progress': progress,
        'trend': trend,
        'trendWindows': {
          for (final e in trendWindows.entries) '${e.key}': e.value
        },
        'stale': stale,
        'ratePairs': ratePairs,
        'latestAt': latestAt?.toUtc().toIso8601String(),
        'alerts': alerts,
        'rationale': rationale,
        'inputs': inputs.map((e) => e.toJson()).toList(),
      };

  /// Stable content fingerprint, for reproducibility, not cryptographic security.
  String get inputHash {
    final bytes = utf8.encode(jsonEncode({
      'task': task.toJson(),
      'inputs': inputs.map((e) => e.toJson()).toList(),
      'algorithm': algorithm
    }));
    var hash = 0x811c9dc5;
    for (final b in bytes) {
      hash = ((hash ^ b) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class AssetInsight {
  const AssetInsight(
      this.assetId, this.assetName, this.category, this.prediction);
  final String assetId, assetName, category;
  final ForecastPrediction? prediction;
  ForecastState get state => prediction?.state ?? ForecastState.notConfigured;
}
