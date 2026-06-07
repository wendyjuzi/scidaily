import http from '@ohos.net.http';
import { API_BASE_URL } from '../config/AppConfig';
import { PaperItem, PaperPage, ReadingProgress } from '../models/Paper';
import { AppErrorCode, AppException } from '../utils/AppError';
import { authService } from './AuthService';
import { httpClient } from './HttpClient';

interface PaperDto {
  id: string;
  title: string;
  abstract: string;
  authors: string[];
  category_id: string;
  category_name: string;
  tags: string[];
  tag_ids: string[];
  source_url: string;
  pdf_url: string;
  local_pdf_path?: string;
  doi?: string;
  published_at: string;
  created_at: string;
}

interface PaperListDto {
  items: PaperDto[];
  next_offset: number;
  has_more: boolean;
}

interface ReadingProgressDto {
  paper_id: string;
  current_page: number;
  progress: number;
  updated_at: string;
}

class PaperService {
  private localPapers: PaperItem[] = [
    {
      id: 'paper-local-rag',
      title: 'Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks',
      abstract: 'A foundational paper on combining language models with retrieval for more reliable knowledge-intensive tasks.',
      authors: ['Patrick Lewis', 'Ethan Perez', 'Aleksandra Piktus'],
      categoryId: 'ai',
      categoryName: '人工智能',
      tags: ['大模型论文'],
      tagIds: ['llm-paper'],
      sourceUrl: 'https://arxiv.org/abs/2005.11401',
      pdfUrl: 'https://arxiv.org/pdf/2005.11401',
      publishedAt: '2020-05-22',
      createdAt: '2026-06-04'
    },
    {
      id: 'paper-local-react',
      title: 'ReAct: Synergizing Reasoning and Acting in Language Models',
      abstract: 'Introduces interleaved reasoning and acting for language model agents.',
      authors: ['Shunyu Yao', 'Jeffrey Zhao', 'Dian Yu'],
      categoryId: 'ai',
      categoryName: '人工智能',
      tags: ['AI Agent', '大模型论文'],
      tagIds: ['ai-agent', 'llm-paper'],
      sourceUrl: 'https://arxiv.org/abs/2210.03629',
      pdfUrl: 'https://arxiv.org/pdf/2210.03629',
      publishedAt: '2022-10-06',
      createdAt: '2026-06-04'
    }
  ];

  async listPapers(offset: number, limit: number): Promise<PaperPage> {
    try {
      const response = await httpClient.request({
        path: `/papers?offset=${offset}&limit=${limit}`,
        method: http.RequestMethod.GET
      });
      return this.fromPageDto(JSON.parse(response) as PaperListDto);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        throw error as Error;
      }
      const slice = this.localPapers.slice(offset, offset + limit);
      return {
        items: slice,
        nextOffset: offset + slice.length,
        hasMore: offset + slice.length < this.localPapers.length
      };
    }
  }

  async getPaper(id: string): Promise<PaperItem | undefined> {
    try {
      const response = await httpClient.request({
        path: `/papers/${id}`,
        method: http.RequestMethod.GET
      });
      return this.fromDto(JSON.parse(response) as PaperDto);
    } catch (error) {
      return this.localPapers.find((item: PaperItem) => item.id === id);
    }
  }

  async saveProgress(paperId: string, currentPage: number, progress: number): Promise<void> {
    if (!authService.isLoggedIn()) {
      return;
    }
    await httpClient.request({
      path: `/papers/${paperId}/progress`,
      method: http.RequestMethod.PUT,
      token: authService.getToken(),
      body: JSON.stringify({
        current_page: currentPage,
        progress
      })
    });
  }

  normalizePdfUrl(url: string): string {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    const marker = '/api/v1';
    const index = API_BASE_URL.indexOf(marker);
    const origin = index >= 0 ? API_BASE_URL.substring(0, index) : API_BASE_URL;
    return `${origin}${url}`;
  }

  private fromPageDto(dto: PaperListDto): PaperPage {
    const items = dto.items.map((item: PaperDto) => this.fromDto(item))
      .filter((item: PaperItem) => !this.isPlaceholderPaper(item));
    return {
      items,
      nextOffset: dto.next_offset,
      hasMore: dto.has_more
    };
  }

  private fromDto(dto: PaperDto): PaperItem {
    return {
      id: dto.id,
      title: dto.title,
      abstract: dto.abstract,
      authors: dto.authors,
      categoryId: dto.category_id,
      categoryName: dto.category_name,
      tags: dto.tags,
      tagIds: dto.tag_ids,
      sourceUrl: dto.source_url,
      pdfUrl: dto.pdf_url,
      localPdfPath: dto.local_pdf_path,
      doi: dto.doi,
      publishedAt: dto.published_at,
      createdAt: dto.created_at
    };
  }

  private isPlaceholderPaper(item: PaperItem): boolean {
    return this.isPlaceholderText(item.title) && this.isPlaceholderText(item.abstract);
  }

  private isPlaceholderText(value: string): boolean {
    const text = value.trim();
    if (text.length < 3) {
      return false;
    }
    for (let index = 0; index < text.length; index += 1) {
      if (text.charAt(index) !== '?') {
        return false;
      }
    }
    return true;
  }
}

export const paperService = new PaperService();
