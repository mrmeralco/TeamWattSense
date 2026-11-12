import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/app_controller.dart';
import '../../../shared/components/design_widgets.dart';
import '../../../shared/models/bill.dart';

const chargeTypes = [
  ('Generation', 'Cost to produce electricity.'),
  ('Transmission', 'High-voltage transport.'),
  ('System Loss', 'Electricity lost in the grid.'),
  ('Distribution (Meralco)', 'Local delivery and network.'),
  ('Subsidies', 'Mandated assistance.'),
  ('Government Taxes', 'Taxes listed on your bill.'),
  ('Universal Charges', 'Charges for mandated programs.'),
  ('FIT-All (Renewable)', 'Support for renewable energy.'),
  (
    'Other charges / credits',
    'Balances, adjustments or credits from your bill.'
  ),
];

class BillReviewForm extends StatefulWidget {
  const BillReviewForm(
      {super.key,
      required this.controller,
      this.bill,
      this.image,
      this.sourceName});
  final AppController controller;
  final Bill? bill;
  final Uint8List? image;
  final String? sourceName;
  @override
  State<BillReviewForm> createState() => _BillReviewFormState();
}

class _BillReviewFormState extends State<BillReviewForm> {
  final key = GlobalKey<FormState>();
  late final TextEditingController usage, amount;
  late final List<TextEditingController> charges;
  late DateTime period, due;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    period = b?.periodEnd ?? DateTime.now();
    due = b?.dueDate ?? DateTime.now().add(const Duration(days: 14));
    usage = TextEditingController(text: b?.consumptionKwh.toString() ?? '');
    amount = TextEditingController(text: b?.totalAmount.toString() ?? '');
    charges = chargeTypes.map((t) {
      final matching = b?.charges.where((v) => v.name == t.$1);
      return TextEditingController(
          text: matching != null && matching.isNotEmpty
              ? matching.first.amount.toString()
              : '');
    }).toList();
  }

  @override
  void dispose() {
    usage.dispose();
    amount.dispose();
    for (final c in charges) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(String label, TextEditingController c,
          {bool optional = false, bool signed = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              controller: c,
              enabled: !busy,
              keyboardType: TextInputType.numberWithOptions(
                  decimal: true, signed: signed),
              decoration:
                  InputDecoration(labelText: widget.controller.t(label)),
              validator: (v) {
                if (optional && (v ?? '').trim().isEmpty) return null;
                final n = double.tryParse(v ?? '');
                return n == null ||
                        !n.isFinite ||
                        (!signed && n < 0) ||
                        n.abs() > 1e12
                    ? 'Enter a valid amount'
                    : null;
              }));
  Future<void> save() async {
    if (busy || !key.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.controller.saveBill(Bill(
          id: widget.bill?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          periodEnd: period,
          dueDate: due,
          consumptionKwh: double.parse(usage.text),
          totalAmount: double.parse(amount.text),
          reviewed: true,
          sourceImage: widget.image ?? widget.bill?.sourceImage,
          sourceName: widget.sourceName ?? widget.bill?.sourceName,
          charges: [
            for (var i = 0; i < charges.length; i++)
              if (charges[i].text.trim().isNotEmpty)
                BillCharge(
                    name: chargeTypes[i].$1,
                    amount: double.parse(charges[i].text),
                    explanation: chargeTypes[i].$2)
          ]));
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
    final image = widget.image ?? widget.bill?.sourceImage;
    return Scaffold(
        appBar: AppBar(title: Text(c.t('Review bill'))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                    key: key,
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      if (image != null) ...[
                        ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(image,
                                height: 220,
                                fit: BoxFit.contain,
                                errorBuilder: (_, e, s) => const Text(
                                    'This image could not be displayed. Choose a JPG or PNG.'))),
                        const SizedBox(height: 16)
                      ],
                      const SurfaceCard(
                          child: Text(
                              'Automatic bill extraction is not connected yet. Enter or correct the details from your bill below. Only reviewed details are shared with Mira.')),
                      const SizedBox(height: 20),
                      for (final isPeriod in [true, false])
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(c.t(
                                isPeriod ? 'Billing period end' : 'Due date')),
                            subtitle: Text(DateFormat.yMMMd()
                                .format(isPeriod ? period : due)),
                            trailing: const Icon(Icons.calendar_month_outlined),
                            onTap: busy
                                ? null
                                : () async {
                                    final picked = await showDatePicker(
                                        context: context,
                                        initialDate: isPeriod ? period : due,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100));
                                    if (picked != null) {
                                      setState(() {
                                        if (isPeriod) {
                                          period = picked;
                                        } else {
                                          due = picked;
                                        }
                                      });
                                    }
                                  }),
                      const SizedBox(height: 16),
                      field('Consumption (kWh)', usage),
                      field('Amount due (PHP)', amount),
                      Text(c.t('Charge breakdown'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const Text(
                          'Optional: copy each charge exactly. Credits may be negative; leave unknown charges blank.'),
                      const SizedBox(height: 16),
                      for (var i = 0; i < chargeTypes.length; i++)
                        field('${chargeTypes[i].$1} (PHP)', charges[i],
                            optional: true, signed: true),
                      FilledButton(
                          onPressed: busy ? null : save,
                          child: Text(c.t('Save reviewed bill'))),
                      const SizedBox(height: 20),
                    ])))));
  }
}
