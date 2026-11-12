import '../../../shared/models/bill.dart';

const meralcoQuestion =
    'What Meralco guidance fits my electricity consumption?';
const meralcoQuestionFil = 'Anong gabay ng Meralco ang bagay sa konsumo ko?';
const meralcoRates = 'https://www.meralco.com.ph/residential/rates-and-charges';
const meralcoBill =
    'https://www.meralco.com.ph/residential/understand-your-bill';
const meralcoTips = 'https://www.meralco.com.ph/residential/bright-ideas';

// Curated residential guidance, not a crawl or live-rate service.
const meralcoKnowledge = <String, Object>{
  'reviewedOn': '2026-11-12',
  'coverage':
      'Selected official residential pages only. Not the entire website, not live browsing. Confirm current terms with Meralco. Do not invent present-month rates, temporary relief deadlines or program approval.',
  'discounts':
      'Lifeline: qualified 4Ps/certified-marginalized households, with enrollment requirements. Published monthly brackets: 0–50 kWh 100%, 51–70 kWh 35%, 71–100 kWh 20% on applicable charges. Do not infer poverty or eligibility from consumption; do not promise a zero total bill or combine discounts. Senior citizen: eligible Filipino senior citizen, account in their name, application/approval and monthly use <=100 kWh; 5% on eligible components, not necessarily the whole bill. Source: $meralcoRates',
  'bill':
      'Explain generation, transmission, distribution, taxes and subsidies separately. Rates vary by billing month. Residential energy tax guidance applies above 650 kWh; inspect the actual bill, do not calculate a tax from total kWh alone. Source: $meralcoBill',
  'efficiency':
      'Prioritize actual logged appliance kWh, quantities and coverage; missing days are unknown. Cooling: maintain filters, keep airflow clear, reduce direct heat, use appropriate settings. Refrigerator: sound seals, clear vents, safe temperatures; never turn it off for savings. Lighting: suitable LEDs and switch off unused lights safely. Fans: useful speed and off in empty rooms. TV: sleep settings and reduce idle operation. Estimates depend on wattage, quantity and hours; no guaranteed percentages. Source: $meralcoTips',
  'solar':
      'Net metering can credit approved excess renewable generation exported to the grid. Up to 100 kW system capacity, not a monthly consumption threshold. Requires technical assessment, permits and Meralco approval. Do not promise payback, free electricity or size a system from monthly kWh alone. Source: https://www.meralco.com.ph/residential/energy-solutions/solar-and-renewables/solar-net-metering',
};

String meralcoGuidance(List<Bill> bills,
    {DateTime? now, String language = 'en'}) {
  final date = now ?? DateTime.now();
  final fil = language == 'fil';
  final valid = bills
      .where((b) =>
          b.reviewed &&
          b.consumptionKwh.isFinite &&
          b.consumptionKwh >= 0 &&
          !b.periodEnd.isAfter(date))
      .toList()
    ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
  final intro = fil
      ? 'Gabay mula sa piling residential pages ng Meralco, sinuri noong 12 Nov 2026. Hindi ito live rates; kumpirmahin ang kasalukuyang terms sa Meralco.'
      : 'Guidance from selected Meralco residential pages, reviewed 12 Nov 2026. This is not live rate information; confirm current terms with Meralco.';
  if (valid.isEmpty) {
    return '$intro\n\n${fil ? 'Mag-save muna ng na-review na bill para maibagay ang gabay sa aktuwal na billed kWh. Hindi sapat ang appliance estimates para patunayan ang discount eligibility.' : 'Save a reviewed bill to match guidance to actual billed kWh. Appliance estimates cannot establish discount eligibility.'}\n\n$meralcoTips';
  }
  final latest = valid.first;
  final month = latest.periodEnd.toIso8601String().substring(0, 10);
  final kwh = latest.consumptionKwh;
  final lines = <String>[
    intro,
    fil
        ? 'Pinakahuling na-review na bill ($month): ${kwh.toStringAsFixed(1)} kWh.'
        : 'Latest reviewed bill ($month): ${kwh.toStringAsFixed(1)} kWh.'
  ];
  final sameMonth = valid
      .where((b) =>
          b.periodEnd.year == latest.periodEnd.year &&
          b.periodEnd.month == latest.periodEnd.month)
      .length;
  if (date.difference(latest.periodEnd).inDays > 62 || sameMonth > 1) {
    lines.add(fil
        ? 'Luma o may magkakaparehong buwan ang bills. Ayusin o magdagdag ng bagong bill bago suriin ang consumption-based programs.'
        : 'This bill is old or its month has multiple saved bills. Review duplicates or add a recent bill before checking consumption-based programs.');
  } else {
    if (kwh <= 100) {
      final discount = kwh <= 50
          ? 100
          : kwh <= 70
              ? 35
              : 20;
      lines.add(fil
          ? 'Maaaring suriin ang Lifeline: ang bracket na ito ay may $discount% discount sa applicable charges para sa kwalipikadong 4Ps/certified-marginalized customer. Hindi sapat ang kWh lang; kumpirmahin ang enrollment at requirements. Hindi ito pangakong libre ang buong bill. Kung kwalipikadong senior citizen at nasa pangalan niya ang account, maaari ring itanong ang 5% discount sa eligible components; kailangan ng approval. Huwag pagsamahin nang kusa ang discounts.\n$meralcoRates'
          : 'Check Lifeline: this bracket has a $discount% discount on applicable charges for qualified 4Ps/certified-marginalized customers. kWh alone is insufficient; confirm enrollment and requirements. This does not promise a free total bill. If an eligible senior citizen owns the account, also ask about the 5% discount on eligible components, subject to approval. Do not automatically combine discounts.\n$meralcoRates');
    }
    if (kwh >= 500) {
      lines.add(fil
          ? 'Suriin ang POP sa Mira. Kailangan ng 12-buwang average na hindi bababa sa 500 kWh at iba pang requirements; hindi sapat ang isang bill.'
          : 'Check POP in Mira. It requires a 12-month average of at least 500 kWh and other conditions; one bill does not establish eligibility.');
    }
    if (kwh > 650) {
      lines.add(fil
          ? 'Lampas 650 kWh: tingnan ang Energy Tax line ng bill. Huwag ituring ang generation rate na kabuuang rate.\n$meralcoBill'
          : 'Above 650 kWh: review the Energy Tax line on your bill. The generation rate is not the total electricity rate.\n$meralcoBill');
    }
  }
  lines.add(fil
      ? 'Unahin ang appliances na may pinakamataas na naka-log na kWh. Suriin ang dami, oras ng paggamit at maintenance. Gamitin ang appliance-specific suggestions sa Mira; huwag bawasan ang essential cooling o ligtas na food storage.\n$meralcoTips'
      : 'Start with appliances with the highest logged kWh. Review quantity, operating hours and maintenance. Use Mira’s appliance-specific suggestions; protect essential cooling and safe food storage.\n$meralcoTips');
  return lines.join('\n\n');
}
