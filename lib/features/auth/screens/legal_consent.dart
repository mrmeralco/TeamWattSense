import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../shared/theme/wattwise_theme.dart';

final pendingPolicyEmails = <String>{};

Future<void> savePolicyAcceptance(Database database) async {
  await database.transaction((tx) async {
    for (final entry in {
      'accepted_policy_version': policyVersion,
      'accepted_policy_at': DateTime.now().toUtc().toIso8601String()
    }.entries) {
      await tx.insert('preferences', {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  });
}

const policyVersion = '2026-11-12-cloud-sync';
const termsText = '''WattWise Terms of Service
Version: 2026-11-12-cloud-sync

Contact: mirangjoshua@gmail.com

WattWise helps you track appliance electricity usage, review electricity bills and ask Mira for energy-saving guidance. It is not a utility provider and cannot pay bills or change your electricity service.

Provide an email address you control and keep your password private. You must verify your email before entering the app. Do not misuse the service, bypass request limits, impersonate others or upload information you are not entitled to use.

Appliance consumption is calculated from the wattage, quantity and hours you enter. It is an estimate, not a meter reading. AI-generated explanations and scanned bill values may be wrong. Review bill values and appliance changes before saving. Your utility bill and meter remain the source for actual charges and consumption. Do not use Mira for emergency or electrical repair instructions.

AI features require internet access and are subject to request limits and availability. Features may change. Your account’s appliance and bill data is stored on this device; cross-device sync is not currently provided. Uninstalling or clearing app storage can remove local records. Keep copies of important bills.

You may stop using WattWise at any time. To request help, account deletion or exercise privacy rights, contact mirangjoshua@gmail.com. Signing out does not delete your local records. Nothing in these terms removes rights granted by applicable law.

Material policy updates will require a new acknowledgment in the app.''';
const privacyText = '''WattWise Privacy Policy
Version: 2026-11-12-cloud-sync

Privacy contact: mirangjoshua@gmail.com

Account information: Firebase Authentication processes your email address, password, account identifier, verification status and display name to register, authenticate and recover your account. WattWise does not store your password in its SQLite database. Verification and reset emails are delivered through Firebase.

Local information: Appliance names, wattage, quantities, usage logs, reviewed bill details, bill images and preferences are stored in an account-specific database on this device. After accepting this policy, account appliances, usage and POP records, saved bills including images, and display/rate preferences sync to Google Cloud Firestore under your Firebase user ID. This can include personal information printed on saved bills. Sign in to the same verified account on another device to restore successfully synced records. Sync runs while the app is open; offline changes wait locally. Chat history, passwords, local AI request counters and policy acknowledgements are not synced. A policy-version acknowledgment and acceptance time are stored locally for your account. Old data created before accounts existed remains separate and is not automatically assigned to a user.

AI processing: When you ask Mira a question, WattWise sends your question, a limited recent conversation, appliance details, summarized usage and reviewed bill information to Google Cloud through Firebase AI Logic. When you choose Read bill with AI, the selected bill image is sent to that service and may include personal information printed on the image. Use only bills you are entitled to share. AI processing is optional; manual appliance entry and bill review remain available. Chat content is kept in the active app session and is cleared when the session is replaced; it is not saved as local chat history.

Service information: Firebase Authentication, App Check and Google Cloud process technical information necessary to operate and protect the service, such as app identifiers, request information and network-related data. These providers may process information outside your country under their service terms. WattWise does not promise that provider logs are erased when local data is removed.

Purposes: Account access, electricity tracking, requested AI assistance, abuse prevention and responding to support requests. No marketing consent is requested by this screen.

Storage and choices: Local records remain until removed or app storage is cleared. Synced records remain in Firestore across sign-out and reinstalls. In-app deletions propagate when connected; deletion markers remain to prevent old devices restoring deleted records. Interrupted uploads or older image versions may remain in provider storage until cleanup or a deletion request. Signing out does not delete cloud or local records. Firebase account information remains until the account is deleted. You can edit appliance and bill records in the app, avoid optional AI features, and request access, correction or deletion through mirangjoshua@gmail.com. Clearing the app alone does not delete the Firebase account. Do not email your password or verification link.

Security and updates: Account separation and App Check reduce unauthorized access, but no device or service is risk-free. Keep your phone protected. Policy changes will be shown in the app with a new version.''';

void showPolicy(BuildContext context, bool privacy) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
            title: Text(privacy ? 'Privacy Policy' : 'Terms of Service'),
            content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                    child: SelectableText(privacy ? privacyText : termsText))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'))
            ]));

class ConsentControls extends StatelessWidget {
  const ConsentControls(
      {super.key,
      required this.terms,
      required this.privacy,
      required this.onTerms,
      required this.onPrivacy});
  final bool terms, privacy;
  final ValueChanged<bool?>? onTerms, onPrivacy;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.transparent,
      child: Column(children: [
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: terms,
            onChanged: onTerms,
            title: const Text('I agree to the Terms of Service',
                style: TextStyle(fontSize: 12))),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: privacy,
            onChanged: onPrivacy,
            title: const Text('I have read the Privacy Policy',
                style: TextStyle(fontSize: 12))),
        Wrap(spacing: 12, children: [
          TextButton(
              onPressed: () => showPolicy(context, false),
              child: const Text('Terms of Service')),
          TextButton(
              onPressed: () => showPolicy(context, true),
              child: const Text('Privacy Policy'))
        ]),
      ]));
}

class PolicyConsentScreen extends StatefulWidget {
  const PolicyConsentScreen(
      {super.key,
      required this.database,
      required this.onAccepted,
      required this.onSignOut});
  final Database database;
  final VoidCallback onAccepted;
  final Future<void> Function() onSignOut;
  @override
  State<PolicyConsentScreen> createState() => _PolicyConsentScreenState();
}

class _PolicyConsentScreenState extends State<PolicyConsentScreen> {
  bool terms = false, privacy = false, busy = false;
  String? error;
  Future<void> accept() async {
    if (!terms || !privacy || busy) return;
    setState(() => busy = true);
    try {
      await savePolicyAcceptance(widget.database);
      if (mounted) widget.onAccepted();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save your acceptance. Please retry.');
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
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Column(children: [
                            const Text('Before using WattWise',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: green)),
                            const SizedBox(height: 16),
                            const Text(
                                'Review and accept these policies for your account on this device. AI features remain optional.'),
                            ConsentControls(
                                terms: terms,
                                privacy: privacy,
                                onTerms: busy
                                    ? null
                                    : (v) => setState(() => terms = v ?? false),
                                onPrivacy: busy
                                    ? null
                                    : (v) =>
                                        setState(() => privacy = v ?? false)),
                            if (error != null) Text(error!),
                            FilledButton(
                                onPressed:
                                    terms && privacy && !busy ? accept : null,
                                child: const Text('Agree and continue')),
                            TextButton(
                                onPressed: busy ? null : widget.onSignOut,
                                child: const Text('Sign out')),
                          ])))))));
}
