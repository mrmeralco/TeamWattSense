import '../../../shared/firebase/ai_request_budget.dart';
import '../services/firebase_bill_reader.dart';
import '../../../shared/firebase/ai_failure.dart';
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
  String? scanMessage;

  Future<void> scan() async {
    final image = widget.image ?? widget.bill?.sourceImage;
    if (busy || image == null) return;
    setState(() {
      busy = true;
      scanMessage = 'Reading your bill…';
    });
    try {
      final db = widget.controller.database;
      if (db == null) {
        throw const AiRequestLimit(
            'Local storage is required to track AI request limits.');
      }
      final data = await FirebaseBillReader(AiRequestBudget(db))
          .read(image, chargeTypes.map((c) => c.$1).toList());
      if (!mounted) return;
      String number(dynamic value, {bool signed = false}) {
        if (value is! num ||
            !value.isFinite ||
            value.abs() > 1e12 ||
            (!signed && value < 0)) {
          return '';
        }
        return value.toString();
      }

      DateTime? date(dynamic value) {
        if (value is! String) return null;
        final parsed = DateTime.tryParse(value);
        if (parsed == null ||
            parsed.year < 2000 ||
            parsed.year > 2100 ||
            parsed.toIso8601String().substring(0, 10) != value) {
          return null;
        }
        return parsed;
      }

      setState(() {
        usage.text = number(data['consumptionKwh']);
        amount.text = number(data['totalAmount']);
        final periodRead = date(data['periodEnd']);
        final dueRead = date(data['dueDate']);
        if (periodRead != null) period = periodRead;
        if (dueRead != null) due = dueRead;
        final values = data['charges'];
        for (var i = 0; i < charges.length; i++) {
          charges[i].text = values is Map
              ? number(values[chargeTypes[i].$1], signed: true)
              : '';
        }
        scanMessage =
            'Review every value before saving. Blank amounts could not be read.'
            '${periodRead == null ? ' Billing period was not read: select it manually.' : ''}'
            '${dueRead == null ? ' Due date was not read: select it manually.' : ''}';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          scanMessage = error is FormatException
              ? error.message
              : firebaseAiFailureMessage(error);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

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
      final consumptionKwh = double.parse(usage.text);
      final totalAmount = double.parse(amount.text);
      await widget.controller.saveBill(Bill(
          id: widget.bill?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          periodEnd: period,
          dueDate: due,
          consumptionKwh: consumptionKwh,
          totalAmount: totalAmount,
          ratePerKwh: consumptionKwh > 0 ? totalAmount / consumptionKwh : 0,
          insights: '${widget.controller.appliances.length} appliance entries estimate ${widget.controller.monthlyKwh.toStringAsFixed(1)} kWh/month. Your reviewed bill records ${usage.text} kWh. Different billing periods and actual usage can explain differences.',
          savingsInsight: widget.controller.pop
              ? 'POP is enabled in your preferences. Ask Mira about your plan; confirm its actual hours and rates on your bill.'
              : 'Review high-wattage appliances and daily hours to find ways to save.',
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
                              'Read bill with AI sends this image to Firebase AI for extraction. Check all results before saving. You can also enter details manually offline.')),
                      if (image != null) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: busy ? null : scan,
                          icon: const Icon(Icons.document_scanner_outlined),
                          label:
                              Text(busy ? 'Please wait…' : 'Read bill with AI'),
                        ),
                        if (busy) const LinearProgressIndicator(),
                        if (scanMessage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: SelectableText(scanMessage!),
                          ),
                      ],
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
