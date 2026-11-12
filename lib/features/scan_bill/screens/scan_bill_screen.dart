import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/app_controller.dart';
import '../../../shared/components/design_widgets.dart';
import '../../../shared/models/bill.dart';
import '../../../shared/theme/wattwise_theme.dart';
import 'bill_review_form.dart';

const chargeColors = [
  green,
  Color(0xffcf822e),
  Color(0xffcbbb36),
  Color(0xff8bb565),
  Color(0xffa270b0),
  Color(0xffa4c5d8),
  Color(0xff78c1be),
  Color(0xff75b69d),
  Color(0xff8a9490)
];

class ScanBillScreen extends StatefulWidget {
  const ScanBillScreen(
      {super.key, required this.controller, required this.onAskMira});
  final AppController controller;
  final VoidCallback onAskMira;
  @override
  State<ScanBillScreen> createState() => _ScanBillScreenState();
}

class _ScanBillScreenState extends State<ScanBillScreen> {
  String? selectedId;
  bool picking = false;
  String money(double n) =>
      NumberFormat.currency(locale: 'en_PH', symbol: '₱').format(n);

  Future<void> showBillArchive(List<Bill> bills) async {
    var archivedBills = bills.toList()
      ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
    final selectedBills = archivedBills.where((bill) => bill.id == selectedId);
    final activeBillId = selectedBills.isNotEmpty
        ? selectedBills.first.id
        : archivedBills.isEmpty
            ? null
            : archivedBills.first.id;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text('Previous scanned bills',
                    style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
              Expanded(
                child: archivedBills.isEmpty
                    ? const Center(child: Text('No saved bills.'))
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: archivedBills.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final bill = archivedBills[index];
                    return SurfaceCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long, color: green),
                        title: Text(DateFormat.yMMMM().format(bill.periodEnd)),
                        subtitle: Text(
                            '${DateFormat.yMMMd().format(bill.periodEnd)} • ${NumberFormat('#,##0.##').format(bill.consumptionKwh)} kWh'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(money(bill.totalAmount)),
                            IconButton(
                              tooltip: 'Delete bill',
                              icon: const Icon(Icons.delete_outline),
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              onPressed: () async {
                                final shouldDelete = await showDialog<bool>(
                                  context: sheetContext,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Delete saved bill?'),
                                    content: Text(
                                        'Delete the bill from ${DateFormat.yMMMd().format(bill.periodEnd)}? This cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text('Delete bill'),
                                      ),
                                    ],
                                  ),
                                );
                                if (shouldDelete != true || !mounted) return;
                                try {
                                  await widget.controller.removeBill(bill.id);
                                  if (!mounted) return;
                                  final remaining = widget.controller.bills
                                      .where((item) => item.reviewed)
                                      .toList()
                                    ..sort((a, b) =>
                                        b.periodEnd.compareTo(a.periodEnd));
                                  setState(() {
                                    if (activeBillId == bill.id) {
                                      selectedId = remaining.isEmpty
                                          ? null
                                          : remaining.first.id;
                                    }
                                  });
                                  if (remaining.isEmpty) {
                                    Navigator.pop(sheetContext);
                                  } else {
                                    setSheetState(() {
                                      archivedBills = remaining;
                                    });
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Could not delete this bill. Try again.')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() => selectedId = bill.id);
                          Navigator.pop(sheetContext);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Future<void> upload() async {
    if (picking) return;
    setState(() => picking = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );
      if (files.isEmpty || !mounted) return;
      final file = files.single;
      final length = await file.length();
      if (length == null || length <= 0 || length > 8 * 1024 * 1024) {
        throw StateError('Select an image under 8 MB.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024 || !mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => BillReviewForm(
                  controller: widget.controller,
                  image: bytes,
                  sourceName: file.name)));
      if (mounted) setState(() => selectedId = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not read the image. Choose a JPG or PNG under 8 MB.')));
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final bills = c.bills.where((b) => b.reviewed).toList();
    final matching = bills.where((b) => b.id == selectedId);
    final b = matching.isNotEmpty
        ? matching.first
        : bills.isEmpty
            ? null
            : bills.first;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          PageHeading(c.t('Bill Scan'), c.t('Make WattWise work for you.')),
          if (b == null)
            SurfaceCard(
                child: Column(children: [
              const Icon(Icons.document_scanner_outlined,
                  size: 50, color: green),
              const SizedBox(height: 16),
              Text(c.t('No reviewed bill yet.'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                  'Choose a clear image of your Meralco bill to review its charges.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                  onPressed: picking ? null : upload,
                  icon: const Icon(Icons.upload_file),
                  label: Text(c.t('Upload a bill'))),
              TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => BillReviewForm(controller: c))),
                  child: Text(c.t('Enter bill manually')))
            ]))
          else ...[
            SurfaceCard(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                  if (b.sourceImage != null)
                    ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.memory(b.sourceImage!,
                            width: 52,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, s) =>
                                const Icon(Icons.receipt_long)))
                  else
                    const Icon(Icons.receipt_long, color: green),
                  const SizedBox(width: 10),
                  const Stack(alignment: Alignment.center, children: [
                    DesignIcon('22_9_imgUploadSuccess'),
                    Text('✓',
                        style: TextStyle(color: Colors.white, fontSize: 12))
                  ]),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(c.t('Bill saved!'),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                            'Meralco • ${DateFormat.yMMM().format(b.periodEnd)}',
                            style: TextStyle(fontSize: 9, color: muted))
                      ])),
                  TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  BillReviewForm(controller: c, bill: b))),
                      child: Text(c.t('Edit bill'),
                          style: const TextStyle(fontSize: 10))),
                ]),
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                        onPressed: () => showBillArchive(bills),
                        icon: const Icon(Icons.history, size: 16),
                        label: const Text('View previous scanned bills',
                            style: TextStyle(fontSize: 11)))),
                ])),
            const SizedBox(height: 12),
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    gradient: summaryGradient,
                    borderRadius: BorderRadius.circular(18)),
                child: DefaultTextStyle(
                    style: const TextStyle(
                        color: Colors.white, fontFamily: 'Inter'),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 3,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.t('Total Amount Due'),
                                        style: const TextStyle(fontSize: 11)),
                                    const SizedBox(height: 8),
                                    FittedBox(
                                        child: Text(money(b.totalAmount),
                                            style: const TextStyle(
                                                fontSize: 23,
                                                fontWeight: FontWeight.w600))),
                                    const SizedBox(height: 18),
                                    Text(
                                        '${c.t('Due date')}: ${DateFormat.yMMMd().format(b.dueDate)}',
                                        style: const TextStyle(fontSize: 9))
                                  ])),
                          const SizedBox(width: 14),
                          Expanded(
                              flex: 2,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.t('Your Consumption'),
                                        style: const TextStyle(fontSize: 10)),
                                    const SizedBox(height: 8),
                                    Text(
                                        '${NumberFormat('#,##0.##').format(b.consumptionKwh)} kWh',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 18),
                                    const Text('Reviewed bill',
                                        style: TextStyle(fontSize: 9))
                                  ])),
                        ]))),
            const SizedBox(height: 12),
            if (bills.length > 1) ...[
              DropdownButtonFormField<String>(
                  initialValue: b.id,
                  decoration: const InputDecoration(labelText: 'Saved bills'),
                  items: bills
                      .map((v) => DropdownMenuItem(
                          value: v.id,
                          child: Text(
                              '${DateFormat.yMMMd().format(v.periodEnd)} • ${money(v.totalAmount)}')))
                      .toList(),
                  onChanged: (id) => setState(() => selectedId = id)),
              const SizedBox(height: 12),
            ],
            SurfaceCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    const Stack(alignment: Alignment.center, children: [
                      DesignIcon('22_9_imgEnergyIconBackground'),
                      DesignIcon('22_9_imgEnergyBolt')
                    ]),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(c.t('Charge breakdown'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)))
                  ]),
                  const SizedBox(height: 22),
                  Row(children: [
                    SizedBox(
                        width: 124,
                        height: 124,
                        child: Stack(alignment: Alignment.center, children: [
                          CustomPaint(
                              size: const Size(124, 124),
                              painter: ChargesPainter(b.charges)),
                          Container(
                              width: 72,
                              height: 72,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  shape: BoxShape.circle),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                            money(b.charges.fold(
                                                0.0,
                                                (s, c) =>
                                                    s + math.max(0, c.amount))),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700))),
                                    const SizedBox(height: 2),
                                    const Text('Listed charges',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 8))
                                  ]))
                        ])),
                    const SizedBox(width: 20),
                    Expanded(
                        child: Text(
                            'Your bill is made up of several charges, each serving a different purpose.',
                            style: TextStyle(
                                fontSize: 12, height: 1.5, color: muted)))
                  ]),
                  const SizedBox(height: 22),
                  if (b.charges.isEmpty)
                    const Text(
                        'No itemized charges entered. Edit this bill to add them.'),
                  for (var i = 0; i < b.charges.length; i++)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: chargeColors[
                                              i % chargeColors.length]))),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(b.charges[i].name,
                                        style: const TextStyle(fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(b.charges[i].explanation,
                                        style: TextStyle(
                                            fontSize: 10, color: muted))
                                  ])),
                              const SizedBox(width: 8),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(money(b.charges[i].amount),
                                        style: const TextStyle(fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(
                                        b.consumptionKwh > 0
                                            ? '${money(b.charges[i].amount / b.consumptionKwh)}/kWh'
                                            : '—',
                                        style: TextStyle(
                                            fontSize: 10, color: muted))
                                  ])
                            ])),
                  const Text(
                      'Credits appear in the list; the ring shows positive charges only. Listed charges may differ from the amount due.',
                      style: TextStyle(fontSize: 10)),
                ])),
            const SizedBox(height: 12),
            SurfaceCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    const DesignIcon('22_9_imgCalculationDocumentIcon'),
                    const SizedBox(width: 10),
                    Text(c.t('Rate calculation'),
                        style: const TextStyle(fontWeight: FontWeight.w600))
                  ]),
                  const SizedBox(height: 16),
                  SurfaceCard(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Column(children: [
                        Text(
                            '${money(b.totalAmount)} ÷ ${b.consumptionKwh} kWh',
                            style: TextStyle(fontSize: 11, color: muted)),
                        const SizedBox(height: 8),
                        Text(
                            b.consumptionKwh > 0
                                ? '≈ ${money(b.effectiveRatePerKwh)} per kWh'
                                : 'Not available for zero consumption',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: green))
                      ])),
                  const SizedBox(height: 16),
                  Text(
                      'This is the average amount due per kWh for this bill, including any balances or adjustments. It is not an official tariff.',
                      style: TextStyle(fontSize: 11, height: 1.5, color: muted))
                ])),
            const SizedBox(height: 12),
            SurfaceCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    const DesignIcon('22_9_imgInsightSun'),
                    const SizedBox(width: 10),
                    Text(c.t('Insights & savings'),
                        style: const TextStyle(fontWeight: FontWeight.w600))
                  ]),
                  const SizedBox(height: 16),
                  Text(
                      b.insights ??
                          '${c.appliances.length} appliance entries estimate ${c.monthlyKwh.toStringAsFixed(1)} kWh/month. Your reviewed bill records ${b.consumptionKwh} kWh. Different billing periods and actual usage can explain differences.',
                      style: const TextStyle(fontSize: 12, height: 1.5)),
                  const SizedBox(height: 16),
                  Row(children: [
                    const DesignIcon('22_9_imgSavingsLeaf'),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            b.savingsInsight ??
                                (c.pop
                                    ? 'POP is enabled in your preferences. Ask Mira about your plan; confirm its actual hours and rates on your bill.'
                                    : 'Review high-wattage appliances and daily hours to find ways to save.'),
                            style: TextStyle(
                                fontSize: 12, height: 1.5, color: muted)))
                  ]),
                  TextButton(
                      onPressed: widget.onAskMira,
                      child: Text(c.t('Explain my bill')))
                ])),
            const SizedBox(height: 16),
            OutlinedButton.icon(
                onPressed: picking ? null : upload,
                icon: const Icon(Icons.upload_file),
                label: Text(c.t('Upload a bill'))),
          ]
        ]);
  }
}

class ChargesPainter extends CustomPainter {
  ChargesPainter(this.charges);
  final List<BillCharge> charges;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(11, 11, size.width - 22, size.height - 22);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22;
    final total = charges.fold(0.0, (s, c) => s + math.max(0, c.amount));
    if (total == 0) {
      canvas.drawOval(rect, paint..color = const Color(0xffe5e5e5));
      return;
    }
    var angle = -math.pi / 2;
    for (var i = 0; i < charges.length; i++) {
      final sweep = math.max(0, charges[i].amount) / total * math.pi * 2;
      canvas.drawArc(rect, angle, sweep, false,
          paint..color = chargeColors[i % chargeColors.length]);
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(ChargesPainter old) => old.charges != charges;
}
