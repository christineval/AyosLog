import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/prediction_models.dart';
import '../../domain/prediction_repository.dart';
import '../../domain/prediction_usecases.dart';

class PredictionViewModel extends StateNotifier<AsyncValue<PredictionReport>> {
  PredictionViewModel(PredictionRepository repository, String assetId)
      : super(const AsyncLoading()) {
    _subscription = repository.watchHistory(assetId).listen((history) {
      try {
        state = AsyncData(
            const BuildMaintenanceRecommendations()(history, DateTime.now()));
      } catch (error, stack) {
        state = AsyncError(error, stack);
      }
    },
        onError: (Object error, StackTrace stack) =>
            state = AsyncError(error, stack));
  }
  late final StreamSubscription<PredictionHistory> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class PredictionFormViewModel extends StateNotifier<AsyncValue<void>> {
  PredictionFormViewModel(this.addReading, this.recordService)
      : super(const AsyncData(null));
  final AddMileageReading addReading;
  final RecordPredictiveService recordService;
  Future<bool> _submit(Future<void> Function() action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await action();
      if (mounted) state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      if (mounted) {
        state = AsyncError(
            error is PredictionValidationException
                ? error
                : const PredictionValidationException(
                    'Could not save. Please try again.'),
            stack);
      }
      return false;
    }
  }

  Future<bool> saveReading(String assetId, MileageReading reading) =>
      _submit(() => addReading(assetId, reading));
  Future<bool> saveService(ServiceDraft draft) =>
      _submit(() => recordService(draft));
  Future<bool> saveRule(String assetId, TaskRule rule,
          {bool markAsCar = false}) =>
      _submit(() => SaveTaskRule(recordService.repository)(assetId, rule,
          markAsCar: markAsCar));
  Future<bool> saveTaskReading(String assetId, TaskUsageReading reading) =>
      _submit(() => AddTaskUsage(recordService.repository)(assetId, reading));
}
