import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wattwise/app/app_controller.dart';
import 'package:wattwise/app/wattwise_app.dart';
import 'package:wattwise/shared/storage/memory_repositories.dart';
import 'package:wattwise/shared/models/appliance.dart';
import 'package:wattwise/shared/models/bill.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<AppController> controller({bool populated = true}) async {
    final c = AppController(
        applianceRepository: MemoryApplianceRepository(),
        billRepository: MemoryBillRepository());
    if (populated) {
      for (final a in [
        const Appliance(
            id: '1',
            name: 'Air Conditioner',
            watts: 1500,
            hoursPerDay: 2,
            daysPerMonth: 30),
        const Appliance(
            id: '2',
            name: 'Refrigerator',
            watts: 120,
            hoursPerDay: 8,
            daysPerMonth: 30),
        const Appliance(
            id: '3',
            name: 'Lights',
            watts: 10,
            hoursPerDay: 6,
            daysPerMonth: 30),
      ]) {
        await c.saveAppliance(a);
      }
      await c.saveBill(Bill(
          id: 'b1',
          periodEnd: DateTime(2026, 10, 31),
          dueDate: DateTime(2026, 11, 17),
          consumptionKwh: 124.5,
          totalAmount: 1988,
          reviewed: true,
          charges: const [
            BillCharge(
                name: 'Generation',
                amount: 1100,
                explanation: 'Cost to produce electricity.'),
            BillCharge(
                name: 'Transmission',
                amount: 130,
                explanation: 'High-voltage transport.'),
            BillCharge(
                name: 'System Loss',
                amount: 145,
                explanation: 'Electricity lost in the grid.'),
            BillCharge(
                name: 'Distribution (Meralco)',
                amount: 200,
                explanation: 'Local delivery and network.'),
            BillCharge(
                name: 'Government Taxes',
                amount: 413,
                explanation: 'Taxes listed on your bill.'),
          ]));
    }
    return c;
  }

  Future<void> setup(WidgetTester tester, AppController c, GlobalKey key,
      {double width = 393, double textScale = 1}) async {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 12);
    addTearDown(tester.view.reset);
    final loader = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await loader.load();
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
        RepaintBoundary(key: key, child: WattWiseApp(controller: c)));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'All tabs render, settings update, and Figma reference previews export',
      (tester) async {
    final c = await controller();
    final key = GlobalKey();
    await setup(tester, c, key);
    for (final tab in ['Dashboard', 'Scan Bill', 'Mira', 'Settings']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/previews').create(recursive: true);
        await File(
                'build/previews/${tab.toLowerCase().replaceAll(' ', '_')}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(c.dark, isTrue);
    await tester.tap(find.text('Filipino'));
    await tester.pumpAndSettle();
    expect(c.language, 'fil');
    expect(find.text('Mga Setting'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('Tabs support narrow screens and larger text', (tester) async {
    final c = await controller();
    await setup(tester, c, GlobalKey(), width: 320, textScale: 1.5);
    for (final tab in ['Dashboard', 'Scan Bill', 'Mira', 'Settings']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await c.preference('language', 'fil');
    await c.preference('dark', 'true');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('Appliance validation and save update the dashboard',
      (tester) async {
    final c = await controller(populated: false);
    await setup(tester, c, GlobalKey(), width: 320);
    await tester.tap(find.text('Add Appliance').first);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Electric Fan');
    await tester.enterText(fields.at(1), '60');
    await tester.enterText(fields.at(2), '25');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Add Appliance');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(c.appliances, isEmpty);
    expect(find.text('Enter a valid number up to 24.0'), findsOneWidget);
    await tester.enterText(fields.at(2), '8');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(c.appliances.single.monthlyKwh, closeTo(14.4, 1e-9));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
