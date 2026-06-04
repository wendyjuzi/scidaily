import http from '@ohos.net.http';
import {
  CommentItem,
  InteractionSummary,
  NotificationBundle,
  NotificationItem,
  ResearchStatsBundle,
  ResearchStatsPoint
} from '../models/Community';
import { ResearchNews } from '../models/ResearchNews';
import { AppErrorCode, AppException, globalErrorHandler } from '../utils/AppError';
import { authService } from './AuthService';
import { httpClient } from './HttpClient';

interface InteractionSummaryDto {
  like_count: number;
  collection_count: number;
  comment_count: number;
}

interface CommentDto {
  id: number;
  news_id: string;
  user_id: number;
  nickname: string;
  content: string;
  parent_id?: number;
  reply_to_nickname?: string;
  like_count: number;
  created_at: string;
}

interface CommentListDto {
  items: CommentDto[];
  total: number;
  page: number;
  size: number;
}

interface CommentCreateDto {
  content: string;
  parent_id?: number;
}

interface ResearchStatsPointDto {
  label: string;
  daily_count: number;
  experiment_count: number;
  literature_count: number;
}

interface ResearchStatsDto {
  range: string;
  total_daily: number;
  total_experiment: number;
  total_literature: number;
  points: ResearchStatsPointDto[];
}

interface NotificationDto {
  id: number;
  type: string;
  title: string;
  content: string;
  related_item_id?: string;
  is_read: boolean;
  created_at: string;
}

interface NotificationListDto {
  items: NotificationDto[];
  unread_count: number;
}

class CommunityService {
  private localComments: Map<string, CommentItem[]> = new Map<string, CommentItem[]>();
  private localNotifications: NotificationItem[] = [
    {
      id: 1,
      type: 'system',
      title: '欢迎使用科研日报社区',
      content: '评论、科研统计看板和消息通知已进入演示模式。',
      relatedItemId: 'welcome',
      isRead: false,
      createdAt: '2026-06-04'
    }
  ];
  private nextCommentId: number = 100;
  private nextNotificationId: number = 2;

  async getInteractionSummary(newsId: string): Promise<InteractionSummary> {
    try {
      const response = await httpClient.request({
        path: `/news/${newsId}/interactions`,
        method: http.RequestMethod.GET
      });
      return this.fromSummaryDto(JSON.parse(response) as InteractionSummaryDto);
    } catch (error) {
      return {
        likeCount: 0,
        collectionCount: 0,
        commentCount: this.getLocalComments(newsId).length
      };
    }
  }

  async getComments(newsId: string, sort: string = 'latest'): Promise<CommentItem[]> {
    try {
      const response = await httpClient.request({
        path: `/news/${newsId}/comments?page=1&size=50&sort=${sort}`,
        method: http.RequestMethod.GET
      });
      const dto = JSON.parse(response) as CommentListDto;
      const items = this.fromCommentListDto(dto);
      this.localComments.set(newsId, items);
      return items;
    } catch (error) {
      const items = this.getLocalComments(newsId);
      if (sort === 'hot') {
        return items.sort((a: CommentItem, b: CommentItem) => b.likeCount - a.likeCount);
      }
      return items;
    }
  }

  async addComment(news: ResearchNews, content: string, parentId?: number): Promise<CommentItem> {
    this.ensureLoggedIn();
    const text = content.trim();
    if (text.length === 0) {
      throw globalErrorHandler.validation('请输入评论内容。');
    }
    try {
      const payload: CommentCreateDto = { content: text };
      if (parentId !== undefined) {
        payload.parent_id = parentId;
      }
      const response = await httpClient.request({
        path: `/news/${news.id}/comments`,
        method: http.RequestMethod.POST,
        body: JSON.stringify(payload),
        token: authService.getToken()
      });
      const item = this.fromCommentDto(JSON.parse(response) as CommentDto);
      this.upsertLocalComment(news.id, item);
      return item;
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
      }
      const currentUser = authService.getCurrentUser();
      const replyTo = parentId !== undefined ? this.getLocalComments(news.id).find((item: CommentItem) => item.id === parentId) : undefined;
      const item: CommentItem = {
        id: this.nextCommentId,
        newsId: news.id,
        userId: currentUser ? currentUser.id : 0,
        nickname: currentUser ? currentUser.nickname : '本地用户',
        content: text,
        parentId,
        replyToNickname: replyTo ? replyTo.nickname : undefined,
        likeCount: 0,
        createdAt: this.todayText()
      };
      this.nextCommentId += 1;
      this.upsertLocalComment(news.id, item);
      this.addLocalNotification(parentId === undefined ? '评论已发布' : '回复已发布', text, 'comment', news.id);
      return item;
    }
  }

  async deleteComment(commentId: number, newsId: string): Promise<void> {
    this.ensureLoggedIn();
    try {
      await httpClient.request({
        path: `/comments/${commentId}`,
        method: http.RequestMethod.DELETE,
        token: authService.getToken()
      });
      this.removeLocalComment(newsId, commentId);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
      }
      this.removeLocalComment(newsId, commentId);
    }
  }

  async getResearchStats(range: string): Promise<ResearchStatsBundle> {
    this.ensureLoggedIn();
    try {
      const response = await httpClient.request({
        path: `/users/me/research-stats?range=${range}`,
        method: http.RequestMethod.GET,
        token: authService.getToken()
      });
      return this.fromStatsDto(JSON.parse(response) as ResearchStatsDto);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
      }
      return this.localStats(range);
    }
  }

  async getNotifications(): Promise<NotificationBundle> {
    this.ensureLoggedIn();
    try {
      const response = await httpClient.request({
        path: '/users/me/notifications',
        method: http.RequestMethod.GET,
        token: authService.getToken()
      });
      return this.fromNotificationListDto(JSON.parse(response) as NotificationListDto);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
      }
      return this.localNotificationBundle();
    }
  }

  async markNotificationRead(id: number): Promise<void> {
    this.ensureLoggedIn();
    try {
      await httpClient.request({
        path: `/users/me/notifications/${id}/read`,
        method: http.RequestMethod.PUT,
        token: authService.getToken()
      });
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
      }
    }
    this.localNotifications = this.localNotifications.map((item: NotificationItem) => {
      if (item.id === id) {
        item.isRead = true;
      }
      return item;
    });
  }

  async markAllNotificationsRead(): Promise<void> {
    this.ensureLoggedIn();
    try {
      await httpClient.request({
        path: '/users/me/notifications/read-all',
        method: http.RequestMethod.PUT,
        token: authService.getToken()
      });
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
      }
    }
    this.localNotifications.forEach((item: NotificationItem) => {
      item.isRead = true;
    });
  }

  async clearNotifications(): Promise<void> {
    this.ensureLoggedIn();
    try {
      await httpClient.request({
        path: '/users/me/notifications',
        method: http.RequestMethod.DELETE,
        token: authService.getToken()
      });
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        if (error instanceof Error) {
          throw error;
        }
      }
    }
    this.localNotifications = [];
  }

  private ensureLoggedIn(): void {
    if (!authService.isLoggedIn()) {
      throw globalErrorHandler.unauthorized('请先登录。');
    }
  }

  private fromSummaryDto(dto: InteractionSummaryDto): InteractionSummary {
    return {
      likeCount: dto.like_count,
      collectionCount: dto.collection_count,
      commentCount: dto.comment_count
    };
  }

  private fromCommentListDto(dto: CommentListDto): CommentItem[] {
    const result: CommentItem[] = [];
    dto.items.forEach((item: CommentDto) => {
      result.push(this.fromCommentDto(item));
    });
    return result;
  }

  private fromCommentDto(dto: CommentDto): CommentItem {
    return {
      id: dto.id,
      newsId: dto.news_id,
      userId: dto.user_id,
      nickname: dto.nickname,
      content: dto.content,
      parentId: dto.parent_id,
      replyToNickname: dto.reply_to_nickname,
      likeCount: dto.like_count,
      createdAt: dto.created_at
    };
  }

  private fromStatsDto(dto: ResearchStatsDto): ResearchStatsBundle {
    const points: ResearchStatsPoint[] = [];
    dto.points.forEach((item: ResearchStatsPointDto) => {
      points.push({
        label: item.label,
        dailyCount: item.daily_count,
        experimentCount: item.experiment_count,
        literatureCount: item.literature_count
      });
    });
    return {
      range: dto.range,
      totalDaily: dto.total_daily,
      totalExperiment: dto.total_experiment,
      totalLiterature: dto.total_literature,
      points
    };
  }

  private fromNotificationListDto(dto: NotificationListDto): NotificationBundle {
    const items: NotificationItem[] = [];
    dto.items.forEach((item: NotificationDto) => {
      items.push({
        id: item.id,
        type: item.type,
        title: item.title,
        content: item.content,
        relatedItemId: item.related_item_id,
        isRead: item.is_read,
        createdAt: item.created_at
      });
    });
    return {
      items,
      unreadCount: dto.unread_count
    };
  }

  private getLocalComments(newsId: string): CommentItem[] {
    if (!this.localComments.has(newsId)) {
      this.localComments.set(newsId, [
        {
          id: this.nextCommentId,
          newsId,
          userId: 1,
          nickname: '科研日报体验号',
          content: '这条内容适合放进本周文献复盘，后续可以继续补实验记录。',
          likeCount: 8,
          createdAt: '2026-06-04'
        },
        {
          id: this.nextCommentId + 1,
          newsId,
          userId: 2,
          nickname: 'AI 方向同学',
          content: '摘要很清楚，建议增加方法和数据集的对比。',
          likeCount: 3,
          createdAt: '2026-06-04'
        }
      ]);
      this.nextCommentId += 2;
    }
    return this.localComments.get(newsId) ?? [];
  }

  private upsertLocalComment(newsId: string, item: CommentItem): void {
    const items = this.getLocalComments(newsId).filter((existing: CommentItem) => existing.id !== item.id);
    items.unshift(item);
    this.localComments.set(newsId, items);
  }

  private removeLocalComment(newsId: string, commentId: number): void {
    this.localComments.set(newsId, this.getLocalComments(newsId).filter((item: CommentItem) => item.id !== commentId && item.parentId !== commentId));
  }

  private localStats(range: string): ResearchStatsBundle {
    const labels = range === 'month' ? ['05-06', '05-13', '05-20', '05-27', '06-03'] : ['05-29', '05-30', '05-31', '06-01', '06-02', '06-03', '06-04'];
    const points: ResearchStatsPoint[] = [];
    labels.forEach((label: string, index: number) => {
      points.push({
        label,
        dailyCount: index % 3 + 1,
        experimentCount: index % 2,
        literatureCount: (index + 1) % 3
      });
    });
    return {
      range,
      totalDaily: points.reduce((sum: number, item: ResearchStatsPoint) => sum + item.dailyCount, 0),
      totalExperiment: points.reduce((sum: number, item: ResearchStatsPoint) => sum + item.experimentCount, 0),
      totalLiterature: points.reduce((sum: number, item: ResearchStatsPoint) => sum + item.literatureCount, 0),
      points
    };
  }

  private localNotificationBundle(): NotificationBundle {
    return {
      items: this.localNotifications,
      unreadCount: this.localNotifications.filter((item: NotificationItem) => !item.isRead).length
    };
  }

  private addLocalNotification(title: string, content: string, type: string, relatedItemId: string): void {
    this.localNotifications.unshift({
      id: this.nextNotificationId,
      type,
      title,
      content,
      relatedItemId,
      isRead: false,
      createdAt: this.todayText()
    });
    this.nextNotificationId += 1;
  }

  private todayText(): string {
    const date = new Date();
    return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
  }
}

export const communityService = new CommunityService();
