import type { ApplianceRepository, BillRepository, MiraContextProvider, SettingsRepository } from '../../../shared/contracts';
import { estimateUsage } from '../../../shared/energy';

export function createMiraContextProvider(
  appliances: ApplianceRepository,
  bills: BillRepository,
  settings: SettingsRepository,
): MiraContextProvider {
  return {
    async getContext() {
      const [items, bill, preferences] = await Promise.all([
        appliances.list(), bills.latestReviewed(), settings.get(),
      ]);
      return {
        appliances: items,
        estimates: items.map(item => estimateUsage(item, preferences.estimatedRatePerKwh)),
        latestReviewedBill: bill,
        language: preferences.language,
        estimatedRatePerKwh: preferences.estimatedRatePerKwh,
      };
    },
  };
}
