import 'forecast_models.dart';

class ForecastAsset {
  const ForecastAsset(
      this.id, this.name, this.category, this.archived, this.subtype,
      [this.setup = const {}]);
  final String id, name, category;
  final bool archived;
  final AssetSubtype? subtype;
  final Map<String, String> setup;
}

class ForecastCompletion {
  const ForecastCompletion(
      {required this.id,
      required this.assetId,
      required this.taskId,
      required this.at,
      required this.description,
      required this.cost,
      this.value,
      this.receiptPath,
      this.kind = 'routine',
      this.performedBy = '',
      this.voided = false,
      this.batteryReplaced = false,
      this.version = 1});
  final String id, assetId, taskId, description;
  final DateTime at;
  final double cost;
  final double? value;
  final String? receiptPath;
  final String kind;
  final String performedBy;
  ForecastCompletion withValue(double? value) => ForecastCompletion(
      id: id,
      assetId: assetId,
      taskId: taskId,
      at: at,
      description: description,
      cost: cost,
      value: value,
      voided: voided,
      version: version,
      batteryReplaced: batteryReplaced,
      receiptPath: receiptPath,
      kind: kind,
      performedBy: performedBy);
  final bool voided;
  final bool batteryReplaced;
  final int version;
}

class ForecastAudit {
  const ForecastAudit(this.recordId, this.taskId, this.action, this.at,
      this.before, this.after);
  final String recordId, taskId, action;
  final DateTime at;
  final String? before, after;
}

class ForecastData {
  const ForecastData(
      {this.assets = const [],
      this.tasks = const [],
      this.observations = const [],
      this.completions = const [],
      this.audit = const []});
  final List<ForecastAsset> assets;
  final List<ForecastTask> tasks;
  final List<Observation> observations;
  final List<ForecastCompletion> completions;
  final List<ForecastAudit> audit;
}

abstract interface class ForecastRepository {
  Stream<ForecastData> watch();
  Future<void> saveTask(ForecastTask task);
  Future<void> saveObservation(Observation observation);
  Future<void> deleteObservation(
      String assetId, String taskId, String id, int version);
  Future<void> complete(ForecastCompletion completion);
}
