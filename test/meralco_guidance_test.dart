import 'package:flutter_test/flutter_test.dart';
import 'package:wattwise/features/mira/services/meralco_guidance.dart';
import 'package:wattwise/shared/models/bill.dart';

void main() {
  final now = DateTime(2026, 11, 12);
  Bill b(double kwh, {bool reviewed = true, DateTime? date}) => Bill(
      id: 'test',
      periodEnd: date ?? DateTime(2026, 11, 1),
      dueDate: now,
      consumptionKwh: kwh,
      totalAmount: 1000,
      charges: [],
      reviewed: reviewed);
  test('Discount brackets use reviewed recent billed consumption', () {
    for (final pair in [(50.0, '100%'), (70.0, '35%'), (100.0, '20%')]) {
      final text = meralcoGuidance([b(pair.$1)], now: now);
      expect(text, contains(pair.$2));
      expect(text, contains('kWh alone is insufficient'));
    }
    expect(meralcoGuidance([b(101)], now: now),
        isNot(contains('Check Lifeline:')));
    expect(meralcoGuidance([b(50, reviewed: false)], now: now),
        contains('Save a reviewed bill'));
    expect(meralcoGuidance([b(50, date: DateTime(2025))], now: now),
        contains('old or'));
    expect(meralcoGuidance([b(50), b(50)], now: now),
        isNot(contains('Check Lifeline:')));
  });
  test(
      'High consumption and unknown data do not promise eligibility or live tariffs',
      () {
    expect(meralcoGuidance([b(650)], now: now), isNot(contains('Above 650')));
    final text = meralcoGuidance([b(651)], now: now);
    expect(text, contains('Energy Tax'));
    expect(text, contains('one bill does not establish eligibility'));
    expect(text, contains('not live rate'));
    expect(meralcoGuidance([b(double.nan)], now: now),
        contains('Save a reviewed bill'));
    expect(meralcoGuidance([b(50)], now: now, language: 'fil'),
        contains('Hindi sapat ang kWh'));
  });
}
