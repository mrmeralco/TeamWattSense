import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wattwise/features/auth/screens/auth_request_guard.dart';
import 'package:wattwise/features/auth/screens/auth_gate.dart';

class RegisteredUser implements User {
  int sent = 0;
  @override
  String get uid => 'new-user';
  @override
  String get email => 'person@example.com';
  @override
  bool get emailVerified => false;
  @override
  Future<void> updateDisplayName(String? value) async {}
  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    sent++;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class Credential implements UserCredential {
  Credential(this.user);
  @override
  final User user;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class RegisterAuth implements FirebaseAuth {
  final changes = StreamController<User?>.broadcast();
  final user = RegisteredUser();
  @override
  User? currentUser;
  @override
  Stream<User?> userChanges() async* {
    yield currentUser;
    yield* changes.stream;
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword(
      {required String email, required String password}) async {
    currentUser = user;
    changes.add(user);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return Credential(user);
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    changes.add(null);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('Registration password checks each required component', () {
    for (final bad in [
      'Ab1!short',
      'abcdefgh1!',
      'Abcdefghij!',
      'Abcdefghi1',
      'Abcdefgh1 '
    ]) {
      expect(registrationPasswordError(bad), isNotNull);
    }
    expect(registrationPasswordError('Abcdefgh1!'), isNull);
  });
  test(
      'Persisted rate counters include failures and limit repeated registration/email attempts',
      () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
        'CREATE TABLE request_limits(action TEXT PRIMARY KEY,started INTEGER NOT NULL,last INTEGER NOT NULL,count INTEGER NOT NULL)');
    final now = DateTime(2026, 11, 12, 12);
    await AuthRequestGuard.reserveIn(db, 'register', now);
    await expectLater(
        AuthRequestGuard.reserveIn(
            db, 'register', now.add(const Duration(seconds: 1))),
        throwsA(isA<AuthRequestLimit>()));
    await AuthRequestGuard.reserveIn(
        db, 'register', now.add(const Duration(minutes: 1)));
    await AuthRequestGuard.reserveIn(
        db, 'register', now.add(const Duration(minutes: 2)));
    await expectLater(
        AuthRequestGuard.reserveIn(
            db, 'register', now.add(const Duration(minutes: 3))),
        throwsA(isA<AuthRequestLimit>()));
    await AuthRequestGuard.reserveIn(
        db, 'register', now.add(const Duration(hours: 1)));
    for (final action in ['reset', 'verify_send']) {
      for (var i = 0; i < 5; i++) {
        await AuthRequestGuard.reserveIn(
            db, action, now.add(Duration(minutes: i)));
      }
      await expectLater(
          AuthRequestGuard.reserveIn(
              db, action, now.add(const Duration(minutes: 6))),
          throwsA(isA<AuthRequestLimit>()));
    }
    await db.close();
  });
  testWidgets(
      'Successful registration sends verification, signs out and shows login popup',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    AuthRequestGuard.testReserve = (_) async {};
    addTearDown(() {
      AuthRequestGuard.testReserve = null;
      registrationInProgress = false;
    });
    final auth = RegisterAuth();
    await tester.pumpWidget(AuthSessionGate(
        auth: auth,
        workspaceBuilder: (_) =>
            throw StateError('Unverified user entered workspace')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    final values = [
      'Test Person',
      'person@example.com',
      'Abcdefgh1!',
      'Abcdefgh1!'
    ];
    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byType(TextFormField).at(i), values[i]);
    }
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.byType(CheckboxListTile).at(i));
      await tester.tap(find.byType(CheckboxListTile).at(i));
      await tester.pump();
    }
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Account created'), findsOneWidget);
    expect(find.textContaining('Try logging in and verifying'), findsOneWidget);
    expect(auth.currentUser, isNull);
    expect(auth.user.sent, 1);
    await tester.tap(find.text('Go to log in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await auth.changes.close();
  });
}
