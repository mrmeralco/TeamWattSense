import type { ApplianceRepository, BillRepository, SettingsRepository } from '../src/shared/contracts';
import type { Appliance, Bill, Settings } from '../src/shared/models';

const clone = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T;

export function createMockRepositories(): {
  appliances: ApplianceRepository;
  bills: BillRepository;
  settings: SettingsRepository;
} {
  const appliances = new Map<string, Appliance>([
    ['sample-fan', { id: 'sample-fan', name: 'Sample electric fan', quantity: 1,
      wattage: 60, hoursPerDay: 8, daysPerMonth: 30 }],
  ]);
  const bills = new Map<string, Bill>();
  // Demonstration rate only; not a current Meralco tariff.
  let settings: Settings = { language: 'en', theme: 'light', estimatedRatePerKwh: 12 };

  return {
    appliances: {
      async list() { return clone([...appliances.values()]); },
      async save(item) { appliances.set(item.id, clone(item)); },
      async remove(id) { appliances.delete(id); },
    },
    bills: {
      async list() { return clone([...bills.values()]); },
      async save(item) { bills.set(item.id, clone(item)); },
      async latestReviewed() {
        const reviewed = [...bills.values()].filter(item => item.reviewStatus === 'reviewed');
        reviewed.sort((a, b) => b.periodEnd.localeCompare(a.periodEnd));
        return clone(reviewed[0] ?? null);
      },
    },
    settings: {
      async get() { return clone(settings); },
      async save(value) { settings = clone(value); },
    },
  };
}
