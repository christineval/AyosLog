import '../entities/asset.dart';

abstract interface class AssetRepository {
  Stream<List<Asset>> watchAssets();
  Future<Asset?> findById(String id);
  Future<String> add(
      {required String name,
      required String category,
      String brand = '',
      String model = '',
      Map<String, String> setup = const {}});
  Future<void> archive(String id);
  Future<void> changeCategory(String id, String category,
      {Map<String, String> setup = const {}});
}
