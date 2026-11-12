import 'package:flutter_test/flutter_test.dart';
import 'package:wattwise/app/app_controller.dart';
import 'package:wattwise/shared/models/daily_usage.dart';
import 'package:wattwise/shared/storage/memory_repositories.dart';
import 'package:wattwise/shared/storage/sqlite_appliance_repository.dart';
import 'cloud_sync_test.dart' show device, fan, transfer;

void main() {
  test(
      'November entries stay on their dates; deleting 13 preserves 10 locally and in cloud sync',
      () async {
    final store = await device(), other = await device();
    await store.initialize();
    await other.initialize();
    await store.db.insert('appliances', fan);
    final repo = SqliteDailyUsageRepository(store.db);
    final c = AppController(
        applianceRepository: SqliteApplianceRepository(store.db),
        billRepository: MemoryBillRepository(),
        dailyUsageRepository: repo,
        database: store.db);
    final ten = DateTime(2026, 11, 10), thirteen = DateTime(2026, 11, 13);
    await c.saveDailyUsages([
      DailyUsage(
          applianceId: 'fan:1', date: ten, hours: 2, watts: 60, quantity: 2)
    ]);
    await c.load();
    expect(c.appliancesForDate(ten).length, 1);
    for (var day = 11; day <= 13; day++) {
      expect(c.appliancesForDate(DateTime(2026, 11, day)), isEmpty);
    }
    await c.saveDailyUsages([
      DailyUsage(
          applianceId: 'fan:1',
          date: thirteen,
          hours: 3,
          watts: 60,
          quantity: 2)
    ]);
    for (final date in [ten, thirteen]) {
      await c.savePopUsageSession(
          'fan:1',
          date,
          date.add(const Duration(hours: 20)),
          date.add(const Duration(hours: 22)));
    }
    await transfer(store, other);
    await c.removeDailyUsage('fan:1', thirteen);
    await c.load();
    expect(c.appliancesForDate(ten).length, 1);
    expect(c.appliancesForDate(thirteen), isEmpty);
    expect(c.recordedKwhForDay(ten), closeTo(.24, .00001));
    expect(c.popUsageSessions.keys, ['fan:1:2026-11-10']);
    expect(c.popUsageSplits.keys, ['fan:1:2026-11-10']);
    expect(c.appliances.length, 1);
    await transfer(store, other);
    expect(
        (await SqliteDailyUsageRepository(other.db).list()).single.date, ten);
    expect((await other.db.query('appliances')).length, 1);
    expect((await other.db.query('pop_usage_sessions')).single['usage_date'],
        '2026-11-10');
    c.dispose();
    await store.db.close();
    await other.db.close();
  });
}
