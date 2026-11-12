import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../shared/contracts/repositories.dart';
import '../shared/models/appliance.dart';
import '../shared/models/bill.dart';
import '../shared/models/daily_usage.dart';
import '../shared/localization/strings.dart';

class AppController extends ChangeNotifier {
  AppController(
      {required this.applianceRepository,
      required this.billRepository,
      this.dailyUsageRepository,
      this.database});
  final ApplianceRepository applianceRepository;
  final BillRepository billRepository;
  final DailyUsageRepository? dailyUsageRepository;
  final Database? database;
  List<Appliance> appliances = [];
  List<Bill> bills = [];
  List<DailyUsage> dailyUsages = [];
  bool dark = false, pop = false;
  List<Map<String, Object?>> popTransitions = [];
  List<Map<String, Object?>> popRates = [];
  final Map<String, Map<String, double>> popUsageSplits = {};
  final Map<String, Map<String, DateTime>> popUsageSessions = {};
  String language = 'en';
  double rate = 12;
  double get billRate {
    for (final bill in bills) {
      if (bill.reviewed && bill.consumptionKwh > 0) {
        return bill.totalAmount / bill.consumptionKwh;
      }
    }
    return rate;
  }
  String t(String key) => translate(key, language);
  double get monthlyKwh => appliances.fold(0, (sum, a) => sum + a.monthlyKwh);
  double get monthlyHours => appliances.fold(
      0, (sum, a) => sum + a.hoursPerDay * a.daysPerMonth * a.quantity);
  Future<void> load() async {
    appliances = await applianceRepository.list();
    bills = await billRepository.list()
      ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
    dailyUsages = await dailyUsageRepository?.list() ?? [];
    final db = database;
    if (db != null) {
      final prefs = {
        for (final row in await db.query('preferences'))
          row['key'] as String: row['value'] as String
      };
      dark = prefs['dark'] == 'true';
      popTransitions = await db.query('pop_transitions',
          orderBy: 'effective_date');
      popRates = await db.query('pop_rates', orderBy: 'effective_month');
      popUsageSplits.clear();
      for (final row in await db.query('pop_usage_split')) {
        popUsageSplits['${row['appliance_id']}:${row['usage_date']}'] = {
          'peak': (row['peak_hours'] as num).toDouble(),
          'offPeak': (row['off_peak_hours'] as num).toDouble(),
        };
      }
      popUsageSessions.clear();
      for (final row in await db.query('pop_usage_sessions')) {
        popUsageSessions['${row['appliance_id']}:${row['usage_date']}'] = {
          'start': DateTime.parse(row['started_at'] as String),
          'stop': DateTime.parse(row['stopped_at'] as String),
        };
      }
      if (popTransitions.isEmpty && prefs['pop'] == 'true') {
        await schedulePopChange(true, effectiveDate: DateTime.now());
      }
      pop = popForDate(DateTime.now());
      language = prefs['language'] ?? 'en';
      rate = double.tryParse(prefs['rate'] ?? '') ?? 12;
    }
    notifyListeners();
  }

  Future<void> preference(String key, String value) async {
    await database?.insert('preferences', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
    switch (key) {
      case 'dark':
        dark = value == 'true';
      case 'language':
        language = value;
      case 'rate':
        rate = double.parse(value);
    }
    notifyListeners();
  }

  bool popForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    var enabled = false;
    for (final row in popTransitions) {
      final effective = DateTime.parse(row['effective_date'] as String);
      if (effective.isAfter(target)) break;
      enabled = row['enabled'] == 1 || row['enabled'] == true;
    }
    return enabled;
  }

  bool get popSwitchValue {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final pending = popTransitions.where((row) =>
        DateTime.parse(row['effective_date'] as String).year == tomorrow.year &&
        DateTime.parse(row['effective_date'] as String).month == tomorrow.month &&
        DateTime.parse(row['effective_date'] as String).day == tomorrow.day);
    return pending.isEmpty ? popForDate(DateTime.now()) :
        (pending.last['enabled'] == 1 || pending.last['enabled'] == true);
  }

  Future<void> schedulePopChange(bool enabled,
      {DateTime? effectiveDate}) async {
    final db = database;
    if (db == null) throw StateError('POP storage is unavailable');
    final selectedDate = effectiveDate ?? DateTime.now().add(const Duration(days: 1));
    final day = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final key = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    await db.insert('pop_transitions', {
      'effective_date': key,
      'enabled': enabled ? 1 : 0,
      'recorded_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    popTransitions = await db.query('pop_transitions', orderBy: 'effective_date');
    pop = popForDate(DateTime.now());
    notifyListeners();
  }

  Future<void> savePopRates({required String effectiveMonth,
      required double peakRate, required double offPeakRate,
      required String source, bool reference = false}) async {
    final db = database;
    if (db == null) throw StateError('POP storage is unavailable');
    await db.insert('pop_rates', {
      'effective_month': effectiveMonth,
      'peak_generation_rate': peakRate,
      'off_peak_generation_rate': offPeakRate,
      'source': source,
      'is_reference': reference ? 1 : 0,
      'recorded_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    popRates = await db.query('pop_rates', orderBy: 'effective_month');
    notifyListeners();
  }

  Future<void> savePopUsageSplit(String applianceId, DateTime date,
      double peakHours, double offPeakHours) async {
    final db = database;
    if (db == null) throw StateError('POP storage is unavailable');
    final total = peakHours + offPeakHours;
    if (!peakHours.isFinite || !offPeakHours.isFinite || peakHours < 0 ||
        offPeakHours < 0 || total > 24) {
      throw ArgumentError('Peak and off-peak hours must total 0 to 24 hours');
    }
    final day = DateTime(date.year, date.month, date.day);
    final dateKey = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    await db.insert('pop_usage_split', {
      'appliance_id': applianceId, 'usage_date': dateKey,
      'peak_hours': peakHours, 'off_peak_hours': offPeakHours,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    popUsageSplits['$applianceId:$dateKey'] = {'peak': peakHours, 'offPeak': offPeakHours};
    notifyListeners();
  }

  Future<double> savePopUsageSession(String applianceId, DateTime date,
      DateTime startedAt, DateTime stoppedAt) async {
    final db = database;
    if (db == null) throw StateError('POP storage is unavailable');
    final day = DateTime(date.year, date.month, date.day);
    if (startedAt.year != day.year || startedAt.month != day.month || startedAt.day != day.day ||
        stoppedAt.year != day.year || stoppedAt.month != day.month || stoppedAt.day != day.day ||
        !stoppedAt.isAfter(startedAt)) {
      throw ArgumentError('The stop time must be later than the start time on the selected day.');
    }
    final duration = stoppedAt.difference(startedAt).inMinutes / 60.0;
    final dateKey = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    await db.insert('pop_usage_sessions', {
      'appliance_id': applianceId, 'usage_date': dateKey,
      'started_at': startedAt.toIso8601String(),
      'stopped_at': stoppedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    var peakMinutes = 0;
    var offPeakMinutes = 0;
    for (var minute = 0; minute < stoppedAt.difference(startedAt).inMinutes; minute++) {
      final at = startedAt.add(Duration(minutes: minute));
      final minuteOfDay = at.hour * 60 + at.minute;
      final isSunday = at.weekday == DateTime.sunday;
      final peak = isSunday
          ? minuteOfDay >= 18 * 60 && minuteOfDay < 20 * 60
          : minuteOfDay >= 8 * 60 && minuteOfDay < 21 * 60;
      if (peak) { peakMinutes++; } else { offPeakMinutes++; }
    }
    final split = {'peak': peakMinutes / 60.0, 'offPeak': offPeakMinutes / 60.0};
    popUsageSessions['$applianceId:$dateKey'] = {'start': startedAt, 'stop': stoppedAt};
    popUsageSplits['$applianceId:$dateKey'] = split;
    notifyListeners();
    return duration;
  }

  double? popGenerationEstimate(DateTime from, DateTime through) {
    var total = 0.0;
    var foundSplit = false;
    for (final entry in dailyUsages) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (day.isBefore(from) || day.isAfter(through) || !popForDate(day)) continue;
      final split = popUsageSplits['${entry.applianceId}:${entry.dateKey}'];
      if (split == null) continue;
      final month = '${day.year}-${day.month.toString().padLeft(2, '0')}';
      final applicable = popRates.where((row) =>
          (row['effective_month'] as String).compareTo(month) <= 0).toList()
        ..sort((a, b) => (b['effective_month'] as String)
            .compareTo(a['effective_month'] as String));
      if (applicable.isEmpty) continue;
      final rate = applicable.first;
      final peakKwh = entry.watts / 1000 * split['peak']! * entry.quantity;
      final offPeakKwh = entry.watts / 1000 * split['offPeak']! * entry.quantity;
      total += peakKwh * (rate['peak_generation_rate'] as num).toDouble();
      total += offPeakKwh * (rate['off_peak_generation_rate'] as num).toDouble();
      foundSplit = true;
    }
    return foundSplit ? total : null;
  }

  Future<void> saveAppliance(Appliance a) async {
    await applianceRepository.save(a);
    appliances = await applianceRepository.list();
    notifyListeners();
  }

  double recordedKwh(DateTime from, DateTime through) {
    final appliancesById = {for (final a in appliances) a.id: a};
    return dailyUsages.fold(0.0, (sum, entry) {
      final appliance = appliancesById[entry.applianceId];
      if (appliance == null) return sum;
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (day.isBefore(from) || day.isAfter(through)) return sum;
      return sum + entry.kwh;
    });
  }

  double recordedKwhForDay(DateTime date) => recordedKwh(
      DateTime(date.year, date.month, date.day),
      DateTime(date.year, date.month, date.day));

  bool hasUsageForDay(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return dailyUsages.any((entry) =>
        entry.date.year == key.year &&
        entry.date.month == key.month &&
        entry.date.day == key.day);
  }

  Future<void> saveDailyUsages(List<DailyUsage> entries) async {
    final repo = dailyUsageRepository;
    if (repo == null) throw StateError('Daily usage storage is unavailable');
    await repo.saveAll(entries);
    dailyUsages = await repo.list();
    notifyListeners();
  }

  Future<void> removeAppliance(String id) async {
    await applianceRepository.remove(id);
    await dailyUsageRepository?.removeForAppliance(id);
    dailyUsages.removeWhere((entry) => entry.applianceId == id);
    appliances = await applianceRepository.list();
    notifyListeners();
  }

  Future<void> saveBill(Bill b) async {
    await billRepository.save(b);
    bills = await billRepository.list()
      ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
    notifyListeners();
  }

  Future<void> removeBill(String id) async {
    await billRepository.remove(id);
    bills = await billRepository.list()
      ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
    notifyListeners();
  }
}
