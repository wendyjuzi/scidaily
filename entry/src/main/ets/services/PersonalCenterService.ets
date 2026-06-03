import http from '@ohos.net.http';
import {
  MessageSettings,
  PersonalItem,
  PersonalStats,
  PrivacySettings,
  SettingsBundle
} from '../models/User';
import { ResearchNews } from '../models/ResearchNews';
import { AppErrorCode, AppException, globalErrorHandler } from '../utils/AppError';
import { authService } from './AuthService';
import { httpClient } from './HttpClient';
import { newsService } from './NewsService';

interface PersonalStatsDto {
  post_count: number;
  collection_count: number;
  like_count: number;
  history_count: number;
  continuous_days: number;
}

interface PersonalItemDto {
  id: string;
  title: string;
  summary: string;
  created_at: string;
  status: string;
}

interface PersonalListDto {
  items: PersonalItemDto[];
}

interface PrivacySettingsDto {
  show_email: boolean;
  show_research_stats: boolean;
  allow_recommendations: boolean;
}

interface MessageSettingsDto {
  like_notice: boolean;
  comment_notice: boolean;
  system_notice: boolean;
}

interface SettingsBundleDto {
  privacy: PrivacySettingsDto;
  messages: MessageSettingsDto;
}

interface PersonalActionDto {
  item_id: string;
  title: string;
  summary: string;
}

interface InteractionStateDto {
  active: boolean;
}

class PersonalCenterService {
  private posts: PersonalItem[] = [
    {
      id: 'post-001',
      title: '实验记录：多模态推理评测复现',
      summary: '记录数据清洗、基线模型和第一轮误差分析。',
      createdAt: '2026-06-01',
      status: '已发布'
    },
    {
      id: 'post-002',
      title: '文献阅读：单细胞免疫图谱',
      summary: '整理核心方法、数据来源和可复用的分析流程。',
      createdAt: '2026-05-30',
      status: '草稿'
    }
  ];
  private collections: PersonalItem[] = [
    {
      id: 'collect-001',
      title: '基础模型提升多模态科学推理能力',
      summary: '工具增强推理显著提升科学问答准确率。',
      createdAt: '2026-06-02',
      status: '已收藏'
    },
    {
      id: 'collect-002',
      title: '高熵钙钛矿用于稳定太阳能转换',
      summary: '高熵钙钛矿提升热稳定性和使用寿命。',
      createdAt: '2026-06-01',
      status: '已收藏'
    }
  ];
  private likes: PersonalItem[] = [
    {
      id: 'like-001',
      title: '单细胞图谱揭示动态免疫细胞状态',
      summary: '跨组织单细胞图谱揭示炎症恢复中的瞬时状态。',
      createdAt: '2026-06-02',
      status: '已点赞'
    },
    {
      id: 'like-002',
      title: '实验记录：多模态推理评测复现',
      summary: '记录数据清洗、基线模型和第一轮误差分析。',
      createdAt: '2026-06-01',
      status: '已点赞'
    }
  ];
  private history: PersonalItem[] = [
    {
      id: 'history-001',
      title: '基础模型提升多模态科学推理能力',
      summary: '工具增强推理显著提升科学问答准确率。',
      createdAt: '2026-06-03',
      status: '已浏览'
    },
    {
      id: 'history-002',
      title: '单细胞图谱揭示动态免疫细胞状态',
      summary: '跨组织单细胞图谱揭示炎症恢复中的瞬时状态。',
      createdAt: '2026-06-02',
      status: '已浏览'
    },
    {
      id: 'history-003',
      title: '高熵钙钛矿用于稳定太阳能转换',
      summary: '高熵钙钛矿提升热稳定性和使用寿命。',
      createdAt: '2026-06-01',
      status: '已浏览'
    }
  ];
  private privacy: PrivacySettings = {
    showEmail: false,
    showResearchStats: true,
    allowRecommendations: true
  };
  private messages: MessageSettings = {
    likeNotice: true,
    commentNotice: true,
    systemNotice: true
  };

  async getStats(): Promise<PersonalStats> {
    this.ensureLoggedIn();
    try {
      const response = await httpClient.request({
        path: '/users/me/stats',
        method: http.RequestMethod.GET,
        token: authService.getToken()
      });
      return this.fromStatsDto(JSON.parse(response) as PersonalStatsDto);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.network('统计数据加载失败。');
      }
      return this.getStatsLocal();
    }
  }

  getStatsLocal(): PersonalStats {
    this.ensureLoggedIn();
    return {
      postCount: this.posts.length,
      collectionCount: this.collections.length,
      likeCount: this.likes.length,
      historyCount: this.history.length,
      continuousDays: this.history.length > 0 ? 3 : 0
    };
  }

  async getItems(type: string): Promise<PersonalItem[]> {
    this.ensureLoggedIn();
    try {
      const response = await httpClient.request({
        path: this.getPath(type),
        method: http.RequestMethod.GET,
        token: authService.getToken()
      });
      return this.fromListDto(JSON.parse(response) as PersonalListDto);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.network('列表数据加载失败。');
      }
      return this.getItemsLocal(type);
    }
  }

  getItemsLocal(type: string): PersonalItem[] {
    this.ensureLoggedIn();
    switch (type) {
      case 'posts':
        return this.posts;
      case 'collections':
        return this.collections;
      case 'likes':
        return this.likes;
      case 'history':
        return this.history;
      default:
        return this.posts;
    }
  }

  getTitle(type: string): string {
    switch (type) {
      case 'posts':
        return '我的发布';
      case 'collections':
        return '我的收藏';
      case 'likes':
        return '我的点赞';
      case 'history':
        return '浏览记录';
      default:
        return '个人列表';
    }
  }

  async getCollectedNews(): Promise<ResearchNews[]> {
    const items = await this.getItems('collections');
    return this.toNewsItems(items);
  }

  async isCollected(newsId: string): Promise<boolean> {
    this.ensureLoggedIn();
    try {
      const response = await httpClient.request({
        path: `/users/me/collections/${newsId}/state`,
        method: http.RequestMethod.GET,
        token: authService.getToken()
      });
      return (JSON.parse(response) as InteractionStateDto).active;
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.network('收藏状态加载失败。');
      }
      return newsService.isBookmarked(newsId);
    }
  }

  async addCollection(news: ResearchNews): Promise<void> {
    this.ensureLoggedIn();
    try {
      const payload: PersonalActionDto = {
        item_id: news.id,
        title: news.title,
        summary: news.aiSummary
      };
      await httpClient.request({
        path: '/users/me/collections',
        method: http.RequestMethod.POST,
        body: JSON.stringify(payload),
        token: authService.getToken()
      });
      newsService.setBookmark(news.id, true);
      this.upsertLocalItem(this.collections, news, '已收藏');
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.network('收藏失败，请稍后重试。');
      }
      newsService.setBookmark(news.id, true);
      this.upsertLocalItem(this.collections, news, '已收藏');
    }
  }

  async removeCollection(newsId: string): Promise<void> {
    this.ensureLoggedIn();
    try {
      await httpClient.request({
        path: `/users/me/collections/${newsId}`,
        method: http.RequestMethod.DELETE,
        token: authService.getToken()
      });
      newsService.setBookmark(newsId, false);
      this.removeLocalItem(this.collections, newsId);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.network('取消收藏失败，请稍后重试。');
      }
      newsService.setBookmark(newsId, false);
      this.removeLocalItem(this.collections, newsId);
    }
  }

  async isLiked(newsId: string): Promise<boolean> {
    this.ensureLoggedIn();
    try {
      const response = await httpClient.request({
        path: `/users/me/likes/${newsId}/state`,
        method: http.RequestMethod.GET,
        token: authService.getToken()
      });
      return (JSON.parse(response) as InteractionStateDto).active;
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.network('点赞状态加载失败。');
      }
      return this.hasLocalItem(this.likes, newsId);
    }
  }

  async addLike(news: ResearchNews): Promise<void> {
    this.ensureLoggedIn();
    try {
      await httpClient.request({
        path: '/users/me/likes',
        method: http.RequestMethod.POST,
        body: JSON.stringify(this.toActionDto(news)),
        token: authService.getToken()
      });
      this.upsertLocalItem(this.likes, news, '已点赞');
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.network('点赞失败，请稍后重试。');
      }
      this.upsertLocalItem(this.likes, news, '已点赞');
    }
  }

  async removeLike(newsId: string): Promise<void> {
    this.ensureLoggedIn();
    try {
      await httpClient.request({
        path: `/users/me/likes/${newsId}`,
        method: http.RequestMethod.DELETE,
        token: authService.getToken()
      });
      this.removeLocalItem(this.likes, newsId);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.network('取消点赞失败，请稍后重试。');
      }
      this.removeLocalItem(this.likes, newsId);
    }
  }

  async addHistory(news: ResearchNews): Promise<void> {
    this.ensureLoggedIn();
    try {
      await httpClient.request({
        path: '/users/me/history',
        method: http.RequestMethod.POST,
        body: JSON.stringify(this.toActionDto(news)),
        token: authService.getToken()
      });
      this.upsertLocalItem(this.history, news, '已浏览');
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.network('浏览记录保存失败。');
      }
      this.upsertLocalItem(this.history, news, '已浏览');
    }
  }

  async clearHistory(): Promise<void> {
    this.ensureLoggedIn();
    try {
      await httpClient.request({
        path: '/users/me/history',
        method: http.RequestMethod.DELETE,
        token: authService.getToken()
      });
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.network('清空浏览记录失败。');
      }
      this.history = [];
      return;
    }
    this.history = [];
  }

  async getSettings(): Promise<SettingsBundle> {
    this.ensureLoggedIn();
    try {
      const response = await httpClient.request({
        path: '/users/me/settings',
        method: http.RequestMethod.GET,
        token: authService.getToken()
      });
      return this.fromSettingsDto(JSON.parse(response) as SettingsBundleDto);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.network('设置加载失败。');
      }
      return this.getSettingsLocal();
    }
  }

  getSettingsLocal(): SettingsBundle {
    this.ensureLoggedIn();
    return {
      privacy: this.privacy,
      messages: this.messages
    };
  }

  async updatePrivacy(settings: PrivacySettings): Promise<SettingsBundle> {
    this.ensureLoggedIn();
    try {
      const payload: PrivacySettingsDto = {
        show_email: settings.showEmail,
        show_research_stats: settings.showResearchStats,
        allow_recommendations: settings.allowRecommendations
      };
      const response = await httpClient.request({
        path: '/users/me/settings/privacy',
        method: http.RequestMethod.PUT,
        body: JSON.stringify(payload),
        token: authService.getToken()
      });
      return this.fromSettingsDto(JSON.parse(response) as SettingsBundleDto);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.network('隐私设置更新失败。');
      }
      this.privacy = settings;
      return this.getSettingsLocal();
    }
  }

  async updateMessages(settings: MessageSettings): Promise<SettingsBundle> {
    this.ensureLoggedIn();
    try {
      const payload: MessageSettingsDto = {
        like_notice: settings.likeNotice,
        comment_notice: settings.commentNotice,
        system_notice: settings.systemNotice
      };
      const response = await httpClient.request({
        path: '/users/me/settings/messages',
        method: http.RequestMethod.PUT,
        body: JSON.stringify(payload),
        token: authService.getToken()
      });
      return this.fromSettingsDto(JSON.parse(response) as SettingsBundleDto);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
        throw globalErrorHandler.network('消息设置更新失败。');
      }
      this.messages = settings;
      return this.getSettingsLocal();
    }
  }

  private ensureLoggedIn(): void {
    if (!authService.isLoggedIn()) {
      throw globalErrorHandler.unauthorized('请先登录。');
    }
  }

  private getPath(type: string): string {
    switch (type) {
      case 'posts':
        return '/users/me/posts';
      case 'collections':
        return '/users/me/collections';
      case 'likes':
        return '/users/me/likes';
      case 'history':
        return '/users/me/history';
      default:
        return '/users/me/posts';
    }
  }

  private fromStatsDto(dto: PersonalStatsDto): PersonalStats {
    return {
      postCount: dto.post_count,
      collectionCount: dto.collection_count,
      likeCount: dto.like_count,
      historyCount: dto.history_count,
      continuousDays: dto.continuous_days
    };
  }

  private fromListDto(dto: PersonalListDto): PersonalItem[] {
    const result: PersonalItem[] = [];
    dto.items.forEach((item: PersonalItemDto) => {
      result.push({
        id: item.id,
        title: item.title,
        summary: item.summary,
        createdAt: item.created_at,
        status: item.status
      });
    });
    return result;
  }

  private fromSettingsDto(dto: SettingsBundleDto): SettingsBundle {
    return {
      privacy: {
        showEmail: dto.privacy.show_email,
        showResearchStats: dto.privacy.show_research_stats,
        allowRecommendations: dto.privacy.allow_recommendations
      },
      messages: {
        likeNotice: dto.messages.like_notice,
        commentNotice: dto.messages.comment_notice,
        systemNotice: dto.messages.system_notice
      }
    };
  }

  private toActionDto(news: ResearchNews): PersonalActionDto {
    return {
      item_id: news.id,
      title: news.title,
      summary: news.aiSummary
    };
  }

  private upsertLocalItem(list: PersonalItem[], news: ResearchNews, status: string): void {
    this.removeLocalItem(list, news.id);
    list.unshift({
      id: news.id,
      title: news.title,
      summary: news.aiSummary,
      createdAt: this.todayText(),
      status
    });
  }

  private removeLocalItem(list: PersonalItem[], newsId: string): void {
    const index = list.findIndex((item: PersonalItem) => item.id === newsId || item.id.endsWith(newsId));
    if (index >= 0) {
      list.splice(index, 1);
    }
  }

  private hasLocalItem(list: PersonalItem[], newsId: string): boolean {
    return list.some((item: PersonalItem) => item.id === newsId || item.id.endsWith(newsId));
  }

  private toNewsItems(items: PersonalItem[]): ResearchNews[] {
    const result: ResearchNews[] = [];
    const allNews = newsService.getDailyNews();
    items.forEach((item: PersonalItem) => {
      const match = allNews.find((news: ResearchNews) => news.title === item.title || item.id.endsWith(news.id));
      if (match !== undefined) {
        result.push(match);
      }
    });
    return result;
  }

  private todayText(): string {
    const date = new Date();
    return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
  }
}

export const personalCenterService = new PersonalCenterService();
