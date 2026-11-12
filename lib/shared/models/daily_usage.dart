class DailyUsage {
  const DailyUsage({
    required this.applianceId,
    required this.date,
    required this.hours,
    required this.watts,
    required this.quantity,
  });

  final String applianceId;
  final DateTime date;
  final double hours;
  final double watts;
  final int quantity;

  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  double get kwh => watts / 1000 * hours * quantity;
}
