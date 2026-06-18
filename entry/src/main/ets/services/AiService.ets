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
    const cleanPrompt = `${this.normalizePrompt(prompt)}\n\n输出风格要求：请像真实聊天对话一样自然回答，不要使用 Markdown 符号，不要输出 **、###、- ** 这类标记。可以分段，但每段直接写中文标题和正文。`;
    const payload: AiWorkbenchRequestDto = {
      mode,
      prompt: cleanPrompt,
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
      answer: this.cleanChatText(dto.answer),
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

  private cleanChatText(text: string): string {
    const lines = text.replace(/\r/g, '').split('\n');
    const cleaned: string[] = [];
    lines.forEach((line: string) => {
      let item = line.trim();
      if (item.length === 0) {
        if (cleaned.length > 0 && cleaned[cleaned.length - 1].length > 0) {
          cleaned.push('');
        }
        return;
      }
      item = item.replace(/^#{1,6}\s*/, '');
      item = item.replace(/^[-*+]\s+/, '');
      item = item.replace(/^\d+[\.\)]\s*/, '');
      item = item.replace(/\*\*/g, '');
      item = item.replace(/__/g, '');
      item = item.replace(/`/g, '');
      item = item.replace(/^\s*[-*+]\s*/, '');
      cleaned.push(item.trim());
    });
    return cleaned.join('\n').replace(/\n{3,}/g, '\n\n').trim();
  }
}

export const aiService = new AiService();
