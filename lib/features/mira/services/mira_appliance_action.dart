import '../../../shared/models/appliance.dart';

class MiraReply {
  const MiraReply(this.text, [this.action]);
  final String text;
  final MiraApplianceAction? action;
}

class MiraApplianceAction {
  const MiraApplianceAction(this.mode, this.values, this.original);
  final String mode;
  final Map<String, Object?> values;
  final Appliance? original;
  static MiraApplianceAction parse(
      Map<String, Object?> args, List<Appliance> inventory) {
    final mode = args['mode'];
    if (mode != 'add' && mode != 'edit') {
      throw const FormatException('Unsupported appliance action.');
    }
    Appliance? original;
    if (mode == 'edit') {
      final matches =
          inventory.where((a) => a.id == args['applianceId']).toList();
      if (matches.length != 1) {
        throw const FormatException('Choose one existing appliance to edit.');
      }
      original = matches.single;
    }
    final values = <String, Object?>{if (original != null) ...original.toMap()};
    for (final key in [
      'name',
      'watts',
      'hours_per_day',
      'days_per_month',
      'quantity'
    ]) {
      if (args[key] != null) values[key] = args[key];
    }
    if (values['name'] != null &&
        (values['name'] is! String ||
            (values['name'] as String).trim().isEmpty ||
            (values['name'] as String).length > 80)) {
      throw const FormatException('Appliance name must be 1–80 characters.');
    }
    for (final key in [
      'watts',
      'hours_per_day',
      'days_per_month',
      'quantity'
    ]) {
      final v = values[key];
      if (v == null) continue;
      final max = {
        'watts': 100000,
        'hours_per_day': 24,
        'days_per_month': 31,
        'quantity': 1000
      }[key]!;
      if (v is! num ||
          !v.isFinite ||
          v < (key == 'quantity' ? 1 : 0) ||
          v > max ||
          (['days_per_month', 'quantity'].contains(key) && v != v.round())) {
        throw FormatException(
            'Invalid appliance $key. Please enter a valid value.');
      }
    }
    for (final key in ['quantity', 'days_per_month']) {
      if (values[key] is num) values[key] = (values[key] as num).toInt();
    }
    return MiraApplianceAction(mode as String, values, original);
  }
}
