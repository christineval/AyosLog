import '../entities/asset_category.dart';
import '../repositories/asset_repository.dart';
import 'create_asset.dart';

class ChangeAssetCategory {
  const ChangeAssetCategory(this.repository);
  final AssetRepository repository;
  Future<void> call(String id, String category,
      {Map<String, String> setup = const {}}) {
    if (AssetCategory.fromKey(category) == null) {
      throw ArgumentError('Choose a valid asset category.');
    }
    return repository.changeCategory(id, category,
        setup: validateAssetSetup(category, setup));
  }
}
