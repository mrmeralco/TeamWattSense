import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../app/app_controller.dart';
import '../../../shared/components/design_widgets.dart';
import '../../../shared/models/appliance.dart';
import 'appliance_form.dart';
import '../services/kload_service.dart';

class KLoadDashboardScreen extends StatefulWidget {
  const KLoadDashboardScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<KLoadDashboardScreen> createState() => _KLoadDashboardScreenState();
}

class _KLoadDashboardScreenState extends State<KLoadDashboardScreen> {
  final _money =
      NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

  Future<void> _edit(Appliance? appliance) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ApplianceForm(
          controller: widget.controller,
          appliance: appliance,
          usageDate: DateTime.now(),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _addTopUp() async {
    final amount = TextEditingController();
    final form = GlobalKey<FormState>();
    ModalRoute<dynamic>? dialogRoute;
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        dialogRoute = ModalRoute.of(dialogContext);
        return AlertDialog(
          title: const Text('Record a load top-up'),
          content: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Top-up amount (₱)'),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  if (parsed == null || !parsed.isFinite || parsed <= 0) {
                    return 'Enter an amount greater than zero';
                  }
                  return null;
                },
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  FocusScope.of(dialogContext).unfocus();
                  Navigator.pop(dialogContext, double.parse(amount.text));
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    // A save can notify all dashboard listeners. Wait until the dialog's
    // reverse transition has removed its inherited dependents first.
    await dialogRoute?.completed;
    amount.dispose();
    if (result == null || !mounted) return;
    try {
      await widget.controller.addKLoadBalanceEvent(
        id: 'kload-${DateTime.now().microsecondsSinceEpoch}',
        date: DateTime.now(),
        amount: result,
      );
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _updateRate() async {
    final input = TextEditingController();
    final form = GlobalKey<FormState>();
    ModalRoute<dynamic>? dialogRoute;
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        dialogRoute = ModalRoute.of(dialogContext);
        return AlertDialog(
          title: const Text('Update KLoad rate'),
          content: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: input,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Rate (₱/kWh)'),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  return parsed == null ||
                          !parsed.isFinite ||
                          parsed < 0 ||
                          parsed > 10000
                      ? 'Enter a valid rate'
                      : null;
                },
              ),
              const SizedBox(height: 6),
              const Text(
                  'This rate takes effect tomorrow. Earlier entries keep their saved rate period.',
                  style: TextStyle(fontSize: 12)),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  FocusScope.of(dialogContext).unfocus();
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    FocusScope.of(dialogContext).unfocus();
                    Navigator.pop(dialogContext, double.parse(input.text));
                  }
                },
                child: const Text('Save rate')),
          ],
        );
      },
    );
    await dialogRoute?.completed;
    input.dispose();
    if (result == null || !mounted) return;
    try {
      await widget.controller.saveKLoadRate(result);
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final today = DateTime.now();
    final todayEntries = c.appliances.where((appliance) =>
        c.dailyUsages.any((entry) =>
            entry.applianceId == appliance.id &&
            entry.date.year == today.year &&
            entry.date.month == today.month &&
            entry.date.day == today.day)).toList();
    final existingIds = c.appliances.map((a) => a.id).toSet();
    final database = c.database;
    if (database == null) {
      return const Center(child: Text('KLoad storage is unavailable.'));
    }
    return FutureBuilder<KLoadSummary>(
      future: KLoadService(database).summarize(
          entries: c.dailyUsages,
          existingApplianceIds: existingIds,
          now: today),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text('Could not load KLoad data: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final month = DateFormat.yMMMM().format(today);
        final muted = Theme.of(context).colorScheme.onSurfaceVariant;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          children: [
            Row(children: [
              const DesignIcon('14_6_imgHomeEnergyLogo'),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('WattWise · KLoad',
                        style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary)),
                    Text(month, style: TextStyle(fontSize: 12, color: muted)),
                  ])),
              const Chip(label: Text('KLOAD ON')),
            ]),
            const SizedBox(height: 18),
            SurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estimated remaining load balance',
                        style: TextStyle(fontSize: 14, color: muted)),
                    const SizedBox(height: 8),
                    Text(_money.format(data.estimatedBalance),
                        style: const TextStyle(
                            fontSize: 36, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                        'Estimate from saved appliance entries and balance events. Unrecorded household usage is not included.',
                        style:
                            TextStyle(fontSize: 12, height: 1.4, color: muted)),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: _metric('Recorded cost · $month',
                              _money.format(data.monthCost))),
                      Expanded(
                          child: _metric('Recorded usage',
                              '${data.monthKwh.toStringAsFixed(1)} kWh')),
                    ])
                  ]),
            ),
            const SizedBox(height: 12),
            SurfaceCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Today · ${DateFormat.MMMd().format(today)}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _metric('Usage recorded',
                            '${data.todayKwh.toStringAsFixed(2)} kWh')),
                    Expanded(
                        child: _metric(
                            'Estimated cost', _money.format(data.todayCost))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: Text(
                            data.currentRate == null
                                ? 'No KLoad rate is saved for today.'
                                : 'Rate: ₱${data.currentRate!.toStringAsFixed(2)}/kWh',
                            style: TextStyle(fontSize: 12, color: muted))),
                    TextButton(
                        onPressed: _updateRate,
                        child: const Text('Update rate')),
                  ]),
                ])),
            const SizedBox(height: 12),
            SurfaceCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Today’s appliance entries',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600))),
                    TextButton.icon(
                        onPressed: () => _edit(null),
                        icon: const Icon(Icons.add),
                        label: const Text('Add appliance')),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                      'Tap an appliance to enter or revise today’s usage, just as in the regular dashboard.',
                      style: TextStyle(fontSize: 12, color: muted)),
                  const SizedBox(height: 8),
                  if (todayEntries.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                            'No appliance entries yet for today. Add one to start recording usage.'))
                  else
                    for (final appliance in todayEntries)
                      Builder(builder: (context) {
                        final matching = c.dailyUsages.where((entry) =>
                            entry.applianceId == appliance.id &&
                            entry.date.year == today.year &&
                            entry.date.month == today.month &&
                            entry.date.day == today.day);
                        final entry = matching.isEmpty ? null : matching.first;
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(appliance.name),
                            subtitle: Text(entry == null
                                ? 'No usage entered today'
                                : '${entry.hours.toStringAsFixed(1)} hours · ${entry.kwh.toStringAsFixed(2)} kWh'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _edit(appliance),
                          ),
                        );
                      }),
                ])),
            const SizedBox(height: 12),
            SurfaceCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Load balance entries',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                      'Record load top-ups to keep the balance estimate aligned with your current load.',
                      style:
                          TextStyle(fontSize: 12, height: 1.4, color: muted)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: _addTopUp,
                      icon: const Icon(Icons.add),
                      label: const Text('Add top-up')),
                ])),
            const SizedBox(height: 12),
            Text(
                'KLoad is separate from POP. The estimate uses only daily appliance entries saved for dates when KLoad tracking is active.',
                style: TextStyle(fontSize: 11, height: 1.4, color: muted),
                textAlign: TextAlign.center),
          ],
        );
      },
    );
  }

  Widget _metric(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 5),
        Text(value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ]);
}
