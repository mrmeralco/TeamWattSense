import 'dart:typed_data';

class BillCharge {
  const BillCharge({
    required this.name,
    required this.amount,
    required this.explanation,
  });
  final String name, explanation;
  final double amount;
}

class Bill {
  const Bill({
    required this.id,
    required this.periodEnd,
    required this.dueDate,
    required this.consumptionKwh,
    required this.totalAmount,
    required this.charges,
    this.reviewed = false,
    this.sourceName,
    this.sourceImage,
    this.ratePerKwh,
    this.insights,
    this.savingsInsight,
  });
  final String id;
  final DateTime periodEnd, dueDate;
  final double consumptionKwh, totalAmount;
  final List<BillCharge> charges;
  final bool reviewed;
  final String? sourceName;
  final Uint8List? sourceImage;
  final double? ratePerKwh;
  final String? insights;
  final String? savingsInsight;
  double get effectiveRatePerKwh =>
      ratePerKwh ?? (consumptionKwh > 0 ? totalAmount / consumptionKwh : 0);
}
