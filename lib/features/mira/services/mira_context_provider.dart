import '../../../shared/contracts/repositories.dart';

class MiraContextProvider {
  const MiraContextProvider(this.appliances, this.bills);
  final ApplianceRepository appliances;
  final BillRepository bills;

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
    return {
      'language': language,
      'registeredInMeralcoPop': registeredPop,
      'popNote':
          'Self-reported enrollment only. Peak hours and rates are unknown; do not assume a discount.',
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
