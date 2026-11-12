import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../app/app_controller.dart';
import '../../../shared/components/design_widgets.dart';
import '../../../shared/models/appliance.dart';
import '../../../shared/theme/wattwise_theme.dart';
import 'appliance_form.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen(
      {super.key, required this.controller, required this.onSettings});
  final AppController controller;
  final VoidCallback onSettings;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int scale = 2;
  int periodOffset = 0;
  String money(double n) =>
      NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2)
          .format(n);
  void edit([Appliance? a]) => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) =>
              ApplianceForm(controller: widget.controller, appliance: a)));
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget stat(String icon, String label, String value) => SurfaceCard(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          DesignIcon(icon),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(c.t(label),
                        style: TextStyle(fontSize: 10, color: muted))),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600))
              ]))
        ]));
    Widget summary(String label, String value, String note) => Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.t(label), style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 12),
          Row(children: [
            if (label == 'Total Usage (This Month)') ...[
              const DesignIcon('14_6_imgEnergyBolt'),
              const SizedBox(width: 5)
            ],
            Expanded(
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w700))))
          ]),
          const SizedBox(height: 12),
          Text(note, style: const TextStyle(fontSize: 10))
        ]));
    final factor = [1 / 30, 7 / 30, 1.0, 12.0][scale];
    final now = DateTime.now();
    final period = scale == 2
        ? DateTime(now.year, now.month + periodOffset)
        : scale == 3
            ? DateTime(now.year + periodOffset)
            : now.add(Duration(days: periodOffset * (scale == 1 ? 7 : 1)));
    final periodLabel = scale == 2
        ? DateFormat.yMMM().format(period)
        : scale == 3
            ? '${period.year}'
            : DateFormat.MMMd().format(period);
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        children: [
          Row(children: [
            const DesignIcon('14_6_imgHomeEnergyLogo'),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('WattWise',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary)),
                  Text(c.t('Monitor • Track • Save'),
                      style: TextStyle(fontSize: 12, color: muted))
                ])),
            IconButton(
                onPressed: widget.onSettings,
                tooltip: c.t('Settings'),
                style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface),
                icon: DesignIcon('14_6_imgSettings', color: muted))
          ]),
          const SizedBox(height: 10),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  gradient: summaryGradient,
                  borderRadius: BorderRadius.circular(18)),
              child: DefaultTextStyle(
                  style:
                      const TextStyle(color: Colors.white, fontFamily: 'Inter'),
                  child: Row(children: [
                    summary(
                        'Total Usage (This Month)',
                        '${c.monthlyKwh.toStringAsFixed(1)} kWh',
                        c.t('Estimated')),
                    Container(
                        height: 72,
                        width: 1,
                        color: const Color(0xff79b78e),
                        margin: const EdgeInsets.symmetric(horizontal: 16)),
                    summary('Total Cost', money(c.monthlyKwh * c.rate),
                        '${c.t('Estimated')} • ₱${c.rate}/kWh'),
                  ]))),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: stat('14_6_imgTotalHoursClock', 'Total Hours',
                    '${c.monthlyHours.toStringAsFixed(1)} hrs')),
            const SizedBox(width: 10),
            Expanded(
                child: stat('14_6_imgConnectedPlug', 'Connected Appliances',
                    '${c.appliances.fold<int>(0, (n, a) => n + a.quantity)}'))
          ]),
          const SizedBox(height: 6),
          SurfaceCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const DesignIcon('14_6_imgUsageChartIcon'),
                      const SizedBox(width: 8),
                      Text(c.t('Usage Overview'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600))
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Text(c.t('View by'),
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: ChoiceBar(
                              compact: true,
                              labels: ['Day', 'Week', 'Month', 'Year']
                                  .map(c.t)
                                  .toList(),
                              selected: scale,
                              onChanged: (v) => setState(() {
                                    scale = v;
                                    periodOffset = 0;
                                  })))
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      IconButton(
                          constraints: const BoxConstraints.tightFor(
                              width: 32, height: 32),
                          padding: const EdgeInsets.all(8),
                          tooltip: 'Previous period',
                          onPressed: () => setState(() => periodOffset--),
                          icon: const DesignIcon('14_6_imgPreviousPeriod')),
                      Expanded(
                          child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text('$periodLabel • ${c.t('Estimated')}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)))),
                      IconButton(
                          constraints: const BoxConstraints.tightFor(
                              width: 32, height: 32),
                          padding: const EdgeInsets.all(8),
                          tooltip: 'Next period',
                          onPressed: () => setState(() => periodOffset++),
                          icon: const DesignIcon('14_6_imgNextPeriod')),
                    ]),
                    const SizedBox(height: 4),
                    SizedBox(
                        height: 18,
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const DesignIcon('14_6_imgCostDataPoint'),
                              const SizedBox(width: 5),
                              Text('Usage (kWh)',
                                  style: TextStyle(fontSize: 9, color: muted)),
                              const SizedBox(width: 20),
                              const DesignIcon('14_6_imgCostDataPoint1'),
                              const SizedBox(width: 5),
                              Text('Cost (₱)',
                                  style: TextStyle(fontSize: 9, color: muted))
                            ])),
                    SizedBox(
                        height: 76,
                        child: c.appliances.isEmpty
                            ? Center(
                                child: Text(
                                    c.t(
                                        'Add your first appliance to estimate your usage.'),
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(fontSize: 12, color: muted)))
                            : CustomPaint(
                                size: const Size(double.infinity, 76),
                                painter: UsagePainter(
                                    total: c.monthlyKwh * factor,
                                    rate: c.rate,
                                    color: muted,
                                    scale: scale))),
                    const SizedBox(height: 4),
                    Text(
                        'Estimate from your current schedule, not meter readings.',
                        style: TextStyle(fontSize: 9, color: muted)),
                  ])),
          const SizedBox(height: 6),
          SurfaceCard(
              padding: const EdgeInsets.all(10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const DesignIcon('14_6_imgAppliancesPlug'),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(c.t('Appliance Details'),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600))),
                      FilledButton(
                          onPressed: () => edit(),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(40, 36),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const DesignIcon('14_6_imgAdd'),
                            const SizedBox(width: 5),
                            Text(c.t('Add Appliance'),
                                style: const TextStyle(fontSize: 10))
                          ]))
                    ]),
                    const SizedBox(height: 6),
                    if (c.appliances.isEmpty)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: Text(c.t('No appliances yet.'))))
                    else
                      LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                      width:
                                          math.max(constraints.maxWidth, 340),
                                      child: Column(children: [
                                        _row(
                                            [
                                              'Appliance',
                                              'Power',
                                              'Hours',
                                              'Energy',
                                              'Cost'
                                            ].map(c.t).toList(),
                                            heading: true),
                                        for (final a in c.appliances)
                                          InkWell(
                                              onTap: () => edit(a),
                                              child: _row([
                                                a.name,
                                                '${a.watts.toStringAsFixed(0)} W',
                                                '${(a.hoursPerDay * a.daysPerMonth * a.quantity).toStringAsFixed(1)} h',
                                                '${a.monthlyKwh.toStringAsFixed(1)} kWh',
                                                money(a.monthlyKwh * c.rate)
                                              ], appliance: a)),
                                        _row([
                                          c.t('Total'),
                                          '',
                                          '${c.monthlyHours.toStringAsFixed(1)} h',
                                          '${c.monthlyKwh.toStringAsFixed(1)} kWh',
                                          money(c.monthlyKwh * c.rate)
                                        ], heading: true),
                                      ])))),
                    TextButton(
                        onPressed: () async {
                          final input =
                              TextEditingController(text: c.rate.toString());
                          final key = GlobalKey<FormState>();
                          final value = await showDialog<double>(
                              context: context,
                              builder: (context) => AlertDialog(
                                      title:
                                          Text(c.t('Estimated rate (PHP/kWh)')),
                                      content: Form(
                                          key: key,
                                          child: TextFormField(
                                              controller: input,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              decoration: InputDecoration(
                                                  helperText: c.t(
                                                      'Sample rate; update using your bill.')),
                                              validator: (v) {
                                                final n =
                                                    double.tryParse(v ?? '');
                                                return n == null ||
                                                        !n.isFinite ||
                                                        n < 0 ||
                                                        n > 10000
                                                    ? 'Enter a rate from 0 to 10000'
                                                    : null;
                                              })),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text(c.t('Cancel'))),
                                        FilledButton(
                                            onPressed: () {
                                              if (key.currentState!
                                                  .validate()) {
                                                Navigator.pop(context,
                                                    double.parse(input.text));
                                              }
                                            },
                                            child: Text(c.t('Save changes')))
                                      ]));
                          input.dispose();
                          if (value != null) {
                            try {
                              await c.preference('rate', '$value');
                            } catch (e) {
                              if (context.mounted) showFailure(context, e);
                            }
                          }
                        },
                        child: Text(
                            '₱${c.rate}/kWh • ${c.t('Sample rate; update using your bill.')}',
                            style: const TextStyle(fontSize: 10))),
                  ])),
        ]);
  }

  Widget _row(List<String> values,
      {bool heading = false, Appliance? appliance}) {
    String icon = '14_6_imgOthersFansEtcIcon';
    final name = appliance?.name.toLowerCase() ?? '';
    if (name.contains('air') || name.contains('ac')) {
      icon = '14_6_imgAirConditionerAcIcon';
    }
    if (name.contains('refrig')) icon = '14_6_imgRefrigeratorIcon';
    if (name.contains('light')) icon = '14_6_imgLightsIcon';
    if (name.contains('tv')) icon = '14_6_imgTvIcon';
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
            color: heading
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : null,
            borderRadius: BorderRadius.circular(8)),
        child: Row(
            children: List.generate(
                5,
                (i) => Expanded(
                    flex: i == 0 ? 3 : 2,
                    child: Row(children: [
                      if (i == 0 && appliance != null) ...[
                        DesignIcon(icon),
                        const SizedBox(width: 4)
                      ],
                      Expanded(
                          child: Text(values[i],
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: heading
                                      ? FontWeight.w600
                                      : FontWeight.w400),
                              textAlign:
                                  i == 4 ? TextAlign.right : TextAlign.left)),
                    ])))));
  }
}

class UsagePainter extends CustomPainter {
  UsagePainter(
      {required this.total,
      required this.rate,
      required this.color,
      required this.scale});
  final double total, rate;
  final Color color;
  final int scale;
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width - 70, height = size.height - 24;
    final factors = scale < 2
        ? [1.0]
        : scale == 2
            ? [7 / 30, 7 / 30, 7 / 30, 9 / 30]
            : [.25, .25, .25, .25];
    final top = math.max(1.0, total * factors.reduce(math.max) * 1.25);
    void label(String value, Offset at, {bool right = false}) {
      final text = TextPainter(
          text: TextSpan(
              text: value,
              style: TextStyle(fontSize: 8, color: color, fontFamily: 'Inter')),
          textDirection: TextDirection.ltr)
        ..layout();
      text.paint(canvas, Offset(right ? at.dx - text.width : at.dx, at.dy));
    }

    final points = <Offset>[];
    for (var i = 0; i < 5; i++) {
      final y = height - i * height / 4;
      canvas.drawLine(Offset(30, y), Offset(size.width - 40, y),
          Paint()..color = color.withValues(alpha: .13));
      label((top * i / 4).toStringAsFixed(0), Offset(25, y - 4), right: true);
      label((top * i / 4 * rate).toStringAsFixed(0),
          Offset(size.width - 35, y - 4));
    }
    for (var i = 0; i < factors.length; i++) {
      final value = total * factors[i],
          x = 30 + width * (i + .5) / factors.length;
      final bar = Rect.fromLTWH(
          x - 16, height - value / top * height, 32, value / top * height);
      canvas.drawRRect(
          RRect.fromRectAndRadius(bar, const Radius.circular(3)),
          Paint()
            ..shader = const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xff6ac778), green])
                .createShader(Rect.fromLTWH(0, 0, size.width, height)));
      points.add(Offset(x, bar.top));
      final text = scale == 0
          ? 'Day'
          : scale == 1
              ? 'Week'
              : scale == 2
                  ? 'Week ${i + 1}'
                  : 'Q${i + 1}';
      label(text, Offset(x - 14, height + 8));
    }
    if (rate > 0) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xff8cbe32)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      for (final p in points) {
        canvas.drawCircle(p, 3, Paint()..color = const Color(0xff8cbe32));
      }
    }
  }

  @override
  bool shouldRepaint(UsagePainter old) =>
      old.total != total ||
      old.scale != scale ||
      old.rate != rate ||
      old.color != color;
}
