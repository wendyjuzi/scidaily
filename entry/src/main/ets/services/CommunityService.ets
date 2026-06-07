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
  parent_id?: number | null;
  reply_to_nickname?: string | null;
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

interface CommentContext {
  title: string;
  summary: string;
  tagNames: string[];
}

interface CommentSeed {
  firstNickname: string;
  firstContent: string;
  firstLikes: number;
  secondNickname: string;
  secondContent: string;
  secondLikes: number;
  firstReplyNickname: string;
  firstReplyContent: string;
  firstReplyLikes: number;
  secondReplyNickname: string;
  secondReplyContent: string;
  secondReplyLikes: number;
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
  private commentContexts: Map<string, CommentContext> = new Map<string, CommentContext>();
  private locallyReadNotificationIds: number[] = [];
  private locallyClearedNotificationIds: number[] = [];
  private localNotifications: NotificationItem[] = [
    {
      id: 1,
      type: 'like',
      title: '赞和收藏',
      content: '导师点赞了你的《多模态科研智能体复现记录》。',
      relatedItemId: 'local-daily-001',
      isRead: false,
      createdAt: '2026-06-05'
    },
    {
      id: 2,
      type: 'collection',
      title: '收藏提醒',
      content: '师兄收藏了你的《单细胞免疫图谱文献阅读》。',
      relatedItemId: 'local-daily-002',
      isRead: false,
      createdAt: '2026-06-05'
    },
    {
      id: 3,
      type: 'follow',
      title: '新增关注',
      content: '中南大学材料学院同学关注了你。',
      relatedItemId: 'author-1',
      isRead: false,
      createdAt: '2026-06-05'
    },
    {
      id: 4,
      type: 'comment',
      title: '收到评论回复',
      content: '师兄回复了你：复现实验脚本我放到共享目录了。',
      relatedItemId: 'local-daily-001',
      isRead: false,
      createdAt: '2026-06-05'
    },
    {
      id: 5,
      type: 'system',
      title: '欢迎使用科研日报社区',
      content: '评论、科研统计看板和消息通知已进入演示模式。',
      relatedItemId: 'welcome',
      isRead: false,
      createdAt: '2026-06-04'
    }
  ];
  private nextCommentId: number = 100;
  private nextNotificationId: number = 6;

  setCommentContext(newsId: string, title: string, summary: string, tagNames: string[] = []): void {
    this.commentContexts.set(newsId, {
      title,
      summary,
      tagNames
    });
  }

  async getInteractionSummary(newsId: string): Promise<InteractionSummary> {
    const localSummary: InteractionSummary = {
      likeCount: 0,
      collectionCount: 0,
      commentCount: this.getLocalComments(newsId).length
    };
    try {
      const response = await httpClient.request({
        path: `/news/${newsId}/interactions`,
        method: http.RequestMethod.GET
      });
      return this.fromSummaryDto(JSON.parse(response) as InteractionSummaryDto);
    } catch (error) {
      return localSummary;
    }
  }

  async getComments(newsId: string, sort: string = 'latest', page: number = 1, size: number = 20): Promise<CommentItem[]> {
    const localItems = this.localCommentPage(newsId, sort, page, size);
    this.syncComments(newsId, sort, page, size);
    if (localItems.length > 0) {
      return localItems;
    }
    try {
      const response = await httpClient.request({
        path: `/news/${newsId}/comments?page=${page}&size=${size}&sort=${sort}`,
        method: http.RequestMethod.GET
      });
      const dto = JSON.parse(response) as CommentListDto;
      const items = this.fromCommentListDto(dto);
      if (page === 1 && items.length > 0) {
        this.localComments.set(newsId, items);
      }
      return items;
    } catch (error) {
      return localItems;
    }
  }

  async addComment(news: ResearchNews, content: string, parentId?: number): Promise<CommentItem> {
    return this.addCommentById(news.id, content, parentId);
  }

  async addCommentById(newsId: string, content: string, parentId?: number): Promise<CommentItem> {
    this.ensureLoggedIn();
    const text = content.trim();
    if (text.length === 0) {
      throw globalErrorHandler.validation('请输入评论内容。');
    }
    if (text.length > 200) {
      throw globalErrorHandler.validation('评论内容不能超过 200 字。');
    }
    const localItem = this.createLocalComment(newsId, text, parentId);
    this.upsertLocalComment(newsId, localItem);
    this.addLocalNotification(parentId === undefined ? '评论已发布' : '回复已发布', text, 'comment', newsId);
    this.syncAddedComment(newsId, text, parentId);
    return localItem;
  }

  private async syncAddedComment(newsId: string, text: string, parentId?: number): Promise<void> {
    try {
      const payload: CommentCreateDto = { content: text };
      if (parentId !== undefined) {
        payload.parent_id = parentId;
      }
      const response = await httpClient.request({
        path: `/news/${newsId}/comments`,
        method: http.RequestMethod.POST,
        body: JSON.stringify(payload),
        token: authService.getToken()
      });
      const item = this.fromCommentDto(JSON.parse(response) as CommentDto);
      this.upsertLocalComment(newsId, item);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        return;
      }
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

  async setCommentLiked(newsId: string, commentId: number, active: boolean): Promise<CommentItem | undefined> {
    this.ensureLoggedIn();
    try {
      const response = await httpClient.request({
        path: `/comments/${commentId}/like`,
        method: active ? http.RequestMethod.POST : http.RequestMethod.DELETE,
        token: authService.getToken()
      });
      const item = this.fromCommentDto(JSON.parse(response) as CommentDto);
      this.upsertLocalComment(newsId, item);
      return item;
    } catch (error) {
      return undefined;
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
      const bundle = this.fromNotificationListDto(JSON.parse(response) as NotificationListDto);
      this.localNotifications = bundle.items;
      return this.localNotificationBundle();
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
    this.rememberNotificationRead(id);
    this.localNotifications = this.localNotifications.map((item: NotificationItem) => {
      if (item.id === id) {
        return this.withNotificationReadState(item, true);
      }
      return item;
    });
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
  }

  async markAllNotificationsRead(): Promise<void> {
    this.ensureLoggedIn();
    this.localNotifications.forEach((item: NotificationItem) => {
      this.rememberNotificationRead(item.id);
    });
    this.localNotifications = this.localNotifications.map((item: NotificationItem) => this.withNotificationReadState(item, true));
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
  }

  async clearNotifications(): Promise<void> {
    this.ensureLoggedIn();
    this.localNotifications.forEach((item: NotificationItem) => {
      this.rememberNotificationCleared(item.id);
    });
    this.localNotifications = [];
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
      parentId: dto.parent_id === null ? undefined : dto.parent_id,
      replyToNickname: dto.reply_to_nickname === null ? undefined : dto.reply_to_nickname,
      likeCount: dto.like_count,
      createdAt: this.formatDate(dto.created_at)
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
      if (this.locallyClearedNotificationIds.indexOf(item.id) < 0) {
        const isRead = item.is_read || this.locallyReadNotificationIds.indexOf(item.id) >= 0;
        items.push({
          id: item.id,
          type: item.type,
          title: item.title,
          content: item.content,
          relatedItemId: item.related_item_id,
          isRead,
          createdAt: this.formatDate(item.created_at)
        });
      }
    });
    return {
      items,
      unreadCount: items.filter((item: NotificationItem) => !item.isRead).length
    };
  }

  private localCommentPage(newsId: string, sort: string, page: number, size: number): CommentItem[] {
    const items = this.getLocalComments(newsId);
    const offset = (page - 1) * size;
    if (sort === 'hot') {
      return items.slice().sort((a: CommentItem, b: CommentItem) => b.likeCount - a.likeCount).slice(offset, offset + size);
    }
    return items.slice(offset, offset + size);
  }

  private syncComments(newsId: string, sort: string, page: number, size: number): void {
    httpClient.request({
      path: `/news/${newsId}/comments?page=${page}&size=${size}&sort=${sort}`,
      method: http.RequestMethod.GET
    }).then((response: string) => {
      const dto = JSON.parse(response) as CommentListDto;
      const items = this.fromCommentListDto(dto);
      if (page === 1 && items.length > 0) {
        this.localComments.set(newsId, items);
      }
    }).catch(() => {
    });
  }

  private createLocalComment(newsId: string, text: string, parentId?: number): CommentItem {
    const currentUser = authService.getCurrentUser();
    const replyTo = parentId !== undefined ? this.getLocalComments(newsId).find((item: CommentItem) => item.id === parentId) : undefined;
    const item: CommentItem = {
      id: this.nextCommentId,
      newsId,
      userId: currentUser ? currentUser.id : 0,
      nickname: currentUser ? currentUser.nickname : '本地用户',
      content: text,
      parentId,
      replyToNickname: replyTo ? replyTo.nickname : undefined,
      likeCount: 0,
      createdAt: this.todayText()
    };
    this.nextCommentId += 1;
    return item;
  }

  private getLocalComments(newsId: string): CommentItem[] {
    if (!this.localComments.has(newsId)) {
      const firstId = this.nextCommentId;
      const secondId = this.nextCommentId + 1;
      const seed = this.commentSeedFor(newsId);
      this.localComments.set(newsId, [
        {
          id: firstId,
          newsId,
          userId: 1,
          nickname: seed.firstNickname,
          content: seed.firstContent,
          likeCount: seed.firstLikes,
          createdAt: '2026-06-04'
        },
        {
          id: secondId,
          newsId,
          userId: 2,
          nickname: seed.secondNickname,
          content: seed.secondContent,
          likeCount: seed.secondLikes,
          createdAt: '2026-06-04'
        },
        {
          id: this.nextCommentId + 2,
          newsId,
          userId: 3,
          nickname: seed.firstReplyNickname,
          content: seed.firstReplyContent,
          parentId: firstId,
          replyToNickname: seed.firstNickname,
          likeCount: seed.firstReplyLikes,
          createdAt: '2026-06-05'
        },
        {
          id: this.nextCommentId + 3,
          newsId,
          userId: 4,
          nickname: seed.secondReplyNickname,
          content: seed.secondReplyContent,
          parentId: firstId,
          replyToNickname: seed.firstNickname,
          likeCount: seed.secondReplyLikes,
          createdAt: '2026-06-05'
        }
      ]);
      this.nextCommentId += 4;
    }
    return this.localComments.get(newsId) ?? [];
  }

  private commentSeedFor(newsId: string): CommentSeed {
    const key = this.commentKey(newsId);
    if (this.containsAny(key, ['rag', 'agent', '智能体', '多模态', '检索', '问答', '大模型', 'transformer'])) {
      return {
        firstNickname: '导师',
        firstContent: '这个复现记录建议把检索命中率、回答正确率和失败原因分开写，后续组会能直接看出卡点。',
        firstLikes: 18,
        secondNickname: 'AI 方向同学',
        secondContent: 'RAG 管线最好补上 chunk 大小、top-k 和引用页码，不然很难判断是召回问题还是生成问题。',
        secondLikes: 12,
        firstReplyNickname: '中南大学同门',
        firstReplyContent: '我也想看错误归因表，尤其是检索没召回和模型答偏这两类。',
        firstReplyLikes: 9,
        secondReplyNickname: '师兄',
        secondReplyContent: '可以把 prompt、模型版本和运行脚本一起放到附录，复现实验会稳很多。',
        secondReplyLikes: 6
      };
    }
    if (this.containsAny(key, ['单细胞', '免疫', '空间转录组', '组学', '细胞'])) {
      return {
        firstNickname: '生命科学同学',
        firstContent: '这篇可以把 QC 阈值、批次校正和 marker gene 单独列一节，后面复用数据处理流程会更方便。',
        firstLikes: 16,
        secondNickname: '师姐',
        secondContent: '如果能补一张细胞状态转移图就更清楚了，尤其是炎症消退阶段的瞬时状态。',
        secondLikes: 11,
        firstReplyNickname: '中南大学同门',
        firstReplyContent: '我关心参考图谱映射那一步，想看看自动标注和人工检查差多少。',
        firstReplyLikes: 7,
        secondReplyNickname: '导师',
        secondReplyContent: '下次汇报把关键 marker 和功能验证证据放在一起，会更像完整证据链。',
        secondReplyLikes: 5
      };
    }
    if (this.containsAny(key, ['钙钛矿', '材料', '传感器', '薄膜', '催化', '稳定性', 'xrd', 'sem'])) {
      return {
        firstNickname: '材料组同学',
        firstContent: '稳定性数据建议把湿度、温度和光照拆开记录，不然很难判断到底是哪一项触发衰减。',
        firstLikes: 14,
        secondNickname: '师兄',
        secondContent: '薄膜部分可以加 SEM 和 XRD 的对应编号，和效率曲线放在一起看会更直观。',
        secondLikes: 10,
        firstReplyNickname: '中南大学同门',
        firstReplyContent: '我也觉得要补空白对照，尤其是封装条件这一组。',
        firstReplyLikes: 8,
        secondReplyNickname: '导师',
        secondReplyContent: '下一轮把批次、退火时间和测试环境写成表，方便横向比较。',
        secondReplyLikes: 6
      };
    }
    if (this.containsAny(key, ['临床', '医学', '影像', '病历', '药物', '诊断'])) {
      return {
        firstNickname: '医学 AI 同学',
        firstContent: '这类内容建议同时写敏感性、特异性和病例级错误分析，光看总体指标容易漏掉偏差。',
        firstLikes: 13,
        secondNickname: '师姐',
        secondContent: '如果涉及电子病历抽取，否定表达和缩写规则最好单独留一栏，后续维护会轻松些。',
        secondLikes: 9,
        firstReplyNickname: '中南大学同门',
        firstReplyContent: '可以再补一个人工校验流程，临床数据这里还是要留痕。',
        firstReplyLikes: 6,
        secondReplyNickname: '导师',
        secondReplyContent: '后面写日报时把数据来源和伦理边界也带上，内容会更完整。',
        secondReplyLikes: 4
      };
    }
    return {
      firstNickname: '导师',
      firstContent: '这篇日报可以继续把研究问题、实验设置和下一步计划拆清楚，后续周报整理会省很多时间。',
      firstLikes: 10,
      secondNickname: '中南大学同门',
      secondContent: '我觉得亮点已经有了，再补一组失败样例和复盘结论会更有参考价值。',
      secondLikes: 7,
      firstReplyNickname: '师兄',
      firstReplyContent: '可以按问题、方法、结果、风险四块整理，组会讨论会更聚焦。',
      firstReplyLikes: 5,
      secondReplyNickname: '课题组同学',
      secondReplyContent: '如果后续有脚本或数据表，也可以挂到共享目录。',
      secondReplyLikes: 3
    };
  }

  private commentKey(newsId: string): string {
    const context = this.commentContexts.get(newsId);
    if (context === undefined) {
      return newsId.toLowerCase();
    }
    return `${newsId} ${context.title} ${context.summary} ${context.tagNames.join(' ')}`.toLowerCase();
  }

  private containsAny(text: string, tokens: string[]): boolean {
    for (let index = 0; index < tokens.length; index += 1) {
      if (text.indexOf(tokens[index].toLowerCase()) >= 0) {
        return true;
      }
    }
    return false;
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
    const labels = range === 'day' ? [this.todayText()] : this.recentLabels(range === 'month' ? 30 : 7);
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
      items: this.localNotifications.slice(),
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

  private rememberNotificationRead(id: number): void {
    if (this.locallyReadNotificationIds.indexOf(id) < 0) {
      this.locallyReadNotificationIds = this.locallyReadNotificationIds.concat([id]);
    }
  }

  private rememberNotificationCleared(id: number): void {
    if (this.locallyClearedNotificationIds.indexOf(id) < 0) {
      this.locallyClearedNotificationIds = this.locallyClearedNotificationIds.concat([id]);
    }
  }

  private withNotificationReadState(item: NotificationItem, isRead: boolean): NotificationItem {
    return {
      id: item.id,
      type: item.type,
      title: item.title,
      content: item.content,
      relatedItemId: item.relatedItemId,
      isRead,
      createdAt: item.createdAt
    };
  }

  private todayText(): string {
    const date = new Date();
    return `${date.getFullYear()}-${this.pad2(date.getMonth() + 1)}-${this.pad2(date.getDate())}`;
  }

  private recentLabels(days: number): string[] {
    const labels: string[] = [];
    const current = new Date();
    for (let index = days - 1; index >= 0; index--) {
      const date = new Date(current.getTime());
      date.setDate(current.getDate() - index);
      labels.push(`${this.pad2(date.getMonth() + 1)}-${this.pad2(date.getDate())}`);
    }
    return labels;
  }

  private formatDate(value: string): string {
    if (value.length >= 10) {
      return value.substring(0, 10);
    }
    return value;
  }

  private pad2(value: number): string {
    if (value < 10) {
      return `0${value}`;
    }
    return value.toString();
  }
}

export const communityService = new CommunityService();
