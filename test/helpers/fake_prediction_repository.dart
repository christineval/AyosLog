import 'package:ayoslog/features/predictions/domain/prediction_models.dart';
import 'package:ayoslog/features/predictions/domain/prediction_repository.dart';

class FakePredictionRepository implements PredictionRepository {
  FakePredictionRepository(
      {this.history = const PredictionHistory(services: [], readings: []),
      this.onWatch,
      this.onSaveReading,
      this.onSaveTaskReading,
      this.onSaveRule,
      this.onSaveService});
  final PredictionHistory history;
  final Stream<PredictionHistory> Function()? onWatch;
  final Future<void> Function(String, MileageReading)? onSaveReading;
  final Future<void> Function(String, TaskUsageReading)? onSaveTaskReading;
  final Future<void> Function(String, TaskRule, bool)? onSaveRule;
  final Future<void> Function(ServiceDraft)? onSaveService;
  @override
  Stream<PredictionHistory> watchHistory(String assetId) =>
      onWatch?.call() ?? Stream.value(history);
  @override
  Future<void> addReading(String assetId, MileageReading reading) async {
    await onSaveReading?.call(assetId, reading);
  }

  @override
  Future<void> recordService(ServiceDraft draft) async {
    await onSaveService?.call(draft);
  }

  @override
  Future<void> saveRule(String assetId, TaskRule rule,
      {bool markAsCar = false}) async {
    await onSaveRule?.call(assetId, rule, markAsCar);
  }

  @override
  Future<void> addTaskReading(String assetId, TaskUsageReading reading) async {
    await onSaveTaskReading?.call(assetId, reading);
  }
}
