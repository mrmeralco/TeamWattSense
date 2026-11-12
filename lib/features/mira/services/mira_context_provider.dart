import 'pop_advice.dart';
import '../../../shared/contracts/repositories.dart';

class MiraContextProvider {
  const MiraContextProvider(this.appliances, this.bills, [this.dailyUsage]);
  final ApplianceRepository appliances;
  final BillRepository bills;
  final DailyUsageRepository? dailyUsage;

  Future<Map<String, Object?>> build({
    required String language,
    required double rate,
    bool registeredPop = false,
  }) async {
    if (!rate.isFinite || rate < 0) {
      throw ArgumentError('Invalid estimated rate');
    }
    final items = await appliances.list();
    final bill = await bills.latestReviewed();
    final reviewed = (await bills.list()).where((b) => b.reviewed).toList()
      ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 29));
    final logs = await dailyUsage?.list(from: start, through: today) ?? [];
    return {
      'reviewedBills': [
        for (final b in reviewed)
          {
            'id': b.id,
            'periodEnd': b.periodEnd.toIso8601String(),
            'dueDate': b.dueDate.toIso8601String(),
            'consumptionKwh': b.consumptionKwh,
            'totalAmount': b.totalAmount,
            'charges': [
              for (final c in b.charges)
                {
                  'name': c.name,
                  'amount': c.amount,
                  'explanation': c.explanation
                }
            ],
          }
      ],
      'usageNotes':
          'Logged kWh are calculated from user-entered hours, saved wattage and quantity, NOT smart-meter measurements. Missing days are unknown, not zero. Monthly appliance estimates are separate from logged usage and actual reviewed bills. Do not compare partial logs to a full bill as if coverage matched.',
      'totalApplianceUnits': items.fold<int>(0, (sum, a) => sum + a.quantity),
      'loggedUsageWindowStart': start.toIso8601String(),
      'loggedUsageWindowEnd': today.toIso8601String(),
      'loggedUsageByAppliance': [
        for (final a in items)
          {
            'applianceId': a.id,
            'name': a.name,
            'loggedDays': logs
                .where((e) => e.applianceId == a.id)
                .map((e) => e.dateKey)
                .toSet()
                .length,
            'loggedKwh': logs
                .where((e) => e.applianceId == a.id)
                .fold<double>(0, (sum, e) => sum + e.kwh),
            'loggedUnitHours': logs
                .where((e) => e.applianceId == a.id)
                .fold<double>(0, (sum, e) => sum + e.hours * e.quantity),
          }
      ],
      'language': language,
      'registeredInMeralcoPop': registeredPop,
      'popAdvice': assessPop(reviewed, registered: registeredPop)
          .text(language: language),
      'estimatedRatePerKwh': rate,
      'appliances': items
          .map(
            (a) => {
              ...a.toMap(),
              'monthlyKwh': a.monthlyKwh,
              'estimatedMonthlyCost': a.monthlyKwh * rate,
            },
          )
          .toList(),
      'latestReviewedBill': bill == null
          ? null
          : {
              'periodEnd': bill.periodEnd.toIso8601String(),
              'totalAmount': bill.totalAmount,
              'consumptionKwh': bill.consumptionKwh,
              'charges': bill.charges
                  .map(
                    (c) => {
                      'name': c.name,
                      'amount': c.amount,
                      'explanation': c.explanation,
                    },
                  )
                  .toList(),
            },
    };
  }
}
