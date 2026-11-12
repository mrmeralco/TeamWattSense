import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wattwise/app/app_controller.dart';
import 'package:wattwise/shared/storage/memory_repositories.dart';
import 'package:wattwise/shared/models/appliance.dart';
import 'package:wattwise/features/mira/services/mira_appliance_action.dart';
import 'package:wattwise/features/mira/screens/mira_appliance_review.dart';

void main() {
  const fan = Appliance(
      id: 'fan',
      name: 'Fan',
      watts: 60,
      hoursPerDay: 8,
      daysPerMonth: 30,
      quantity: 2);
  test(
      'Edit uses exact ID and preserves unspecified details; additions leave missing fields blank',
      () {
    final edit = MiraApplianceAction.parse(
        {'mode': 'edit', 'applianceId': 'fan', 'quantity': 3.0}, [fan]);
    expect(edit.values['quantity'], 3);
    expect(edit.values['watts'], 60);
    expect(edit.original, fan);
    final defaults = MiraApplianceAction.parse(
        {'mode': 'add', 'name': 'Fan', 'days_per_month': 7}, []);
    expect(defaults.values['days_per_month'], 30);
    expect(defaults.values['quantity'], 1);
    const old = Appliance(
        id: 'old', name: 'Fan', watts: 60, hoursPerDay: 8, daysPerMonth: 15);
    expect(
        MiraApplianceAction.parse(
            {'mode': 'edit', 'applianceId': 'old', 'days_per_month': 7},
            [old]).values['days_per_month'],
        15);
    expect(
        MiraApplianceAction.parse({'mode': 'add', 'name': 'Fan'}, [])
            .values
            .containsKey('watts'),
        false);
    expect(
        () => MiraApplianceAction.parse(
            {'mode': 'edit', 'applianceId': 'missing'}, [fan]),
        throwsFormatException);
    expect(() => MiraApplianceAction.parse({'mode': 'delete'}, [fan]),
        throwsFormatException);
    expect(
        () => MiraApplianceAction.parse({'mode': 'add', 'quantity': 1.5}, []),
        throwsFormatException);
    expect(
        () =>
            MiraApplianceAction.parse({'mode': 'add', 'watts': double.nan}, []),
        throwsFormatException);
    expect(
        () =>
            MiraApplianceAction.parse({'mode': 'add', 'hours_per_day': 25}, []),
        throwsFormatException);
  });
  Future<void> open(
      WidgetTester tester, AppController c, MiraApplianceAction a) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<String>(
                        context: context,
                        builder: (_) =>
                            MiraApplianceReview(action: a, controller: c)),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Cancel does not write; Save adds once and refreshes controller',
      (tester) async {
    final c = AppController(
        applianceRepository: MemoryApplianceRepository(),
        billRepository: MemoryBillRepository());
    final action = MiraApplianceAction.parse({
      'mode': 'add',
      'name': 'Fan',
      'watts': 60,
      'hours_per_day': 8,
      'quantity': 2
    }, []);
    await open(tester, c, action);
    expect(find.text('Days per month'), findsNothing);
    expect(await c.applianceRepository.list(), isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(c.appliances, isEmpty);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save appliance'));
    await tester.pumpAndSettle();
    expect(c.appliances.length, 1);
    expect(c.appliances.single.quantity, 2);
    expect(c.appliances.single.daysPerMonth, 30);
    expect((await c.applianceRepository.list()).length, 1);
    expect(c.dailyUsages, isEmpty);
  });
  testWidgets(
      'Edit saves existing ID; stale edit cannot overwrite changed values',
      (tester) async {
    final c = AppController(
        applianceRepository: MemoryApplianceRepository(),
        billRepository: MemoryBillRepository());
    await c.saveAppliance(fan);
    var action = MiraApplianceAction.parse(
        {'mode': 'edit', 'applianceId': 'fan', 'quantity': 3}, [fan]);
    await open(tester, c, action);
    await tester.tap(find.text('Save appliance'));
    await tester.pumpAndSettle();
    expect(c.appliances.single.id, 'fan');
    expect(c.appliances.single.quantity, 3);
    action = MiraApplianceAction.parse(
        {'mode': 'edit', 'applianceId': 'fan', 'quantity': 4}, [fan]);
    await open(tester, c, action);
    await tester.tap(find.text('Save appliance'));
    await tester.pumpAndSettle();
    expect(find.textContaining('changed after Mira read it'), findsOneWidget);
    expect(c.appliances.single.quantity, 3);
  });
}
