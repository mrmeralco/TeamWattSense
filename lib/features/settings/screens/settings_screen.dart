import '../../auth/screens/legal_consent.dart';
import 'package:flutter/material.dart';
import '../../../app/app_controller.dart';
import '../../../shared/components/design_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen(
      {super.key, required this.controller, this.accountEmail, this.onSignOut});
  final AppController controller;
  final String? accountEmail;
  final Future<void> Function()? onSignOut;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    Future<void> change(String key, String value) async {
      try {
        await c.preference(key, value);
      } catch (e) {
        if (context.mounted) showFailure(context, e);
      }
    }

    Widget card(String title, String description, Widget child) => SurfaceCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.t(title),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(c.t(description),
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          child
        ]));
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          PageHeading(c.t('Settings'), c.t('Make WattWise work for you.')),
          Wrap(children: [
            TextButton(
                onPressed: () => showPolicy(context, false),
                child: const Text('Terms of Service')),
            TextButton(
                onPressed: () => showPolicy(context, true),
                child: const Text('Privacy Policy')),
          ]),
          if (onSignOut != null) ...[
            const SizedBox(height: 10),
            SurfaceCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Account',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(accountEmail ?? 'Signed in'),
                  const Text(
                      'Appliances and bills are saved for this account on this device. Cloud sync is not enabled.'),
                  TextButton.icon(
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out')),
                ])),
          ],
          const SizedBox(height: 10),
          card(
              'Language',
              'Choose your preferred app language.',
              ChoiceBar(
                  labels: const ['English', 'Filipino'],
                  selected: c.language == 'en' ? 0 : 1,
                  onChanged: (v) => change('language', v == 0 ? 'en' : 'fil'))),
          const SizedBox(height: 16),
          card(
              'Appearance',
              'Choose a light or dark theme.',
              ChoiceBar(
                  labels: [c.t('Light'), c.t('Dark')],
                  selected: c.dark ? 1 : 0,
                  onChanged: (v) => change('dark', '${v == 1}'))),
          const SizedBox(height: 16),
          SurfaceCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(c.t('Peak / Off-Peak program'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Meralco POP', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: Text(c.t('I’m registered in POP'),
                          style: const TextStyle(fontSize: 14))),
                  Switch(value: c.pop, onChanged: (v) => change('pop', '$v'))
                ]),
                const SizedBox(height: 8),
                Text(
                    c.t(
                        'Enable only if you’re enrolled with Meralco. This helps tailor your estimates and Mira’s tips. Turning this on does not enroll you in POP.'),
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant))
              ])),
          const SizedBox(height: 28),
          Text(c.t('Your preferences, your energy journey.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          Text('WattWise • ${c.t('Monitor • Track • Save')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11)),
        ]);
  }
}
