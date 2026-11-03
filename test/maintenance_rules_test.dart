import 'package:flutter_test/flutter_test.dart';
import 'package:ayoslog/features/maintenance/domain/maintenance_rules.dart';

void main() {
  test('monthly recurrence clamps Jan 31 to Feb end', () {
    expect(nextDueDate(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
  });
  test('zero interval is rejected', () {
    expect(() => nextDueDate(DateTime(2026, 1, 1), 0), throwsArgumentError);
  });
}
