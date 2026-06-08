import http from '@ohos.net.http';
import { httpClient } from './HttpClient';

interface AiWorkbenchRequestDto {
  mode: string;
  prompt: string;
  history: AiConversationMessage[];
}

interface AiWorkbenchResponseDto {
  mode: string;
  title: string;
  answer: string;
  source: string;
}

export interface AiWorkbenchResult {
  mode: string;
  title: string;
  answer: string;
  source: string;
}

export interface AiConversationMessage {
  role: string;
  content: string;
}

class AiService {
  async generate(mode: string, prompt: string, history: AiConversationMessage[]): Promise<AiWorkbenchResult> {
    const payload: AiWorkbenchRequestDto = {
      mode,
      prompt: this.normalizePrompt(prompt),
      history
    };
    const response = await httpClient.request({
      path: '/ai/workbench',
      method: http.RequestMethod.POST,
      body: JSON.stringify(payload),
      timeoutMs: 70000
    });
    const dto = JSON.parse(response) as AiWorkbenchResponseDto;
    return {
      mode: dto.mode,
      title: dto.title,
      answer: dto.answer,
      source: dto.source
    };
  }

  private normalizePrompt(prompt: string): string {
    const text = prompt.trim();
    if (text.length > 0) {
      return text;
    }
    return '当前研究问题';
  }
}

export const aiService = new AiService();
