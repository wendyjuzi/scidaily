import http from '@ohos.net.http';
import { AgentMeetingBundle, AgentMeetingMessage, AgentMeetingSession } from '../models/AgentMeeting';
import { AppErrorCode, AppException, globalErrorHandler } from '../utils/AppError';
import { authService } from './AuthService';
import { httpClient } from './HttpClient';

interface AgentSessionDto {
  id: string;
  user_id: number;
  title: string;
  input: string;
  source_type: string;
  source_id: string;
  status: string;
  current_round: number;
  memory_version: number;
  created_at: string;
  updated_at: string;
}

interface AgentMessageDto {
  id: number;
  session_id: string;
  agent_key: string;
  agent_name: string;
  role: string;
  content: string;
  status: string;
  round: number;
  context_version_started: number;
  created_at: string;
  started_at?: string;
  completed_at?: string;
}

interface AgentSessionResponseDto {
  item: AgentSessionDto;
}

interface AgentSessionListResponseDto {
  items: AgentSessionDto[];
}

interface AgentMessageListResponseDto {
  session: AgentSessionDto;
  messages: AgentMessageDto[];
}

interface AgentSessionCreateDto {
  prompt: string;
  source_type: string;
  source_id: string;
  title: string;
}

interface AgentSessionContinueDto {
  prompt: string;
}

class AgentMeetingService {
  async create(prompt: string, title: string = '', sourceType: string = '', sourceId: string = ''): Promise<AgentMeetingSession> {
    this.ensureLoggedIn();
    const payload: AgentSessionCreateDto = {
      prompt,
      title,
      source_type: sourceType,
      source_id: sourceId
    };
    const response = await httpClient.request({
      path: '/agent-sessions',
      method: http.RequestMethod.POST,
      token: authService.getToken(),
      body: JSON.stringify(payload),
      timeoutMs: 12000
    });
    return this.sessionFromDto((JSON.parse(response) as AgentSessionResponseDto).item);
  }

  async continueSession(sessionId: string, prompt: string): Promise<AgentMeetingSession> {
    this.ensureLoggedIn();
    const payload: AgentSessionContinueDto = {
      prompt
    };
    const response = await httpClient.request({
      path: `/agent-sessions/${sessionId}/messages`,
      method: http.RequestMethod.POST,
      token: authService.getToken(),
      body: JSON.stringify(payload),
      timeoutMs: 12000
    });
    return this.sessionFromDto((JSON.parse(response) as AgentSessionResponseDto).item);
  }

  async stop(sessionId: string): Promise<AgentMeetingSession> {
    this.ensureLoggedIn();
    const response = await httpClient.request({
      path: `/agent-sessions/${sessionId}/stop`,
      method: http.RequestMethod.POST,
      token: authService.getToken(),
      timeoutMs: 12000
    });
    return this.sessionFromDto((JSON.parse(response) as AgentSessionResponseDto).item);
  }

  async list(): Promise<AgentMeetingSession[]> {
    this.ensureLoggedIn();
    try {
      const response = await httpClient.request({
        path: '/agent-sessions',
        method: http.RequestMethod.GET,
        token: authService.getToken(),
        timeoutMs: 12000
      });
      return (JSON.parse(response) as AgentSessionListResponseDto).items.map((item: AgentSessionDto) => this.sessionFromDto(item));
    } catch (error) {
      if (error instanceof AppException && error.code === AppErrorCode.Network) {
        throw globalErrorHandler.network('组会历史加载失败。');
      }
      throw error as Error;
    }
  }

  async messages(sessionId: string): Promise<AgentMeetingBundle> {
    this.ensureLoggedIn();
    const response = await httpClient.request({
      path: `/agent-sessions/${sessionId}/messages`,
      method: http.RequestMethod.GET,
      token: authService.getToken(),
      timeoutMs: 12000
    });
    const dto = JSON.parse(response) as AgentMessageListResponseDto;
    return {
      session: this.sessionFromDto(dto.session),
      messages: dto.messages.map((item: AgentMessageDto) => this.messageFromDto(item))
    };
  }

  private ensureLoggedIn(): void {
    if (!authService.isLoggedIn()) {
      throw globalErrorHandler.unauthorized('请先登录。');
    }
  }

  private sessionFromDto(dto: AgentSessionDto): AgentMeetingSession {
    return {
      id: dto.id,
      userId: dto.user_id,
      title: dto.title,
      input: dto.input,
      sourceType: dto.source_type,
      sourceId: dto.source_id,
      status: dto.status,
      currentRound: dto.current_round,
      memoryVersion: dto.memory_version,
      createdAt: dto.created_at,
      updatedAt: dto.updated_at
    };
  }

  private messageFromDto(dto: AgentMessageDto): AgentMeetingMessage {
    return {
      id: dto.id,
      sessionId: dto.session_id,
      agentKey: dto.agent_key,
      agentName: dto.agent_name,
      role: dto.role,
      content: dto.content,
      status: dto.status,
      round: dto.round,
      contextVersionStarted: dto.context_version_started,
      createdAt: dto.created_at,
      startedAt: dto.started_at ?? '',
      completedAt: dto.completed_at ?? ''
    };
  }
}

export const agentMeetingService = new AgentMeetingService();
