import { router } from '@kit.ArkUI';
import { NotificationBundle, NotificationItem } from '../models/Community';
import { PaperItem } from '../models/Paper';
import { ResearchNews } from '../models/ResearchNews';
import { DailyPost, DailyPostDraft, DailyTemplate, TopicCategory, TopicTag } from '../models/DailyPost';
import { PersonalStats, UserProfile } from '../models/User';
import { authService } from '../services/AuthService';
import { communityService } from '../services/CommunityService';
import { newsService } from '../services/NewsService';
import { dailyPostService } from '../services/DailyPostService';
import { paperService } from '../services/PaperService';
import { personalCenterService } from '../services/PersonalCenterService';
import { AppColor, Space, Radius, Font, Elevation } from '../theme/AppTheme';

interface CollegeInfo {
  id: string;
  name: string;
  city: string;
  tagLine: string;
  activeCount: number;
  followerText: string;
}

interface CollegeNewsItem {
  id: string;
  collegeId: string;
  title: string;
  summary: string;
  source: string;
  time: string;
  topic: string;
  heat: number;
}

@Entry
@Component
struct Index {
  @State posts: DailyPost[] = [];
  @State leftPosts: DailyPost[] = [];
  @State rightPosts: DailyPost[] = [];
  @State categories: TopicCategory[] = [];
  @State tags: TopicTag[] = [];
  @State templates: DailyTemplate[] = [];
  @State myPosts: DailyPost[] = [];
  @State homeChannel: string = 'discover';
  @State selectedCollegeId: string = 'tsinghua';
  @State selectedCategoryId: string = 'all';
  @State selectedTagId: string = '';
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State hasMore: boolean = true;
  @State nextOffset: number = 0;
  @State currentUser: UserProfile | undefined = undefined;
  @State profileStats: PersonalStats = {
    postCount: 0,
    collectionCount: 0,
    likeCount: 0,
    historyCount: 0,
    continuousDays: 0
  };
  @State editorId: string = '';
  @State editorTitle: string = '';
  @State editorSummary: string = '';
  @State editorContent: string = '';
  @State editorCoverUrl: string = 'https://images.unsplash.com/photo-1677442136019-21780ecad995?auto=format&fit=crop&w=900&q=80';
  @State editorImageInput: string = '';
  @State editorImages: string[] = [];
  @State editorCategoryId: string = 'ai';
  @State editorTagIds: string[] = [];
  @State editorError: string = '';
  @State toastText: string = '';
  @State newTagName: string = '';
  @State newCategoryName: string = '';
  @State selectedTemplateId: string = '';
  @State detailPost: DailyPost | undefined = undefined;
  @State unreadCount: number = 0;
  @State messageItems: NotificationItem[] = [];
  @State messageError: string = '';
  @State aiMode: string = 'paper';
  @State aiPrompt: string = '';
  @State aiAnswer: string = '';
  @State currentTab: number = 0;
  @State likedPostIds: string[] = [];
  @State colleges: CollegeInfo[] = [
    {
      id: 'tsinghua',
      name: '清华大学',
      city: '北京',
      tagLine: 'AI、材料与交叉学科动态密集更新',
      activeCount: 128,
      followerText: '3.8 万同学关注'
    },
    {
      id: 'pku',
      name: '北京大学',
      city: '北京',
      tagLine: '生命科学、医学与基础研究资讯',
      activeCount: 96,
      followerText: '3.1 万同学关注'
    },
    {
      id: 'sjtu',
      name: '上海交通大学',
      city: '上海',
      tagLine: '工程、医工交叉与创新项目集合',
      activeCount: 84,
      followerText: '2.6 万同学关注'
    },
    {
      id: 'zju',
      name: '浙江大学',
      city: '杭州',
      tagLine: '机器人、农业科学与数据智能前沿',
      activeCount: 72,
      followerText: '2.2 万同学关注'
    }
  ];
  @State collegeNewsItems: CollegeNewsItem[] = [
    {
      id: 'tsinghua-1',
      collegeId: 'tsinghua',
      title: '交叉信息院团队开源多模态科研助手评测集',
      summary: '覆盖论文检索、实验设计和结果复核等场景，适合做组会分享与课程项目基线。',
      source: '清华科研快讯',
      time: '今天 09:20',
      topic: '人工智能',
      heat: 86
    },
    {
      id: 'tsinghua-2',
      collegeId: 'tsinghua',
      title: '材料学院发布柔性传感器最新进展',
      summary: '新结构提升了低温环境下的稳定性，相关论文已开放预印本。',
      source: '材料学院',
      time: '昨天 18:40',
      topic: '材料科学',
      heat: 62
    },
    {
      id: 'pku-1',
      collegeId: 'pku',
      title: '生命科学学院举办单细胞组学方法训练营',
      summary: '课程覆盖数据质控、聚类注释和疾病队列分析，面向研究生开放报名。',
      source: '北大生科',
      time: '今天 10:05',
      topic: '生命科学',
      heat: 78
    },
    {
      id: 'pku-2',
      collegeId: 'pku',
      title: '医学部临床 AI 读书会更新本周论文清单',
      summary: '重点讨论真实世界数据中的偏倚校正与模型外部验证。',
      source: '医学部研会',
      time: '昨天 16:10',
      topic: '医学 AI',
      heat: 55
    },
    {
      id: 'sjtu-1',
      collegeId: 'sjtu',
      title: '电院智能机器人方向开放联合课题报名',
      summary: '项目聚焦具身智能、工业巡检和低成本机械臂控制，支持跨院系组队。',
      source: '交大电院',
      time: '今天 08:30',
      topic: '机器人',
      heat: 74
    },
    {
      id: 'zju-1',
      collegeId: 'zju',
      title: '计算机学院发布农业智能感知挑战赛赛题',
      summary: '赛题包含田间图像分割、病虫害识别和时序预测三个方向。',
      source: '浙大 CS',
      time: '今天 11:25',
      topic: '数据智能',
      heat: 69
    }
  ];
  aboutToAppear(): void {
    this.bootstrap();
  }

  onPageShow(): void {
    this.currentUser = authService.getCurrentUser();
    this.reloadProfile();
    this.reloadMine();
    this.reloadNotifications();
  }

  private bootstrap(): void {
    this.currentUser = authService.getCurrentUser();
    dailyPostService.listCategories().then((items: TopicCategory[]) => {
      this.categories = items;
      const firstReal = items.find((item: TopicCategory) => item.id !== 'all');
      if (firstReal !== undefined) {
        this.editorCategoryId = firstReal.id;
      }
    });
    dailyPostService.listTags().then((items: TopicTag[]) => {
      this.tags = items;
    });
    dailyPostService.listTemplates().then((items: DailyTemplate[]) => {
      this.templates = items;
    });
    this.reloadProfile();
    this.reloadMine();
    this.reloadNotifications();
    this.refreshFeed();
  }

  private refreshFeed(): void {
    this.refreshing = true;
    this.nextOffset = 0;
    dailyPostService.listPublished(this.selectedCategoryId, this.selectedTagId, 0, 10)
      .then((page) => {
        this.nextOffset = page.nextOffset;
        this.hasMore = page.hasMore;
        paperService.listPapers(0, 20).then((paperPage) => {
          const paperPosts = paperPage.items.map((paper: PaperItem) => this.paperToFeedPost(paper));
          this.posts = this.mergeFeedItems(page.items, paperPosts);
          this.splitColumns();
        }).catch((error: Error) => {
          this.posts = page.items;
          this.splitColumns();
        });
      })
      .finally(() => {
        this.loading = false;
        this.refreshing = false;
      });
  }

  private mergeFeedItems(dailyItems: DailyPost[], paperItems: DailyPost[]): DailyPost[] {
    const result: DailyPost[] = [];
    const maxLength = Math.max(dailyItems.length, paperItems.length);
    for (let index = 0; index < maxLength; index++) {
      if (index < dailyItems.length) {
        result.push(dailyItems[index]);
      }
      if (index < paperItems.length) {
        result.push(paperItems[index]);
      }
    }
    return result;
  }

  private loadMore(): void {
    if (!this.hasMore || this.refreshing) {
      return;
    }
    this.refreshing = true;
    dailyPostService.listPublished(this.selectedCategoryId, this.selectedTagId, this.nextOffset, 10)
      .then((page) => {
        this.posts = this.posts.concat(page.items);
        this.nextOffset = page.nextOffset;
        this.hasMore = page.hasMore;
        this.splitColumns();
      })
      .finally(() => {
        this.refreshing = false;
      });
  }

  private splitColumns(): void {
    const left: DailyPost[] = [];
    const right: DailyPost[] = [];
    this.posts.forEach((item: DailyPost, index: number) => {
      if (index % 2 === 0) {
        left.push(item);
      } else {
        right.push(item);
      }
    });
    this.leftPosts = left;
    this.rightPosts = right;
  }

  private paperToFeedPost(paper: PaperItem): DailyPost {
    return {
      id: `paper:${paper.id}`,
      authorId: 0,
      authorName: paper.authors.length > 0 ? paper.authors[0] : 'Open PDF',
      title: paper.title,
      summary: paper.abstract,
      content: paper.abstract,
      coverUrl: this.paperCoverUrl(paper.categoryId),
      imageUrls: [],
      categoryId: paper.categoryId,
      categoryName: `PDF · ${paper.categoryName}`,
      tags: paper.tags.length > 0 ? paper.tags : ['PDF'],
      tagIds: paper.tagIds,
      status: 'published',
      createdAt: paper.createdAt,
      updatedAt: paper.createdAt,
      publishedAt: paper.publishedAt
    };
  }

  private paperCoverUrl(categoryId: string): string {
    if (categoryId === 'bio') {
      return 'https://images.unsplash.com/photo-1576086213369-97a306d36557?auto=format&fit=crop&w=900&q=80';
    }
    if (categoryId === 'materials') {
      return 'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?auto=format&fit=crop&w=900&q=80';
    }
    if (categoryId === 'medicine') {
      return 'https://images.unsplash.com/photo-1583912267550-d44c03f6df43?auto=format&fit=crop&w=900&q=80';
    }
    return 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=900&q=80';
  }

  private feedCoverUrl(post: DailyPost): string {
    const url = post.coverUrl.trim();
    if (post.title.includes('单细胞聚类参数对比') || url.includes('1581093458791-9d09f8d088f4')) {
      return this.paperCoverUrl('bio');
    }
    if (url.length > 0 && url.startsWith('http')) {
      return url;
    }
    return this.paperCoverUrl(post.categoryId);
  }

  private selectCategory(categoryId: string): void {
    this.selectedCategoryId = categoryId;
    this.selectedTagId = '';
    dailyPostService.listTags(categoryId).then((items: TopicTag[]) => {
      this.tags = items;
    });
    this.refreshFeed();
  }

  private selectTag(tagId: string): void {
    this.selectedTagId = this.selectedTagId === tagId ? '' : tagId;
    this.refreshFeed();
  }

  private reloadProfile(): void {
    this.currentUser = authService.getCurrentUser();
    if (this.currentUser) {
      personalCenterService.getStats().then((stats: PersonalStats) => {
        this.profileStats = stats;
      }).catch((error: Error) => {
        this.profileStats = this.emptyStats();
      });
      return;
    }
    this.profileStats = this.emptyStats();
  }

  private emptyStats(): PersonalStats {
    return {
      postCount: 0,
      collectionCount: 0,
      likeCount: 0,
      historyCount: 0,
      continuousDays: 0
    };
  }

  private reloadMine(): void {
    if (!authService.isLoggedIn()) {
      this.myPosts = [];
      return;
    }
    dailyPostService.listMine().then((items: DailyPost[]) => {
      this.myPosts = items;
    });
  }

  private reloadNotifications(): void {
    if (!authService.isLoggedIn()) {
      this.unreadCount = 0;
      this.messageItems = [];
      this.messageError = '';
      return;
    }
    communityService.getNotifications().then((bundle: NotificationBundle) => {
      this.unreadCount = bundle.unreadCount;
      this.messageItems = bundle.items;
      this.messageError = '';
    }).catch((error: Error) => {
      this.unreadCount = 0;
      this.messageItems = [];
      this.messageError = error.message;
    });
  }

  private readNotification(id: number): void {
    communityService.markNotificationRead(id).then(() => {
      this.reloadNotifications();
    }).catch((error: Error) => {
      this.messageError = error.message;
    });
  }

  private readAllNotifications(): void {
    communityService.markAllNotificationsRead().then(() => {
      this.reloadNotifications();
    }).catch((error: Error) => {
      this.messageError = error.message;
    });
  }

  private clearNotifications(): void {
    communityService.clearNotifications().then(() => {
      this.reloadNotifications();
    }).catch((error: Error) => {
      this.messageError = error.message;
    });
  }

  private selectMainTab(index: number): void {
    this.currentTab = index;
    if (index === 3) {
      this.reloadNotifications();
    }
  }

  private requireLogin(): boolean {
    if (authService.isLoggedIn()) {
      return true;
    }
    router.pushUrl({ url: 'pages/Login' });
    return false;
  }

  private applyTemplate(template: DailyTemplate): void {
    this.selectedTemplateId = template.id;
    this.editorContent = dailyPostService.applyTemplate(template);
    if (this.editorTitle.length === 0) {
      this.editorTitle = template.title;
    }
  }

  private toggleEditorTag(tagId: string): void {
    if (this.editorTagIds.includes(tagId)) {
      this.editorTagIds = this.editorTagIds.filter((id: string) => id !== tagId);
      return;
    }
    this.editorTagIds = this.editorTagIds.concat([tagId]);
  }

  private addImageUrl(): void {
    const url = this.editorImageInput.trim();
    if (url.length === 0) {
      return;
    }
    this.editorImages = this.editorImages.concat([url]);
    this.editorImageInput = '';
  }

  private removeImageUrl(url: string): void {
    this.editorImages = this.editorImages.filter((item: string) => item !== url);
  }

  private saveDraft(): void {
    if (!this.requireLogin()) {
      return;
    }
    if (!this.validateEditor(false)) {
      return;
    }
    dailyPostService.saveDraft(this.currentDraft()).then((post: DailyPost) => {
      this.afterSaved(post, '草稿已保存');
    });
  }

  private publishDraft(): void {
    if (!this.requireLogin()) {
      return;
    }
    if (!this.validateEditor(true)) {
      return;
    }
    dailyPostService.publish(this.currentDraft()).then((post: DailyPost) => {
      this.afterSaved(post, '科研日报已发布');
      this.refreshFeed();
    });
  }

  private validateEditor(strict: boolean): boolean {
    if (this.editorTitle.trim().length === 0) {
      this.editorError = '请先填写标题';
      return false;
    }
    if (this.editorContent.trim().length === 0) {
      this.editorError = '请先填写正文';
      return false;
    }
    if (strict && this.editorSummary.trim().length === 0) {
      this.editorError = '即时发布需要填写摘要';
      return false;
    }
    if (strict && this.editorTagIds.length === 0) {
      this.editorError = '即时发布至少选择一个研究方向标签';
      return false;
    }
    this.editorError = '';
    return true;
  }

  private editPost(post: DailyPost): void {
    this.editorId = post.id;
    this.editorTitle = post.title;
    this.editorSummary = post.summary;
    this.editorContent = post.content;
    this.editorCoverUrl = post.coverUrl;
    this.editorImages = post.imageUrls;
    this.editorCategoryId = post.categoryId;
    this.editorTagIds = post.tagIds;
    this.selectMainTab(2);
  }

  private deletePost(postId: string): void {
    if (!this.requireLogin()) {
      return;
    }
    dailyPostService.remove(postId).then(() => {
      this.toastText = '日报已删除';
      this.reloadMine();
      this.refreshFeed();
    });
  }

  private afterSaved(post: DailyPost, message: string): void {
    this.editorId = post.id;
    this.toastText = message;
    this.reloadMine();
  }

  private resetEditor(): void {
    this.editorId = '';
    this.editorTitle = '';
    this.editorSummary = '';
    this.editorContent = '';
    this.editorCoverUrl = 'https://images.unsplash.com/photo-1677442136019-21780ecad995?auto=format&fit=crop&w=900&q=80';
    this.editorImages = [];
    this.editorImageInput = '';
    this.editorTagIds = [];
    this.selectedTemplateId = '';
    this.editorError = '';
  }

  private currentDraft(): DailyPostDraft {
    return {
      id: this.editorId.length > 0 ? this.editorId : undefined,
      title: this.editorTitle,
      summary: this.editorSummary,
      content: this.editorContent,
      coverUrl: this.editorCoverUrl,
      imageUrls: this.editorImages,
      categoryId: this.editorCategoryId,
      tagIds: this.editorTagIds,
      status: 'draft'
    };
  }

  private addTopicTag(): void {
    if (!this.requireLogin()) {
      return;
    }
    const name = this.newTagName.trim();
    if (name.length === 0) {
      return;
    }
    dailyPostService.addTag(name, this.editorCategoryId).then((tag: TopicTag) => {
      this.tags = [tag].concat(this.tags);
      this.newTagName = '';
      this.toastText = '标签已添加';
    });
  }

  private addTopicCategory(): void {
    if (!this.requireLogin()) {
      return;
    }
    const name = this.newCategoryName.trim();
    if (name.length === 0) {
      return;
    }
    dailyPostService.addCategory(name).then((category: TopicCategory) => {
      if (!this.categories.some((item: TopicCategory) => item.id === category.id)) {
        this.categories = this.categories.concat([category]);
      }
      this.editorCategoryId = category.id;
      this.newCategoryName = '';
      this.toastText = '学科分类已添加';
    });
  }

  private deleteTopicTag(tag: TopicTag): void {
    if (!this.requireLogin()) {
      return;
    }
    dailyPostService.deleteTag(tag.id).then(() => {
      this.tags = this.tags.filter((item: TopicTag) => item.id !== tag.id);
      this.editorTagIds = this.editorTagIds.filter((id: string) => id !== tag.id);
      if (this.selectedTagId === tag.id) {
        this.selectedTagId = '';
        this.refreshFeed();
      }
      this.toastText = '标签已删除';
    });
  }

  private insertText(snippet: string): void {
    const prefix = this.editorContent.length > 0 ? `${this.editorContent}\n\n` : '';
    this.editorContent = `${prefix}${snippet}`;
  }

  private previewAuthorName(): string {
    if (this.currentUser !== undefined) {
      return this.currentUser.nickname;
    }
    return '我';
  }

  private editorCategoryName(): string {
    const category = this.categories.find((item: TopicCategory) => item.id === this.editorCategoryId);
    if (category !== undefined) {
      return category.name;
    }
    return '科研';
  }

  private cardImageHeight(index: number): number {
    const heights = [156, 206, 132, 188, 224];
    return heights[index % heights.length];
  }

  private initial(name: string): string {
    return name.length > 0 ? name.substring(0, 1).toUpperCase() : '研';
  }

  private avatarColor(seed: string): string {
    const palette: string[] = [AppColor.primary, AppColor.accent, AppColor.accentStrong, AppColor.series3, AppColor.primaryStrong];
    let sum = 0;
    for (let i = 0; i < seed.length; i++) {
      sum += seed.charCodeAt(i);
    }
    return palette[sum % palette.length];
  }

  private hasRealAvatar(url: string): boolean {
    return url.length > 0 && url.startsWith('http') && !url.includes('example.com');
  }

  private greetingTitle(): string {
    if (this.currentUser !== undefined) {
      return `Hi，${this.currentUser.nickname}`;
    }
    return '科研日报';
  }

  private feedLikeText(index: number): string {
    const values: string[] = ['49', '61', '1.5万', '10', '84', '128'];
    return values[index % values.length];
  }

  private selectedCollege(): CollegeInfo {
    const college = this.colleges.find((item: CollegeInfo) => item.id === this.selectedCollegeId);
    return college === undefined ? this.colleges[0] : college;
  }

  private currentCollegeNews(): CollegeNewsItem[] {
    return this.collegeNewsItems.filter((item: CollegeNewsItem) => item.collegeId === this.selectedCollegeId);
  }

  private isFeedLiked(postId: string): boolean {
    return this.likedPostIds.includes(postId);
  }

  private openFeedPost(post: DailyPost): void {
    if (post.id.startsWith('paper:')) {
      router.pushUrl({
        url: 'pages/PDFReader',
        params: { paperId: post.id.substring(6) }
      });
      return;
    }
    router.pushUrl({
      url: 'pages/DailyPostDetail',
      params: { id: post.id }
    });
  }

  private toggleFeedLike(post: DailyPost): void {
    if (!authService.isLoggedIn()) {
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
    if (this.isFeedLiked(post.id)) {
      personalCenterService.removeLikeItem(post.id).then(() => {
        this.likedPostIds = this.likedPostIds.filter((id: string) => id !== post.id);
      }).catch((error: Error) => {
        this.toastText = error.message;
      });
      return;
    }
    personalCenterService.addLikeItem(post.id, post.title, post.summary).then(() => {
      this.likedPostIds = this.likedPostIds.concat([post.id]);
    }).catch((error: Error) => {
      this.toastText = error.message;
    });
  }

  @Builder
  private topChannel(title: string, channel: string): void {
    Column({ space: Space.xs }) {
      Text(title)
        .fontSize(22)
        .fontWeight(this.homeChannel === channel ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.homeChannel === channel ? AppColor.textTitle : AppColor.textMuted);
      Column()
        .width(36)
        .height(4)
        .backgroundColor(this.homeChannel === channel ? AppColor.accent : '#00FFFFFF')
        .borderRadius(2);
    }
    .height(56)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.homeChannel = channel;
    });
  }

  @Builder
  private feedFilterText(title: string, active: boolean, action: () => void): void {
    Text(title)
      .fontSize(18)
      .fontWeight(active ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(active ? AppColor.textTitle : AppColor.textMuted)
      .maxLines(1)
      .onClick(action);
  }

  @Builder
  private discoveryHeader(): void {
    Row() {
      Text('○')
        .width(46)
        .height(56)
        .fontSize(34)
        .fontColor(AppColor.textTitle)
        .textAlign(TextAlign.Center);

      Row({ space: 34 }) {
        this.topChannel('关注', 'follow');
        this.topChannel('发现', 'discover');
        this.topChannel('高校', 'college');
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center);

      Text('⌕')
        .width(46)
        .height(56)
        .fontSize(34)
        .fontColor(AppColor.textTitle)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Search' });
        });
    }
    .width('100%')
    .height(64)
    .padding({ left: Space.sm, right: Space.sm })
    .backgroundColor(AppColor.surface);
  }

  @Builder
  private discoveryFilterBar(): void {
    Scroll() {
      Row({ space: 30 }) {
        this.feedFilterText('推荐', this.selectedCategoryId === 'all' && this.selectedTagId.length === 0, () => {
          this.selectCategory('all');
        });
        ForEach(this.categories.filter((item: TopicCategory) => item.id !== 'all'), (category: TopicCategory) => {
          this.feedFilterText(category.name, this.selectedCategoryId === category.id, () => {
            this.selectCategory(category.id);
          });
        }, (category: TopicCategory) => category.id);
        Text('⌄')
          .fontSize(22)
          .fontColor(AppColor.textTitle);
      }
      .padding({ left: Space.lg, right: Space.xxl });
    }
    .width('100%')
    .height(52)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .backgroundColor(AppColor.surface)
    .border({ width: 1, color: AppColor.border });
  }

  @Builder
  private avatarBadge(name: string, url: string, size: number): void {
    if (this.hasRealAvatar(url)) {
      Image(url)
        .width(size)
        .height(size)
        .borderRadius(size / 2)
        .objectFit(ImageFit.Cover)
        .backgroundColor(AppColor.surfaceSoft);
    } else {
      Text(this.initial(name))
        .width(size)
        .height(size)
        .borderRadius(size / 2)
        .backgroundColor(this.avatarColor(name))
        .fontColor(AppColor.textOnPrimary)
        .fontSize(size * 0.42)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center);
    }
  }

  @Builder
  private statCell(label: string, value: number, action: () => void): void {
    Column({ space: 3 }) {
      Text(value.toString())
        .fontSize(Font.title)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textTitle);
      Text(label)
        .fontSize(Font.caption)
        .fontColor(AppColor.textMuted);
    }
    .layoutWeight(1)
    .onClick(action);
  }

  @Builder
  private statDivider(): void {
    Column()
      .width(1)
      .height(26)
      .backgroundColor(AppColor.border);
  }

  @Builder
  private menuRow(icon: string, title: string, badge: number, action: () => void): void {
    Row({ space: Space.md }) {
      Text(icon)
        .fontSize(Font.sub)
        .fontColor(AppColor.accent)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppColor.accentSoft)
        .borderRadius(Radius.md);
      Text(title)
        .fontSize(Font.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textBody)
        .layoutWeight(1);
      if (badge > 0) {
        Text(badge.toString())
          .fontSize(Font.caption)
          .fontColor(AppColor.textOnPrimary)
          .backgroundColor(AppColor.danger)
          .borderRadius(Radius.pill)
          .padding({ left: 7, right: 7, top: 2, bottom: 2 });
      }
      Text('›')
        .fontSize(Font.title)
        .fontColor(AppColor.textMuted);
    }
    .width('100%')
    .height(52)
    .padding({ left: Space.md, right: Space.md })
    .onClick(action);
  }

  @Builder
  private tabBarItem(title: string, index: number): void {
    if (index === 2) {
      Column() {
        Text('+')
          .width(58)
          .height(42)
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textOnPrimary)
          .textAlign(TextAlign.Center)
          .backgroundColor(AppColor.primary)
          .borderRadius(12);
      }
      .height(58)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.selectMainTab(index);
      });
    } else {
      Column({ space: Space.xs }) {
        Row({ space: Space.xs }) {
          Text(title)
            .fontSize(22)
            .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.currentTab === index ? AppColor.textTitle : AppColor.textMuted);
          if (index === 3 && this.unreadCount > 0) {
            Text(this.unreadCount > 99 ? '99+' : this.unreadCount.toString())
              .fontSize(Font.caption)
              .fontColor(AppColor.textOnPrimary)
              .backgroundColor(AppColor.danger)
              .borderRadius(Radius.pill)
              .padding({ left: 6, right: 6, top: 1, bottom: 1 });
          }
        }
        .alignItems(VerticalAlign.Center);
        Column()
          .width(this.currentTab === index ? 34 : 0)
          .height(3)
          .backgroundColor(AppColor.accent)
          .borderRadius(2);
      }
      .height(58)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.selectMainTab(index);
      });
    }
  }

  @Builder
  private categoryChip(category: TopicCategory): void {
    Button(category.name)
      .height(34)
      .fontSize(Font.small)
      .fontWeight(this.selectedCategoryId === category.id ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.selectedCategoryId === category.id ? AppColor.textOnPrimary : AppColor.textBody)
      .backgroundColor(this.selectedCategoryId === category.id ? AppColor.primary : AppColor.surface)
      .border({ width: 1, color: this.selectedCategoryId === category.id ? AppColor.primary : AppColor.border })
      .borderRadius(Radius.lg)
      .padding({ left: Space.lg, right: Space.lg })
      .onClick(() => {
        this.selectCategory(category.id);
      });
  }

  @Builder
  private tagChip(tag: TopicTag, active: boolean): void {
    Button(`#${tag.name}`)
      .height(30)
      .fontSize(Font.small)
      .fontColor(active ? AppColor.accentStrong : AppColor.textSecondary)
      .backgroundColor(active ? AppColor.accentSoft : AppColor.surfaceSoft)
      .borderRadius(Radius.md)
      .padding({ left: Space.md, right: Space.md })
      .onClick(() => {
        this.selectTag(tag.id);
      });
  }

  @Builder
  private skeletonCard(height: number): void {
    Column({ space: Space.md }) {
      Text('')
        .height(height)
        .width('100%')
        .backgroundColor(AppColor.surfaceSoft)
        .borderRadius({ topLeft: Radius.lg, topRight: Radius.lg });
      Text('')
        .height(18)
        .width('86%')
        .backgroundColor(AppColor.surfaceSoft)
        .borderRadius(Radius.sm);
      Text('')
        .height(14)
        .width('62%')
        .backgroundColor(AppColor.surfaceSoft)
        .borderRadius(Radius.sm);
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border });
  }

  @Builder
  private waterfallCard(post: DailyPost, index: number): void {
    Column({ space: Space.sm }) {
      Image(this.feedCoverUrl(post))
        .width('100%')
        .height(this.cardImageHeight(index))
        .objectFit(ImageFit.Cover)
        .borderRadius({ topLeft: Radius.sm, topRight: Radius.sm });

      Text(post.title)
        .fontSize(Font.sub)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textTitle)
        .lineHeight(22)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({ left: Space.sm, right: Space.sm });

      if (post.summary.length > 0) {
        Text(post.summary)
          .fontSize(Font.small)
          .fontColor(AppColor.textSecondary)
          .lineHeight(18)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: Space.sm, right: Space.sm });
      }

      Row({ space: Space.xs }) {
        this.avatarBadge(post.authorName, '', 22);
        Text(post.authorName)
          .fontSize(Font.caption)
          .fontColor(AppColor.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);
        Text(this.isFeedLiked(post.id) ? '♥' : '♡')
          .fontSize(Font.title)
          .fontColor(this.isFeedLiked(post.id) ? AppColor.accent : AppColor.textMuted)
          .onClick(() => {
            this.toggleFeedLike(post);
          });
        Text(this.feedLikeText(index))
          .fontSize(Font.caption)
          .fontColor(AppColor.textSecondary);
      }
      .width('100%')
      .padding({ left: Space.sm, right: Space.sm, bottom: Space.sm })
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .clip(true)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.sm)
    .onClick(() => {
      this.openFeedPost(post);
    });
  }

  @Builder
  private detailPanel(post: DailyPost): void {
    Column({ space: Space.md }) {
      Row() {
        Text(post.title)
          .fontSize(Font.sub)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);
        Button('关闭')
          .height(28)
          .fontSize(Font.caption)
          .fontColor(AppColor.primary)
          .backgroundColor(AppColor.primarySoft)
          .borderRadius(Radius.md)
          .onClick(() => {
            this.detailPost = undefined;
          });
      }
      .width('100%');
      Image(this.feedCoverUrl(post))
        .width('100%')
        .height(170)
        .objectFit(ImageFit.Cover)
        .borderRadius(Radius.md);
      Text(post.summary)
        .fontSize(Font.small)
        .fontColor(AppColor.textSecondary)
        .lineHeight(20)
        .width('100%');
      Text(post.content)
        .fontSize(Font.body)
        .fontColor(AppColor.textBody)
        .lineHeight(22)
        .width('100%');
      if (post.imageUrls.length > 0) {
        Scroll() {
          Row({ space: Space.sm }) {
            ForEach(post.imageUrls, (url: string) => {
              Image(url)
                .width(110)
                .height(82)
                .objectFit(ImageFit.Cover)
                .borderRadius(Radius.sm);
            }, (url: string) => url);
          }
        }
        .height(88)
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off);
      }
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(post.tags, (tag: string) => {
          Text(`#${tag}`)
            .fontSize(Font.caption)
            .fontColor(AppColor.accentStrong)
            .backgroundColor(AppColor.accentSoft)
            .borderRadius(Radius.md)
            .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
            .margin({ right: Space.sm, bottom: Space.sm });
        }, (tag: string) => tag);
      }
      .width('100%');
    }
    .width('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border })
    .shadow(Elevation.card);
  }

  @Builder
  private collegeChip(college: CollegeInfo): void {
    Column({ space: 2 }) {
      Text(college.name)
        .fontSize(Font.body)
        .fontWeight(this.selectedCollegeId === college.id ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selectedCollegeId === college.id ? AppColor.textOnPrimary : AppColor.textBody)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(college.city)
        .fontSize(Font.caption)
        .fontColor(this.selectedCollegeId === college.id ? AppColor.onHeroSoft : AppColor.textMuted);
    }
    .width(116)
    .height(56)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.selectedCollegeId === college.id ? AppColor.primary : AppColor.surface)
    .border({ width: 1, color: this.selectedCollegeId === college.id ? AppColor.primary : AppColor.border })
    .borderRadius(Radius.lg)
    .onClick(() => {
      this.selectedCollegeId = college.id;
    });
  }

  @Builder
  private collegeSummaryCard(college: CollegeInfo): void {
    Column({ space: Space.md }) {
      Row() {
        Column({ space: Space.xs }) {
          Text(college.name)
            .fontSize(Font.h2)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textTitle)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(college.tagLine)
            .fontSize(Font.body)
            .fontColor(AppColor.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .lineHeight(20);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text('关注')
          .fontSize(Font.small)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.accentStrong)
          .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm })
          .backgroundColor(AppColor.accentSoft)
          .borderRadius(Radius.pill);
      }
      .width('100%')
      .alignItems(VerticalAlign.Top);

      Row() {
        Column({ space: 2 }) {
          Text(college.activeCount.toString())
            .fontSize(Font.sub)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textTitle);
          Text('活跃资讯')
            .fontSize(Font.caption)
            .fontColor(AppColor.textMuted);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center);
        Column({ space: 2 }) {
          Text(college.followerText)
            .fontSize(Font.sub)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textTitle);
          Text('关注热度')
            .fontSize(Font.caption)
            .fontColor(AppColor.textMuted);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center);
        Column({ space: 2 }) {
          Text(this.currentCollegeNews().length.toString())
            .fontSize(Font.sub)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textTitle);
          Text('今日更新')
            .fontSize(Font.caption)
            .fontColor(AppColor.textMuted);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center);
      }
      .width('100%')
      .padding({ top: Space.md, bottom: Space.md })
      .backgroundColor(AppColor.surfaceSoft)
      .borderRadius(Radius.md);
    }
    .width('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border })
    .shadow(Elevation.card);
  }

  @Builder
  private collegeNewsCard(item: CollegeNewsItem): void {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        Text(item.topic)
          .fontSize(Font.caption)
          .fontColor(AppColor.accentStrong)
          .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
          .backgroundColor(AppColor.accentSoft)
          .borderRadius(Radius.sm);
        Text(item.source)
          .fontSize(Font.caption)
          .fontColor(AppColor.textMuted)
          .layoutWeight(1);
        Text(item.time)
          .fontSize(Font.caption)
          .fontColor(AppColor.textMuted);
      }
      .width('100%');

      Text(item.title)
        .fontSize(Font.sub)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textTitle)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');

      Text(item.summary)
        .fontSize(Font.body)
        .fontColor(AppColor.textSecondary)
        .lineHeight(20)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');

      Text(`${item.heat} 热度`)
        .fontSize(Font.small)
        .fontColor(AppColor.warning)
        .width('100%');
    }
    .width('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border });
  }

  @Builder
  private collegeFeedContent(): void {
    Column({ space: Space.md }) {
      Scroll() {
        Row({ space: Space.sm }) {
          ForEach(this.colleges, (college: CollegeInfo) => {
            this.collegeChip(college);
          }, (college: CollegeInfo) => college.id);
        }
      }
      .width('100%')
      .height(62)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);

      this.collegeSummaryCard(this.selectedCollege());

      Row() {
        Text('校园资讯')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle);
        Blank();
        Text('按学校更新')
          .fontSize(Font.small)
          .fontColor(AppColor.textMuted);
      }
      .width('100%');

      ForEach(this.currentCollegeNews(), (item: CollegeNewsItem) => {
        this.collegeNewsCard(item);
      }, (item: CollegeNewsItem) => item.id);
    }
    .width('100%');
  }

  @Builder
  private followFeedContent(): void {
    Column({ space: Space.md }) {
      Text('关注动态')
        .fontSize(Font.title)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textTitle);
      Text('你关注的研究者和高校动态会显示在这里。')
        .fontSize(Font.body)
        .fontColor(AppColor.textSecondary)
        .lineHeight(20)
        .textAlign(TextAlign.Center);
    }
    .width('100%')
    .height(260)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private feedTab(): void {
    Column() {
      this.discoveryHeader();
      if (this.homeChannel === 'discover') {
        this.discoveryFilterBar();
      }
      Scroll() {
        Column({ space: Space.md }) {
          if (this.homeChannel === 'college') {
            this.collegeFeedContent();
          } else if (this.homeChannel === 'follow') {
            this.followFeedContent();
          } else if (this.loading) {
            Row({ space: Space.sm }) {
              Column({ space: Space.sm }) {
                this.skeletonCard(150);
                this.skeletonCard(210);
              }
              .layoutWeight(1);
              Column({ space: Space.sm }) {
                this.skeletonCard(200);
                this.skeletonCard(140);
              }
              .layoutWeight(1);
            }
            .width('100%');
          } else if (this.posts.length === 0) {
            Column({ space: Space.md }) {
              Text('暂无匹配日报')
                .fontSize(Font.title)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColor.textTitle);
              Text('换一个话题标签，或者去创作页发布第一篇科研日报。')
                .fontSize(Font.small)
                .fontColor(AppColor.textSecondary)
                .textAlign(TextAlign.Center);
            }
            .width('100%')
            .height(260)
            .justifyContent(FlexAlign.Center);
          } else {
            Column({ space: Space.md }) {
              Row({ space: Space.sm }) {
                Column({ space: Space.sm }) {
                  ForEach(this.leftPosts, (post: DailyPost, index: number) => {
                    this.waterfallCard(post, index);
                  }, (post: DailyPost) => post.id);
                }
                .layoutWeight(1);
                Column({ space: Space.sm }) {
                  ForEach(this.rightPosts, (post: DailyPost, index: number) => {
                    this.waterfallCard(post, index + 3);
                  }, (post: DailyPost) => post.id);
                }
                .layoutWeight(1);
              }
              .width('100%')
              .alignItems(VerticalAlign.Top);

              Button(this.hasMore ? (this.refreshing ? '加载中...' : '上拉加载更多') : '已经到底了')
                .height(42)
                .width('100%')
                .enabled(this.hasMore && !this.refreshing)
                .fontColor(this.hasMore ? AppColor.textOnPrimary : AppColor.textMuted)
                .backgroundColor(this.hasMore ? AppColor.primary : AppColor.surfaceSoft)
                .borderRadius(Radius.lg)
                .onClick(() => {
                  this.loadMore();
                });
            }
          }

          if (this.toastText.length > 0) {
            Text(this.toastText)
              .fontSize(Font.small)
              .fontColor(AppColor.textBody)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .padding(Space.md)
              .backgroundColor(AppColor.surface)
              .borderRadius(Radius.md)
              .border({ width: 1, color: AppColor.border });
          }
        }
        .width('100%')
        .padding({ left: Space.sm, right: Space.sm, bottom: Space.md });
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .backgroundColor(AppColor.bg);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.bg);
  }

  @Builder
  private templateCard(template: DailyTemplate): void {
    Column({ space: Space.sm }) {
      Text(template.title)
        .fontSize(Font.body)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedTemplateId === template.id ? AppColor.accentStrong : AppColor.textTitle);
      Text(template.description)
        .fontSize(Font.caption)
        .fontColor(AppColor.textSecondary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width(148)
    .height(96)
    .padding(Space.lg)
    .backgroundColor(this.selectedTemplateId === template.id ? AppColor.accentSoft : AppColor.surface)
    .border({ width: 1, color: this.selectedTemplateId === template.id ? AppColor.accent : AppColor.border })
    .borderRadius(Radius.lg)
    .onClick(() => {
      this.applyTemplate(template);
    });
  }

  @Builder
  private createActionCard(title: string, subtitle: string, buttonText: string, targetUrl: string): void {
    Column({ space: Space.md }) {
      Text(title)
        .fontSize(Font.h2)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textTitle)
        .width('100%');
      Text(subtitle)
        .fontSize(Font.body)
        .fontColor(AppColor.textSecondary)
        .lineHeight(20)
        .width('100%');
      Button(buttonText)
        .height(44)
        .width('100%')
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textOnPrimary)
        .backgroundColor(AppColor.primary)
        .borderRadius(Radius.lg)
        .onClick(() => {
          router.pushUrl({ url: targetUrl });
        });
    }
    .width('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border })
    .shadow(Elevation.card);
  }

  @Builder
  private editorTab(): void {
    Column() {
      Scroll() {
        Column({ space: Space.lg }) {
          Text('创作')
            .fontSize(Font.h1)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textTitle)
            .width('100%');

          this.createActionCard(
            '发布科研日报',
            '进入独立发布页，像发布笔记一样添加图片、标题、正文、话题和可见性。',
            '开始创作',
            'pages/CreatePost'
          );

          Button('文献 PDF 库')
            .height(44)
            .width('100%')
            .fontColor(AppColor.accentStrong)
            .backgroundColor(AppColor.accentSoft)
            .borderRadius(Radius.lg)
            .onClick(() => {
              router.pushUrl({ url: 'pages/PaperLibrary' });
            });

          if (this.myPosts.length > 0) {
            Text('我的日报')
              .fontSize(Font.title)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textTitle)
              .width('100%');
            ForEach(this.myPosts, (post: DailyPost) => {
              Row({ space: Space.md }) {
                Column({ space: Space.xs }) {
                  Text(post.title)
                    .fontSize(Font.body)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppColor.textTitle)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%');
                  Text(post.status === 'published' ? '已发布' : '草稿')
                    .fontSize(Font.small)
                    .fontColor(post.status === 'published' ? AppColor.accent : AppColor.textMuted);
                }
                .layoutWeight(1);
                Button('删除')
                  .height(32)
                  .fontSize(Font.small)
                  .fontColor(AppColor.danger)
                  .backgroundColor(AppColor.dangerSoft)
                  .borderRadius(Radius.md)
                  .onClick(() => {
                    this.deletePost(post.id);
                  });
              }
              .width('100%')
              .padding(Space.md)
              .backgroundColor(AppColor.surface)
              .borderRadius(Radius.lg)
              .border({ width: 1, color: AppColor.border });
            }, (post: DailyPost) => post.id);
          }
        }
        .width('100%')
        .padding({ left: Space.md, right: Space.md, top: Space.lg, bottom: Space.xxl });
      }
      .height('100%')
      .scrollBar(BarState.Off)
      .backgroundColor(AppColor.bg);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppColor.bg);
  }

  private aiModeName(mode: string): string {
    if (mode === 'topic') {
      return '选题';
    }
    if (mode === 'experiment') {
      return '实验';
    }
    return '文献';
  }

  private aiModeDescription(): string {
    if (this.aiMode === 'topic') {
      return '把模糊想法整理成可执行的研究问题。';
    }
    if (this.aiMode === 'experiment') {
      return '拆解实验目标、变量、指标和风险点。';
    }
    return '快速提炼论文贡献、方法、数据和可复现线索。';
  }

  private fillAiPrompt(text: string): void {
    this.aiPrompt = text;
    this.aiAnswer = '';
  }

  private generateAiAnswer(): void {
    const subject = this.aiPrompt.trim().length > 0 ? this.aiPrompt.trim() : '当前研究问题';
    if (this.aiMode === 'topic') {
      this.aiAnswer = `围绕「${subject}」可以先收敛为三个方向：\n1. 明确目标人群、数据来源和可验证指标。\n2. 找 5 篇近两年的综述或基准论文，整理尚未解决的限制。\n3. 把问题写成“输入、方法、输出、评价”的一句话，并准备一个最小验证实验。`;
      return;
    }
    if (this.aiMode === 'experiment') {
      this.aiAnswer = `针对「${subject}」建议这样拆实验：\n1. 固定一个主变量，只保留必要对照组。\n2. 先跑小样本验证流程，记录失败条件和数据缺口。\n3. 指标至少包含效果、稳定性和成本三类，方便后续写日报复盘。`;
      return;
    }
    this.aiAnswer = `阅读「${subject}」时可以重点抓四件事：\n1. 论文要解决的问题和已有方法的短板。\n2. 核心方法中真正新增的模块或假设。\n3. 数据集、评价指标和消融实验是否支撑结论。\n4. 可迁移到你当前课题的代码、数据或实验模板。`;
  }

  @Builder
  private aiModeChip(mode: string, title: string): void {
    Text(title)
      .fontSize(Font.body)
      .fontWeight(this.aiMode === mode ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.aiMode === mode ? AppColor.textOnPrimary : AppColor.textBody)
      .height(38)
      .padding({ left: Space.lg, right: Space.lg })
      .backgroundColor(this.aiMode === mode ? AppColor.primary : AppColor.surface)
      .border({ width: 1, color: this.aiMode === mode ? AppColor.primary : AppColor.border })
      .borderRadius(Radius.pill)
      .onClick(() => {
        this.aiMode = mode;
        this.aiAnswer = '';
      });
  }

  @Builder
  private aiPromptPreset(text: string): void {
    Text(text)
      .fontSize(Font.small)
      .fontColor(AppColor.textBody)
      .maxLines(2)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm })
      .backgroundColor(AppColor.surface)
      .border({ width: 1, color: AppColor.border })
      .borderRadius(Radius.md)
      .margin({ right: Space.sm, bottom: Space.sm })
      .onClick(() => {
        this.fillAiPrompt(text);
      });
  }

  @Builder
  private aiTab(): void {
    Column() {
      Scroll() {
        Column({ space: Space.lg }) {
          Column({ space: Space.xs }) {
            Text('AI')
              .fontSize(Font.h1)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textTitle)
              .width('100%');
            Text('把科研想法整理成下一步行动')
              .fontSize(Font.small)
              .fontColor(AppColor.textSecondary)
              .width('100%');
          }
          .width('100%');

          Column({ space: Space.md }) {
            Row({ space: Space.sm }) {
              this.aiModeChip('paper', '文献速读');
              this.aiModeChip('topic', '选题建议');
              this.aiModeChip('experiment', '实验设计');
            }
            .width('100%');

            Text(this.aiModeDescription())
              .fontSize(Font.small)
              .fontColor(AppColor.textSecondary)
              .width('100%');

            TextArea({ placeholder: '输入论文标题、研究想法或实验目标', text: this.aiPrompt })
              .height(142)
              .fontSize(Font.body)
              .fontColor(AppColor.textBody)
              .placeholderColor(AppColor.textMuted)
              .lineHeight(22)
              .backgroundColor(AppColor.surfaceSoft)
              .border({ width: 1, color: AppColor.border })
              .borderRadius(Radius.lg)
              .padding(Space.md)
              .onChange((value: string) => {
                this.aiPrompt = value;
              });

            Button(`生成${this.aiModeName(this.aiMode)}建议`)
              .height(44)
              .width('100%')
              .fontColor(AppColor.textOnPrimary)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(AppColor.primary)
              .borderRadius(Radius.lg)
              .onClick(() => {
                this.generateAiAnswer();
              });
          }
          .width('100%')
          .padding(Space.lg)
          .backgroundColor(AppColor.surface)
          .borderRadius(Radius.lg)
          .border({ width: 1, color: AppColor.border })
          .shadow(Elevation.card);

          Column({ space: Space.sm }) {
            Text('常用入口')
              .fontSize(Font.title)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textTitle)
              .width('100%');
            Flex({ wrap: FlexWrap.Wrap }) {
              this.aiPromptPreset('帮我梳理这篇论文的创新点和可复现实验');
              this.aiPromptPreset('把单细胞免疫图谱方向整理成一个开题问题');
              this.aiPromptPreset('为 Retrieval-Augmented Generation 设计一组对照实验');
            }
            .width('100%');
          }
          .width('100%');

          if (this.aiAnswer.length > 0) {
            Column({ space: Space.md }) {
              Row() {
                Text(`${this.aiModeName(this.aiMode)}建议`)
                  .fontSize(Font.title)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppColor.textTitle);
                Blank();
                Text('本地草稿')
                  .fontSize(Font.caption)
                  .fontColor(AppColor.accentStrong)
                  .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
                  .backgroundColor(AppColor.accentSoft)
                  .borderRadius(Radius.sm);
              }
              .width('100%');

              Text(this.aiAnswer)
                .fontSize(Font.body)
                .fontColor(AppColor.textBody)
                .lineHeight(24)
                .width('100%');
            }
            .width('100%')
            .padding(Space.lg)
            .backgroundColor(AppColor.surface)
            .borderRadius(Radius.lg)
            .border({ width: 1, color: AppColor.border });
          }
        }
        .width('100%')
        .padding({ left: Space.lg, right: Space.lg, top: Space.lg, bottom: Space.xxl });
      }
      .height('100%')
      .scrollBar(BarState.Off)
      .backgroundColor(AppColor.bg);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppColor.bg);
  }

  private notificationTypeText(type: string): string {
    if (type === 'like') {
      return '点赞';
    }
    if (type === 'comment') {
      return '评论';
    }
    return '系统';
  }

  private notificationTypeColor(type: string): string {
    if (type === 'like') {
      return AppColor.series3;
    }
    if (type === 'comment') {
      return AppColor.series2;
    }
    return AppColor.series1;
  }

  @Builder
  private messageCard(item: NotificationItem): void {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        Text(this.notificationTypeText(item.type))
          .fontSize(Font.small)
          .fontColor(this.notificationTypeColor(item.type))
          .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
          .backgroundColor(item.isRead ? AppColor.surfaceSoft : AppColor.accentSoft)
          .borderRadius(Radius.sm);
        Text(item.isRead ? '已读' : '未读')
          .fontSize(Font.small)
          .fontColor(item.isRead ? AppColor.textMuted : AppColor.warning);
        Blank();
        Text(item.createdAt)
          .fontSize(Font.small)
          .fontColor(AppColor.textMuted);
      }
      .width('100%');

      Text(item.title)
        .fontSize(Font.sub)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textTitle)
        .width('100%');

      Text(item.content)
        .fontSize(Font.body)
        .fontColor(AppColor.textSecondary)
        .lineHeight(20)
        .width('100%');
    }
    .width('100%')
    .padding(Space.lg)
    .backgroundColor(item.isRead ? AppColor.surface : AppColor.accentSoft)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: item.isRead ? AppColor.border : AppColor.accent })
    .onClick(() => {
      if (!item.isRead) {
        this.readNotification(item.id);
      }
    });
  }

  @Builder
  private messagesTab(): void {
    Column({ space: Space.lg }) {
      Row() {
        Column({ space: Space.xs }) {
          Text('消息')
            .fontSize(Font.h1)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textTitle);
          Text('点赞、评论回复和系统通知')
            .fontSize(Font.small)
            .fontColor(AppColor.textSecondary);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        if (authService.isLoggedIn() && this.messageItems.length > 0) {
          Button('全已读')
            .height(32)
            .fontSize(Font.small)
            .fontColor(AppColor.textOnPrimary)
            .backgroundColor(AppColor.primary)
            .borderRadius(Radius.pill)
            .onClick(() => {
              this.readAllNotifications();
            });
          Button('清空')
            .height(32)
            .fontSize(Font.small)
            .fontColor(AppColor.danger)
            .backgroundColor(AppColor.dangerSoft)
            .borderRadius(Radius.pill)
            .onClick(() => {
              this.clearNotifications();
            });
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      if (!authService.isLoggedIn()) {
        Column({ space: Space.md }) {
          Text('✉')
            .fontSize(32)
            .fontColor(AppColor.accent)
            .width(64)
            .height(64)
            .textAlign(TextAlign.Center)
            .backgroundColor(AppColor.accentSoft)
            .borderRadius(32);
          Text('登录后查看消息')
            .fontSize(Font.title)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textTitle);
          Text('社区互动、回复提醒和系统公告会同步到这里。')
            .fontSize(Font.small)
            .fontColor(AppColor.textSecondary)
            .textAlign(TextAlign.Center)
            .lineHeight(20);
          Button('登录 / 注册')
            .height(44)
            .width('100%')
            .fontColor(AppColor.textOnPrimary)
            .backgroundColor(AppColor.primary)
            .borderRadius(Radius.lg)
            .onClick(() => {
              router.pushUrl({ url: 'pages/Login' });
            });
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else if (this.messageItems.length === 0) {
        Column({ space: Space.sm }) {
          Text('暂无消息')
            .fontSize(Font.sub)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textBody);
          Text('新的点赞、评论和系统公告会显示在这里。')
            .fontSize(Font.body)
            .fontColor(AppColor.textMuted)
            .textAlign(TextAlign.Center);
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else {
        if (this.messageError.length > 0) {
          Text(this.messageError)
            .fontSize(Font.small)
            .fontColor(AppColor.danger)
            .width('100%');
        }

        List({ space: Space.md }) {
          ForEach(this.messageItems, (item: NotificationItem) => {
            ListItem() {
              this.messageCard(item);
            }
          }, (item: NotificationItem) => item.id.toString());
        }
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .layoutWeight(1);
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: Space.lg, right: Space.lg, top: Space.lg, bottom: Space.md })
    .backgroundColor(AppColor.bg);
  }

  private profileSubtitle(): string {
    if (this.currentUser === undefined) {
      return '';
    }
    const institution = this.currentUser.institution;
    const field = this.currentUser.researchField;
    if (institution.length > 0 && field.length > 0) {
      return `${institution} · ${field}`;
    }
    if (institution.length > 0) {
      return institution;
    }
    if (field.length > 0) {
      return field;
    }
    return '完善资料，展示你的研究方向';
  }

  @Builder
  private profileTab(): void {
    Scroll() {
      Column({ space: Space.lg }) {
        if (this.currentUser) {
          Column({ space: Space.lg }) {
            Row({ space: Space.lg }) {
              if (this.hasRealAvatar(this.currentUser.avatarUrl)) {
                Image(this.currentUser.avatarUrl)
                  .width(64)
                  .height(64)
                  .borderRadius(32)
                  .objectFit(ImageFit.Cover)
                  .border({ width: 2, color: AppColor.glassStrong });
              } else {
                Text(this.initial(this.currentUser.nickname))
                  .width(64)
                  .height(64)
                  .borderRadius(32)
                  .backgroundColor(AppColor.glass)
                  .border({ width: 2, color: AppColor.glassStrong })
                  .fontColor(AppColor.textOnPrimary)
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                  .textAlign(TextAlign.Center);
              }
              Column({ space: Space.xs }) {
                Text(this.currentUser.nickname)
                  .fontSize(Font.h2)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppColor.textOnPrimary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%');
                Text(this.profileSubtitle())
                  .fontSize(Font.small)
                  .fontColor(AppColor.onHeroSoft)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%');
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);

              Button('编辑')
                .height(32)
                .fontSize(Font.small)
                .fontColor(AppColor.textOnPrimary)
                .backgroundColor(AppColor.glass)
                .borderRadius(Radius.pill)
                .onClick(() => {
                  router.pushUrl({ url: 'pages/ProfileEdit' });
                });
            }
            .width('100%')
            .alignItems(VerticalAlign.Top);

            if (this.currentUser.bio.length > 0) {
              Text(this.currentUser.bio)
                .fontSize(Font.small)
                .fontColor(AppColor.onHeroSoft)
                .lineHeight(20)
                .width('100%');
            }
          }
          .width('100%')
          .padding(Space.xl)
          .borderRadius(Radius.lg)
          .linearGradient({
            angle: 135,
            colors: [[AppColor.heroStart, 0.0], [AppColor.heroEnd, 1.0]]
          })
          .shadow(Elevation.card);

          Row() {
            this.statCell('发布', this.profileStats.postCount, () => {
              router.pushUrl({ url: 'pages/PersonalList', params: { type: 'posts' } });
            });
            this.statDivider();
            this.statCell('收藏', this.profileStats.collectionCount, () => {
              router.pushUrl({ url: 'pages/PersonalList', params: { type: 'collections' } });
            });
            this.statDivider();
            this.statCell('点赞', this.profileStats.likeCount, () => {
              router.pushUrl({ url: 'pages/PersonalList', params: { type: 'likes' } });
            });
            this.statDivider();
            this.statCell('连续', this.profileStats.continuousDays, () => {
            });
          }
          .width('100%')
          .padding({ top: Space.lg, bottom: Space.lg })
          .backgroundColor(AppColor.surface)
          .borderRadius(Radius.lg)
          .border({ width: 1, color: AppColor.border });

          Column() {
            this.menuRow('✦', '热门趋势', 0, () => {
              router.pushUrl({ url: 'pages/Trending' });
            });
            Divider().color(AppColor.border).margin({ left: 64, right: Space.md });
            this.menuRow('◷', '浏览记录', 0, () => {
              router.pushUrl({ url: 'pages/PersonalList', params: { type: 'history' } });
            });
            Divider().color(AppColor.border).margin({ left: 64, right: Space.md });
            this.menuRow('✉', '消息通知', this.unreadCount, () => {
              router.pushUrl({ url: 'pages/Messages' });
            });
            Divider().color(AppColor.border).margin({ left: 64, right: Space.md });
            this.menuRow('▤', '科研数据看板', 0, () => {
              router.pushUrl({ url: 'pages/ResearchDashboard' });
            });
            Divider().color(AppColor.border).margin({ left: 64, right: Space.md });
            this.menuRow('▦', '文献 PDF 库', 0, () => {
              router.pushUrl({ url: 'pages/PaperLibrary' });
            });
          }
          .width('100%')
          .padding({ top: Space.sm, bottom: Space.sm })
          .backgroundColor(AppColor.surface)
          .borderRadius(Radius.lg)
          .border({ width: 1, color: AppColor.border });

          Column() {
            this.menuRow('⚙', '账号设置', 0, () => {
              router.pushUrl({ url: 'pages/Settings' });
            });
            Divider().color(AppColor.border).margin({ left: 64, right: Space.md });
            this.menuRow('◎', '账号安全', 0, () => {
              router.pushUrl({ url: 'pages/SecuritySettings' });
            });
          }
          .width('100%')
          .padding({ top: Space.sm, bottom: Space.sm })
          .backgroundColor(AppColor.surface)
          .borderRadius(Radius.lg)
          .border({ width: 1, color: AppColor.border });
        } else {
          Column({ space: Space.md }) {
            Text(this.initial('研'))
              .width(64)
              .height(64)
              .borderRadius(32)
              .backgroundColor(AppColor.primarySoft)
              .fontColor(AppColor.primary)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .textAlign(TextAlign.Center);
            Text('登录科研社区')
              .fontSize(Font.title)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textTitle);
            Text('登录后可发布日报、收藏文献、参与讨论、追踪科研数据。')
              .fontSize(Font.small)
              .fontColor(AppColor.textSecondary)
              .textAlign(TextAlign.Center)
              .lineHeight(20);
            Button('登录 / 注册')
              .height(44)
              .width('100%')
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.textOnPrimary)
              .backgroundColor(AppColor.primary)
              .borderRadius(Radius.lg)
              .onClick(() => {
                router.pushUrl({ url: 'pages/Login' });
              });
          }
          .width('100%')
          .padding(Space.xl)
          .backgroundColor(AppColor.surface)
          .borderRadius(Radius.lg)
          .border({ width: 1, color: AppColor.border })
          .alignItems(HorizontalAlign.Center);
        }
      }
      .width('100%')
      .padding({ left: Space.md, right: Space.md, top: Space.lg, bottom: Space.xxl });
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(AppColor.bg);
  }

  build() {
    Column() {
      Column() {
        if (this.currentTab === 0) {
          this.feedTab();
        } else if (this.currentTab === 1) {
          this.aiTab();
        } else if (this.currentTab === 2) {
          this.editorTab();
        } else if (this.currentTab === 3) {
          this.messagesTab();
        } else {
          this.profileTab();
        }
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .clip(true);

      Divider()
        .color(AppColor.border)
        .height(1);

      Row() {
        this.tabBarItem('首页', 0);
        this.tabBarItem('AI', 1);
        this.tabBarItem('创作', 2);
        this.tabBarItem('消息', 3);
        this.tabBarItem('我的', 4);
      }
      .width('100%')
      .height(68)
      .padding({ left: Space.xs, right: Space.xs })
      .backgroundColor(AppColor.surface)
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.bg);
  }
}
