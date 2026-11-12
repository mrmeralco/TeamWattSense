import 'auth_request_guard.dart';
import 'legal_consent.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../shared/theme/wattwise_theme.dart';

String authErrorMessage(FirebaseAuthException e) => switch (e.code) {
      'invalid-email' => 'Enter a valid email address.',
      'password-does-not-meet-requirements' ||
      'weak-password' =>
        'Choose a stronger password that meets the account password policy.',
      'email-already-in-use' =>
        'Unable to register this email. Try signing in or resetting your password.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'Email or password is incorrect.',
      'network-request-failed' => 'Connect to the internet and try again.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      'user-disabled' =>
        'This account is disabled. Contact the app administrator.',
      'operation-not-allowed' =>
        'Email/password sign-in is not enabled for this project.',
      _ => 'Unable to complete this request (${e.code}). Please retry.',
    };

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});
  final FirebaseAuth auth;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final navigator = GlobalKey<NavigatorState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  String mode = 'login';
  String? message;
  bool busy = false, obscure = true, obscureConfirm = true;
  DateTime? resetSent;
  bool terms = false, privacy = false;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  void changeMode(String next) {
    setState(() {
      mode = next;
      terms = false;
      privacy = false;
      message = null;
      password.clear();
      confirm.clear();
    });
    form.currentState?.reset();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    if (mode != 'reset' && (!terms || !privacy)) {
      setState(() =>
          message = 'Please review and acknowledge both policies to continue.');
      return;
    }
    final consentEmail = email.text.trim().toLowerCase();
    if (mode != 'reset') pendingPolicyEmails.add(consentEmail);
    if (mode == 'reset' &&
        resetSent != null &&
        DateTime.now().difference(resetSent!) < const Duration(seconds: 60)) {
      setState(() =>
          message = 'Please wait a minute before requesting another email.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await AuthRequestGuard.reserve(mode);
      if (mode == 'register') {
        registrationInProgress = true;
        final displayName = name.text.trim();
        final credential = await widget.auth.createUserWithEmailAndPassword(
            email: email.text.trim(), password: password.text);
        var emailSent = false;
        try {
          await credential.user?.updateDisplayName(displayName);
          await AuthRequestGuard.reserve('verify_send');
          await credential.user?.sendEmailVerification();
          emailSent = true;
        } catch (_) {
          // The account exists even if profile update or email delivery fails.
        }
        await widget.auth.signOut();
        registrationInProgress = false;
        pendingPolicyEmails.remove(consentEmail);
        if (mounted) {
          changeMode('login');
          await showDialog<void>(
              context: navigator.currentContext!,
              builder: (dialogContext) => AlertDialog(
                    title: const Text('Account created'),
                    content: Text(emailSent
                        ? 'Try logging in and verifying your account. We sent a verification link to your email. Check your inbox or spam folder and open the link before accessing WattWise.'
                        : 'Try logging in and verifying your account. Your account was created, but the verification email could not be sent. Log in to request a verification link.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Go to log in'))
                    ],
                  ));
        }
      } else if (mode == 'reset') {
        try {
          await widget.auth.sendPasswordResetEmail(email: email.text.trim());
        } on FirebaseAuthException catch (e) {
          if (e.code != 'user-not-found') rethrow;
        }
        resetSent = DateTime.now();
        if (mounted) {
          setState(() => message =
              'If this email has an account, a password-reset link has been sent. Check your inbox and spam folder.');
        }
      } else {
        await widget.auth.signInWithEmailAndPassword(
            email: email.text.trim(), password: password.text);
      }
    } on AuthRequestLimit catch (e) {
      pendingPolicyEmails.remove(consentEmail);
      if (mounted) setState(() => message = e.message);
    } on FirebaseAuthException catch (e) {
      pendingPolicyEmails.remove(consentEmail);
      if (mounted) setState(() => message = authErrorMessage(e));
    } catch (_) {
      pendingPolicyEmails.remove(consentEmail);
      if (mounted) {
        setState(() => message = 'Unable to connect. Please try again.');
      }
    } finally {
      registrationInProgress = false;
      if (mounted) setState(() => busy = false);
    }
  }

  static const muted = Color(0xff686d6a),
      border = Color(0xffe2e5e3),
      background = Color(0xfff7f7f7);
  TextStyle type(double size, double height,
          {Color? color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(
          fontFamily: 'Inter',
          fontSize: size,
          height: height / size,
          color: color ?? const Color(0xff242827),
          fontWeight: weight);
  Widget link(String label, VoidCallback action, {double size = 13}) =>
      TextButton(
          onPressed: busy ? null : action,
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: green,
              textStyle: type(size, 20, weight: FontWeight.w600)),
          child: Text(label));
  Widget field(String label, String hint, TextEditingController input,
      {bool secret = false, bool confirmation = false}) {
    final compact = mode == 'register';
    final hidden = confirmation ? obscureConfirm : obscure;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: type(13, 18, weight: FontWeight.w500)),
      SizedBox(height: compact ? 4 : 8),
      TextFormField(
          key: ValueKey(label),
          controller: input,
          enabled: !busy,
          obscureText: secret && hidden,
          autocorrect: false,
          enableSuggestions: !secret,
          keyboardType:
              input == email ? TextInputType.emailAddress : TextInputType.text,
          textInputAction: TextInputAction.next,
          autofillHints: input == email
              ? const [AutofillHints.email]
              : input == name
                  ? const [AutofillHints.name]
                  : [
                      mode == 'register'
                          ? AutofillHints.newPassword
                          : AutofillHints.password
                    ],
          style: type(14, 20),
          decoration: InputDecoration(
              hintText: hint,
              hintStyle: type(14, 20, color: muted),
              filled: true,
              fillColor: background,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 14, vertical: compact ? 12 : 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: green)),
              errorMaxLines: 2,
              suffixIcon: secret
                  ? SizedBox(
                      width: 72,
                      child: Center(
                          child: link(
                              hidden ? 'Show' : 'Hide',
                              () => setState(() {
                                    if (confirmation) {
                                      obscureConfirm = !obscureConfirm;
                                    } else {
                                      obscure = !obscure;
                                    }
                                  }),
                              size: 12)))
                  : null,
              suffixIconConstraints: BoxConstraints(
                  minHeight: compact ? 44 : 48, maxHeight: compact ? 44 : 48)),
          validator: (v) {
            if (input == name) {
              return v == null || v.trim().isEmpty || v.trim().length > 80
                  ? 'Enter your full name (up to 80 characters)'
                  : null;
            }
            if (input == email) {
              return v == null ||
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                  ? 'Enter a valid email'
                  : null;
            }
            if (confirmation) {
              return v != password.text ? 'Passwords do not match' : null;
            }
            return v == null || v.isEmpty
                ? 'Enter your password'
                : mode == 'register'
                    ? registrationPasswordError(v)
                    : null;
          }),
    ]);
  }

  Widget get actionButton => SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
          onPressed: busy ? null : submit,
          style: FilledButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: type(14, 22, weight: FontWeight.w600)),
          child: Text(busy
              ? 'Please wait…'
              : mode == 'register'
                  ? 'Create account'
                  : mode == 'reset'
                      ? 'Send reset link'
                      : 'Log in')));
  Widget get formCard => Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.fromLTRB(15, 19, 15, mode == 'login' ? 31 : 23),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (mode == 'register') ...[
          field('Full name', 'Enter your full name', name),
          const SizedBox(height: 16)
        ],
        field('Email address', 'you@example.com', email),
        if (mode != 'reset') ...[
          SizedBox(height: mode == 'register' ? 16 : 18),
          field(
              'Password',
              mode == 'register' ? 'Create a password' : 'Enter your password',
              password,
              secret: true),
        ],
        if (mode == 'register') ...[
          const SizedBox(height: 8),
          Text(passwordHelp, style: type(11, 16, color: muted)),
          const SizedBox(height: 16),
          field('Confirm password', 'Re-enter your password', confirm,
              secret: true, confirmation: true),
          const SizedBox(height: 28),
        ] else if (mode == 'reset') ...[
          const SizedBox(height: 12),
          Text('Use the email you registered with.',
              style: type(12, 18, color: muted)),
          const SizedBox(height: 34),
        ] else ...[
          const SizedBox(height: 18),
          Align(
              alignment: Alignment.centerRight,
              child: link('Forgot password?', () => changeMode('reset'),
                  size: 12)),
          const SizedBox(height: 24),
        ],
        if (mode != 'reset') ...[
          ConsentControls(
              terms: terms,
              privacy: privacy,
              onTerms: busy ? null : (v) => setState(() => terms = v ?? false),
              onPrivacy:
                  busy ? null : (v) => setState(() => privacy = v ?? false)),
          const SizedBox(height: 12),
        ],
        if (message != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(
                  liveRegion: true,
                  child: Text(message!, style: type(13, 20)))),
        actionButton,
      ]));
  @override
  Widget build(BuildContext context) => MaterialApp(
      navigatorKey: navigator,
      theme: wattwiseTheme(false),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
          backgroundColor: background,
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: Padding(
                              padding: EdgeInsets.zero,
                              child: AutofillGroup(
                                  child: Form(
                                      key: form,
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            SizedBox(
                                                height: mode == 'register'
                                                    ? 114
                                                    : 134,
                                                child: Stack(
                                                    clipBehavior: Clip.none,
                                                    children: [
                                                      Positioned(
                                                          left: -44,
                                                          top: -48,
                                                          width: 184,
                                                          height: 184,
                                                          child: ExcludeSemantics(
                                                              child: Image.asset(
                                                                  'assets/figma/auth_brand.png',
                                                                  fit: BoxFit
                                                                      .cover))),
                                                      Positioned(
                                                          left: 80,
                                                          top: 22,
                                                          child: Text(
                                                              'WattWise',
                                                              style: type(
                                                                  26, 32,
                                                                  color: green,
                                                                  weight:
                                                                      FontWeight
                                                                          .w700))),
                                                      Positioned(
                                                          left: 81,
                                                          top: 59,
                                                          child: Text(
                                                              'Monitor • Track • Save',
                                                              style: type(
                                                                  12, 18,
                                                                  color:
                                                                      muted))),
                                                    ])),
                                            Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 24),
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                          mode == 'register'
                                                              ? 'Create an account'
                                                              : mode == 'reset'
                                                                  ? 'Forgot password?'
                                                                  : 'Welcome back',
                                                          style: type(26, 32,
                                                              color: green,
                                                              weight: FontWeight
                                                                  .w700)),
                                                      const SizedBox(
                                                          height: 10),
                                                      Text(
                                                          mode == 'register'
                                                              ? 'Start your journey to smarter energy use.'
                                                              : mode == 'reset'
                                                                  ? 'No worries. Enter your account email and we’ll\nsend you a link to reset your password.'
                                                                  : 'Log in to keep your energy use on track.',
                                                          style: type(13, 20,
                                                              color: muted)),
                                                    ])),
                                            SizedBox(
                                                height: mode == 'register'
                                                    ? 20
                                                    : 28),
                                            formCard,
                                            SizedBox(
                                                height: mode == 'register'
                                                    ? 22
                                                    : 28),
                                            Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 24),
                                                child: mode == 'reset'
                                                    ? Center(
                                                        child: link(
                                                            'Back to log in',
                                                            () => changeMode(
                                                                'login')))
                                                    : Wrap(
                                                        alignment: WrapAlignment
                                                            .center,
                                                        crossAxisAlignment:
                                                            WrapCrossAlignment
                                                                .center,
                                                        spacing: 5,
                                                        children: [
                                                            Text(
                                                                mode == 'register'
                                                                    ? 'Already have an account?'
                                                                    : 'New to WattWise?',
                                                                style: type(
                                                                    13, 20,
                                                                    color:
                                                                        muted)),
                                                            link(
                                                                mode == 'register'
                                                                    ? 'Log in'
                                                                    : 'Create an account',
                                                                () => changeMode(mode ==
                                                                        'register'
                                                                    ? 'login'
                                                                    : 'register')),
                                                          ])),
                                            if (mode == 'reset') ...[
                                              const SizedBox(height: 56),
                                              Text('Can’t find the email?',
                                                  textAlign: TextAlign.center,
                                                  style: type(13, 20,
                                                      weight: FontWeight.w600)),
                                              const SizedBox(height: 8),
                                              Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 24),
                                                  child: Text(
                                                      'Check your spam or junk folder, or try again\nwith the email linked to your account.',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: type(12, 19,
                                                          color: muted))),
                                            ],
                                            const SizedBox(height: 28),
                                            const SizedBox(height: 24),
                                            Text(
                                                'Smarter energy. Everyday savings.',
                                                textAlign: TextAlign.center,
                                                style:
                                                    type(12, 18, color: muted)),
                                            const SizedBox(height: 50),
                                          ]))))),
                    )),
          )))));
}
