import type { Appliance, Bill, ChatMessage, MiraContext, Settings } from '../models';

export interface ApplianceRepository {
  list(): Promise<Appliance[]>;
  save(appliance: Appliance): Promise<void>;
  remove(id: string): Promise<void>;
}

export interface BillRepository {
  list(): Promise<Bill[]>;
  save(bill: Bill): Promise<void>;
  latestReviewed(): Promise<Bill | null>;
}

export interface SettingsRepository {
  get(): Promise<Settings>;
  save(settings: Settings): Promise<void>;
}

export interface MiraContextProvider {
  getContext(): Promise<MiraContext>;
}

export interface BillExtractionService {
  // Return draft values only. The user must review extraction before saving as reviewed.
  extract(file: { bytes: Uint8Array; mimeType: string }): Promise<Partial<Omit<Bill, 'reviewStatus'>>>;
}

export interface ChatService {
  reply(messages: ChatMessage[], context: MiraContext): Promise<ChatMessage>;
}
