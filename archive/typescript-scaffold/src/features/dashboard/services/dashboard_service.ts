import type { ApplianceRepository, SettingsRepository } from '../../../shared/contracts';
import { estimateUsage } from '../../../shared/energy';

export async function loadDashboard(appliances: ApplianceRepository, settings: SettingsRepository) {
  const [items, preferences] = await Promise.all([appliances.list(), settings.get()]);
  const estimates = items.map(item => estimateUsage(item, preferences.estimatedRatePerKwh));
  return {
    appliances: items,
    estimates,
    totalMonthlyKwh: estimates.reduce((sum, item) => sum + item.monthlyKwh, 0),
    totalEstimatedCost: estimates.reduce((sum, item) => sum + item.estimatedMonthlyCost, 0),
  };
}
