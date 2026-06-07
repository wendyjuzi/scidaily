import http from '@ohos.net.http';
import { DailyPost, DailyPostDraft, DailyTemplate, TopicCategory, TopicTag } from '../models/DailyPost';
import { UserProfile } from '../models/User';
import { AppErrorCode, AppException, globalErrorHandler } from '../utils/AppError';
import { authService } from './AuthService';
import { httpClient } from './HttpClient';

interface DailyPostDto {
  id: string;
  author_id: number;
  author_name: string;
  title: string;
  summary: string;
  content: string;
  cover_url: string;
  image_urls: string[];
  category_id: string;
  category_name: string;
  tags: string[];
  tag_ids: string[];
  status: string;
  created_at: string;
  updated_at: string;
  published_at?: string;
}

interface DailyPostListDto {
  items: DailyPostDto[];
  next_offset: number;
  has_more: boolean;
}

interface DailyPostResponseDto {
  item: DailyPostDto;
}

interface TopicCategoryDto {
  id: string;
  name: string;
  description: string;
  post_count: number;
}

interface TopicTagDto {
  id: string;
  name: string;
  category_id: string;
  category_name: string;
  description: string;
  post_count: number;
}

interface TopicCategoryListDto {
  items: TopicCategoryDto[];
}

interface TopicTagListDto {
  items: TopicTagDto[];
}

interface DailyPostPayload {
  title: string;
  summary: string;
  content: string;
  cover_url: string;
  image_urls: string[];
  category_id: string;
  tag_ids: string[];
  status: string;
}

interface ImageUploadDto {
  url: string;
}

export interface DailyPostPage {
  items: DailyPost[];
  nextOffset: number;
  hasMore: boolean;
}

class DailyPostService {
  private localPosts: DailyPost[] = [
    {
      id: 'local-daily-001',
      authorId: 1,
      authorName: '科研日报体验号',
      title: '多模态科研智能体复现记录',
      summary: '把论文检索、实验脚本和结果复盘串成自动化流程，记录第一轮复现实验的收获。',
      content: '今天完成了多模态科研智能体的最小复现。核心变化是把检索、代码执行和结果摘要拆成三个可观察节点，方便定位失败原因。下一步会加入更严格的基准任务和错误归因表。',
      coverUrl: 'https://images.unsplash.com/photo-1677442136019-21780ecad995?auto=format&fit=crop&w=900&q=80',
      imageUrls: ['https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=900&q=80'],
      categoryId: 'ai',
      categoryName: '人工智能',
      tags: ['AI Agent', '大模型论文'],
      tagIds: ['ai-agent', 'llm-paper'],
      status: 'published',
      createdAt: '2026-06-01',
      updatedAt: '2026-06-01',
      publishedAt: '2026-06-01'
    },
    {
      id: 'local-daily-002',
      authorId: 1,
      authorName: '科研日报体验号',
      title: '单细胞免疫图谱文献阅读',
      summary: '整理炎症消退过程中的瞬时免疫状态，标注可复用的数据处理与可视化方法。',
      content: '这篇工作最值得复用的是跨组织整合策略。作者没有只停留在聚类命名，而是把状态转移、标志基因和功能验证连成证据链。',
      coverUrl: 'https://images.unsplash.com/photo-1576086213369-97a306d36557?auto=format&fit=crop&w=900&q=80',
      imageUrls: [],
      categoryId: 'bio',
      categoryName: '生命科学',
      tags: ['单细胞', '免疫学'],
      tagIds: ['single-cell', 'immunology'],
      status: 'published',
      createdAt: '2026-05-31',
      updatedAt: '2026-05-31',
      publishedAt: '2026-05-31'
    },
    {
      id: 'local-daily-003',
      authorId: 1,
      authorName: '材料组小记',
      title: '钙钛矿稳定性实验小结',
      summary: '记录退火温度、封装条件和湿热测试对器件寿命的影响，准备下一轮对照实验。',
      content: '本轮实验显示封装条件比单纯调配方更影响早期衰减。下一步需要把湿度、温度和光照强度拆开做三因素设计。',
      coverUrl: 'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?auto=format&fit=crop&w=900&q=80',
      imageUrls: [],
      categoryId: 'materials',
      categoryName: '材料科学',
      tags: ['钙钛矿'],
      tagIds: ['perovskite'],
      status: 'published',
      createdAt: '2026-05-30',
      updatedAt: '2026-05-30',
      publishedAt: '2026-05-30'
    }
  ];

  private categories: TopicCategory[] = [
    { id: 'all', name: '全部', description: '全部科研日报', postCount: 3 },
    { id: 'ai', name: '人工智能', description: 'AI for Science、智能体与科研自动化', postCount: 1 },
    { id: 'bio', name: '生命科学', description: '组学、细胞、免疫与机制发现', postCount: 1 },
    { id: 'materials', name: '材料科学', description: '能源材料、催化与表征', postCount: 1 },
    { id: 'medicine', name: '医学转化', description: '临床、药物研发与公共健康', postCount: 0 }
  ];

  private tags: TopicTag[] = [
    { id: 'ai-agent', name: 'AI Agent', categoryId: 'ai', categoryName: '人工智能', description: '科研智能体、工具调用与自动化流程', postCount: 1 },
    { id: 'llm-paper', name: '大模型论文', categoryId: 'ai', categoryName: '人工智能', description: '大模型方法、评测和应用阅读', postCount: 1 },
    { id: 'single-cell', name: '单细胞', categoryId: 'bio', categoryName: '生命科学', description: '单细胞组学图谱与机制发现', postCount: 1 },
    { id: 'immunology', name: '免疫学', categoryId: 'bio', categoryName: '生命科学', description: '免疫状态、炎症和疾病机制', postCount: 1 },
    { id: 'perovskite', name: '钙钛矿', categoryId: 'materials', categoryName: '材料科学', description: '光伏、稳定性和器件工艺', postCount: 1 }
  ];

  private templates: DailyTemplate[] = [
    { id: 'experiment', title: '实验记录', description: '目的、方法、过程、结果与下一步。', blocks: ['实验目的', '材料与方法', '关键过程', '结果观察', '问题与下一步'] },
    { id: 'literature', title: '文献阅读', description: '问题、方法、数据、结论与启发。', blocks: ['研究问题', '核心方法', '数据与实验', '主要结论', '我的启发'] },
    { id: 'summary', title: '科研总结', description: '进展、发现、阻塞、资源与计划。', blocks: ['本周进展', '关键发现', '风险阻塞', '资源需求', '下周计划'] }
  ];

  async listPublished(categoryId: string, tagId: string, offset: number, limit: number): Promise<DailyPostPage> {
    try {
      const params = this.buildQuery(categoryId, tagId, offset, limit);
      const response = await httpClient.request({
        path: `/daily-posts${params}`,
        method: http.RequestMethod.GET
      });
      return this.fromPageDto(JSON.parse(response) as DailyPostListDto);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        throw error as Error;
      }
      return this.listPublishedLocal(categoryId, tagId, offset, limit);
    }
  }

  async getById(postId: string): Promise<DailyPost> {
    const localMatch = this.localPosts.find((item: DailyPost) => item.id === postId);
    if (localMatch !== undefined) {
      return localMatch;
    }
    try {
      const response = await httpClient.request({
        path: `/daily-posts/${postId}`,
        method: http.RequestMethod.GET
      });
      return this.fromPostDto(JSON.parse(response) as DailyPostDto);
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        throw error as Error;
      }
      throw globalErrorHandler.network('日报详情加载失败。');
    }
  }

  async listMine(): Promise<DailyPost[]> {
    this.ensureLoggedIn();
    try {
      const response = await httpClient.request({
        path: '/users/me/daily-posts?status_filter=all&limit=50&offset=0',
        method: http.RequestMethod.GET,
        token: authService.getToken()
      });
      return this.fromPageDto(JSON.parse(response) as DailyPostListDto).items;
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        throw error as Error;
      }
      return this.localPosts;
    }
  }

  async saveDraft(draft: DailyPostDraft): Promise<DailyPost> {
    return this.upsert(draft, 'draft');
  }

  async publish(draft: DailyPostDraft): Promise<DailyPost> {
    return this.upsert(draft, 'published');
  }

  async remove(postId: string): Promise<void> {
    this.ensureLoggedIn();
    try {
      await httpClient.request({
        path: `/users/me/daily-posts/${postId}`,
        method: http.RequestMethod.DELETE,
        token: authService.getToken()
      });
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        throw error as Error;
      }
    }
    this.localPosts = this.localPosts.filter((item: DailyPost) => item.id !== postId);
  }

  async listCategories(): Promise<TopicCategory[]> {
    try {
      const response = await httpClient.request({
        path: '/topics/categories',
        method: http.RequestMethod.GET
      });
      const dto = JSON.parse(response) as TopicCategoryListDto;
      const items = dto.items.map((item: TopicCategoryDto) => this.fromCategoryDto(item));
      const allCategory: TopicCategory = {
        id: 'all',
        name: '全部',
        description: '全部科研日报',
        postCount: items.reduce((sum: number, item: TopicCategory) => sum + item.postCount, 0)
      };
      return [allCategory].concat(items);
    } catch (error) {
      return this.categories;
    }
  }

  async listTags(categoryId: string = ''): Promise<TopicTag[]> {
    try {
      const suffix = categoryId.length > 0 && categoryId !== 'all' ? `?category_id=${categoryId}` : '';
      const response = await httpClient.request({
        path: `/topics/tags${suffix}`,
        method: http.RequestMethod.GET
      });
      const dto = JSON.parse(response) as TopicTagListDto;
      return dto.items.map((item: TopicTagDto) => this.fromTagDto(item));
    } catch (error) {
      if (categoryId.length === 0 || categoryId === 'all') {
        return this.tags;
      }
      return this.tags.filter((item: TopicTag) => item.categoryId === categoryId);
    }
  }

  async addTag(name: string, categoryId: string): Promise<TopicTag> {
    this.ensureLoggedIn();
    const category = this.categories.find((item: TopicCategory) => item.id === categoryId) ?? this.categories[1];
    try {
      const response = await httpClient.request({
        path: '/topics/tags',
        method: http.RequestMethod.POST,
        token: authService.getToken(),
        body: JSON.stringify({ name, category_id: category.id, description: '用户自定义科研标签' })
      });
      return this.fromTagDto(JSON.parse(response) as TopicTagDto);
    } catch (error) {
      const tag: TopicTag = {
        id: `local-${Date.now()}`,
        name,
        categoryId: category.id,
        categoryName: category.name,
        description: '用户自定义科研标签',
        postCount: 0
      };
      this.tags.unshift(tag);
      return tag;
    }
  }

  async addCategory(name: string): Promise<TopicCategory> {
    this.ensureLoggedIn();
    try {
      const response = await httpClient.request({
        path: '/topics/categories',
        method: http.RequestMethod.POST,
        token: authService.getToken(),
        body: JSON.stringify({ name, description: '用户自定义学科分类' })
      });
      const category = this.fromCategoryDto(JSON.parse(response) as TopicCategoryDto);
      this.categories = this.categories.concat([category]);
      return category;
    } catch (error) {
      const category: TopicCategory = {
        id: `local-cat-${Date.now()}`,
        name,
        description: '用户自定义学科分类',
        postCount: 0
      };
      this.categories = this.categories.concat([category]);
      return category;
    }
  }

  async deleteTag(tagId: string): Promise<void> {
    this.ensureLoggedIn();
    try {
      await httpClient.request({
        path: `/topics/tags/${tagId}`,
        method: http.RequestMethod.DELETE,
        token: authService.getToken()
      });
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        throw error as Error;
      }
    }
    this.tags = this.tags.filter((item: TopicTag) => item.id !== tagId);
    this.localPosts = this.localPosts.map((post: DailyPost) => {
      const index = post.tagIds.indexOf(tagId);
      if (index < 0) {
        return post;
      }
      const tagIds = post.tagIds.filter((id: string) => id !== tagId);
      const tags = post.tags.filter((_name: string, tagIndex: number) => tagIndex !== index);
      return {
        id: post.id,
        authorId: post.authorId,
        authorName: post.authorName,
        title: post.title,
        summary: post.summary,
        content: post.content,
        coverUrl: post.coverUrl,
        imageUrls: post.imageUrls,
        categoryId: post.categoryId,
        categoryName: post.categoryName,
        tags: tags,
        tagIds: tagIds,
        status: post.status,
        createdAt: post.createdAt,
        updatedAt: post.updatedAt,
        publishedAt: post.publishedAt
      };
    });
  }

  async listTemplates(): Promise<DailyTemplate[]> {
    try {
      const response = await httpClient.request({
        path: '/daily-posts/templates',
        method: http.RequestMethod.GET
      });
      return JSON.parse(response) as DailyTemplate[];
    } catch (error) {
      return this.templates;
    }
  }

  async uploadImage(filename: string, contentBase64: string): Promise<string> {
    this.ensureLoggedIn();
    const response = await httpClient.request({
      path: '/uploads/images',
      method: http.RequestMethod.POST,
      token: authService.getToken(),
      body: JSON.stringify({
        filename,
        content_base64: contentBase64
      })
    });
    return (JSON.parse(response) as ImageUploadDto).url;
  }

  applyTemplate(template: DailyTemplate): string {
    let content = '';
    template.blocks.forEach((block: string) => {
      content += `## ${block}\n\n`;
    });
    return content.trim();
  }

  private async upsert(draft: DailyPostDraft, status: string): Promise<DailyPost> {
    this.ensureLoggedIn();
    const payload = this.toPayload(draft, status);
    try {
      const response = await httpClient.request({
        path: draft.id ? `/users/me/daily-posts/${draft.id}` : '/users/me/daily-posts',
        method: draft.id ? http.RequestMethod.PUT : http.RequestMethod.POST,
        body: JSON.stringify(payload),
        token: authService.getToken()
      });
      const item = this.fromPostDto((JSON.parse(response) as DailyPostResponseDto).item);
      this.upsertLocal(item);
      return item;
    } catch (error) {
      if (!(error instanceof AppException) || error.code !== AppErrorCode.Network) {
        throw error as Error;
      }
      const item = this.localFromDraft(draft, status);
      this.upsertLocal(item);
      return item;
    }
  }

  private buildQuery(categoryId: string, tagId: string, offset: number, limit: number): string {
    const params: string[] = [`offset=${offset}`, `limit=${limit}`];
    if (categoryId.length > 0 && categoryId !== 'all') {
      params.push(`category_id=${categoryId}`);
    }
    if (tagId.length > 0) {
      params.push(`tag_id=${tagId}`);
    }
    return `?${params.join('&')}`;
  }

  private listPublishedLocal(categoryId: string, tagId: string, offset: number, limit: number): DailyPostPage {
    let items = this.localPosts.filter((item: DailyPost) => item.status === 'published');
    if (categoryId.length > 0 && categoryId !== 'all') {
      items = items.filter((item: DailyPost) => item.categoryId === categoryId);
    }
    if (tagId.length > 0) {
      items = items.filter((item: DailyPost) => item.tagIds.includes(tagId));
    }
    const slice = items.slice(offset, offset + limit);
    return {
      items: slice,
      nextOffset: offset + slice.length,
      hasMore: offset + slice.length < items.length
    };
  }

  private toPayload(draft: DailyPostDraft, status: string): DailyPostPayload {
    return {
      title: draft.title,
      summary: draft.summary,
      content: draft.content,
      cover_url: draft.coverUrl,
      image_urls: draft.imageUrls,
      category_id: draft.categoryId,
      tag_ids: draft.tagIds,
      status
    };
  }

  private localFromDraft(draft: DailyPostDraft, status: string): DailyPost {
    const category = this.categories.find((item: TopicCategory) => item.id === draft.categoryId) ?? this.categories[1];
    const tags = this.tags.filter((item: TopicTag) => draft.tagIds.includes(item.id));
    const dateText = this.todayText();
    const user: UserProfile | undefined = authService.getCurrentUser();
    return {
      id: draft.id ?? `local-${Date.now()}`,
      authorId: 1,
      authorName: user !== undefined ? user.nickname : '我',
      title: draft.title,
      summary: draft.summary,
      content: draft.content,
      coverUrl: draft.coverUrl,
      imageUrls: draft.imageUrls,
      categoryId: category.id,
      categoryName: category.name,
      tags: tags.map((item: TopicTag) => item.name),
      tagIds: tags.map((item: TopicTag) => item.id),
      status,
      createdAt: dateText,
      updatedAt: dateText,
      publishedAt: status === 'published' ? dateText : undefined
    };
  }

  private upsertLocal(post: DailyPost): void {
    this.localPosts = this.localPosts.filter((item: DailyPost) => item.id !== post.id);
    this.localPosts.unshift(post);
  }

  private fromPageDto(dto: DailyPostListDto): DailyPostPage {
    const items = dto.items.map((item: DailyPostDto) => this.fromPostDto(item))
      .filter((item: DailyPost) => !this.isPlaceholderPost(item));
    items.forEach((item: DailyPost) => {
      this.upsertLocal(item);
    });
    return {
      items,
      nextOffset: dto.next_offset,
      hasMore: dto.has_more
    };
  }

  private fromPostDto(dto: DailyPostDto): DailyPost {
    return {
      id: dto.id,
      authorId: dto.author_id,
      authorName: dto.author_name,
      title: dto.title,
      summary: dto.summary,
      content: dto.content,
      coverUrl: dto.cover_url,
      imageUrls: dto.image_urls,
      categoryId: dto.category_id,
      categoryName: dto.category_name,
      tags: dto.tags,
      tagIds: dto.tag_ids,
      status: dto.status,
      createdAt: dto.created_at,
      updatedAt: dto.updated_at,
      publishedAt: dto.published_at
    };
  }

  private isPlaceholderPost(item: DailyPost): boolean {
    return this.isPlaceholderText(item.title) && this.isPlaceholderText(item.summary);
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

  private fromCategoryDto(dto: TopicCategoryDto): TopicCategory {
    return {
      id: dto.id,
      name: dto.name,
      description: dto.description,
      postCount: dto.post_count
    };
  }

  private fromTagDto(dto: TopicTagDto): TopicTag {
    return {
      id: dto.id,
      name: dto.name,
      categoryId: dto.category_id,
      categoryName: dto.category_name,
      description: dto.description,
      postCount: dto.post_count
    };
  }

  private ensureLoggedIn(): void {
    if (!authService.isLoggedIn()) {
      throw globalErrorHandler.unauthorized('请先登录后再创作科研日报。');
    }
  }

  private todayText(): string {
    const date = new Date();
    const monthValue = date.getMonth() + 1;
    const dayValue = date.getDate();
    const month = monthValue < 10 ? `0${monthValue}` : `${monthValue}`;
    const day = dayValue < 10 ? `0${dayValue}` : `${dayValue}`;
    return `${date.getFullYear()}-${month}-${day}`;
  }
}

export const dailyPostService = new DailyPostService();
