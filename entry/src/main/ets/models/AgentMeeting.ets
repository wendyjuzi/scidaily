export interface AgentMeetingSession {
  id: string;
  userId: number;
  title: string;
  input: string;
  sourceType: string;
  sourceId: string;
  status: string;
  currentRound: number;
  memoryVersion: number;
  createdAt: string;
  updatedAt: string;
}

export interface AgentMeetingMessage {
  id: number;
  sessionId: string;
  agentKey: string;
  agentName: string;
  role: string;
  content: string;
  status: string;
  round: number;
  contextVersionStarted: number;
  createdAt: string;
  startedAt: string;
  completedAt: string;
}

export interface AgentMeetingBundle {
  session: AgentMeetingSession;
  messages: AgentMeetingMessage[];
}
