import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../domain/maintenance_schedule.dart';

class SetupScheduleViewModel extends StateNotifier<AsyncValue<void>> {
  SetupScheduleViewModel(this.save) : super(const AsyncData(null));
  final SaveMaintenanceSchedule save;
  Future<bool> submit(MaintenanceScheduleDraft draft) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await save(draft);
      if (mounted) state = const AsyncData(null);
      return true;
    } catch (e, s) {
      if (mounted) state = AsyncError(e, s);
      return false;
    }
  }
}

final setupScheduleProvider = StateNotifierProvider.autoDispose
    .family<SetupScheduleViewModel, AsyncValue<void>, String>((ref, id) =>
        SetupScheduleViewModel(
            SaveMaintenanceSchedule(ref.watch(maintenanceRepositoryProvider))));
