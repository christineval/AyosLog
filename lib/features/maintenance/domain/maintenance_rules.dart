/// Calendar-month cadence avoids treating every month as 30 days.
DateTime nextDueDate(DateTime completedAt, int intervalMonths) {
  if (intervalMonths <= 0) {
    throw ArgumentError('intervalMonths must be positive');
  }
  final year =
      completedAt.year + (completedAt.month - 1 + intervalMonths) ~/ 12;
  final month = (completedAt.month - 1 + intervalMonths) % 12 + 1;
  final maxDay = DateTime(year, month + 1, 0).day;
  final day = completedAt.day > maxDay ? maxDay : completedAt.day;
  return DateTime(year, month, day);
}
