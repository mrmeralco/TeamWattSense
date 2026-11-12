import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wattwise/app/app_controller.dart';
import 'package:wattwise/features/dashboard/screens/dashboard_screen.dart';
import 'package:wattwise/shared/models/appliance.dart';
import 'package:wattwise/shared/models/daily_usage.dart';
import 'package:wattwise/shared/storage/memory_repositories.dart';

void main() {
  testWidgets('weekly chart keeps Tuesday and Wednesday in separate buckets',
      (tester) async {
    final usageRepository = MemoryDailyUsageRepository();
    final controller = AppController(
      applianceRepository: MemoryApplianceRepository(),
      billRepository: MemoryBillRepository(),
      dailyUsageRepository: usageRepository,
    );
    await controller.saveAppliance(const Appliance(
      id: 'fan-1',
      name: 'Fan',
      watts: 1200,
      hoursPerDay: 1,
      daysPerMonth: 30,
    ));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    await controller.saveDailyUsages([
      DailyUsage(
        applianceId: 'fan-1',
        date: monday.add(const Duration(days: 1)),
        hours: 1,
        watts: 1200,
        quantity: 1,
      ),
      DailyUsage(
        applianceId: 'fan-1',
        date: monday.add(const Duration(days: 2)),
        hours: 2,
        watts: 1200,
        quantity: 1,
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DashboardScreen(controller: controller, onSettings: () {}),
      ),
    ));
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    final chart = tester.widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is UsagePainter,
    ));
    final buckets = (chart.painter! as UsagePainter).values;
    expect(buckets, hasLength(7));
    expect(buckets[0], isNull); // Monday has no entry.
    expect(buckets[1], closeTo(1.2, 1e-9)); // Tuesday: 1 hour × 1.2 kW.
    expect(buckets[2], closeTo(2.4, 1e-9)); // Wednesday: 2 hours × 1.2 kW.
    expect(buckets.skip(3), everyElement(isNull));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
