import 'dart:convert';
import '../../../app/app_controller.dart';
import '../../../shared/models/appliance.dart';
import '../../../shared/models/daily_usage.dart';
import 'mira_appliance_action.dart';

bool canSaveMiraAction(MiraApplianceAction action) => [
      'name',
      'watts',
      'hours_per_day'
    ].every((key) => action.values[key] != null);
Future<String> saveMiraAction(
    AppController controller, MiraApplianceAction action,
    {String? id, DateTime? date}) async {
  final usageDate = date ?? DateTime.now();
  final newId = id ?? DateTime.now().microsecondsSinceEpoch.toString();
  if (!canSaveMiraAction(action))
    throw const FormatException(
        'Please provide appliance name, wattage and hours used.');
  final original = action.original;
  final inventory = await controller.applianceRepository.list();
  if (original != null) {
    final current = inventory.where((a) => a.id == original.id).toList();
    if (current.length != 1 ||
        jsonEncode(current.single.toMap()) != jsonEncode(original.toMap())) {
      throw const FormatException(
          'This appliance changed after Mira read it. Cancel and request the edit again.');
    }
  }
  final values = <String, Object?>{...action.values, 'mode':action.mode, 'applianceId':original?.id};
  final validated = MiraApplianceAction.parse(values, inventory);
  final a = Appliance(
      id: original?.id ?? newId,
      name: validated.values['name'] as String,
      watts: (values['watts'] as num).toDouble(),
      hoursPerDay: (values['hours_per_day'] as num).toDouble(),
      daysPerMonth: values['days_per_month'] as int,
      quantity: values['quantity'] as int);
  if (controller.dailyUsageRepository == null) {
    throw StateError('Daily usage storage is unavailable');
  }
  final dateKey =
      '${usageDate.year.toString().padLeft(4, '0')}-${usageDate.month.toString().padLeft(2, '0')}-${usageDate.day.toString().padLeft(2, '0')}';
  final session = controller.popUsageSessions['${a.id}:$dateKey'];
  if (session != null) {
    final recordedHours =
        session['stop']!.difference(session['start']!).inMinutes / 60;
    if ((recordedHours - a.hoursPerDay).abs() > .01) {
      throw const FormatException(
          'This entry has POP on/off times. Change its times in Dashboard to update the hours consistently. Nothing was changed.');
    }
  }
  await controller.saveAppliance(a);
  {
    await controller.saveDailyUsages([
      DailyUsage(
          applianceId: a.id,
          date: usageDate,
          hours: a.hoursPerDay,
          watts: a.watts,
          quantity: a.quantity)
    ]);
  }

  return '${original == null ? 'Added' : 'Updated'} ${a.name}: ${a.watts} W, ${a.hoursPerDay} hours. Saved for today; view today in Dashboard.';
}

