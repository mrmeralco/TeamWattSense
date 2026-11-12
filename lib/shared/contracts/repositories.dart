import '../models/appliance.dart';
import '../models/bill.dart';

abstract interface class ApplianceRepository {
  Future<List<Appliance>> list();
  Future<void> save(Appliance appliance);
  Future<void> remove(String id);
}

abstract interface class BillRepository {
  Future<List<Bill>> list();
  Future<void> save(Bill bill);
  Future<Bill?> latestReviewed();
}

abstract interface class CloudSyncService {
  // Implement authentication, per-user rules, retry queue and conflict policy first.
  Future<void> synchronize();
}
