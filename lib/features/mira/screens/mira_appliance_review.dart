import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../app/app_controller.dart';
import '../../../shared/models/appliance.dart';
import '../services/mira_appliance_action.dart';

class MiraApplianceReview extends StatefulWidget {
  const MiraApplianceReview(
      {super.key, required this.action, required this.controller});
  final MiraApplianceAction action;
  final AppController controller;
  @override
  State<MiraApplianceReview> createState() => _MiraApplianceReviewState();
}

class _MiraApplianceReviewState extends State<MiraApplianceReview> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    fields = {
      for (final k in [
        'name',
        'watts',
        'hours_per_day',
        'days_per_month',
        'quantity'
      ])
        k: TextEditingController(
            text: widget.action.values[k]?.toString() ?? '')
    };
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final original = widget.action.original;
      final inventory = await widget.controller.applianceRepository.list();
      if (original != null) {
        final current = inventory.where((a) => a.id == original.id).toList();
        if (current.length != 1 ||
            jsonEncode(current.single.toMap()) !=
                jsonEncode(original.toMap())) {
          throw const FormatException(
              'This appliance changed after Mira read it. Cancel and request the edit again.');
        }
      }
      final values = <String, Object?>{
        'mode': widget.action.mode,
        'applianceId': original?.id,
        'name': fields['name']!.text.trim(),
        'watts': double.parse(fields['watts']!.text),
        'hours_per_day': double.parse(fields['hours_per_day']!.text),
        'days_per_month': int.parse(fields['days_per_month']!.text),
        'quantity': int.parse(fields['quantity']!.text)
      };
      final validated = MiraApplianceAction.parse(values, inventory);
      final a = Appliance(
          id: original?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          name: validated.values['name'] as String,
          watts: values['watts'] as double,
          hoursPerDay: values['hours_per_day'] as double,
          daysPerMonth: values['days_per_month'] as int,
          quantity: values['quantity'] as int);
      await widget.controller.saveAppliance(a);
      if (mounted) {
        Navigator.pop(context,
            '${original == null ? 'Added' : 'Updated'} ${a.quantity} × ${a.name}: ${a.watts} W each, ${a.hoursPerDay} hours/day, ${a.daysPerMonth} days/month.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is FormatException
            ? e.message
            : 'Could not save the appliance. Please retry.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(widget.action.mode == 'add'
            ? 'Review new appliance'
            : 'Review appliance changes'),
        content: SizedBox(
            width: 420,
            child: Form(
                key: form,
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      'Check the details before saving. Hours are your usual daily estimate; this does not change recorded daily usage.'),
                  if (widget.action.original != null)
                    Text(
                        'Current: ${widget.action.original!.quantity} × ${widget.action.original!.name}, ${widget.action.original!.watts} W, ${widget.action.original!.hoursPerDay} h/day, ${widget.action.original!.daysPerMonth} days/month.'),
                  for (final e in fields.entries)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextFormField(
                            controller: e.value,
                            enabled: !saving,
                            keyboardType: e.key == 'name'
                                ? TextInputType.text
                                : const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: InputDecoration(
                                labelText: {
                              'name': 'Appliance name',
                              'watts': 'Watts per appliance',
                              'hours_per_day': 'Usual hours per day',
                              'days_per_month': 'Days per month',
                              'quantity': 'Quantity'
                            }[e.key]),
                            validator: (v) {
                              if (e.key == 'name') {
                                return v == null ||
                                        v.trim().isEmpty ||
                                        v.length > 80
                                    ? 'Enter a name, up to 80 characters'
                                    : null;
                              }
                              final n = num.tryParse(v ?? '');
                              final max = {
                                'watts': 100000,
                                'hours_per_day': 24,
                                'days_per_month': 31,
                                'quantity': 1000
                              }[e.key]!;
                              if (n == null ||
                                  !n.isFinite ||
                                  n < (e.key == 'quantity' ? 1 : 0) ||
                                  n > max ||
                                  (['quantity', 'days_per_month']
                                          .contains(e.key) &&
                                      int.tryParse(v!) == null)) {
                                return 'Enter a valid value up to $max';
                              }
                              return null;
                            })),
                  if (error != null)
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                ])))),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Saving…' : 'Save appliance'))
        ],
      ));
}
