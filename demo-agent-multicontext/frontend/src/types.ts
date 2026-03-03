export type UserType = 'anonymous' | 'low' | 'full';

export interface Station {
  id: string;
  name: string;
  callSign: string;
  market: string;
  domain: string;
}

export interface DemoUser {
  key: string;
  id: string;
  name: string;
  stationId: string;
  stationName: string;
  tier: string;
}

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
}

export interface AgentContext {
  userType: UserType;
  stationId: string;
  userId?: string;
  userName?: string;
  memberTier?: string;
}

export interface ApiPayloadPreview {
  endpoint: string;
  headers: Record<string, string>;
  body: Record<string, unknown>;
}
