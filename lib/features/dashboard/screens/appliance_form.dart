import 'package:flutter/material.dart';
import '../../../app/app_controller.dart';
import '../../../shared/components/design_widgets.dart';
import '../../../shared/models/appliance.dart';
import '../../../shared/theme/wattwise_theme.dart';

class ApplianceForm extends StatefulWidget {
  const ApplianceForm({super.key, required this.controller, this.appliance});
  final AppController controller;
  final Appliance? appliance;
  @override
  State<ApplianceForm> createState() => _ApplianceFormState();
}

class _ApplianceFormState extends State<ApplianceForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController name, watts, hours, days, quantity;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final a = widget.appliance;
    name = TextEditingController(text: a?.name);
    watts = TextEditingController(text: a?.watts.toString() ?? '');
    hours = TextEditingController(text: a?.hoursPerDay.toString() ?? '');
    days = TextEditingController(text: '${a?.daysPerMonth ?? 30}');
    quantity = TextEditingController(text: '${a?.quantity ?? 1}');
  }

  @override
  void dispose() {
    for (final c in [name, watts, hours, days, quantity]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !_form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.controller.saveAppliance(Appliance(
          id: widget.appliance?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          name: name.text.trim(),
          watts: double.parse(watts.text),
          hoursPerDay: double.parse(hours.text),
          daysPerMonth: int.parse(days.text),
          quantity: int.parse(quantity.text)));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final daily = (double.tryParse(watts.text) ?? 0) *
        (double.tryParse(hours.text) ?? 0) *
        (int.tryParse(quantity.text) ?? 1) /
        1000;
    Widget field(String label, TextEditingController input, String asset,
            {String? unit, double? max, bool integer = false}) =>
        Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.t(label),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextFormField(
                  controller: input,
                  enabled: !busy,
                  onChanged: (_) => setState(() {}),
                  keyboardType: unit == null
                      ? TextInputType.text
                      : TextInputType.numberWithOptions(decimal: !integer),
                  decoration: InputDecoration(
                      prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: DesignIcon(asset)),
                      suffixText: unit),
                  validator: (v) {
                    if (unit == null) {
                      return v == null || v.trim().isEmpty
                          ? 'Enter a name'
                          : null;
                    }
                    final n = double.tryParse(v ?? '');
                    if (n == null ||
                        !n.isFinite ||
                        n < (label == 'Quantity' ? 1 : 0) ||
                        (max != null && n > max) ||
                        (integer && int.tryParse(v ?? '') == null)) {
                      return 'Enter a valid ${integer ? 'whole ' : ''}number${max == null ? '' : ' up to $max'}';
                    }
                    return null;
                  })
            ]));
    return Scaffold(
        backgroundColor: c.dark ? null : const Color(0xffeffcf0),
        appBar: AppBar(
            leading: IconButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                icon: const DesignIcon('44_41_imgBack')),
            title: Row(children: [
              const DesignIcon('44_41_imgPlug'),
              const SizedBox(width: 16),
              Text(
                  c.t(widget.appliance == null
                      ? 'Add Appliance'
                      : 'Edit Appliance'),
                  style: const TextStyle(
                      fontSize: 23, fontWeight: FontWeight.w700))
            ])),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                    key: _form,
                    child:
                        ListView(padding: const EdgeInsets.all(20), children: [
                      Text(c.t(
                          'Enter your appliance details to track energy use.')),
                      const SizedBox(height: 32),
                      field('Appliance name', name, '44_41_imgFan'),
                      field('Power rating', watts, '44_41_imgPower',
                          unit: 'W', max: 1000000),
                      field('Average daily use', hours, '44_41_imgClock',
                          unit: 'hrs/day', max: 24),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: field(
                                    'Days per month', days, '44_41_imgClock',
                                    unit: 'days', max: 31, integer: true)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: field(
                                    'Quantity', quantity, '44_41_imgPlug',
                                    unit: 'pcs', max: 10000, integer: true))
                          ]),
                      SurfaceCard(
                          color: c.dark ? null : paleGreen,
                          child: Row(children: [
                            const DesignIcon('44_41_imgEnergyBolt'),
                            const SizedBox(width: 24),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(c.t('Estimated daily usage'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                      '${daily.isFinite ? daily.toStringAsFixed(2) : '—'} kWh',
                                      style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700)),
                                  Text(c.t('Based on wattage and daily hours.'),
                                      style: const TextStyle(fontSize: 12))
                                ]))
                          ])),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                          onPressed: busy ? null : save,
                          icon: const DesignIcon('44_41_imgPlus'),
                          label: Text(c.t(widget.appliance == null
                              ? 'Add Appliance'
                              : 'Save changes'))),
                      TextButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          child: Text(c.t('Cancel'))),
                      if (widget.appliance != null)
                        TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                                title: Text(
                                                    c.t('Delete appliance')),
                                                content: Text(
                                                    widget.appliance!.name),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, false),
                                                      child:
                                                          Text(c.t('Cancel'))),
                                                  FilledButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, true),
                                                      child: Text(c.t(
                                                          'Delete appliance')))
                                                ]));
                                    if (confirmed != true || !mounted) return;
                                    setState(() => busy = true);
                                    try {
                                      await c.removeAppliance(
                                          widget.appliance!.id);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        showFailure(context, e);
                                      }
                                    } finally {
                                      if (mounted) setState(() => busy = false);
                                    }
                                  },
                            child: Text(c.t('Delete appliance'),
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)))
                    ])))));
  }
}
