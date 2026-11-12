import 'package:sqflite/sqflite.dart';

import '../../../shared/models/daily_usage.dart';

class KLoadService {
  const KLoadService(this.database);
  final Database database;

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<List<Map<String, Object?>>> transitions() =>
      database.query('kload_transitions', orderBy: 'effective_date');

  /// Applies a previously queued transition immediately after upgrading from
  /// the older next-day toggle behavior. Mode transitions are now date-based
  /// and take effect on the current local day.
  Future<void> applyPendingModeChangeNow() async {
    final today = dateKey(DateTime.now());
    final upcoming = await database.query('kload_transitions',
        where: 'effective_date > ?',
        whereArgs: [today],
        orderBy: 'effective_date');
    if (upcoming.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final enabled = upcoming.last['enabled'];
    await database.transaction((txn) async {
      await txn.delete('kload_transitions',
          where: 'effective_date > ?', whereArgs: [today]);
      await txn.insert('kload_transitions',
          {'effective_date': today, 'enabled': enabled, 'recorded_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<bool> enabledOn(DateTime date) async {
    final key = dateKey(date);
    final rows = await database.query('kload_transitions',
        where: 'effective_date <= ?',
        whereArgs: [key],
        orderBy: 'effective_date DESC',
        limit: 1);
    return rows.isNotEmpty &&
        (rows.first['enabled'] == 1 || rows.first['enabled'] == true);
  }

  Future<bool> get switchValue async {
    final today = day(DateTime.now());
    final pending = await database.query('kload_transitions',
        where: 'effective_date = ?', whereArgs: [dateKey(today)], limit: 1);
    return pending.isEmpty
        ? enabledOn(DateTime.now())
        : pending.first['enabled'] == 1;
  }

  Future<void> scheduleActivation({
    required double startingBalance,
    required double rate,
    double balanceAdjustment = 0,
    DateTime? effectiveDate,
  }) async {
    _validateAmount(startingBalance, 'Starting load balance');
    _validateAmount(rate, 'KLoad rate');
    final effective = day(effectiveDate ?? DateTime.now());
    final key = dateKey(effective);
    final now = DateTime.now().toIso8601String();
    await database.transaction((txn) async {
      // Mode changes apply now. Remove any old queued transitions so they
      // cannot unexpectedly switch the dashboard again on a later date.
      await txn.delete('kload_transitions',
          where: 'effective_date > ?', whereArgs: [key]);
      final profile =
          await txn.query('kload_profile', where: 'id = 1', limit: 1);
      final firstActivation = profile.isEmpty;
      if (firstActivation) {
        await txn.insert('kload_profile', {'id': 1, 'created_at': now});
        await txn.insert('kload_balance_events', {
          'id': 'initial-${key.replaceAll('-', '')}',
          'event_date': key,
          'event_type': 'initial',
          'amount': startingBalance,
          'note': 'Starting KLoad balance at activation',
          'recorded_at': now,
        });
      }
      if (balanceAdjustment != 0) {
        await txn.insert(
            'kload_balance_events',
            {
              'id': 'reconcile-${DateTime.now().microsecondsSinceEpoch}',
              'event_date': key,
              'event_type': 'adjustment',
              'amount': balanceAdjustment,
              'note': 'Current balance reconciled at KLoad activation',
              'recorded_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert(
          'kload_rates',
          {
            'effective_date': key,
            'rate_per_kwh': rate,
            'source': '',
            'recorded_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert(
          'kload_transitions',
          {
            'effective_date': key,
            'enabled': 1,
            'recorded_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> scheduleDeactivation({DateTime? effectiveDate}) async {
    final effective = day(effectiveDate ?? DateTime.now());
    final key = dateKey(effective);
    await database.transaction((txn) async {
      await txn.delete('kload_transitions',
          where: 'effective_date > ?', whereArgs: [key]);
      await txn.insert(
          'kload_transitions',
          {
            'effective_date': key,
            'enabled': 0,
            'recorded_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> saveRate({
    required double rate,
    DateTime? effectiveDate,
  }) async {
    _validateAmount(rate, 'KLoad rate');
    final effective =
        day(effectiveDate ?? DateTime.now().add(const Duration(days: 1)));
    await database.insert(
        'kload_rates',
        {
          'effective_date': dateKey(effective),
          'rate_per_kwh': rate,
          'source': '',
          'recorded_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> addBalanceEvent({
    required String id,
    required DateTime date,
    required double amount,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Top-up amount must be greater than zero');
    }
    await database.insert(
        'kload_balance_events',
        {
          'id': id,
          'event_date': dateKey(date),
          'event_type': 'top_up',
          'amount': amount,
          'note': 'Load top-up',
          'recorded_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<double?> rateFor(DateTime date) async {
    final rows = await database.query('kload_rates',
        where: 'effective_date <= ?',
        whereArgs: [dateKey(date)],
        orderBy: 'effective_date DESC',
        limit: 1);
    return rows.isEmpty ? null : (rows.first['rate_per_kwh'] as num).toDouble();
  }

  Future<KLoadSummary> summarize({
    required List<DailyUsage> entries,
    required Set<String> existingApplianceIds,
    DateTime? now,
  }) async {
    final current = day(now ?? DateTime.now());
    final events = await database.query('kload_balance_events',
        where: 'event_date <= ?',
        whereArgs: [dateKey(current)],
        orderBy: 'event_date, recorded_at');
    final rates = await database.query('kload_rates',
        where: 'effective_date <= ?',
        whereArgs: [dateKey(current)],
        orderBy: 'effective_date');
    final transitions = await database.query('kload_transitions',
        where: 'effective_date <= ?',
        whereArgs: [dateKey(current)],
        orderBy: 'effective_date');
    double? rateForDate(DateTime date) {
      final key = dateKey(date);
      Map<String, Object?>? selected;
      for (final rate in rates) {
        if ((rate['effective_date'] as String).compareTo(key) <= 0) {
          selected = rate;
        }
      }
      return selected == null
          ? null
          : (selected['rate_per_kwh'] as num).toDouble();
    }

    bool activeOn(DateTime date) {
      final key = dateKey(date);
      var active = false;
      for (final transition in transitions) {
        if ((transition['effective_date'] as String).compareTo(key) > 0) break;
        active = transition['enabled'] == 1 || transition['enabled'] == true;
      }
      return active;
    }

    final firstTransitions = await database.query('kload_transitions',
        where: 'enabled = 1', orderBy: 'effective_date', limit: 1);
    final firstTransition =
        firstTransitions.isEmpty ? null : firstTransitions.first;
    final start = firstTransition == null
        ? null
        : DateTime.parse(firstTransition['effective_date'] as String);
    var totalKwh = 0.0;
    var totalCost = 0.0;
    var monthKwh = 0.0;
    var monthCost = 0.0;
    var todayKwh = 0.0;
    var todayCost = 0.0;
    final monthStart = DateTime(current.year, current.month);
    for (final entry in entries) {
      if (!existingApplianceIds.contains(entry.applianceId)) continue;
      final entryDay = day(entry.date);
      if (entryDay.isAfter(current) || !activeOn(entryDay)) continue;
      final unitRate = rateForDate(entryDay);
      if (unitRate == null) continue;
      final cost = entry.kwh * unitRate;
      totalKwh += entry.kwh;
      totalCost += cost;
      if (!entryDay.isBefore(monthStart)) {
        monthKwh += entry.kwh;
        monthCost += cost;
      }
      if (entryDay == current) {
        todayKwh += entry.kwh;
        todayCost += cost;
      }
    }
    final eventBalance = events.fold<double>(
        0, (sum, event) => sum + (event['amount'] as num).toDouble());
    final todayRate = rateForDate(current);
    final initial = events
        .where((event) => event['event_type'] == 'initial')
        .fold<double>(
            0, (sum, event) => sum + (event['amount'] as num).toDouble());
    return KLoadSummary(
      activeToday: activeOn(current),
      activationDate: start,
      startingBalance: initial,
      estimatedBalance: eventBalance - totalCost,
      totalKwh: totalKwh,
      totalCost: totalCost,
      monthKwh: monthKwh,
      monthCost: monthCost,
      todayKwh: todayKwh,
      todayCost: todayCost,
      currentRate: todayRate,
      eventCount: events.length,
    );
  }

  static void _validateAmount(double value, String label) {
    if (!value.isFinite || value < 0 || value > 100000000) {
      throw ArgumentError('$label must be between 0 and 100,000,000');
    }
  }
}

class KLoadSummary {
  const KLoadSummary({
    required this.activeToday,
    required this.activationDate,
    required this.startingBalance,
    required this.estimatedBalance,
    required this.totalKwh,
    required this.totalCost,
    required this.monthKwh,
    required this.monthCost,
    required this.todayKwh,
    required this.todayCost,
    required this.currentRate,
    required this.eventCount,
  });

  final bool activeToday;
  final DateTime? activationDate;
  final double startingBalance;
  final double estimatedBalance;
  final double totalKwh;
  final double totalCost;
  final double monthKwh;
  final double monthCost;
  final double todayKwh;
  final double todayCost;
  final double? currentRate;
  final int eventCount;

  bool get hasStartingBalance => eventCount > 0;
}
