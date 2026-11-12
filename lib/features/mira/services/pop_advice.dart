import '../../../shared/models/bill.dart';

/// Published reference figures, deliberately not represented as live tariffs.
const popSource =
    'https://www.meralco.com.ph/residential/energy-solutions/peak-off-peak';
const popQuestion = 'Check my Meralco POP eligibility and savings';
const popQuestionFil = 'Suriin ang eligibility at pagtitipid ko sa Meralco POP';

class PopAdvice {
  const PopAdvice(this.months, this.average, this.complete, this.registered);
  final int months;
  final double? average;
  final bool complete, registered;
  bool get meetsConsumption => complete && average! >= 500;
  bool get suggest => registered || (average != null && average! >= 500);

  String text({String language = 'en'}) {
    final fil = language == 'fil';
    final evidence = average == null
        ? (fil
            ? 'Wala pang sapat na na-review na bills.'
            : 'No usable reviewed bills yet.')
        : (fil
            ? 'Average ng $months na buwan ng na-review na bills: ${average!.toStringAsFixed(1)} kWh/buwan.'
            : 'Your $months months of reviewed bills average ${average!.toStringAsFixed(1)} kWh/month.');
    final status = registered
        ? (fil
            ? 'Naka-enable ang POP enrollment mo sa Settings (self-reported).'
            : 'You marked yourself as enrolled in POP in Settings (self-reported).')
        : !complete
            ? (fil
                ? 'Maaaring sulit suriin ang POP, pero hindi pa makumpirma ang consumption requirement. Kailangan ng 12 sunod-sunod na buwan ng bills, hanggang kasalukuyan o nakaraang buwan, na walang duplicate o invalid na bill.'
                : 'POP may be worth checking, but the consumption requirement is not confirmed. Save 12 consecutive monthly bills ending this or last month, without duplicate or invalid bills.')
            : meetsConsumption
                ? (fil
                    ? 'Pasok ang na-review mong konsumo sa 500 kWh/buwan na requirement. Hindi pa ito approval ng Meralco.'
                    : 'Your reviewed usage meets the 500 kWh/month consumption threshold. This is not Meralco approval.')
                : (fil
                    ? 'Mas mababa ito sa 500 kWh/buwan na consumption requirement.'
                    : 'This is below the 500 kWh/month consumption requirement.');
    final intro = fil
        ? 'Alam mo ba? Sa reference ng Meralco noong 18 June 2025, ang POP off-peak generation rate ay PHP 4.55/kWh. Hindi ito current rate o kabuuang singil.'
        : 'Did you know? A POP customer could pay as low as PHP 4.55/kWh for off-peak generation in Meralco’s 18 June 2025 example. This is not a current rate or the total electricity rate.';
    // A transparent scenario, never an inferred time-of-use split or bill forecast.
    final scenario = average != null && suggest
        ? (fil
            ? 'Halimbawa lang gamit ang ${average!.toStringAsFixed(1)} kWh at 80% off-peak / 20% peak: PHP ${(average! * 5.316).toStringAsFixed(2)} generation, kumpara sa PHP ${(average! * 6.64).toStringAsFixed(2)} non-POP generation; PHP ${(average! * 1.324).toStringAsFixed(2)} na diperensya. Assumption lang ang 80%; walang oras ng paggamit ang logs.'
            : 'Illustration at ${average!.toStringAsFixed(1)} kWh, assuming 80% off-peak and 20% peak: PHP ${(average! * 5.316).toStringAsFixed(2)} generation versus PHP ${(average! * 6.64).toStringAsFixed(2)} non-POP generation, a PHP ${(average! * 1.324).toStringAsFixed(2)} difference. The 80% split is hypothetical; your logs do not record time of use.')
        : '';
    return [
      evidence,
      status,
      if (suggest || average == null) intro,
      if (scenario.isNotEmpty) scenario,
      fil
          ? 'Requirement: 12-buwang average na hindi bababa sa 500 kWh, kayang ilipat ang paggamit sa off-peak, at walang contract violation/service irregularities. Ipakumpirma sa Meralco ang eligibility, kasalukuyang rates at fees. Reference peak: PHP 8.38/kWh; non-POP: PHP 6.64/kWh. Mas maraming peak use ay maaaring magpataas ng gastos. Hindi kasama ang ibang bill charges, taxes o application fee.'
          : 'Requirements: a 12-month average of at least 500 kWh, ability to use more electricity off-peak, and no contract violations/service irregularities. Confirm eligibility, current rates and fees with Meralco. Reference peak: PHP 8.38/kWh; non-POP: PHP 6.64/kWh. More peak use can cost more. Other bill charges, taxes and application fees are excluded.',
      fil
          ? 'Off-peak: Lunes–Sabado 9pm–8am; Linggo 12am–6pm at 8pm–12am. Huwag patayin ang essential appliances para lang mag-shift.'
          : 'Off-peak: Monday–Saturday 9pm–8am; Sunday midnight–6pm and 8pm–midnight. Do not shut down essential appliances just to shift usage.',
      'Source (checked 12 Nov 2026): $popSource',
    ].join('\n\n');
  }
}

PopAdvice assessPop(List<Bill> bills,
    {DateTime? now, bool registered = false}) {
  final today = now ?? DateTime.now();
  final current = today.year * 12 + today.month;
  final recent = bills
      .where((b) =>
          b.reviewed &&
          !b.periodEnd.isAfter(today) &&
          b.periodEnd.year * 12 + b.periodEnd.month >= current - 12)
      .toList();
  final grouped = <int, List<Bill>>{};
  for (final b in recent) {
    (grouped[b.periodEnd.year * 12 + b.periodEnd.month] ??= []).add(b);
  }
  final keys = grouped.keys.toList()..sort();
  final end = keys.isEmpty ? current : keys.last;
  final valid = <double>[];
  for (var month = end - 11; month <= end; month++) {
    final group = grouped[month];
    if (group?.length == 1) {
      final kwh = group!.single.consumptionKwh;
      if (kwh.isFinite && kwh >= 0) valid.add(kwh);
    }
  }
  return PopAdvice(
      valid.length,
      valid.isEmpty ? null : valid.reduce((a, b) => a + b) / valid.length,
      valid.length == 12 && end >= current - 1,
      registered);
}
