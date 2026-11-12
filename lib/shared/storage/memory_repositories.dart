import '../contracts/repositories.dart';
import '../models/appliance.dart';
import '../models/bill.dart';
import '../models/daily_usage.dart';

class MemoryApplianceRepository implements ApplianceRepository {
  final _items = <String, Appliance>{};
  @override
  Future<List<Appliance>> list() async => _items.values.toList();
  @override
  Future<void> save(Appliance appliance) async {
    appliance.monthlyKwh;
    _items[appliance.id] = appliance;
  }

  @override
  Future<void> remove(String id) async {
    _items.remove(id);
  }
}

class MemoryBillRepository implements BillRepository {
  final _items = <String, Bill>{};
  @override
  Future<List<Bill>> list() async => _items.values.toList();
  @override
  Future<void> save(Bill bill) async {
    _items[bill.id] = bill;
  }

  @override
  Future<void> remove(String id) async {
    _items.remove(id);
  }

  @override
  Future<Bill?> latestReviewed() async {
    final items = _items.values.where((b) => b.reviewed).toList()
      ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
    return items.isEmpty ? null : items.first;
  }
}

class MemoryDailyUsageRepository implements DailyUsageRepository {
  final _items = <String, DailyUsage>{};

  String _key(DailyUsage entry) => '${entry.applianceId}:${entry.dateKey}';

  @override
  Future<List<DailyUsage>> list({DateTime? from, DateTime? through}) async =>
      _items.values.where((entry) {
        final date =
            DateTime(entry.date.year, entry.date.month, entry.date.day);
        return (from == null || !date.isBefore(from)) &&
            (through == null || !date.isAfter(through));
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<void> saveAll(List<DailyUsage> entries) async {
    for (final entry in entries) {
      if (!entry.hours.isFinite || entry.hours < 0 || entry.hours > 24) {
        throw ArgumentError('Daily usage must be between 0 and 24 hours');
      }
      if (!entry.watts.isFinite || entry.watts < 0 || entry.quantity < 1) {
        throw ArgumentError('Invalid appliance details for daily usage');
      }
    }
    for (final entry in entries) {
      _items[_key(entry)] = entry;
    }
  }

  @override
  Future<void> removeForDate(String applianceId, DateTime date) async {
    _items.removeWhere((_, e) =>
        e.applianceId == applianceId &&
        e.date.year == date.year &&
        e.date.month == date.month &&
        e.date.day == date.day);
  }

  @override
  Future<void> removeForAppliance(String applianceId) async {
    _items.removeWhere((_, entry) => entry.applianceId == applianceId);
  }
}
