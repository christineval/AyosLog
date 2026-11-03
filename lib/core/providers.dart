import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'database/app_database.dart';
import '../features/assets/domain/entities/asset.dart' as domain;
import '../features/assets/domain/repositories/asset_repository.dart';
import '../features/assets/domain/usecases/create_asset.dart';
import '../features/assets/data/repositories/drift_asset_repository.dart';
import '../features/maintenance/data/maintenance_repository.dart';
import '../features/maintenance/domain/service_history.dart';
import '../features/maintenance/data/drift_service_history_repository.dart';
import '../features/maintenance/presentation/viewmodels/service_history_viewmodel.dart';
import '../features/predictions/data/drift_prediction_repository.dart';
import '../features/predictions/domain/prediction_models.dart';
import '../features/predictions/domain/prediction_repository.dart';
import '../features/predictions/domain/prediction_usecases.dart';
import '../features/predictions/presentation/viewmodels/prediction_viewmodels.dart';

final predictionRepositoryProvider = Provider<PredictionRepository>(
    (ref) => DriftPredictionRepository(ref.watch(databaseProvider)));
final serviceHistoryRepositoryProvider = Provider<ServiceHistoryRepository>(
    (ref) => DriftServiceHistoryRepository(ref.watch(databaseProvider)));
final serviceHistoryProvider = StateNotifierProvider.autoDispose
    .family<ServiceHistoryViewModel, AsyncValue<List<ServiceRecord>>, String>(
        (ref, id) => ServiceHistoryViewModel(
            WatchServiceHistory(ref.watch(serviceHistoryRepositoryProvider)),
            id));
final serviceRecordProvider = StateNotifierProvider.autoDispose.family<
        ServiceRecordViewModel, AsyncValue<ServiceRecord?>, (String, String)>(
    (ref, ids) => ServiceRecordViewModel(
        WatchServiceRecord(
            WatchServiceHistory(ref.watch(serviceHistoryRepositoryProvider))),
        ids.$1,
        ids.$2));
final predictionProvider = StateNotifierProvider.autoDispose
    .family<PredictionViewModel, AsyncValue<PredictionReport>, String>(
        (ref, id) =>
            PredictionViewModel(ref.watch(predictionRepositoryProvider), id));
final mileageFormProvider = StateNotifierProvider.autoDispose
    .family<PredictionFormViewModel, AsyncValue<void>, String>((ref, id) =>
        PredictionFormViewModel(
            AddMileageReading(ref.watch(predictionRepositoryProvider)),
            RecordPredictiveService(ref.watch(predictionRepositoryProvider))));
final predictiveServiceFormProvider = StateNotifierProvider.autoDispose
    .family<PredictionFormViewModel, AsyncValue<void>, String>((ref, id) =>
        PredictionFormViewModel(
            AddMileageReading(ref.watch(predictionRepositoryProvider)),
            RecordPredictiveService(ref.watch(predictionRepositoryProvider))));
final taskRuleFormProvider = StateNotifierProvider.autoDispose
    .family<PredictionFormViewModel, AsyncValue<void>, String>((ref, id) =>
        PredictionFormViewModel(
            AddMileageReading(ref.watch(predictionRepositoryProvider)),
            RecordPredictiveService(ref.watch(predictionRepositoryProvider))));

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
final assetRepositoryProvider = Provider<AssetRepository>(
    (ref) => DriftAssetRepository(ref.watch(databaseProvider)));
final createAssetProvider = Provider<CreateAsset>(
    (ref) => CreateAsset(ref.watch(assetRepositoryProvider)));
final assetsProvider = StreamProvider<List<domain.Asset>>(
    (ref) => ref.watch(assetRepositoryProvider).watchAssets());
final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
    (ref) => MaintenanceRepository(ref.watch(databaseProvider)));
final plansProvider = StreamProvider(
    (ref) => ref.watch(maintenanceRepositoryProvider).watchPlans());
final themeProvider = StateNotifierProvider<ThemeController, ThemeMode>(
    (ref) => ThemeController());

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system) {
    _load();
  }
  Future<void> _load() async {
    final pref = await SharedPreferences.getInstance();
    final v = pref.getString('theme');
    state = switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final p = await SharedPreferences.getInstance();
    await p.setString('theme', mode.name);
  }
}
