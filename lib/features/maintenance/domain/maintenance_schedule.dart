class MaintenanceScheduleDraft {
  const MaintenanceScheduleDraft(
      {required this.id,
      required this.assetId,
      required this.title,
      required this.intervalMonths,
      required this.firstDue,
      this.reminderDays = 7});
  final String id, assetId, title;
  final int intervalMonths, reminderDays;
  final DateTime firstDue;
}

abstract interface class MaintenanceScheduleRepository {
  Future<void> saveSchedule(MaintenanceScheduleDraft draft);
}

class SaveMaintenanceSchedule {
  const SaveMaintenanceSchedule(this.repository);
  final MaintenanceScheduleRepository repository;
  Future<void> call(MaintenanceScheduleDraft d) {
    if (d.id.isEmpty ||
        d.assetId.isEmpty ||
        d.title.trim().isEmpty ||
        d.title.trim().length > 80 ||
        d.intervalMonths < 1 ||
        d.intervalMonths > 1200 ||
        d.reminderDays < 0 ||
        d.reminderDays > 365 ||
        d.firstDue.year < 2000 ||
        d.firstDue.year > 2100) {
      throw ArgumentError(
          'Enter a task title, a valid repeat schedule, first due date and reminder.');
    }
    return repository.saveSchedule(d);
  }
}
