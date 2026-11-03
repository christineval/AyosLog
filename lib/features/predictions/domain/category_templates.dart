import 'forecast_engine.dart';
import 'forecast_models.dart';
import '../../assets/domain/entities/asset_category.dart';

enum CategoryFieldType { number, choice, text }

class CategoryField {
  const CategoryField(this.id, this.label, this.type,
      {this.required = false,
      this.minimum,
      this.maximum,
      this.whole = false,
      this.options = const [],
      this.help = ''});
  final String id, label, help;
  final CategoryFieldType type;
  final bool required, whole;
  final double? minimum, maximum;
  final List<String> options;
}

class CategoryTemplate {
  const CategoryTemplate(this.subtype, this.metric, this.tasks, this.setup,
      this.readings, this.conditions,
      {this.estimates = const []});
  final AssetSubtype subtype;
  final ForecastMetric metric;
  final List<String> tasks;
  final List<CategoryField> setup, readings, conditions, estimates;
  bool get supportsEstimate => estimates.isNotEmpty;
  List<CategoryField> fields(UsageMethod method) => [
        if (method == UsageMethod.counter || method == UsageMethod.trend)
          ...readings,
        if (method == UsageMethod.estimated) ...estimates,
        ...conditions,
      ];
}

CategoryField choice(String id, String label, List<String> options,
        {bool required = false}) =>
    CategoryField(id, label, CategoryFieldType.choice,
        options: options, required: required);
CategoryField condition(String id, String label, List<String> options) =>
    choice(id, label, [...options, 'unknown']);
CategoryField number(String id, String label,
        {bool required = false,
        double min = 0,
        double max = 1e12,
        bool whole = false,
        String help = ''}) =>
    CategoryField(id, label, CategoryFieldType.number,
        required: required,
        minimum: min,
        maximum: max,
        whole: whole,
        help: help);

final categoryTemplates = <AssetSubtype, CategoryTemplate>{
  AssetSubtype.vehicle:
      CategoryTemplate(AssetSubtype.vehicle, ForecastMetric.distance, [
    'Oil change',
    'Tires',
    'Brake inspection',
    'Custom'
  ], [
    choice('vehicle_type', 'Vehicle type', ['motorcycle', 'car', 'other']),
    const CategoryField(
        'make_model', 'Make / model (optional)', CategoryFieldType.text)
  ], [
    number('reading', 'Odometer', required: true, max: 99999999),
    choice('unit', 'Distance unit', ['km', 'mi'], required: true),
    number('fuel_efficiency', 'Fuel efficiency (km/L, optional)')
  ], [
    condition('unusual_noise', 'Unusual noise', ['normal', 'unusual']),
    condition('warning_lights', 'Warning lights', ['yes', 'no'])
  ]),
  AssetSubtype.airConditioner:
      CategoryTemplate(AssetSubtype.airConditioner, ForecastMetric.hours, [
    'Filter inspection',
    'Coil inspection',
    'Custom'
  ], [
    choice('ac_type', 'Air conditioner type',
        ['split', 'window', 'central', 'portable'])
  ], [
    number('reading', 'Total operating hours', required: true)
  ], [
    condition('dust_exposure', 'Dust exposure', ['normal', 'high']),
    condition(
        'cooling_performance', 'Cooling performance', ['normal', 'weaker']),
    condition('filter_condition', 'Filter condition', ['clean', 'dirty'])
  ], estimates: [
    number('hours_per_day', 'Hours used per day', required: true, max: 24),
    number('days_per_week', 'Days used per week',
        required: true, max: 7, whole: true)
  ]),
  AssetSubtype.waterFilter:
      CategoryTemplate(AssetSubtype.waterFilter, ForecastMetric.litres, [
    'Cartridge replacement',
    'Custom'
  ], [
    const CategoryField(
        'filter_model', 'Filter model (optional)', CategoryFieldType.text),
    number('household_size', 'Household size (optional)',
        min: 1, max: 100, whole: true)
  ], [
    number('reading', 'Cumulative meter litres', required: true)
  ], [
    condition('flow', 'Water flow', ['normal', 'reduced']),
    condition('taste_or_odor_change', 'Taste or smell changed', ['yes', 'no'])
  ], estimates: [
    number('litres_per_day', 'Estimated litres per day', required: true)
  ]),
  AssetSubtype.washingMachine:
      CategoryTemplate(AssetSubtype.washingMachine, ForecastMetric.cycles, [
    'Drum clean',
    'Filter clean',
    'Inspection',
    'Custom'
  ], [
    choice('washer_type', 'Washing machine type',
        ['front_load', 'top_load', 'other'])
  ], [
    number('reading', 'Lifetime wash counter', required: true, whole: true)
  ], [
    condition('vibration', 'Vibration', ['normal', 'high']),
    condition('leak', 'Leak', ['yes', 'no']),
    condition('noise', 'Noise', ['normal', 'unusual'])
  ], estimates: [
    number('cycles_per_week', 'Estimated washes per week', required: true)
  ]),
  AssetSubtype.refrigerator:
      CategoryTemplate(AssetSubtype.refrigerator, ForecastMetric.temperature, [
    'Temperature check',
    'Seal inspection',
    'Custom'
  ], [
    choice('equipment_type', 'Equipment type', ['fridge', 'freezer'],
        required: true),
    const CategoryField('model', 'Model (optional)', CategoryFieldType.text)
  ], [
    number('reading', 'Internal temperature',
        required: true, min: -148, max: 302),
    choice('unit', 'Temperature unit', ['°C', '°F'], required: true)
  ], [
    condition('door_seal', 'Door seal', ['good', 'worn']),
    condition('noise', 'Noise', ['normal', 'unusual']),
    condition('cooling_issue', 'Cooling issue', ['yes', 'no'])
  ]),
  AssetSubtype.laptop:
      CategoryTemplate(AssetSubtype.laptop, ForecastMetric.battery, [
    'Battery health check',
    'Cleaning',
    'Custom'
  ], [
    choice('device_type', 'Device type', ['laptop', 'tablet', 'other'],
        required: true),
    const CategoryField('manufacturer_model', 'Manufacturer / model (optional)',
        CategoryFieldType.text)
  ], [
    number('reading', 'Battery health (%)', max: 100),
    number('cycle_count', 'Battery charge cycles (optional)', whole: true)
  ], [
    condition('overheating', 'Overheating', ['never', 'sometimes', 'often']),
    condition('fan_noise', 'Fan noise', ['normal', 'unusual']),
    condition('performance_issues', 'Performance issues', ['yes', 'no'])
  ]),
  AssetSubtype.custom:
      CategoryTemplate(AssetSubtype.custom, ForecastMetric.custom, [
    'Custom'
  ], [
    const CategoryField(
        'metric_label', 'What are you measuring?', CategoryFieldType.text,
        required: true)
  ], [
    number('reading', 'Total reading', required: true)
  ], [
    condition('review', 'Anything needs attention?', ['normal', 'yes'])
  ], estimates: [
    number('daily_rate', 'Estimated units per day', required: true)
  ]),
};

List<AssetSubtype> subtypesForCategory(String category) {
  final canonical = AssetCategory.fromKey(category);
  if (canonical != null) {
    return [AssetSubtype.values.byName(canonical.subtypeKey)];
  }
  // Read-only compatibility for fixtures / source data predating migration 6.
  return switch (category.toLowerCase()) {
    'vehicle' || 'car' => [AssetSubtype.vehicle, AssetSubtype.custom],
    'appliance' => [
        AssetSubtype.airConditioner,
        AssetSubtype.refrigerator,
        AssetSubtype.washingMachine,
        AssetSubtype.waterFilter,
        AssetSubtype.custom
      ],
    'electronics' => [AssetSubtype.laptop, AssetSubtype.custom],
    'home' => [
        AssetSubtype.waterFilter,
        AssetSubtype.airConditioner,
        AssetSubtype.custom
      ],
    _ => AssetSubtype.values,
  };
}

Map<String, String> validateCategoryFields(
    List<CategoryField> fields, Map<String, String> values) {
  final errors = <String, String>{};
  for (final f in fields) {
    final text = (values[f.id] ?? '').trim();
    if (text.isEmpty) {
      if (f.required) errors[f.id] = 'Enter ${f.label.toLowerCase()}.';
      continue;
    }
    if (f.type == CategoryFieldType.number) {
      final value = double.tryParse(text);
      if (value == null ||
          !value.isFinite ||
          value < f.minimum! ||
          value > f.maximum! ||
          f.whole && value % 1 != 0) {
        errors[f.id] =
            'Enter ${f.whole ? 'a whole number' : 'a number'} from ${f.minimum} to ${f.maximum}.';
      }
    } else if (f.type == CategoryFieldType.choice &&
        !f.options.contains(text)) {
      errors[f.id] = 'Choose an available option.';
    } else if (text.length > 160) {
      errors[f.id] = 'Keep this within 160 characters.';
    }
  }
  return errors;
}

double estimatedDailyRate(AssetSubtype subtype, Map<String, String> values) =>
    switch (subtype) {
      AssetSubtype.airConditioner => double.parse(values['hours_per_day']!) *
          double.parse(values['days_per_week']!) /
          7,
      AssetSubtype.waterFilter => double.parse(values['litres_per_day']!),
      AssetSubtype.washingMachine =>
        double.parse(values['cycles_per_week']!) / 7,
      AssetSubtype.custom => double.parse(values['daily_rate']!),
      _ => throw const ForecastValidation(
          'This category needs dated measurements.'),
    };

List<UsageMethod> methodsFor(AssetSubtype subtype) {
  final t = categoryTemplates[subtype]!;
  return t.metric.counter
      ? [
          UsageMethod.counter,
          if (t.supportsEstimate) UsageMethod.estimated,
          UsageMethod.calendar
        ]
      : [UsageMethod.trend, UsageMethod.calendar];
}

List<CategoryField> planFieldsFor(AssetSubtype subtype, UsageMethod method) {
  final t = categoryTemplates[subtype]!;
  return [
    ...t.setup,
    if (t.metric.counter && method != UsageMethod.calendar)
      number(
          'interval',
          subtype == AssetSubtype.vehicle
              ? 'Service interval (selected distance unit)'
              : subtype == AssetSubtype.waterFilter
                  ? 'Rated filter capacity (L)'
                  : subtype == AssetSubtype.washingMachine
                      ? 'Washes between maintenance'
                      : 'Service interval (${t.metric.unit})',
          min: .0001,
          required: subtype != AssetSubtype.washingMachine,
          whole: t.metric == ForecastMetric.cycles),
    if (method == UsageMethod.counter)
      number(
          'baseline',
          subtype == AssetSubtype.vehicle
              ? 'Last service odometer'
              : 'Counter at last service',
          required: true),
    if (subtype == AssetSubtype.vehicle)
      choice('unit', 'Distance unit', ['km', 'mi'], required: true),
    if (subtype == AssetSubtype.custom)
      const CategoryField('custom_unit', 'Unit name', CategoryFieldType.text,
          required: true),
    number('interval_days',
        'Maximum days between services${method == UsageMethod.calendar ? '' : ' (optional)'}',
        min: 1,
        max: 36500,
        whole: true,
        required: method == UsageMethod.calendar ||
            subtype == AssetSubtype.refrigerator),
    if (method == UsageMethod.estimated) ...t.estimates,
    if (subtype == AssetSubtype.refrigerator) ...[
      number('minimum', 'Expected minimum temperature (optional)',
          min: -148, max: 302),
      number('maximum', 'Expected maximum temperature (optional)',
          min: -148, max: 302),
      choice('unit', 'Temperature unit', ['°C', '°F'], required: true)
    ],
    number('warning_days', 'Warn this many days before',
        required: true, max: 36500, whole: true),
    number('freshness_days', 'Ask for an update after this many days',
        required: true, min: 1, max: 36500, whole: true),
    number('warning_percent', 'Warn when this percent of usage remains',
        max: 100),
  ];
}

ForecastTask buildForecastTask(
    {required String id,
    required String assetId,
    required String name,
    required AssetSubtype subtype,
    required UsageMethod method,
    required DateTime baselineAt,
    required PlanSource source,
    required String reference,
    required Map<String, String> values,
    required DateTime now,
    int version = 1}) {
  final errors = validateCategoryFields(planFieldsFor(subtype, method), values);
  if (errors.isNotEmpty) throw ForecastValidation(errors.values.first);
  double? n(String key) => double.tryParse(values[key] ?? '');
  double? convert(double? v) =>
      v == null ? null : canonicalValue(v, values['unit'] ?? 'units');
  final t = categoryTemplates[subtype]!;
  final task = ForecastTask(
      id: id,
      assetId: assetId,
      name: name.trim(),
      subtype: subtype,
      metric: t.metric,
      method: method,
      baselineAt: baselineAt.toUtc(),
      baseline: subtype == AssetSubtype.vehicle
          ? convert(n('baseline') ?? 0)!
          : n('baseline') ?? 0,
      interval: method == UsageMethod.calendar
          ? null
          : subtype == AssetSubtype.vehicle
              ? convert(n('interval'))
              : n('interval'),
      intervalDays: n('interval_days')?.toInt(),
      dailyRate: method == UsageMethod.estimated
          ? estimatedDailyRate(subtype, values)
          : null,
      minimum:
          subtype == AssetSubtype.refrigerator ? convert(n('minimum')) : null,
      maximum:
          subtype == AssetSubtype.refrigerator ? convert(n('maximum')) : null,
      source: source,
      reference: reference.trim(),
      warningDays: n('warning_days')!.toInt(),
      warningFraction: (n('warning_percent') ?? 10) / 100,
      freshnessDays: n('freshness_days')!.toInt(),
      customUnit: values['custom_unit'] ?? '',
      version: version,
      setup: {
        for (final f in t.setup) f.id: values[f.id] ?? '',
        if (method == UsageMethod.estimated)
          for (final f in t.estimates) f.id: values[f.id] ?? ''
      });
  validateForecastTask(task, now);
  return task;
}

Observation buildObservation(
    {required ForecastTask task,
    required String id,
    required Map<String, String> values,
    required DateTime at,
    required DateTime now,
    EvidenceSource source = EvidenceSource.manual,
    String notes = '',
    bool reset = false,
    bool confirmed = false,
    int version = 1,
    bool conditionsOnly = false}) {
  final template = categoryTemplates[task.subtype]!;
  final fields =
      conditionsOnly ? template.conditions : template.fields(task.method);
  final errors = validateCategoryFields(fields, values);
  if (errors.isNotEmpty) throw ForecastValidation(errors.values.first);
  if (at.isAfter(now.add(const Duration(minutes: 5))) ||
      at.year < 1900 ||
      at.isBefore(task.baselineAt)) {
    throw const ForecastValidation(
        'Choose a check-in date after the service baseline and no later than now.');
  }
  if (notes.length > 1000 || reset && notes.trim().isEmpty) {
    throw const ForecastValidation(
        'Keep notes within 1,000 characters; explain a meter reset.');
  }
  final numbers = <String, double>{};
  final conditions = <String, String>{};
  for (final f in fields) {
    final input = values[f.id] ?? '';
    if (f.type == CategoryFieldType.number && input.isNotEmpty) {
      numbers[f.id] = double.parse(input);
    }
    if (template.conditions.any((c) => c.id == f.id)) {
      conditions[f.id] = input.isEmpty ? 'unknown' : input;
    }
  }
  if (numbers['reading'] != null) {
    final unit = values['unit'] ?? task.unit;
    if (task.metric == ForecastMetric.distance &&
            !['km', 'mi'].contains(unit) ||
        task.metric == ForecastMetric.temperature &&
            !['°C', '°F'].contains(unit)) {
      throw const ForecastValidation(
          'The reading unit does not match this plan.');
    }
    if (task.metric == ForecastMetric.distance ||
        task.metric == ForecastMetric.temperature) {
      numbers['reading'] = canonicalValue(numbers['reading']!, unit);
    }
    if (task.metric == ForecastMetric.temperature) {
      final n = numbers['reading']!;
      if (n < -100 || n > 150) {
        throw const ForecastValidation(
            'Temperature is outside the supported measurement range.');
      }
      if ((n < -50 || n > 80) && !confirmed) {
        throw const ForecastValidation(
            'Confirm this unusual temperature before saving.');
      }
    }
  }
  if (task.method == UsageMethod.estimated && !conditionsOnly) {
    numbers['daily_rate'] = estimatedDailyRate(task.subtype, values);
  }
  if (task.subtype == AssetSubtype.laptop &&
      !conditionsOnly &&
      numbers.isEmpty) {
    throw const ForecastValidation(
        'Enter battery health or a charge cycle count.');
  }
  if (conditionsOnly && !conditions.values.any((v) => v != 'unknown')) {
    throw const ForecastValidation('Record at least one checked condition.');
  }
  return Observation(
      id: id,
      assetId: task.assetId,
      taskId: task.id,
      at: at.toUtc(),
      values: numbers,
      conditions: conditions,
      source: source,
      notes: notes.trim(),
      reset: reset,
      confirmed: confirmed,
      version: version);
}
