import type { Appliance, UsageEstimate } from './models';

export function estimateUsage(appliance: Appliance, rate: number): UsageEstimate {
  const values = [appliance.wattage, appliance.hoursPerDay, appliance.daysPerMonth, rate];
  if (values.some(value => !Number.isFinite(value) || value < 0)
      || !Number.isInteger(appliance.quantity) || appliance.quantity < 1
      || appliance.hoursPerDay > 24 || appliance.daysPerMonth > 31) {
    throw new Error('Invalid appliance usage or electricity rate.');
  }
  const monthlyKwh = appliance.wattage / 1000 * appliance.hoursPerDay
    * appliance.daysPerMonth * appliance.quantity;
  return { applianceId: appliance.id, monthlyKwh, estimatedMonthlyCost: monthlyKwh * rate };
}
