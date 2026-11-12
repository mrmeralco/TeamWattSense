import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wattwise/app/app_controller.dart';
import 'package:wattwise/features/dashboard/screens/dashboard_screen.dart';
import 'package:wattwise/shared/models/appliance.dart';
import 'package:wattwise/shared/models/daily_usage.dart';
import 'package:wattwise/shared/storage/memory_repositories.dart';

void main() {
  testWidgets('usage overview groups weeks, months, and years as selected',
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
    final entries = <DailyUsage>[
      DailyUsage(
        applianceId: 'fan-1',
        date: DateTime(now.year, now.month, 1),
        hours: 1,
        watts: 1200,
        quantity: 1,
      ),
      DailyUsage(
        applianceId: 'fan-1',
        date: DateTime(now.year, now.month, 8),
        hours: 2,
        watts: 1200,
        quantity: 1,
      ),
      DailyUsage(
        applianceId: 'fan-1',
        date: DateTime(now.year, 1, 15),
        hours: 3,
        watts: 1200,
        quantity: 1,
      ),
      DailyUsage(
        applianceId: 'fan-1',
        date: DateTime(2024, 1, 15),
        hours: 4,
        watts: 1200,
        quantity: 1,
      ),
      DailyUsage(
        applianceId: 'fan-1',
        date: DateTime(2025, 2, 15),
        hours: 5,
        watts: 1200,
        quantity: 1,
      ),
    ];
    await controller.saveDailyUsages(entries);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DashboardScreen(controller: controller, onSettings: () {}),
      ),
    ));

    CustomPainter chartPainter() => (tester
        .widget<CustomPaint>(find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is UsagePainter,
        ))
        .painter!);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    var chart = chartPainter() as UsagePainter;
    expect(chart.scale, 0);
    expect(chart.values[0], closeTo(1.2, 1e-9));
    expect(chart.values[1], closeTo(2.4, 1e-9));

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    chart = chartPainter() as UsagePainter;
    expect(chart.scale, 1);
    expect(chart.values, hasLength(12));
    expect(chart.values[0], closeTo(3.6, 1e-9));

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    chart = chartPainter() as UsagePainter;
    expect(chart.scale, 2);
    expect(chart.values, hasLength(now.year - 2024 + 1));
    expect(chart.values[0], closeTo(4.8, 1e-9));
    expect(chart.values[1], closeTo(6, 1e-9));
    expect(chart.values.last, closeTo(7.2, 1e-9));
    expect(find.text('2024–${now.year} • Recorded'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
