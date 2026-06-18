import http from '@ohos.net.http';
import { InspirationDraft, InspirationItem } from '../models/Inspiration';
import { AppErrorCode, AppException, globalErrorHandler } from '../utils/AppError';
import { authService } from './AuthService';
import { httpClient } from './HttpClient';

interface InspirationItemDto {
  id: string;
  content: string;
  scene: string;
  source: string;
  status: string;
  created_at: string;
  updated_at: string;
}

interface InspirationListDto {
  items: InspirationItemDto[];
}

interface InspirationCreateDto {
  content: string;
  scene: string;
  source: string;
}

interface InspirationUpdateDto {
  content?: string;
  scene?: string;
  source?: string;
  status?: string;
}

interface InspirationDraftDto {
  title: string;
  summary: string;
  content: string;
  category_id: string;
  tag_ids: string[];
}

interface PostInspirationDto {
  item: InspirationItemDto;
  source: string;
}

class InspirationService {
  async list(): Promise<InspirationItem[]> {
    this.ensureLoggedIn();
    try {
      const response = await httpClient.request({
        path: '/users/me/inspirations',
        method: http.RequestMethod.GET,
        token: authService.getToken(),
        timeoutMs: 12000
      });
      return (JSON.parse(response) as InspirationListDto).items.map((item: InspirationItemDto) => this.fromDto(item));
    } catch (error) {
      if (error instanceof AppException && error.code === AppErrorCode.Network) {
        throw globalErrorHandler.network('灵感箱加载失败。');
      }
      throw error as Error;
    }
  }

  async create(content: string, scene: string, source: string): Promise<InspirationItem> {
    this.ensureLoggedIn();
    const response = await httpClient.request({
      path: '/users/me/inspirations',
      method: http.RequestMethod.POST,
      token: authService.getToken(),
      body: JSON.stringify({
        content,
        scene,
        source
      } as InspirationCreateDto),
      timeoutMs: 12000
    });
    return this.fromDto(JSON.parse(response) as InspirationItemDto);
  }

  async update(itemId: string, payload: InspirationUpdateDto): Promise<InspirationItem> {
    this.ensureLoggedIn();
    const response = await httpClient.request({
      path: `/users/me/inspirations/${itemId}`,
      method: http.RequestMethod.PUT,
      token: authService.getToken(),
      body: JSON.stringify(payload),
      timeoutMs: 12000
    });
    return this.fromDto(JSON.parse(response) as InspirationItemDto);
  }

  async remove(itemId: string): Promise<void> {
    this.ensureLoggedIn();
    await httpClient.request({
      path: `/users/me/inspirations/${itemId}`,
      method: http.RequestMethod.DELETE,
      token: authService.getToken(),
      timeoutMs: 12000
    });
  }

  async buildDraft(itemId: string): Promise<InspirationDraft> {
    this.ensureLoggedIn();
    const response = await httpClient.request({
      path: `/users/me/inspirations/${itemId}/draft`,
      method: http.RequestMethod.POST,
      token: authService.getToken(),
      timeoutMs: 12000
    });
    const dto = JSON.parse(response) as InspirationDraftDto;
    return {
      title: dto.title,
      summary: dto.summary,
      content: dto.content,
      categoryId: dto.category_id,
      tagIds: dto.tag_ids
    };
  }

  async createFromPost(postId: string): Promise<InspirationItem> {
    this.ensureLoggedIn();
    const response = await httpClient.request({
      path: '/users/me/inspirations/from-post',
      method: http.RequestMethod.POST,
      token: authService.getToken(),
      body: JSON.stringify({
        post_id: postId
      }),
      timeoutMs: 70000
    });
    return this.fromDto((JSON.parse(response) as PostInspirationDto).item);
  }

  private ensureLoggedIn(): void {
    if (!authService.isLoggedIn()) {
      throw globalErrorHandler.unauthorized('请先登录。');
    }
  }

  private fromDto(dto: InspirationItemDto): InspirationItem {
    return {
      id: dto.id,
      content: dto.content,
      scene: dto.scene,
      source: dto.source,
      status: dto.status,
      createdAt: dto.created_at,
      updatedAt: dto.updated_at
    };
  }
}

export const inspirationService = new InspirationService();
