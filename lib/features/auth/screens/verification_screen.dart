import 'auth_request_guard.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../shared/theme/wattwise_theme.dart';
import 'auth_screen.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key, required this.auth});
  final FirebaseAuth auth;
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with WidgetsBindingObserver {
  bool busy = false;
  String message = 'Verify your email before accessing WattWise.';
  static final sentAt = <String, DateTime>{};
  Timer? timer;
  int get remaining {
    final last = sentAt[widget.auth.currentUser?.uid];
    return last == null
        ? 0
        : (60 - DateTime.now().difference(last).inSeconds).clamp(0, 60);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    unawaited(send());
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(check());
  }

  Future<void> send() async {
    if (busy || remaining > 0) return;
    final user = widget.auth.currentUser;
    if (user == null) return;
    setState(() => busy = true);
    sentAt[user.uid] = DateTime.now();
    try {
      await AuthRequestGuard.reserve('verify_send');
      await user.sendEmailVerification();
      if (mounted) {
        setState(() => message =
            'Verification link sent. Check your inbox and spam folder, open the link, then return here.');
      }
    } on AuthRequestLimit catch (e) {
      if (mounted) setState(() => message = e.message);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => message = authErrorMessage(e));
    } catch (_) {
      if (mounted) {
        setState(() =>
            message = 'Could not send the verification email. Please retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> check() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await AuthRequestGuard.reserve('verify_check');
      await widget.auth.currentUser?.reload();
      final user = widget.auth.currentUser;
      if (user?.emailVerified == true) {
        await user!.getIdToken(true);
      } else if (mounted) {
        setState(() => message =
            'Not verified yet. Open the link in your email, then tap “I verified my email”.');
      }
    } on AuthRequestLimit catch (e) {
      if (mounted) setState(() => message = e.message);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => message = authErrorMessage(e));
    } catch (_) {
      if (mounted) {
        setState(() => message =
            'Could not check verification. Connect to the internet and retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      theme: wattwiseTheme(false),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
          body: SafeArea(
              child: Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.mark_email_unread_outlined,
                                size: 56, color: green),
                            const SizedBox(height: 24),
                            const Text('Verify your WattWise email',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: green)),
                            const SizedBox(height: 12),
                            Text(widget.auth.currentUser?.email ?? '',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            Semantics(
                                liveRegion: true,
                                child:
                                    Text(message, textAlign: TextAlign.center)),
                            const SizedBox(height: 24),
                            FilledButton(
                                onPressed: busy ? null : check,
                                child: const Text('I verified my email')),
                            TextButton(
                                onPressed: busy || remaining > 0 ? null : send,
                                child: Text(remaining > 0
                                    ? 'Resend in ${remaining}s'
                                    : 'Resend verification email')),
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        try {
                                          await widget.auth.signOut();
                                        } catch (_) {
                                          if (mounted) {
                                            setState(() => message =
                                                'Could not sign out. Please retry.');
                                          }
                                        }
                                      },
                                child:
                                    const Text('Use another email / Sign out')),
                          ])))))));
}
