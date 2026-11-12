import 'package:wattwise/features/auth/screens/auth_request_guard.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wattwise/features/auth/screens/auth_screen.dart';
import 'package:wattwise/shared/storage/sqlite_appliance_repository.dart';
import 'package:wattwise/shared/storage/sqlite_bill_repository.dart';
import 'package:wattwise/shared/models/appliance.dart';
import 'package:wattwise/shared/models/bill.dart';
import 'package:wattwise/shared/models/daily_usage.dart';

class FakeAuth implements FirebaseAuth {
  final calls = <String>[];
  @override
  Future<UserCredential> signInWithEmailAndPassword(
      {required String email, required String password}) async {
    calls.add('login:$email');
    throw FirebaseAuthException(code: 'invalid-credential');
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword(
      {required String email, required String password}) async {
    calls.add('register:$email');
    throw FirebaseAuthException(code: 'email-already-in-use');
  }

  @override
  Future<void> sendPasswordResetEmail(
      {required String email, ActionCodeSettings? actionCodeSettings}) async {
    calls.add('reset:$email');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    AuthRequestGuard.testReserve = (_) async {};
  });
  tearDown(() {
    AuthRequestGuard.testReserve = null;
    registrationInProgress = false;
  });
  test(
      'Account databases isolate appliances bills logs preferences and preserve legacy data',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final temp = await Directory.systemTemp.createTemp('wattwise-accounts-');
    await databaseFactory.setDatabasesPath(temp.path);
    final legacy = await SqliteApplianceRepository.open();
    const appliance = Appliance(
        id: 'same-id',
        name: 'Fan',
        watts: 60,
        hoursPerDay: 8,
        daysPerMonth: 30);
    await legacy.save(appliance);
    final a = await SqliteApplianceRepository.open(userId: 'user-A');
    final b = await SqliteApplianceRepository.open(userId: 'user-B');
    expect(await a.list(), isEmpty);
    expect(await b.list(), isEmpty);
    await a.save(appliance);
    await SqliteBillRepository(a.database).save(Bill(
        id: 'bill',
        periodEnd: DateTime(2026, 11, 1),
        dueDate: DateTime(2026, 11, 20),
        consumptionKwh: 10,
        totalAmount: 120,
        charges: [],
        reviewed: true));
    await SqliteDailyUsageRepository(a.database).saveAll([
      DailyUsage(
          applianceId: 'same-id',
          date: DateTime(2026, 11, 1),
          hours: 2,
          watts: 60,
          quantity: 1)
    ]);
    await a.database.insert('preferences', {'key': 'language', 'value': 'fil'});
    expect(await b.list(), isEmpty);
    expect(await SqliteBillRepository(b.database).list(), isEmpty);
    expect(await SqliteDailyUsageRepository(b.database).list(), isEmpty);
    expect(await b.database.query('preferences'), isEmpty);
    await a.close();
    final reopened = await SqliteApplianceRepository.open(userId: 'user-A');
    expect((await reopened.list()).single.name, 'Fan');
    expect(
        (await SqliteBillRepository(reopened.database).list())
            .single
            .totalAmount,
        120);
    expect((await legacy.list()).single.name, 'Fan');
    expect(SqliteApplianceRepository.databaseNameForUser('../user'),
        isNot(contains('/')));
    expect(() => SqliteApplianceRepository.databaseNameForUser(''),
        throwsArgumentError);
    await reopened.close();
    await b.close();
    await legacy.close();
    await temp.delete(recursive: true);
  });
  testWidgets(
      'Login registration and password reset validate and call Firebase',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuth();
    await tester.pumpWidget(AuthScreen(auth: auth));
    await tester.enterText(
        find.byType(TextFormField).at(0), 'person@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
    expect(auth.calls, isEmpty);
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.byType(CheckboxListTile).at(i));
      await tester.tap(find.byType(CheckboxListTile).at(i));
      await tester.pump();
    }
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Log in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
    expect(auth.calls, ['login:person@example.com']);
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Test Person');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'person@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');
    await tester.enterText(find.byType(TextFormField).at(3), 'different');
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.byType(CheckboxListTile).at(i));
      await tester.tap(find.byType(CheckboxListTile).at(i));
      await tester.pump();
    }
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(auth.calls.length, 1);
    await tester.enterText(find.byType(TextFormField).at(3), 'Password123!');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(auth.calls.last, 'register:person@example.com');
    await tester.ensureVisible(find.text('Log in'));
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'person@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pumpAndSettle();
    expect(auth.calls.last, 'reset:person@example.com');
    expect(find.textContaining('If this email has an account'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pumpAndSettle();
    expect(auth.calls.where((c) => c.startsWith('reset')).length, 1);
  });
}
