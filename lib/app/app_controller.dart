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
      pop = prefs['pop'] == 'true';
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
      case 'pop':
        pop = value == 'true';
      case 'language':
        language = value;
      case 'rate':
        rate = double.parse(value);
    }
    notifyListeners();
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
