import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/app_controller.dart';
import '../../../shared/components/design_widgets.dart';
import '../../../shared/models/appliance.dart';
import '../../../shared/models/daily_usage.dart';
import '../../../shared/theme/wattwise_theme.dart';
import '../models/appliance_catalog_item.dart';
import '../services/appliance_catalog_repository.dart';

class ApplianceForm extends StatefulWidget {
  const ApplianceForm(
      {super.key, required this.controller, this.appliance, this.usageDate});
  final AppController controller;
  final Appliance? appliance;
  final DateTime? usageDate;
  @override
  State<ApplianceForm> createState() => _ApplianceFormState();
}

class _ApplianceFormState extends State<ApplianceForm> {
  final _form = GlobalKey<FormState>();
  final _catalog = ApplianceCatalogRepository();
  late final TextEditingController name, watts, dailyHours;
  TimeOfDay? turnedOnAt, turnedOffAt;
  bool busy = false;

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void _updateSessionDuration() {
    final start = turnedOnAt;
    final stop = turnedOffAt;
    if (start == null || stop == null) {
      dailyHours.clear();
      return;
    }
    final startMinute = start.hour * 60 + start.minute;
    var stopMinute = stop.hour * 60 + stop.minute;
    if (stopMinute > startMinute) {
      dailyHours.text = ((stopMinute - startMinute) / 60).toStringAsFixed(2);
    } else {
      dailyHours.clear();
    }
  }

  Widget _sessionTimeField(BuildContext context, String label, TimeOfDay? value,
      ValueChanged<TimeOfDay> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : () async {
              final picked = await showTimePicker(context: context, initialTime: value ?? TimeOfDay.now());
              if (picked != null) onChanged(picked);
            },
            icon: const Icon(Icons.access_time),
            label: Text(value?.format(context) ?? 'Select time'),
          ),
        ]),
      );
  @override
  void initState() {
    super.initState();
    final a = widget.appliance;
    name = TextEditingController(text: a?.name);
    watts = TextEditingController(text: a?.watts.toString() ?? '');
    final date = widget.usageDate ?? DateTime.now();
    final entries = a == null
        ? <DailyUsage>[]
        : widget.controller.dailyUsages.where((e) =>
            e.applianceId == a.id &&
            e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day).toList();
    dailyHours = TextEditingController(
        text: entries.isEmpty ? '' : entries.first.hours.toString());
    final session = a == null ? null : widget.controller.popUsageSessions['${a.id}:${_dateKey(date)}'];
    if (session != null) {
      turnedOnAt = TimeOfDay.fromDateTime(session['start']!);
      turnedOffAt = TimeOfDay.fromDateTime(session['stop']!);
      dailyHours.text = (session['stop']!.difference(session['start']!).inMinutes / 60).toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    for (final c in [name, watts, dailyHours]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !_form.currentState!.validate()) return;
    final date = widget.usageDate ?? DateTime.now();
    final popDay = widget.controller.popForDate(date);
    if (popDay) {
      if (turnedOnAt == null || turnedOffAt == null) {
        showFailure(context, StateError('Enter when the appliance was turned on and off.'));
        return;
      }
      final start = DateTime(date.year, date.month, date.day, turnedOnAt!.hour, turnedOnAt!.minute);
      final stop = DateTime(date.year, date.month, date.day, turnedOffAt!.hour, turnedOffAt!.minute);
      if (!stop.isAfter(start)) {
        showFailure(context, StateError('The off time must be later than the on time on the selected day.'));
        return;
      }
      dailyHours.text = (stop.difference(start).inMinutes / 60).toStringAsFixed(2);
    }
    setState(() => busy = true);
    try {
      final appliance = Appliance(
          id: widget.appliance?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          name: name.text.trim(),
          watts: double.parse(watts.text),
          hoursPerDay: double.parse(dailyHours.text),
          daysPerMonth: widget.appliance?.daysPerMonth ?? 30,
          quantity: widget.appliance?.quantity ?? 1);
      await widget.controller.saveAppliance(appliance);
      await widget.controller.saveDailyUsages([
        DailyUsage(
            applianceId: appliance.id,
            date: date,
            hours: double.parse(dailyHours.text),
            watts: appliance.watts,
            quantity: appliance.quantity)
      ]);
      if (popDay) {
        final start = DateTime(date.year, date.month, date.day, turnedOnAt!.hour, turnedOnAt!.minute);
        final stop = DateTime(date.year, date.month, date.day, turnedOffAt!.hour, turnedOffAt!.minute);
        await widget.controller.savePopUsageSession(appliance.id, date, start, stop);
      }
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
    final popDay = c.popForDate(widget.usageDate ?? DateTime.now());
    final dailyEstimate = (double.tryParse(watts.text) ?? 0) *
        (double.tryParse(dailyHours.text) ?? 0) / 1000;
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
                        n < 0 ||
                        (max != null && n > max) ||
                        (integer && int.tryParse(v ?? '') == null)) {
                      return 'Enter a valid ${integer ? 'whole ' : ''}number${max == null ? '' : ' up to $max'}';
                    }
                    return null;
                  })
            ]));
    Widget applianceNameInput() {
      if (widget.appliance != null) {
        return field('Appliance name', name, '44_41_imgFan');
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.t('Appliance name'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Autocomplete<ApplianceCatalogItem>(
          initialValue: TextEditingValue(text: name.text),
          displayStringForOption: (option) => option.name,
          optionsBuilder: (value) async {
            final query = value.text.trim();
            if (query.length < 2) return const <ApplianceCatalogItem>[];
            final results = await _catalog.search(query);
            return [...results, ApplianceCatalogItem.custom(query)];
          },
          onSelected: (option) {
            name.text = option.name;
            if (option.isCustom || option.watts == null) {
              watts.clear();
            } else {
              watts.text = option.watts!.toStringAsFixed(
                  option.watts! == option.watts!.roundToDouble() ? 0 : 2);
            }
            setState(() {});
          },
          fieldViewBuilder: (context, input, focusNode, onFieldSubmitted) =>
              TextFormField(
            controller: input,
            focusNode: focusNode,
            enabled: !busy,
            onChanged: (value) => name.text = value,
            decoration: InputDecoration(
              prefixIcon: const Padding(
                padding: EdgeInsets.all(12),
                child: DesignIcon('44_41_imgFan'),
              ),
              hintText: c.t('Search appliances or enter a custom name'),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? c.t('Enter a name')
                : null,
            onFieldSubmitted: (_) => onFieldSubmitted(),
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300, maxWidth: 560),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: options.map((option) {
                    final subtitle = option.isCustom
                        ? c.t('Enter wattage manually')
                        : option.watts == null
                            ? c.t('Wattage unavailable — enter it manually')
                            : '${option.watts!.toStringAsFixed(option.watts! == option.watts!.roundToDouble() ? 0 : 2)} W';
                    return ListTile(
                      dense: true,
                      title: Text(option.isCustom
                          ? '${c.t('Use custom appliance')}: ${option.name}'
                          : option.name),
                      subtitle: Text(subtitle),
                      onTap: () => onSelected(option),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ]);
    }
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
                      Text(c.t(
                          'Daily entry for ${DateFormat.yMMMMd().format(widget.usageDate ?? DateTime.now())}')),
                      const SizedBox(height: 32),
                      applianceNameInput(),
                      field('Power rating (Wattage)', watts, '44_41_imgPower',
                          unit: 'W', max: 1000000),
                      if (popDay) ...[
                        Text(c.t('POP usage time (estimate only)'),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _sessionTimeField(context, c.t('Turned on at'), turnedOnAt,
                            (value) => setState(() { turnedOnAt = value; _updateSessionDuration(); })),
                        _sessionTimeField(context, c.t('Turned off at'), turnedOffAt,
                            (value) => setState(() { turnedOffAt = value; _updateSessionDuration(); })),
                        Text('${c.t('Hours used per day')}: ${dailyHours.text.isEmpty ? '—' : dailyHours.text}',
                            style: const TextStyle(fontSize: 12)),
                        Text(c.t('Enter one on/off interval for this appliance on the selected date.'),
                            style: const TextStyle(fontSize: 11)),
                      ] else
                        field('Hours used per day', dailyHours, '44_41_imgClock',
                            unit: 'hours', max: 24),
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
                                      '${dailyEstimate.isFinite ? dailyEstimate.toStringAsFixed(2) : '—'} kWh',
                                      style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700)),
                                  Text(c.t(
                                      'Based on wattage and hours used per day.'),
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
