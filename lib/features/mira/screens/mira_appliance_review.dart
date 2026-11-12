import 'package:flutter/material.dart';
import '../../../app/app_controller.dart';
import '../services/save_mira_action.dart';
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
  late final String newId = DateTime.now().microsecondsSinceEpoch.toString();
  final usageDate = DateTime.now();
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    fields = {
      for (final k in ['name', 'watts', 'hours_per_day'])
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
      final inventory = await widget.controller.applianceRepository.list();
      final action = MiraApplianceAction.parse({
        'mode': widget.action.mode,
        'applianceId': widget.action.original?.id,
        'name': fields['name']!.text.trim(),
        'watts': double.parse(fields['watts']!.text),
        'hours_per_day': double.parse(fields['hours_per_day']!.text),
        'quantity': widget.action.values['quantity'] ??
            widget.action.original?.quantity ??
            1,
      }, inventory);
      // Preserve the original snapshot for stale-edit detection.
      final result = await saveMiraAction(
          widget.controller,
          MiraApplianceAction(
              action.mode, action.values, widget.action.original),
          id: newId,
          date: usageDate);
      if (mounted) Navigator.pop(context, result);
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
                  Text(widget.action.original == null
                      ? 'Saving adds this appliance and records these hours for today. Earlier days are unchanged. For POP timing, edit today’s entry in Dashboard to enter on/off times.'
                      : 'Check the details before saving. This updates the appliance and today’s recorded hours, wattage, and quantity. Earlier daily usage stays unchanged.'),
                  if (widget.action.original != null)
                    Text(
                        'Current: ${widget.action.original!.quantity} × ${widget.action.original!.name}, ${widget.action.original!.watts} W, ${widget.action.original!.hoursPerDay} h/day.'),
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
                              'hours_per_day': 'Hours used today',
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
