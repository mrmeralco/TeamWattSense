import 'package:wattwise/features/auth/screens/auth_request_guard.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wattwise/features/auth/screens/auth_screen.dart';
import 'account_test.dart' show FakeAuth;

void main() {
  setUp(() {
    AuthRequestGuard.testReserve = (_) async {};
  });
  tearDown(() {
    AuthRequestGuard.testReserve = null;
    registrationInProgress = false;
  });
  testWidgets(
      'Figma account screens render, show passwords, and support smaller screens',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 14);
    addTearDown(tester.view.reset);
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
    final key = GlobalKey();
    await tester.pumpWidget(
        RepaintBoundary(key: key, child: AuthScreen(auth: FakeAuth())));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/figma/auth_brand.png'),
        tester.element(find.byType(AuthScreen))));
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final shot = await boundary.toImage(pixelRatio: 1);
        final data = await shot.toByteData(format: ui.ImageByteFormat.png);

        final file = File(
            'C:/Users/ASUS/Documents/Codex/2026-11-12/referenced-chatgpt-conversation-this-is-an/outputs/previews/auth_$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
      });
    }

    await capture('login');
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/figma/auth_brand.png'),
        tester.element(find.byType(AuthScreen))));
    await tester.pumpAndSettle();
    await capture('register');
    await tester.enterText(
        find.byKey(const ValueKey('Password')), 'testing123');
    await tester.tap(find.text('Show').first);
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/figma/auth_brand.png'),
        tester.element(find.byType(AuthScreen))));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.descendant(
                of: find.byKey(const ValueKey('Password')),
                matching: find.byType(TextField)))
            .obscureText,
        false);
    await tester.ensureVisible(find.text('Log in'));
    await tester.tap(find.text('Log in'));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/figma/auth_brand.png'),
        tester.element(find.byType(AuthScreen))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/figma/auth_brand.png'),
        tester.element(find.byType(AuthScreen))));
    await tester.pumpAndSettle();
    await capture('reset');
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/figma/auth_brand.png'),
        tester.element(find.byType(AuthScreen))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Back to log in'));
    await tester.tap(find.text('Back to log in'));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/figma/auth_brand.png'),
        tester.element(find.byType(AuthScreen))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create an account'));
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/figma/auth_brand.png'),
        tester.element(find.byType(AuthScreen))));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    expect(tester.takeException(), isNull);
  });
}
