import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../shared/contracts/repositories.dart';
import '../shared/models/appliance.dart';
import '../shared/models/bill.dart';
import '../shared/localization/strings.dart';

class AppController extends ChangeNotifier {
  AppController(
      {required this.applianceRepository,
      required this.billRepository,
      this.database});
  final ApplianceRepository applianceRepository;
  final BillRepository billRepository;
  final Database? database;
  List<Appliance> appliances = [];
  List<Bill> bills = [];
  bool dark = false, pop = false;
  String language = 'en';
  double rate = 12;
  String t(String key) => translate(key, language);
  double get monthlyKwh => appliances.fold(0, (sum, a) => sum + a.monthlyKwh);
  double get monthlyHours => appliances.fold(
      0, (sum, a) => sum + a.hoursPerDay * a.daysPerMonth * a.quantity);
  Future<void> load() async {
    appliances = await applianceRepository.list();
    bills = await billRepository.list()
      ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
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

  Future<void> removeAppliance(String id) async {
    await applianceRepository.remove(id);
    appliances = await applianceRepository.list();
    notifyListeners();
  }

  Future<void> saveBill(Bill b) async {
    await billRepository.save(b);
    bills = await billRepository.list()
      ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
    notifyListeners();
  }
}
