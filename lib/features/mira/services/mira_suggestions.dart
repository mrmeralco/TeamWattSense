import '../../../shared/models/appliance.dart';
import '../../../shared/models/daily_usage.dart';
import '../../../shared/models/bill.dart';

List<String> miraSuggestions(
    List<Appliance> appliances, List<DailyUsage> logs, List<Bill> bills,
    {DateTime? now, String language = 'en'}) {
  final today = now ?? DateTime.now();
  final end = DateTime(today.year, today.month, today.day);
  final start = end.subtract(const Duration(days: 29));
  final fil = language == 'fil';
  if (appliances.isEmpty) {
    return [
      fil
          ? 'Paano magdagdag ng appliances sa WattWise?'
          : 'How do I add appliances in WattWise?',
      if (bills.any((b) => b.reviewed))
        fil
            ? 'Ipaliwanag ang na-review kong bill'
            : 'Explain my reviewed electricity bill'
    ];
  }
  final groups = <String,
      ({
    String name,
    int quantity,
    double estimate,
    double logged,
    bool hasLog
  })>{};
  for (final a in appliances) {
    final key = a.name.trim().toLowerCase();
    final previous = groups[key];
    final entries = logs.where((e) =>
        e.applianceId == a.id &&
        !e.date.isBefore(start) &&
        e.date.isBefore(end.add(const Duration(days: 1))));
    groups[key] = (
      name: a.name,
      quantity: (previous?.quantity ?? 0) + a.quantity,
      estimate: (previous?.estimate ?? 0) + a.monthlyKwh,
      logged: (previous?.logged ?? 0) +
          entries.fold<double>(0, (s, e) => s + e.kwh),
      hasLog: (previous?.hasLog ?? false) || entries.isNotEmpty
    );
  }
  final hasLogs = groups.values.any((g) => g.hasLog);
  final ranked = groups.values.where((g) => !hasLogs || g.hasLog).toList()
    ..sort((a, b) => (hasLogs ? b.logged : b.estimate)
        .compareTo(hasLogs ? a.logged : a.estimate));
  final top = ranked.first;
  final units = appliances.fold<int>(0, (s, a) => s + a.quantity);
  return [
    fil
        ? 'Paano makatipid sa ${top.quantity} ${top.name} ko (${(hasLogs ? top.logged : top.estimate).toStringAsFixed(1)} kWh, ${hasLogs ? 'naka-log sa 30 araw' : 'buwanang estimate'})?'
        : 'How can I save electricity with my ${top.quantity} ${top.name} (${(hasLogs ? top.logged : top.estimate).toStringAsFixed(1)} kWh ${hasLogs ? 'logged in 30 days' : 'monthly estimate'})?',
    fil
        ? 'Suriin ang konsumo ng $units appliances ko ayon sa uri'
        : 'Compare electricity usage across my $units appliances by type',
    if (bills.any((b) => b.reviewed))
      fil
          ? 'Ihambing ang na-review kong bill sa appliance usage'
          : 'Compare my reviewed electricity bill with appliance usage',
    if (!hasLogs)
      fil
          ? 'Paano mag-log ng araw-araw na konsumo sa WattWise?'
          : 'How do I log daily appliance usage in WattWise?',
  ];
}
