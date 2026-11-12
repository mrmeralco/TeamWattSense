import 'cloud_sync_test.dart' show device;
import 'dart:convert';
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

void main(){
  Future<AppController> controller({bool populated = true}) async {
    final store = await device();
    final c = AppController(database: store.db,
        applianceRepository: MemoryApplianceRepository(),
        billRepository: MemoryBillRepository(), dailyUsageRepository: MemoryDailyUsageRepository());
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


 testWidgets('Record real app operations', (tester) async {
 final c=(await tester.runAsync(controller))!;final key=GlobalKey();await setup(tester,c,key);
 final shots=<Map<String,Object>>[];var index=0;
 Future<void> shot(String title,String detail,{double? x,double? y}) async {
 await tester.pump(const Duration(milliseconds:120));
 await tester.runAsync(() async {final image=await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio:2);final bytes=await image.toByteData(format:ui.ImageByteFormat.png);await Directory('build/walkthrough').create(recursive:true);await File('build/walkthrough/${index.toString().padLeft(3,'0')}.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();});
 shots.add({'file':'${index.toString().padLeft(3,'0')}.png','title':title,'detail':detail,'x':x??-1,'y':y??-1});index++;
 }
 Future<void> tap(Finder finder,String title,String detail) async {await tester.ensureVisible(finder);await tester.pumpAndSettle();final p=tester.getCenter(finder);await shot(title,detail,x:p.dx,y:p.dy);await tester.tap(finder);await tester.pump();await tester.runAsync(() async {await Future<void>.delayed(const Duration(milliseconds:500));});await tester.pumpAndSettle();await shot(title,detail);}
 await shot('Start on Dashboard','This is the actual WattWise app, operated with isolated sample data.');
 await tap(find.text('Add Appliance').first,'Add an appliance','Open the normal appliance form.');
 final fields=find.byType(TextFormField);
 for(final entry in [(0,'Electric Fan'),(1,'60'),(2,'8')]) {
 final value=entry.$2;for(var n=1;n<=value.length;n++){await tester.enterText(fields.at(entry.$1),value.substring(0,n));await tester.pump(const Duration(milliseconds:150));await shot('Enter appliance details','Electric Fan • 60 watts • 8 hours today');}
 }
 tester.testTextInput.hide();await tester.pumpAndSettle();
 await tap(find.widgetWithText(FilledButton,'Add Appliance'),'Save today’s usage','Save the appliance and its dated usage entry.');
 expect(c.dailyUsages,isNotEmpty);
 await shot('See the result','The dashboard now includes the recorded appliance usage.');
 await tap(find.text('Scan Bill').last,'Review a bill','Open a preloaded sample bill. This does not simulate a live scan.');
 await tester.drag(find.byType(ListView).first,const Offset(0,-260));await tester.pumpAndSettle();await shot('Read the breakdown','Scroll through the bill details and explanations.');
 await tap(find.text('Mira').last,'Ask Mira','Open the assistant using your saved appliance and bill context.');
 final chat=find.byType(TextField).last;
 for(final text in ['How','How can I','How can I reduce','How can I reduce my fan usage?']) {await tester.enterText(chat,text);await tester.pump();await shot('Compose a question','Typing a real question. It is not sent in this offline demonstration.');}
 tester.testTextInput.hide();await tester.pumpAndSettle();
 await tap(find.text('Settings').last,'Personalize WattWise','Open language, appearance, and energy-program settings.');
 await tester.ensureVisible(find.text('Dark'));await tester.pumpAndSettle();await tap(find.text('Dark'),'Switch to dark mode','The app immediately updates its appearance.');
 await tap(find.text('Light'),'Return to light mode','Choose the appearance you prefer.');

 await tap(find.byType(Switch).at(1),'Enable POP estimates','Only enable this if already enrolled with Meralco. The switch does not enroll you.');
 await tap(find.widgetWithText(FilledButton,'Confirm'),'Confirm POP mode','POP estimates use appliance start and stop times.');
 await tap(find.text('Dashboard').last,'Record POP usage','Open an appliance to enter its timed usage.');
 await tap(find.text('Electric Fan').first,'POP appliance form','Use Time turned on and Time turned off to split peak and off-peak usage.');
 await shot('Peak and off-peak timing','The actual appliance form now includes both time fields.');
 await tester.tap(find.byType(IconButton).first);await tester.pumpAndSettle();
 await tap(find.text('Settings').last,'Set up KLoad','KLoad is a separate prepaid balance view.');
 await tap(find.byType(Switch).first,'Activate KLoad','Enter the current load balance and your applicable rate.');
 await tester.enterText(find.byType(TextFormField).at(0),'500');await shot('Starting balance','Enter a sample balance of 500 pesos.');
 await tester.enterText(find.byType(TextFormField).at(1),'12');tester.testTextInput.hide();await tester.pumpAndSettle();await shot('Set your rate','12 pesos per kWh is an illustrative rate, not a current tariff.');
 await tap(find.widgetWithText(FilledButton,'Activate now'),'Start KLoad mode','Activate the separate prepaid dashboard.');
 await tap(find.text('Dashboard').last,'KLoad dashboard','See the estimated balance and recorded appliance usage.');
 await tester.drag(find.byType(ListView).first,const Offset(0,-600));await tester.pumpAndSettle();
 await tap(find.text('Add top-up'),'Record a top-up','Log a load purchase to update the estimate.');
 await tester.enterText(find.byType(TextFormField).first,'100');tester.testTextInput.hide();await tester.pumpAndSettle();await shot('Enter top-up amount','Record a sample 100-peso top-up.');
 await tap(find.widgetWithText(FilledButton,'Save'),'Save top-up','The estimated balance reflects the saved top-up.');
 await shot('KLoad updated','These estimates depend on your entered usage and rate.');
 await tester.runAsync(() async {await File('build/walkthrough/steps.json').writeAsString(jsonEncode(shots));});
 await tester.pumpWidget(const SizedBox());c.dispose();
 });
}



