import '../../predictions/domain/category_templates.dart';
import '../../predictions/domain/forecast_engine.dart';
import '../../predictions/domain/forecast_models.dart';
import '../../assets/domain/entities/asset_category.dart';

List<CategoryField> categoryServiceFields(String category,
        {String? customUnit}) =>
    switch (category) {
      'vehicle' => [
          number('service_value', 'Odometer at service',
              required: true, max: 99999999),
          choice('distance_unit', 'Distance unit', ['km', 'mi'], required: true)
        ],
      'air_conditioner' => [
          number('service_value', 'Meter hours at service (optional)')
        ],
      'water_filter' => [
          number('service_value', 'Meter litres at replacement (optional)')
        ],
      'washing_machine' => [
          number('service_value', 'Wash counter at service (optional)',
              whole: true)
        ],
      'custom' when customUnit != null && customUnit.isNotEmpty => [
          number('service_value', 'Reading at service ($customUnit, optional)')
        ],
      _ => [],
    };
List<String> serviceTasks(String category) {
  final c = AssetCategory.fromKey(category);
  return c == null
      ? const ['Custom']
      : categoryTemplates[AssetSubtype.values.byName(c.subtypeKey)]!.tasks;
}

class CategoryServiceReading {
  const CategoryServiceReading(this.value, this.unit);
  final double? value;
  final String unit;
}

CategoryServiceReading parseCategoryServiceReading(
    String category, Map<String, String> values,
    {String? customUnit}) {
  final errors = validateCategoryFields(
      categoryServiceFields(category, customUnit: customUnit), values);
  if (errors.isNotEmpty) throw ForecastValidation(errors.values.first);
  final value = double.tryParse(values['service_value'] ?? '');
  final unit = switch (category) {
    'vehicle' => 'km',
    'air_conditioner' => 'hours',
    'water_filter' => 'L',
    'washing_machine' => 'cycles',
    'custom' => customUnit ?? '',
    _ => ''
  };
  return CategoryServiceReading(
      value == null
          ? null
          : category == 'vehicle'
              ? canonicalValue(value, values['distance_unit'] ?? 'km')
              : value,
      unit);
}
