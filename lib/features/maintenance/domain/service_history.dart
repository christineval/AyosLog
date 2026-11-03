class ServiceRecord {
  const ServiceRecord(
      {required this.id,
      required this.assetId,
      required this.assetName,
      required this.description,
      required this.kind,
      required this.cost,
      required this.performedAt,
      this.task = '',
      this.component = '',
      this.performedBy = '',
      this.receiptPath,
      this.usageValue,
      this.usageUnit = ''});
  final String id,
      assetId,
      assetName,
      description,
      kind,
      task,
      component,
      performedBy,
      usageUnit;
  final double cost;
  final DateTime performedAt;
  final String? receiptPath;
  final double? usageValue;
  String get title => task.isEmpty ? 'Maintenance service' : task;
}

abstract interface class ServiceHistoryRepository {
  Stream<List<ServiceRecord>> watchRecords(String assetId);
}

class WatchServiceHistory {
  const WatchServiceHistory(this.repository);
  final ServiceHistoryRepository repository;
  Stream<List<ServiceRecord>> call(String assetId) {
    if (assetId.trim().isEmpty) throw ArgumentError('Asset is required.');
    return repository.watchRecords(assetId);
  }
}

class WatchServiceRecord {
  const WatchServiceRecord(this.history);
  final WatchServiceHistory history;
  Stream<ServiceRecord?> call(String assetId, String recordId) =>
      history(assetId).map((records) {
        for (final record in records) {
          if (record.id == recordId) return record;
        }
        return null;
      });
}
