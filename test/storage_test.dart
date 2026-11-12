import 'package:wattwise/shared/models/daily_usage.dart';
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
  test('Version 7 databases receive the KLoad table migration safely',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final temp = await Directory.systemTemp.createTemp('wattwise-v7-test-');
    await databaseFactory.setDatabasesPath(temp.path);
    final legacy = await openDatabase('${temp.path}/wattwise.db',
        version: 7,
        onCreate: (db, _) => db.execute(
            'CREATE TABLE appliances (id TEXT PRIMARY KEY, name TEXT NOT NULL, watts REAL NOT NULL, hours_per_day REAL NOT NULL, days_per_month INTEGER NOT NULL, quantity INTEGER NOT NULL)'));
    await legacy.close();

    final migrated = await SqliteApplianceRepository.open();
    for (final table in [
      'kload_profile',
      'kload_transitions',
      'kload_rates',
      'kload_balance_events',
    ]) {
      expect(
        await migrated.database.query('sqlite_master',
            where: 'type = ? AND name = ?', whereArgs: ['table', table]),
        isNotEmpty,
        reason: '$table is created for existing version 7 databases',
      );
    }
    await migrated.close();
    await temp.delete(recursive: true);
  });

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
    for (final table in [
      'kload_profile',
      'kload_transitions',
      'kload_rates',
      'kload_balance_events',
    ]) {
      expect(
        await a.database.query('sqlite_master',
            where: 'type = ? AND name = ?', whereArgs: ['table', table]),
        isNotEmpty,
        reason: '$table is created by the additive database migration',
      );
    }
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
    final daily = SqliteDailyUsageRepository(a.database);
    final now = DateTime.now();
    await daily.saveAll([
      DailyUsage(
          applianceId: 'fan',
          date: DateTime(now.year, now.month, now.day),
          hours: 2,
          watts: 120,
          quantity: 3)
    ]);
    final context = MiraContextProvider(a, bills, daily);
    final first =
        await context.build(language: 'fil', rate: 12, registeredPop: true);
    expect((first['latestReviewedBill'] as Map)['totalAmount'], 1200);
    expect((first['reviewedBills'] as List).length, 1);
    expect(((first['reviewedBills'] as List).single as Map)['id'], 'reviewed');
    final logged = (first['loggedUsageByAppliance'] as List).single as Map;
    expect(logged['loggedKwh'], closeTo(0.72, 1e-9));
    expect(logged['loggedDays'], 1);
    expect(logged['loggedUnitHours'], 6);
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
