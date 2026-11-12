import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wattwise/shared/storage/sqlite_appliance_repository.dart';
import 'package:wattwise/shared/storage/sqlite_bill_repository.dart';
import 'package:wattwise/shared/models/appliance.dart';
import 'package:wattwise/shared/models/bill.dart';
import 'package:wattwise/app/app_controller.dart';
import 'package:wattwise/features/mira/services/mira_context_provider.dart';

void main() {
  test(
      'Version 1 appliance data survives migration, bills and preferences survive reopening, Mira sees fresh data',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final temp = await Directory.systemTemp.createTemp('wattwise-test-');
    await databaseFactory.setDatabasesPath(temp.path);
    final original = await openDatabase('${temp.path}/wattwise.db',
        version: 1,
        onCreate: (db, v) => db.execute(
            'CREATE TABLE appliances (id TEXT PRIMARY KEY, name TEXT NOT NULL, watts REAL NOT NULL, hours_per_day REAL NOT NULL, days_per_month INTEGER NOT NULL, quantity INTEGER NOT NULL)'));
    await original.insert(
        'appliances',
        const Appliance(
                id: 'fan',
                name: 'Fan',
                watts: 60,
                hoursPerDay: 8,
                daysPerMonth: 30)
            .toMap());
    await original.close();
    final a = await SqliteApplianceRepository.open();
    final bills = SqliteBillRepository(a.database);
    expect((await a.list()).single.monthlyKwh, closeTo(14.4, 1e-9));
    final c = AppController(
        applianceRepository: a, billRepository: bills, database: a.database);
    await c.load();
    await c.preference('dark', 'true');
    await c.preference('language', 'fil');
    await c.preference('pop', 'true');
    await bills.save(Bill(
        id: 'reviewed',
        periodEnd: DateTime(2026, 10, 31),
        dueDate: DateTime(2026, 11, 15),
        consumptionKwh: 100,
        totalAmount: 1200,
        charges: const [],
        reviewed: true));
    await bills.save(Bill(
        id: 'draft',
        periodEnd: DateTime(2026, 11, 30),
        dueDate: DateTime(2026, 12, 15),
        consumptionKwh: 999,
        totalAmount: 9999,
        charges: const []));
    final context = MiraContextProvider(a, bills);
    final first =
        await context.build(language: 'fil', rate: 12, registeredPop: true);
    expect((first['latestReviewedBill'] as Map)['totalAmount'], 1200);
    await a.save(const Appliance(
        id: 'fan', name: 'Fan', watts: 100, hoursPerDay: 8, daysPerMonth: 30));
    final fresh = await context.build(language: 'fil', rate: 12);
    expect(((fresh['appliances'] as List).single as Map)['monthlyKwh'], 24);
    await a.close();
    final reopened = await SqliteApplianceRepository.open();
    final restored = AppController(
        applianceRepository: reopened,
        billRepository: SqliteBillRepository(reopened.database),
        database: reopened.database);
    await restored.load();
    expect(restored.dark, isTrue);
    expect(restored.language, 'fil');
    expect(restored.pop, isTrue);
    expect(restored.bills.length, 2);
    await reopened.close();
    c.dispose();
    restored.dispose();
    await temp.delete(recursive: true);
  });
}
