import 'package:flutter_test/flutter_test.dart';
import 'package:wattwise/app/app_controller.dart';
import 'package:wattwise/shared/storage/memory_repositories.dart';
import 'cloud_sync_test.dart' show device;

void main() {
  test('Enabling either program disables the other and survives reload',
      () async {
    final store = await device();
    await store.initialize();
    final c = AppController(
        applianceRepository: MemoryApplianceRepository(),
        billRepository: MemoryBillRepository(),
        database: store.db);
    final old = DateTime.now().subtract(const Duration(days: 2));
    await c.schedulePopChange(true, effectiveDate: old);
    await c.scheduleKLoadActivation(startingBalance: 500, rate: 12);
    expect(c.kloadSwitchValue, isTrue);
    expect(c.popSwitchValue, isFalse);
    expect(c.popForDate(old), isTrue);
    await c.load();
    expect(c.popSwitchValue, isFalse);
    expect(c.kloadSwitchValue, isTrue);
    await c.schedulePopChange(true);
    expect(c.popSwitchValue, isTrue);
    expect(c.kloadSwitchValue, isFalse);
    await c.load();
    expect(c.popSwitchValue, isTrue);
    expect(c.kloadSwitchValue, isFalse);
    expect(await store.db.query('kload_balance_events'), isNotEmpty);
    await c.scheduleKLoadActivation(startingBalance: 500, rate: 12);
    expect(c.popSwitchValue, isFalse);
    expect(c.kloadSwitchValue, isTrue);
    expect(await store.pending(), isNotEmpty);
    c.dispose();
    await store.db.close();
  });
}
