import 'package:flutter_test/flutter_test.dart';
import 'package:wattwise/features/mira/services/pop_advice.dart';
import 'package:wattwise/features/mira/services/mira_suggestions.dart';
import 'package:wattwise/features/mira/services/mira_policy.dart';
import 'package:wattwise/shared/models/bill.dart';

Bill bill(int month, double kwh, {bool reviewed = true, String? id}) => Bill(
    id: id ?? '$month',
    periodEnd: DateTime(2026, month, 1),
    dueDate: DateTime(2026, month, 20),
    consumptionKwh: kwh,
    totalAmount: kwh * 12,
    charges: [],
    reviewed: reviewed);
void main() {
  final now = DateTime(2026, 11, 12);
  List<Bill> year(double kwh) => [for (var m = 0; m < 12; m++) bill(m, kwh)];
  test('Threshold requires twelve recent consecutive reviewed months', () {
    expect(assessPop(year(500), now: now).meetsConsumption, true);
    expect(assessPop(year(499.9), now: now).meetsConsumption, false);
    expect(assessPop([bill(11, 900)], now: now).complete, false);
    expect(assessPop([bill(11, 900, reviewed: false)], now: now).average, null);
    expect(assessPop(year(700).sublist(1), now: now).complete, false);
    expect(
        assessPop([...year(700), bill(3, 700, id: 'duplicate')], now: now)
            .complete,
        false);
    expect(
        assessPop([...year(700).sublist(1), bill(0, double.nan)], now: now)
            .complete,
        false);
    expect(assessPop(year(700), now: DateTime(2027, 3)).complete, false);
    expect(assessPop([bill(12, 700)], now: now).average, null);
  });
  test(
      'Advice separates historical generation scenarios from current total bill',
      () {
    final advice = assessPop(year(600), now: now);
    final text = advice.text();
    expect(text, contains('meets the 500'));
    expect(text, contains('not Meralco approval'));
    expect(text, contains('18 June 2025'));
    expect(text, contains('PHP 3189.60'));
    expect(text, contains('PHP 794.40'));
    expect(text, contains('hypothetical'));
    expect(text, contains('not a current rate'));
    expect(text, contains('can cost more'));
    expect(assessPop(year(400), now: now).text(), contains('below'));
    expect(assessPop([], now: now, registered: true).text(),
        contains('self-reported'));
    expect(advice.text(language: 'fil'), contains('Hindi pa ito approval'));
  });
  test(
      'Bill-only users receive POP chip, no data does not invent qualification',
      () {
    expect(miraSuggestions([], [], year(600), now: now), contains(popQuestion));
    expect(miraSuggestions([], [], [], now: now), isNot(contains(popQuestion)));
    expect(miraLocalReply(popQuestion), isNull);
    expect(miraLocalReply(popQuestionFil), isNull);
  });
}
