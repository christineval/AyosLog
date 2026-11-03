import 'package:ayoslog/features/maintenance/domain/service_history.dart';

class FakeServiceHistoryRepository implements ServiceHistoryRepository {
  FakeServiceHistoryRepository(this.records, {this.onWatch});
  final List<ServiceRecord> records;
  final Stream<List<ServiceRecord>> Function()? onWatch;
  @override
  Stream<List<ServiceRecord>> watchRecords(String assetId) =>
      onWatch?.call() ??
      Stream.value(records.where((r) => r.assetId == assetId).toList());
}
