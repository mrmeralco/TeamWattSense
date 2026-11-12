import '../contracts/repositories.dart';
import '../models/appliance.dart';
import '../models/bill.dart';

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
  Future<Bill?> latestReviewed() async {
    final items = _items.values.where((b) => b.reviewed).toList()
      ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
    return items.isEmpty ? null : items.first;
  }
}
