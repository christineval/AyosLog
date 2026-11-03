import 'prediction_models.dart';

abstract interface class PredictionRepository {
  Stream<PredictionHistory> watchHistory(String assetId);
  Future<void> addReading(String assetId, MileageReading reading);
  Future<void> recordService(ServiceDraft draft);
  Future<void> saveRule(String assetId, TaskRule rule,
      {bool markAsCar = false});
  Future<void> addTaskReading(String assetId, TaskUsageReading reading);
}
