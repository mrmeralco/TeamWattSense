import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wattwise/app/app_controller.dart';
import 'package:wattwise/features/dashboard/services/kload_service.dart';
import 'package:wattwise/shared/models/appliance.dart';
import 'package:wattwise/shared/models/daily_usage.dart';
import 'package:wattwise/shared/storage/memory_repositories.dart';
import 'package:wattwise/shared/storage/sqlite_appliance_repository.dart';

void main() {
  test('KLoad activation and deactivation take effect on the current day',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final temp = await Directory.systemTemp.createTemp('wattwise-kload-now-');
    await databaseFactory.setDatabasesPath(temp.path);
    final repository = await SqliteApplianceRepository.open();
    final service = KLoadService(repository.database);
    final today = DateTime.now();
    final todayKey = KLoadService.dateKey(today);
    final tomorrowKey =
        KLoadService.dateKey(today.add(const Duration(days: 1)));

    await service.scheduleActivation(startingBalance: 500, rate: 12);
    expect(await service.enabledOn(today), isTrue);
    expect(await service.switchValue, isTrue);

    await repository.database.insert('kload_transitions', {
      'effective_date': tomorrowKey,
      'enabled': 0,
      'recorded_at': DateTime.now().toIso8601String(),
    });
    await service.applyPendingModeChangeNow();

    expect(await service.enabledOn(today), isFalse);
    expect(await service.switchValue, isFalse);

    await service.scheduleActivation(startingBalance: 500, rate: 12);
    expect(await service.enabledOn(today), isTrue);
    await repository.database.insert('kload_transitions', {
      'effective_date': tomorrowKey,
      'enabled': 0,
      'recorded_at': DateTime.now().toIso8601String(),
    });
    await service.scheduleDeactivation();

    expect(await service.enabledOn(today), isFalse);
    expect(await service.switchValue, isFalse);
    final transitions = await service.transitions();
    expect(transitions, hasLength(1));
    expect(transitions.single['effective_date'], todayKey);
    expect(transitions.single['enabled'], 0);

    await repository.close();
    await temp.delete(recursive: true);
  });

  test('immediate activation reconciles today entries to current balance',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final temp =
        await Directory.systemTemp.createTemp('wattwise-kload-balance-');
    await databaseFactory.setDatabasesPath(temp.path);
    final repository = await SqliteApplianceRepository.open();
    final usageRepository = MemoryDailyUsageRepository();
    final controller = AppController(
      applianceRepository: MemoryApplianceRepository(),
      billRepository: MemoryBillRepository(),
      dailyUsageRepository: usageRepository,
      database: repository.database,
    );
    await controller.saveAppliance(const Appliance(
      id: 'fan',
      name: 'Fan',
      watts: 1000,
      hoursPerDay: 2,
      daysPerMonth: 30,
    ));
    await controller.saveDailyUsages([
      DailyUsage(
        applianceId: 'fan',
        date: DateTime.now(),
        hours: 2,
        watts: 1000,
        quantity: 1,
      ),
    ]);

    await controller.scheduleKLoadActivation(startingBalance: 500, rate: 10);
    final summary = await KLoadService(repository.database).summarize(
      entries: controller.dailyUsages,
      existingApplianceIds: controller.appliances.map((a) => a.id).toSet(),
    );
    expect(summary.activeToday, isTrue);
    expect(summary.todayCost, closeTo(20, 1e-9));
    expect(summary.estimatedBalance, closeTo(500, 1e-9));

    controller.dispose();
    await repository.close();
    await temp.delete(recursive: true);
  });

  test(
      'KLoad totals use recorded active-day entries and effective rate history',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final temp = await Directory.systemTemp.createTemp('wattwise-kload-');
    await databaseFactory.setDatabasesPath(temp.path);
    final repository = await SqliteApplianceRepository.open();
    final service = KLoadService(repository.database);

    await service.scheduleActivation(
      startingBalance: 1000,
      rate: 12,
      effectiveDate: DateTime(2026, 11, 10),
    );
    await service.saveRate(
      rate: 10,
      effectiveDate: DateTime(2026, 11, 11),
    );
    await service.addBalanceEvent(
      id: 'topup-1',
      date: DateTime(2026, 11, 11),
      amount: 100,
    );
    await service.scheduleDeactivation(effectiveDate: DateTime(2026, 11, 12));

    final summary = await service.summarize(
      entries: [
        DailyUsage(
            applianceId: 'fan',
            date: DateTime(2026, 11, 10),
            hours: 10,
            watts: 100,
            quantity: 1),
        DailyUsage(
            applianceId: 'fan',
            date: DateTime(2026, 11, 11),
            hours: 10,
            watts: 200,
            quantity: 1),
        DailyUsage(
            applianceId: 'fan',
            date: DateTime(2026, 11, 12),
            hours: 10,
            watts: 300,
            quantity: 1),
      ],
      existingApplianceIds: {'fan'},
      now: DateTime(2026, 11, 12),
    );

    expect(summary.activeToday, isFalse);
    expect(summary.totalKwh, closeTo(3, 1e-9));
    expect(summary.totalCost, closeTo(32, 1e-9));
    expect(summary.monthCost, closeTo(32, 1e-9));
    expect(summary.todayCost, 0);
    expect(summary.estimatedBalance, closeTo(1068, 1e-9));
    expect(await service.rateFor(DateTime(2026, 11, 10)), 12);
    expect(await service.rateFor(DateTime(2026, 11, 11)), 10);

    await repository.close();
    await temp.delete(recursive: true);
  });
}
