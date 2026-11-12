import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../app/app_controller.dart';
import '../../../shared/components/design_widgets.dart';
import '../../../shared/models/appliance.dart';
import '../../../shared/theme/wattwise_theme.dart';
import 'appliance_form.dart';
import 'kload_dashboard_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen(
      {super.key, required this.controller, required this.onSettings});
  final AppController controller;
  final VoidCallback onSettings;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int scale = 1;
  int periodOffset = 0;
  int applianceDayOffset = 0;
  Timer? _dayRefreshTimer;
  String _lastLocalDay = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastLocalDay = _todayKey;
    _scheduleDayRefresh();
  }

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  void _scheduleDayRefresh() {
    _dayRefreshTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dayRefreshTimer = Timer(nextDay.difference(now), _refreshForNewDay);
  }

  void _refreshForNewDay() {
    if (!mounted) return;
    final today = _todayKey;
    if (today != _lastLocalDay) {
      _lastLocalDay = today;
      setState(() {});
    }
    _scheduleDayRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshForNewDay();
  }

  @override
  void dispose() {
    _dayRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String money(double n) =>
      NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2)
          .format(n);
  DateTime get applianceDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + applianceDayOffset);
  }

  void edit([Appliance? a]) => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => ApplianceForm(
              controller: widget.controller,
              appliance: a,
              usageDate: applianceDate)));

  DateTime _periodStart(DateTime now, int scale, int offset) {
    if (scale == 0) return DateTime(now.year, now.month + offset);
    if (scale == 1) return DateTime(now.year + offset, 1);
    return DateTime(2024, 1);
  }

  double? _recordedBucket(AppController c, DateTime from, DateTime through) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(through.year, through.month, through.day);
    final hasEntry = c.dailyUsages.any((entry) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      return !day.isBefore(start) && !day.isAfter(end);
    });
    return hasEntry ? c.recordedKwh(start, end) : null;
  }

  List<double?> _periodBuckets(AppController c, int scale, DateTime start) {
    if (scale == 0) {
      final days = DateTime(start.year, start.month + 1, 0).day;
      final weekCount = (days / 7).ceil();
      return List.generate(weekCount, (i) {
        final firstDay = i * 7 + 1;
        final lastDay = math.min(firstDay + 6, days).toInt();
        final from = DateTime(start.year, start.month, firstDay);
        final through = DateTime(start.year, start.month, lastDay);
        return _recordedBucket(c, from, through);
      });
    }
    if (scale == 1) {
      return List.generate(12, (i) {
        final from = DateTime(start.year, i + 1);
        return _recordedBucket(c, from, DateTime(start.year, i + 2, 0));
      });
    }
    final currentYear = DateTime.now().year;
    final yearCount = math.max(0, currentYear - start.year + 1);
    return List.generate(yearCount, (i) {
      final year = start.year + i;
      return _recordedBucket(c, DateTime(year, 1), DateTime(year, 12, 31));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final now = DateTime.now();
    if (c.kloadForDate(DateTime(now.year, now.month, now.day))) {
      return KLoadDashboardScreen(controller: c);
    }
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget summary(String label, String value, String note) => Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.t(label), style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 12),
          Row(children: [
            if (label == 'Usage so far') ...[
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
    final period = _periodStart(now, scale, periodOffset);
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month);
    final monthUsage = c.recordedKwh(monthStart, today);
    final popEstimate = c.popGenerationEstimate(monthStart, today);
    final buckets = _periodBuckets(c, scale, period);
    final visibleAppliances = c.appliances.where((appliance) {
      return c.dailyUsages.any((entry) =>
          entry.applianceId == appliance.id &&
          entry.date.year == applianceDate.year &&
          entry.date.month == applianceDate.month &&
          entry.date.day == applianceDate.day);
    }).toList();
    final periodLabel = scale == 0
        ? DateFormat.yMMM().format(period)
        : scale == 1
            ? '${period.year}'
            : '${period.year}–${now.year}';
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
                        'Usage so far',
                        '${monthUsage.toStringAsFixed(1)} kWh',
                        DateFormat.yMMM().format(now)),
                    Container(
                        height: 72,
                        width: 1,
                        color: const Color(0xff79b78e),
                        margin: const EdgeInsets.symmetric(horizontal: 16)),
                    summary('Cost so far', money(monthUsage * c.billRate),
                        '₱${c.billRate.toStringAsFixed(2)}/kWh • ${c.t('Bill average rate')}'),
                  ]))),
          const SizedBox(height: 6),
          if (popEstimate != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                    '${c.t('POP generation estimate only')}: ${money(popEstimate)} • ${c.t('Estimate, not full bill cost')}',
                    style: TextStyle(fontSize: 11, color: muted))),
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
                              labels:
                                  ['Week', 'Month', 'Year'].map(c.t).toList(),
                              selected: scale,
                              onChanged: (v) => setState(() {
                                    scale = v;
                                    periodOffset = 0;
                                  })))
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      if (scale < 2)
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
                              child: Text('$periodLabel • ${c.t('Recorded')}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)))),
                      if (scale < 2)
                        IconButton(
                            constraints: const BoxConstraints.tightFor(
                                width: 32, height: 32),
                            padding: const EdgeInsets.all(8),
                            tooltip: 'Next period',
                            onPressed: periodOffset < 0
                                ? () => setState(() => periodOffset++)
                                : null,
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
                            ])),
                    SizedBox(
                        height: 76,
                        child: c.appliances.isEmpty
                            ? Center(
                                child: Text(
                                    c.t(
                                        'Add an appliance and enter its daily hours to see recorded usage.'),
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(fontSize: 12, color: muted)))
                            : buckets.every((value) => value == null)
                                ? Center(
                                    child: Text(
                                        c.t(
                                            'No entries recorded for this period.'),
                                        style: TextStyle(
                                            fontSize: 11, color: muted)))
                                : CustomPaint(
                                    size: const Size(double.infinity, 76),
                                    painter: UsagePainter(
                                        values: buckets,
                                        scale: scale,
                                        color: muted))),
                    const SizedBox(height: 4),
                    Text(
                        'Only manually entered daily usage is included. Missing days are not counted as zero.',
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
                    Row(children: [
                      IconButton(
                          tooltip: c.t('Previous day'),
                          onPressed: () => setState(() => applianceDayOffset--),
                          icon: const Icon(Icons.arrow_back_ios_new, size: 16)),
                      Expanded(
                          child: Text(DateFormat.yMMMMd().format(applianceDate),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                      IconButton(
                          tooltip: c.t('Next day'),
                          onPressed: applianceDayOffset >= 0
                              ? null
                              : () => setState(() => applianceDayOffset++),
                          icon: const Icon(Icons.arrow_forward_ios, size: 16)),
                    ]),
                    const SizedBox(height: 6),
                    if (c.appliances.isEmpty)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: Text(c.t('No appliances yet.'))))
                    else if (visibleAppliances.isEmpty)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                              child: Text(c.t(
                                  'No appliances were recorded by this date.'))))
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
                                              'Hours',
                                              'Rate',
                                              'Cost'
                                            ].map(c.t).toList(),
                                            heading: true),
                                        for (final a in visibleAppliances)
                                          Builder(builder: (context) {
                                            final entry = c.dailyUsages
                                                .where((e) =>
                                                    e.applianceId == a.id &&
                                                    e.date.year ==
                                                        applianceDate.year &&
                                                    e.date.month ==
                                                        applianceDate.month &&
                                                    e.date.day ==
                                                        applianceDate.day)
                                                .toList();
                                            final usage = entry.isEmpty
                                                ? null
                                                : entry.first;
                                            return InkWell(
                                                onTap: () => edit(a),
                                                child: _row([
                                                  a.name,
                                                  usage == null
                                                      ? '—'
                                                      : '${usage.hours.toStringAsFixed(1)} h',
                                                  '${c.billRate.toStringAsFixed(2)} ₱/kWh',
                                                  usage == null
                                                      ? '—'
                                                      : money(usage.kwh *
                                                          c.billRate)
                                                ], appliance: a));
                                          }),
                                      ])))),
                    if (visibleAppliances.isNotEmpty &&
                        !c.hasUsageForDay(applianceDate))
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                              c.t('No entries for this day. Tap an appliance to add its daily use.'),
                              style: TextStyle(fontSize: 11, color: muted))),
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
                values.length,
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
                              textAlign: i == values.length - 1
                                  ? TextAlign.right
                                  : TextAlign.left)),
                    ])))));
  }
}

class UsagePainter extends CustomPainter {
  UsagePainter(
      {required this.values, required this.color, required this.scale});
  final List<double?> values;
  final Color color;
  final int scale;
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width - 70, height = size.height - 24;
    final maxValue = values.fold<double>(
        0,
        (current, value) =>
            value == null ? current : math.max(current, value).toDouble());
    final top = math.max(1.0, maxValue * 1.25).toDouble();
    void label(String value, Offset at,
        {bool right = false, bool centered = false}) {
      final text = TextPainter(
          text: TextSpan(
              text: value,
              style: TextStyle(fontSize: 8, color: color, fontFamily: 'Inter')),
          textDirection: TextDirection.ltr)
        ..layout();
      final dx = centered
          ? at.dx - text.width / 2
          : right
              ? at.dx - text.width
              : at.dx;
      text.paint(canvas, Offset(dx, at.dy));
    }

    for (var i = 0; i < 5; i++) {
      final y = height - i * height / 4;
      canvas.drawLine(Offset(30, y), Offset(size.width - 40, y),
          Paint()..color = color.withValues(alpha: .13));
      label((top * i / 4).toStringAsFixed(0), Offset(25, y - 4), right: true);
    }
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final x = 30 + width * (i + .5) / values.length;
      final category = scale == 0
          ? 'W${i + 1}'
          : scale == 1
              ? DateFormat.MMM().format(DateTime(2020, i + 1))
              : '${2024 + i}';
      label(category, Offset(x, height + 8), centered: true);
      if (value == null) continue;
      final barWidth = math.min(32.0, width / values.length * .65).toDouble();
      final bar = Rect.fromLTWH(x - barWidth / 2, height - value / top * height,
          barWidth, value / top * height);
      canvas.drawRRect(
          RRect.fromRectAndRadius(bar, const Radius.circular(3)),
          Paint()
            ..shader = const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xff6ac778), green])
                .createShader(Rect.fromLTWH(0, 0, size.width, height)));
      if (value == 0) {
        canvas.drawCircle(Offset(x, height), 2, Paint()..color = green);
      }
    }
  }

  @override
  bool shouldRepaint(UsagePainter old) =>
      old.values != values || old.scale != scale || old.color != color;
}
