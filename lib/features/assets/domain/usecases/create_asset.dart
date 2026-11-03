import '../repositories/asset_repository.dart';
import '../entities/asset_category.dart';
import '../../../predictions/domain/category_templates.dart';
import '../../../predictions/domain/forecast_models.dart';

List<CategoryField> assetSetupFields(String category) {
  final selected = AssetCategory.fromKey(category);
  if (selected == AssetCategory.custom) return const [];
  return selected == null
      ? const []
      : categoryTemplates[AssetSubtype.values.byName(selected.subtypeKey)]!
          .setup;
}

Map<String, String> validateAssetSetup(
    String category, Map<String, String> values) {
  final fields = assetSetupFields(category);
  final errors = validateCategoryFields(fields, values);
  if (errors.isNotEmpty) throw ArgumentError(errors.values.first);
  return {
    for (final f in fields)
      if ((values[f.id] ?? '').trim().isNotEmpty) f.id: values[f.id]!.trim()
  };
}

class CreateAsset {
  const CreateAsset(this.repository);
  final AssetRepository repository;
  Future<String> call(
      {required String name,
      required String category,
      String brand = '',
      String model = '',
      Map<String, String> setup = const {}}) {
    if (name.trim().isEmpty) throw ArgumentError('Asset name cannot be blank');
    category = category.trim().toLowerCase();
    if (AssetCategory.fromKey(category) == null) {
      throw ArgumentError('Choose a valid asset category.');
    }
    return repository.add(
        name: name.trim(),
        category: category,
        setup: validateAssetSetup(category, setup),
        brand: brand.trim(),
        model: model.trim());
  }
}
