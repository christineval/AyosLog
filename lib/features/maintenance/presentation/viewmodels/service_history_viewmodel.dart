import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/service_history.dart';

class ServiceHistoryViewModel
    extends StateNotifier<AsyncValue<List<ServiceRecord>>> {
  ServiceHistoryViewModel(WatchServiceHistory watch, String assetId)
      : super(const AsyncLoading()) {
    _subscription = watch(assetId).listen(
        (records) => state = AsyncData(records),
        onError: (Object error, StackTrace stack) =>
            state = AsyncError(error, stack));
  }
  late final StreamSubscription<List<ServiceRecord>> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class ServiceRecordViewModel extends StateNotifier<AsyncValue<ServiceRecord?>> {
  ServiceRecordViewModel(
      WatchServiceRecord watch, String assetId, String recordId)
      : super(const AsyncLoading()) {
    _subscription = watch(assetId, recordId).listen(
        (record) => state = AsyncData(record),
        onError: (Object error, StackTrace stack) =>
            state = AsyncError(error, stack));
  }
  late final StreamSubscription<ServiceRecord?> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
