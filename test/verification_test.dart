import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wattwise/features/auth/screens/auth_gate.dart';
import 'package:wattwise/features/auth/screens/legal_consent.dart';

class TestUser implements User {
  TestUser(this.uid);
  @override
  final String uid;
  @override
  String get email => 'person@example.com';
  @override
  bool emailVerified = false;
  int sent = 0, reloads = 0;
  bool verifiedOnReload = false;
  late void Function() changed;
  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    sent++;
  }

  @override
  Future<void> reload() async {
    reloads++;
    emailVerified = verifiedOnReload;
    changed();
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'test-token';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestAuth implements FirebaseAuth {
  TestAuth(this.currentUser) {
    currentUser!.changed = () => changes.add(currentUser);
  }
  @override
  TestUser? currentUser;
  final changes = StreamController<User?>.broadcast();
  @override
  Stream<User?> userChanges() async* {
    yield currentUser;
    yield* changes.stream;
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    changes.add(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'Unverified users cannot open workspace; verified reload unlocks it',
      (tester) async {
    final user = TestUser('verify-test');
    final auth = TestAuth(user);
    var opened = 0;
    await tester.pumpWidget(AuthSessionGate(
        auth: auth,
        workspaceBuilder: (_) {
          opened++;
          return const MaterialApp(home: Text('Private workspace'));
        }));
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(user.sent, 1);
    expect(find.textContaining('Resend in'), findsOneWidget);
    await tester.tap(find.text('I verified my email'));
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(find.textContaining('Not verified yet'), findsOneWidget);
    user.verifiedOnReload = true;
    await tester.tap(find.text('I verified my email'));
    await tester.pumpAndSettle();
    expect(find.text('Private workspace'), findsOneWidget);
    expect(opened, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    await auth.changes.close();
  });
  testWidgets('Verification sign out returns to login without workspace',
      (tester) async {
    final auth = TestAuth(TestUser('sign-out-test'));
    await tester.pumpWidget(AuthSessionGate(
        auth: auth,
        workspaceBuilder: (_) => throw StateError('Must remain gated')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use another email / Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await auth.changes.close();
  });
  test(
      'Consent receipt stores version and UTC time only in its account database',
      () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
        'CREATE TABLE preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await savePolicyAcceptance(db);
    final rows = await db.query('preferences');
    expect(
        rows.singleWhere((r) => r['key'] == 'accepted_policy_version')['value'],
        policyVersion);
    expect(
        DateTime.parse(rows.singleWhere(
                (r) => r['key'] == 'accepted_policy_at')['value'] as String)
            .isUtc,
        true);
    await db.close();
  });
}
