import '../../auth/screens/legal_consent.dart';
import 'package:flutter/material.dart';
import '../../../app/app_controller.dart';
import '../../../shared/components/design_widgets.dart';

String? _rateValidator(String? value) {
  final rate = double.tryParse(value ?? '');
  if (rate == null || !rate.isFinite || rate < 0 || rate > 10000) {
    return 'Enter a valid rate';
  }
  return null;
}

String? _loadBalanceValidator(String? value) {
  final balance = double.tryParse(value ?? '');
  if (balance == null ||
      !balance.isFinite ||
      balance < 0 ||
      balance > 100000000) {
    return 'Enter a valid balance';
  }
  return null;
}

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

    Future<void> changePop(bool value) async {
      final start = DateTime.now().add(const Duration(days: 1));
      final applies = DateTime(start.year, start.month, start.day);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
              c.t(value ? 'Enable POP estimates?' : 'Disable POP estimates?')),
          content: Text(c.t(
              'This takes effect tomorrow (${applies.month}/${applies.day}/${applies.year}). Existing daily usage and overview history will not be erased.')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(c.t('Cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(c.t('Confirm'))),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await c.schedulePopChange(value);
      } catch (e) {
        if (context.mounted) showFailure(context, e);
      }
    }

    Future<void> editPopRates() async {
      final peak = TextEditingController();
      final offPeak = TextEditingController();
      final source = TextEditingController(text: 'Current Meralco bill');
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final key = GlobalKey<FormState>();
      final result = await showDialog<List<String>>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(c.t('POP generation rates')),
          content: Form(
              key: key,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: peak,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(labelText: c.t('Peak rate (PHP/kWh)')),
                    validator: _rateValidator),
                TextFormField(
                    controller: offPeak,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: c.t('Off-peak rate (PHP/kWh)')),
                    validator: _rateValidator),
                TextFormField(
                    controller: source,
                    decoration: InputDecoration(labelText: c.t('Rate source'))),
                const SizedBox(height: 8),
                Text(
                    '${c.t('Effective month')}: $month • ${c.t('Estimate only')}',
                    style: const TextStyle(fontSize: 12)),
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(c.t('Cancel'))),
            FilledButton(
                onPressed: () {
                  if (key.currentState!.validate()) {
                    Navigator.pop(
                        context, [peak.text, offPeak.text, source.text]);
                  }
                },
                child: Text(c.t('Save rates'))),
          ],
        ),
      );
      if (result == null) return;
      try {
        await c.savePopRates(
            effectiveMonth: month,
            peakRate: double.parse(result[0]),
            offPeakRate: double.parse(result[1]),
            source: result[2]);
      } catch (e) {
        if (context.mounted) showFailure(context, e);
      }
    }

    Future<void> changeKLoad(bool value) async {
      if (value) {
        final balance = TextEditingController();
        final rate = TextEditingController();
        final key = GlobalKey<FormState>();
        final existing = c.hasKLoadProfile;
        ModalRoute<dynamic>? dialogRoute;
        final result = await showDialog<List<String>>(
          context: context,
          builder: (dialogContext) {
            dialogRoute = ModalRoute.of(dialogContext);
            return AlertDialog(
              title:
                  Text(c.t(existing ? 'Resume KLoad now' : 'Set up KLoad now')),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: key,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.t('KLoad starts immediately. Your balance is reconciled with saved entries for today. Daily entries have no time detail, so the estimate cannot separate usage from before or after activation.'),
                          style: const TextStyle(fontSize: 13, height: 1.45),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: balance,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: c.t('Current KLoad balance'),
                            helperText:
                                c.t('Enter the balance shown on KLoad.'),
                            prefixText: '₱ ',
                          ),
                          validator: _loadBalanceValidator,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: rate,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: c.t('KLoad rate'),
                            helperText: c.t('Enter the rate shown on KLoad.'),
                            suffixText: 'PHP/kWh',
                          ),
                          validator: _rateValidator,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      FocusScope.of(dialogContext).unfocus();
                      Navigator.pop(dialogContext);
                    },
                    child: Text(c.t('Cancel'))),
                FilledButton(
                    onPressed: () {
                      if (key.currentState!.validate()) {
                        FocusScope.of(dialogContext).unfocus();
                        Navigator.pop(dialogContext, [balance.text, rate.text]);
                      }
                    },
                    child: Text(c.t(existing ? 'Resume now' : 'Activate now'))),
              ],
            );
          },
        );
        await dialogRoute?.completed;
        balance.dispose();
        rate.dispose();
        if (result == null) return;
        try {
          await c.scheduleKLoadActivation(
            startingBalance: double.parse(result[0]),
            rate: double.parse(result[1]),
          );
        } catch (e) {
          if (context.mounted) showFailure(context, e);
        }
        return;
      }
      ModalRoute<dynamic>? dialogRoute;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          dialogRoute = ModalRoute.of(dialogContext);
          return AlertDialog(
            title: Text(c.t('Turn off KLoad dashboard?')),
            content: Text(c.t(
                'The regular dashboard returns immediately. Appliance entries and KLoad history are kept. KLoad estimates will stop including usage from today while tracking is off.')),
            actions: [
              TextButton(
                  onPressed: () {
                    FocusScope.of(dialogContext).unfocus();
                    Navigator.pop(dialogContext, false);
                  },
                  child: Text(c.t('Cancel'))),
              FilledButton(
                  onPressed: () {
                    FocusScope.of(dialogContext).unfocus();
                    Navigator.pop(dialogContext, true);
                  },
                  child: Text(c.t('Confirm'))),
            ],
          );
        },
      );
      await dialogRoute?.completed;
      if (confirmed != true) return;
      try {
        await c.scheduleKLoadDeactivation();
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
                      'Appliances, usage, bills and saved bill images sync privately with this account. Offline changes upload when connected. Keep the app open until sync finishes.'),
                  Text(c.cloudSyncStatus),
                  TextButton.icon(
                      onPressed: c.syncNow,
                      icon: const Icon(Icons.sync),
                      label: const Text('Sync now')),
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
                Text(c.t('KLoad budget dashboard'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                    c.t('Switch to a separate KLoad view that estimates costs from daily appliance entries and the load balance you enter.'),
                    style: const TextStyle(fontSize: 12, height: 1.5)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text(c.t('Use KLoad dashboard'))),
                  Switch(value: c.kloadSwitchValue, onChanged: changeKLoad),
                ]),
                Text(
                    c.t(
                        'Starts or stops immediately. KLoad is separate from POP; switching modes keeps your appliance history.'),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
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
                  Switch(value: c.popSwitchValue, onChanged: changePop)
                ]),
                Text(
                    c.t('POP rates affect generation estimates only; results are estimates and do not replace your full bill rate.'),
                    style: const TextStyle(fontSize: 12)),
                TextButton(
                    onPressed: editPopRates,
                    child: Text(c.t('Enter POP rates from bill'))),
                TextButton(
                    onPressed: () => c.savePopRates(
                        effectiveMonth: '2025-06',
                        peakRate: 8.38,
                        offPeakRate: 4.55,
                        source: 'Meralco reference figures dated 18 June 2025',
                        reference: true),
                    child: Text(c.t('Save June 2025 reference rates'))),
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
