import '../models/appliance.dart';
import '../models/bill.dart';
import '../models/daily_usage.dart';

abstract interface class ApplianceRepository {
  Future<List<Appliance>> list();
  Future<void> save(Appliance appliance);
  Future<void> remove(String id);
}

abstract interface class BillRepository {
  Future<List<Bill>> list();
  Future<void> save(Bill bill);
  Future<void> remove(String id);
  Future<Bill?> latestReviewed();
}

abstract interface class DailyUsageRepository {
  Future<List<DailyUsage>> list({DateTime? from, DateTime? through});
  Future<void> saveAll(List<DailyUsage> entries);
  Future<void> removeForDate(String applianceId, DateTime date);
  Future<void> removeForAppliance(String applianceId);
}

abstract interface class CloudSyncService {
  // Implement authentication, per-user rules, retry queue and conflict policy first.
  Future<void> synchronize();
}
