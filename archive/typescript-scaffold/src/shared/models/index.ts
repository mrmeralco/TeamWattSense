export interface Appliance {
  id: string;
  name: string;
  quantity: number;
  wattage: number;
  hoursPerDay: number;
  daysPerMonth: number;
}

export interface BillCharge {
  name: string;
  amount: number;
  explanation: string;
}

export interface Bill {
  id: string;
  periodStart: string;
  periodEnd: string;
  consumptionKwh: number;
  totalAmount: number;
  dueDate: string;
  charges: BillCharge[];
  reviewStatus: 'pending' | 'reviewed';
}

export interface Settings {
  language: 'en' | 'fil';
  theme: 'light' | 'dark';
  estimatedRatePerKwh: number;
}

export interface UsageEstimate {
  applianceId: string;
  monthlyKwh: number;
  estimatedMonthlyCost: number;
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  createdAt: string;
}

export interface MiraContext {
  appliances: Appliance[];
  estimates: UsageEstimate[];
  latestReviewedBill: Bill | null;
  language: Settings['language'];
  estimatedRatePerKwh: number;
}
