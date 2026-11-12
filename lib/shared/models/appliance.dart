class Appliance {
  const Appliance({
    required this.id,
    required this.name,
    required this.watts,
    required this.hoursPerDay,
    required this.daysPerMonth,
    this.quantity = 1,
  });
  final String id, name;
  final double watts, hoursPerDay;
  final int daysPerMonth, quantity;

  double get monthlyKwh {
    if (!watts.isFinite ||
        watts < 0 ||
        !hoursPerDay.isFinite ||
        hoursPerDay < 0 ||
        hoursPerDay > 24 ||
        daysPerMonth < 0 ||
        daysPerMonth > 31 ||
        quantity < 1) {
      throw ArgumentError('Invalid appliance usage');
    }
    return watts / 1000 * hoursPerDay * daysPerMonth * quantity;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'watts': watts,
        'hours_per_day': hoursPerDay,
        'days_per_month': daysPerMonth,
        'quantity': quantity,
      };
  factory Appliance.fromMap(Map<String, Object?> map) => Appliance(
        id: map['id'] as String,
        name: map['name'] as String,
        watts: (map['watts'] as num).toDouble(),
        hoursPerDay: (map['hours_per_day'] as num).toDouble(),
        daysPerMonth: map['days_per_month'] as int,
        quantity: map['quantity'] as int,
      );
}
