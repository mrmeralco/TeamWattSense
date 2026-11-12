import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wattwise/app/app_controller.dart';
import 'package:wattwise/app/wattwise_app.dart';
import 'package:wattwise/features/dashboard/services/kload_service.dart';
import 'package:wattwise/shared/storage/memory_repositories.dart';

void main() {
  testWidgets('dashboard switches between normal and KLoad views safely',
      (tester) async {
    final controller = AppController(
      applianceRepository: MemoryApplianceRepository(),
      billRepository: MemoryBillRepository(),
    );
    await tester.pumpWidget(WattWiseApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('Set up KLoad now'), findsOneWidget);
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Set up KLoad now'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    final today = KLoadService.dateKey(DateTime.now());
    controller.kloadTransitions = [
      {'effective_date': today, 'enabled': 1},
    ];
    controller.notifyListeners();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    expect(find.text('KLoad storage is unavailable.'), findsOneWidget);

    controller.kloadTransitions = [];
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Usage Overview'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
