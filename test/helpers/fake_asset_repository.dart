import 'package:ayoslog/features/assets/domain/entities/asset.dart';
import 'package:ayoslog/features/assets/domain/repositories/asset_repository.dart';

class FakeAssetRepository implements AssetRepository {
  const FakeAssetRepository(this.assets);
  final List<Asset> assets;
  @override
  Stream<List<Asset>> watchAssets() => Stream.value(assets);
  @override
  Future<Asset?> findById(String id) async {
    for (final a in assets) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Future<String> add(
          {required String name,
          required String category,
          String brand = '',
          String model = '',
          Map<String, String> setup = const {}}) async =>
      'a';
  @override
  Future<void> archive(String id) async {}
  @override
  Future<void> changeCategory(String id, String category,
      {Map<String, String> setup = const {}}) async {}
}
