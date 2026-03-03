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

export interface ThinkingStep {
  type: 'status' | 'thinking' | 'tool_use' | 'tool_status';
  text: string;
  timestamp: Date;
}

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
  thinkingSteps?: ThinkingStep[];
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
