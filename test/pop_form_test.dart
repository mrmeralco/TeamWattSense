import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wattwise/app/app_controller.dart';
import 'package:wattwise/shared/storage/memory_repositories.dart';
import 'package:wattwise/features/dashboard/screens/appliance_form.dart';
import 'cloud_sync_test.dart' show device;

void main() {
  testWidgets('Enabling POP today immediately shows both time fields',
      (tester) async {
    final store = (await tester.runAsync(device))!;
    final c = AppController(
        applianceRepository: MemoryApplianceRepository(),
        billRepository: MemoryBillRepository(),
        database: store.db);
    await tester.runAsync(() => c.schedulePopChange(false, effectiveDate: DateTime.now().add(const Duration(days: 1))));
    await tester.runAsync(() => c.schedulePopChange(true));
    expect(c.popForDate(DateTime.now()), true);
    expect(c.popForDate(DateTime.now().add(const Duration(days: 1))), true);
    await tester.pumpWidget(MaterialApp(home: ApplianceForm(controller: c)));
    await tester.pumpAndSettle();
    expect(find.text('Time turned on'), findsOneWidget);
    expect(find.text('Time turned off'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => c.schedulePopChange(false));
    expect(c.popForDate(DateTime.now()), false);
    await tester.pumpWidget(MaterialApp(home: ApplianceForm(controller: c)));
    await tester.pumpAndSettle();
    expect(find.text('Time turned on'), findsNothing);
    expect(find.text('Hours used per day'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.runAsync(store.db.close);
  });
  test('Weekday and Sunday boundaries are persisted and restored', () async {
    final store = await device();
    await store.initialize();
    final c = AppController(
        applianceRepository: MemoryApplianceRepository(),
        billRepository: MemoryBillRepository(),
        database: store.db);
    final weekday = DateTime(2026, 11, 12);
    await c.savePopUsageSession(
        'fan', weekday, DateTime(2026, 11, 12, 20), DateTime(2026, 11, 12, 22));
    final sunday = DateTime(2026, 11, 15);
    await c.savePopUsageSession(
        'fan', sunday, DateTime(2026, 11, 15, 17), DateTime(2026, 11, 15, 21));
    await c.load();
    expect(c.popUsageSplits['fan:2026-11-12'], {'peak': 1.0, 'offPeak': 1.0});
    expect(c.popUsageSplits['fan:2026-11-15'], {'peak': 2.0, 'offPeak': 2.0});
    expect(c.popUsageSessions.length, 2);
    expect(
        (await store.pending())
            .where((r) => r.table == 'pop_usage_split')
            .length,
        2);
    await expectLater(
        c.savePopUsageSession('fan', weekday, DateTime(2026, 11, 12, 22),
            DateTime(2026, 11, 12, 20)),
        throwsArgumentError);
    c.dispose();
    await store.db.close();
  });
}
