import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../data/drift_forecast_repository.dart';
import '../domain/forecast_repository.dart';
import 'viewmodels/forecast_viewmodels.dart';

final forecastRepositoryProvider = Provider<ForecastRepository>(
    (ref) => DriftForecastRepository(ref.watch(databaseProvider)));
final insightsProvider = StateNotifierProvider.autoDispose<InsightsViewModel,
        AsyncValue<ForecastScreenData>>(
    (ref) => InsightsViewModel(ref.watch(forecastRepositoryProvider)));
final forecastFormProvider = StateNotifierProvider.autoDispose
    .family<ForecastFormViewModel, AsyncValue<void>, String>((ref, key) =>
        ForecastFormViewModel(ref.watch(forecastRepositoryProvider)));
