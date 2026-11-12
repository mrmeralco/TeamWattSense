export const tabs = [
  { id: 'dashboard', label: 'Dashboard' },
  { id: 'scan_bill', label: 'Scan Bill' },
  { id: 'mira', label: 'Mira' },
  { id: 'settings', label: 'Settings' },
] as const;

export type TabId = typeof tabs[number]['id'];
