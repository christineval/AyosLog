import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../domain/usecases/change_asset_category.dart';

class AssetFormViewModel extends StateNotifier<AsyncValue<void>> {
  AssetFormViewModel(this.ref) : super(const AsyncData(null));
  final Ref ref;
  Future<bool> changeCategory(String id, String category,
      {Map<String, String> setup = const {}}) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await ChangeAssetCategory(ref.read(assetRepositoryProvider))(id, category,
          setup: setup);
      if (mounted) state = const AsyncData(null);
      return true;
    } catch (e, s) {
      if (mounted) state = AsyncError(e, s);
      return false;
    }
  }

  Future<String?> submit(
      {required String name,
      required String category,
      String brand = '',
      String model = '',
      Map<String, String> setup = const {}}) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      final id = await ref.read(createAssetProvider)(
          name: name,
          category: category,
          brand: brand,
          model: model,
          setup: setup);
      if (mounted) state = const AsyncData(null);
      return id;
    } catch (e, st) {
      if (mounted) state = AsyncError(e, st);
      return null;
    }
  }
}

final assetFormViewModelProvider =
    StateNotifierProvider.autoDispose<AssetFormViewModel, AsyncValue<void>>(
        (ref) => AssetFormViewModel(ref));
