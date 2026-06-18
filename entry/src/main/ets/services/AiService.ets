import http from '@ohos.net.http';
import { httpClient } from './HttpClient';

interface AiWorkbenchRequestDto {
  mode: string;
  prompt: string;
  history: AiConversationMessage[];
}

interface AiCreatorRequestDto {
  mode: string;
  prompt: string;
  title: string;
  summary: string;
  content: string;
  category_name: string;
  tags: string[];
  paper_title: string;
  paper_abstract: string;
  paper_doi: string;
  paper_source_url: string;
  paper_pdf_url: string;
}

interface AiWorkbenchResponseDto {
  mode: string;
  title: string;
  answer: string;
  source: string;
}

interface AiCreatorResponseDto {
  mode: string;
  title: string;
  summary: string;
  content: string;
  tags: string[];
  topic: string;
  note: string;
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

export interface AiCreatorContext {
  title: string;
  summary: string;
  content: string;
  categoryName: string;
  tags: string[];
  paperTitle: string;
  paperAbstract: string;
  paperDoi: string;
  paperSourceUrl: string;
  paperPdfUrl: string;
}

export interface AiCreatorResult {
  mode: string;
  title: string;
  summary: string;
  content: string;
  tags: string[];
  topic: string;
  note: string;
  source: string;
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

  async createDailyDraft(mode: string, prompt: string, context: AiCreatorContext): Promise<AiCreatorResult> {
    const payload: AiCreatorRequestDto = {
      mode,
      prompt: this.normalizePrompt(prompt),
      title: context.title,
      summary: context.summary,
      content: context.content,
      category_name: context.categoryName,
      tags: context.tags,
      paper_title: context.paperTitle,
      paper_abstract: context.paperAbstract,
      paper_doi: context.paperDoi,
      paper_source_url: context.paperSourceUrl,
      paper_pdf_url: context.paperPdfUrl
    };
    const response = await httpClient.request({
      path: '/ai/creator',
      method: http.RequestMethod.POST,
      body: JSON.stringify(payload),
      timeoutMs: 70000
    });
    const dto = JSON.parse(response) as AiCreatorResponseDto;
    return {
      mode: dto.mode,
      title: dto.title,
      summary: dto.summary,
      content: dto.content,
      tags: dto.tags,
      topic: dto.topic,
      note: dto.note,
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
