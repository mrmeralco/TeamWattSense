import 'auth_request_guard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/sync/cloud_sync.dart';
import '../../../shared/sync/sync_store.dart';
import 'verification_screen.dart';
import 'legal_consent.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../../app/app_controller.dart';
import '../../../app/wattwise_app.dart';
import '../../../shared/storage/sqlite_appliance_repository.dart';
import '../../../shared/storage/sqlite_bill_repository.dart';
import '../../../shared/firebase/ai_request_budget.dart';
import '../../mira/services/firebase_mira_service.dart';
import '../../mira/services/mira_context_provider.dart';
import 'auth_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.app});
  final FirebaseApp app;
  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instanceFor(app: app);
    return AuthSessionGate(
        auth: auth,
        workspaceBuilder: (user) => UserWorkspace(
            key: ValueKey(user.uid), app: app, auth: auth, user: user));
  }
}

class AuthSessionGate extends StatelessWidget {
  const AuthSessionGate(
      {super.key, required this.auth, required this.workspaceBuilder});
  final FirebaseAuth auth;
  final Widget Function(User) workspaceBuilder;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
        stream: auth.userChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MaterialApp(
                home:
                    Scaffold(body: Center(child: CircularProgressIndicator())));
          }
          if (snapshot.hasError) {
            return MaterialApp(
                home: Scaffold(
                    body: Center(
                        child: TextButton(
                            onPressed: auth.signOut,
                            child: const Text(
                                'Session unavailable. Return to sign in.')))));
          }
          final user = snapshot.data;
          if (user == null || registrationInProgress) {
            return AuthScreen(auth: auth);
          }
          if (!user.emailVerified) {
            return VerificationScreen(key: ValueKey(user.uid), auth: auth);
          }
          return workspaceBuilder(user);
        });
  }
}

class UserWorkspace extends StatefulWidget {
  const UserWorkspace(
      {super.key, required this.app, required this.auth, required this.user});
  final FirebaseApp app;
  final FirebaseAuth auth;
  final User user;
  @override
  State<UserWorkspace> createState() => _UserWorkspaceState();
}

class _UserWorkspaceState extends State<UserWorkspace> {
  AppController? controller;
  SqliteApplianceRepository? repository;
  FirebaseMiraService? mira;
  String? error;
  bool signingOut = false;
  bool policyAccepted = false;
  CloudSync? cloudSync;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final repo =
          await SqliteApplianceRepository.open(userId: widget.user.uid);
      if (!mounted) {
        await repo.close();
        return;
      }
      repository = repo;
      final bills = SqliteBillRepository(repo.database);
      final daily = SqliteDailyUsageRepository(repo.database);
      final c = AppController(
          applianceRepository: repo,
          billRepository: bills,
          dailyUsageRepository: daily,
          database: repo.database);
      await c.load();
      final email = widget.user.email?.trim().toLowerCase();
      if (email != null && pendingPolicyEmails.contains(email)) {
        await savePolicyAcceptance(repo.database);
        pendingPolicyEmails.remove(email);
      }
      final receipt = await repo.database.query('preferences',
          where: 'key = ?', whereArgs: ['accepted_policy_version']);
      final accepted =
          receipt.isNotEmpty && receipt.first['value'] == policyVersion;
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        controller = c;
        policyAccepted = accepted;
        mira = FirebaseMiraService(
            widget.app,
            MiraContextProvider(repo, bills, daily),
            AiRequestBudget(repo.database));
      });
      if (accepted) await startSync();
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Could not open your account data. Your saved data has not been replaced.');
      }
    }
  }

  Future<void> startSync() async {
    if (!mounted || cloudSync != null || controller == null) return;
    final c = controller!;
    final service = CloudSync(
        store: SyncStore(repository!.database),
        firestore: FirebaseFirestore.instanceFor(app: widget.app),
        auth: widget.auth,
        uid: widget.user.uid,
        onChanged: () async {
          if (mounted) await c.load();
        },
        onStatus: (status) {
          if (mounted) c.setCloudSyncStatus(status);
        });
    cloudSync = service;
    try {
      await service.start();
      if (!mounted) return;
      c.syncNow = service.sync;
      c.onLocalChange = () {
        unawaited(service.sync());
      };
    } catch (_) {
      if (mounted) {
        c.setCloudSyncStatus(
            'Cloud sync could not start. Your local records are safe. Reopen the app to retry.');
      }
    }
  }

  Future<void> signOut() async {
    if (signingOut) return;
    setState(() => signingOut = true);
    try {
      controller?.onLocalChange = null;
      await cloudSync?.stop();
      cloudSync = null;
      await widget.auth.signOut();
    } catch (_) {
      if (mounted) {
        setState(() {
          signingOut = false;
          error = 'Could not sign out. Please retry.';
          unawaited(startSync());
        });
      }
    }
  }

  @override
  void dispose() {
    controller?.onLocalChange = null;
    controller?.dispose();
    final repo = repository;
    final service = cloudSync;
    unawaited(() async {
      await service?.stop();
      if (repo != null) await repo.close();
    }());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (signingOut) {
      return const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    if (error != null) {
      return MaterialApp(
          home: Scaffold(
              body: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error!),
        TextButton(onPressed: signOut, child: const Text('Sign out'))
      ]))));
    }
    if (controller == null) {
      return const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    if (!policyAccepted) {
      return PolicyConsentScreen(
          database: repository!.database,
          onAccepted: () {
            setState(() => policyAccepted = true);
            unawaited(startSync());
          },
          onSignOut: signOut);
    }
    return WattWiseApp(
        controller: controller!,
        mira: mira,
        accountEmail: widget.user.email,
        onSignOut: signOut);
  }
}
