import { router } from '@kit.ArkUI';
import { NotificationBundle } from '../models/Community';
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
  private tabsController: TabsController = new TabsController();

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
      return;
    }
    communityService.getNotifications().then((bundle: NotificationBundle) => {
      this.unreadCount = bundle.unreadCount;
    }).catch((error: Error) => {
      this.unreadCount = 0;
    });
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
    this.tabsController.changeIndex(1);
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

  @Builder
  private tabLabel(title: string): void {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Medium);
  }

  @Builder
  private categoryChip(category: TopicCategory): void {
    Button(category.name)
      .height(34)
      .fontSize(13)
      .fontColor(this.selectedCategoryId === category.id ? '#FFFFFF' : '#2B2B2B')
      .backgroundColor(this.selectedCategoryId === category.id ? '#007AFF' : '#FFFFFF')
      .borderRadius(17)
      .padding({ left: 14, right: 14 })
      .onClick(() => {
        this.selectCategory(category.id);
      });
  }

  @Builder
  private tagChip(tag: TopicTag, active: boolean): void {
    Button(`#${tag.name}`)
      .height(30)
      .fontSize(12)
      .fontColor(active ? '#007AFF' : '#555555')
      .backgroundColor(active ? '#EAF4FF' : '#F1F5F9')
      .borderRadius(15)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        this.selectTag(tag.id);
      });
  }

  @Builder
  private skeletonCard(height: number): void {
    Column({ space: 10 }) {
      Text('')
        .height(height)
        .width('100%')
        .backgroundColor('#ECEFF3')
        .borderRadius({ topLeft: 16, topRight: 16 });
      Text('')
        .height(18)
        .width('86%')
        .backgroundColor('#ECEFF3')
        .borderRadius(6);
      Text('')
        .height(14)
        .width('62%')
        .backgroundColor('#ECEFF3')
        .borderRadius(6);
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#FFFFFF')
    .borderRadius(16);
  }

  @Builder
  private waterfallCard(post: DailyPost, index: number): void {
    Column({ space: 10 }) {
      Image(post.coverUrl)
        .width('100%')
        .height(this.cardImageHeight(index))
        .objectFit(ImageFit.Cover)
        .borderRadius({ topLeft: 16, topRight: 16 });
      Column({ space: 8 }) {
        Text(post.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#202124')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Text(post.summary)
          .fontSize(12)
          .fontColor('#60646C')
          .lineHeight(19)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Row({ space: 6 }) {
          Text(post.categoryName)
            .fontSize(11)
            .fontColor('#007AFF');
          Blank();
          Text(post.authorName)
            .fontSize(11)
            .fontColor('#8B8F98')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .width('100%');
        if (post.tags.length > 0) {
          Text(`#${post.tags[0]}`)
            .fontSize(11)
            .fontColor('#475569')
            .backgroundColor('#F8FAFC')
            .border({ width: 1, color: '#E2E8F0' })
            .borderRadius(12)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 });
        }
      }
      .padding({ left: 14, right: 14, bottom: 14 });
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({ radius: 18, color: '#0D000000', offsetY: 6 })
    .onClick(() => {
      if (post.id.startsWith('paper:')) {
        router.pushUrl({
          url: 'pages/PDFReader',
          params: { paperId: post.id.substring(6) }
        });
        return;
      }
      this.detailPost = post;
    });
  }

  @Builder
  private detailPanel(post: DailyPost): void {
    Column({ space: 12 }) {
      Row() {
        Text(post.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111111')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);
        Button('关闭')
          .height(28)
          .fontSize(11)
          .fontColor('#007AFF')
          .backgroundColor('#EAF4FF')
          .borderRadius(14)
          .onClick(() => {
            this.detailPost = undefined;
          });
      }
      .width('100%');
      Image(post.coverUrl)
        .width('100%')
        .height(170)
        .objectFit(ImageFit.Cover)
        .borderRadius(10);
      Text(post.summary)
        .fontSize(13)
        .fontColor('#5F6368')
        .lineHeight(20)
        .width('100%');
      Text(post.content)
        .fontSize(14)
        .fontColor('#202124')
        .lineHeight(22)
        .width('100%');
      if (post.imageUrls.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(post.imageUrls, (url: string) => {
              Image(url)
                .width(110)
                .height(82)
                .objectFit(ImageFit.Cover)
                .borderRadius(8);
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
            .fontSize(11)
            .fontColor('#007AFF')
            .backgroundColor('#EAF4FF')
            .borderRadius(12)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .margin({ right: 6, bottom: 6 });
        }, (tag: string) => tag);
      }
      .width('100%');
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({ radius: 18, color: '#0D000000', offsetY: 6 });
  }

  @Builder
  private feedTab(): void {
    Column({ space: 14 }) {
      Row() {
        Text('科研日报')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111111');
        Blank();
        Button('↻')
          .height(32)
          .width(32)
          .fontSize(18)
          .fontColor('#007AFF')
          .backgroundColor('#00000000')
          .borderRadius(16)
          .onClick(() => {
            this.refreshFeed();
          });
      }
      .width('100%');

      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.categories, (category: TopicCategory) => {
            this.categoryChip(category);
          }, (category: TopicCategory) => category.id);
        }
        .padding({ right: 16 });
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .height(42);

      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.tags, (tag: TopicTag) => {
            this.tagChip(tag, this.selectedTagId === tag.id);
          }, (tag: TopicTag) => tag.id);
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .height(38);

      if (this.detailPost !== undefined) {
        this.detailPanel(this.detailPost);
      }

      Scroll() {
        if (this.loading) {
          Row({ space: 14 }) {
            Column({ space: 14 }) {
              this.skeletonCard(150);
              this.skeletonCard(210);
            }
            .layoutWeight(1);
            Column({ space: 14 }) {
              this.skeletonCard(200);
              this.skeletonCard(140);
            }
            .layoutWeight(1);
          }
          .width('100%');
        } else if (this.posts.length === 0) {
          Column({ space: 10 }) {
            Text('暂无匹配日报')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333');
            Text('换一个话题标签，或者去创作页发布第一篇科研日报。')
              .fontSize(13)
              .fontColor('#777777')
              .textAlign(TextAlign.Center);
          }
          .width('100%')
          .height(260)
          .justifyContent(FlexAlign.Center);
        } else {
          Column({ space: 16 }) {
            Row({ space: 14 }) {
              Column({ space: 14 }) {
                ForEach(this.leftPosts, (post: DailyPost, index: number) => {
                  this.waterfallCard(post, index);
                }, (post: DailyPost) => post.id);
              }
              .layoutWeight(1);
              Column({ space: 14 }) {
                ForEach(this.rightPosts, (post: DailyPost, index: number) => {
                  this.waterfallCard(post, index + 3);
                }, (post: DailyPost) => post.id);
              }
              .layoutWeight(1);
            }
            .width('100%');
            Button(this.hasMore ? (this.refreshing ? '加载中...' : '上拉加载更多') : '已经到底了')
              .height(42)
              .width('100%')
              .enabled(this.hasMore && !this.refreshing)
              .fontColor(this.hasMore ? '#FFFFFF' : '#8B8F98')
              .backgroundColor(this.hasMore ? '#007AFF' : '#E5E7EB')
              .borderRadius(21)
              .onClick(() => {
                this.loadMore();
              });
          }
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off);

      if (this.toastText.length > 0) {
        Text(this.toastText)
          .fontSize(12)
          .fontColor('#5F6368')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding(10)
          .backgroundColor('#FFFFFF')
          .borderRadius(10);
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 12, top: 14, bottom: 8 })
    .backgroundColor('#F6F8FB');
  }

  @Builder
  private templateCard(template: DailyTemplate): void {
    Column({ space: 8 }) {
      Text(template.title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedTemplateId === template.id ? '#007AFF' : '#222222');
      Text(template.description)
        .fontSize(11)
        .fontColor('#6B7280')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width(148)
    .height(96)
    .padding(14)
    .backgroundColor(this.selectedTemplateId === template.id ? '#EAF4FF' : '#FFFFFF')
    .border({ width: 1, color: this.selectedTemplateId === template.id ? '#B7D8FF' : '#E5E7EB' })
    .borderRadius(16)
    .onClick(() => {
      this.applyTemplate(template);
    });
  }

  @Builder
  private createActionCard(title: string, subtitle: string, buttonText: string, targetUrl: string): void {
    Column({ space: 10 }) {
      Text(title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .width('100%');
      Text(subtitle)
        .fontSize(13)
        .fontColor('#64748B')
        .lineHeight(20)
        .width('100%');
      Button(buttonText)
        .height(44)
        .width('100%')
        .fontColor('#FFFFFF')
        .backgroundColor('#007AFF')
        .borderRadius(22)
        .onClick(() => {
          router.pushUrl({ url: targetUrl });
        });
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({ radius: 18, color: '#0D000000', offsetY: 6 });
  }

  @Builder
  private editorTab(): void {
    Scroll() {
      Column({ space: 16 }) {
        Text('创作')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .width('100%');

        this.createActionCard(
          '发布科研日报',
          '进入独立发布页，像发布笔记一样添加图片、标题、正文、话题和可见性。',
          '开始创作',
          'pages/CreatePost'
        );

        Row({ space: 12 }) {
          Button('文献 PDF 库')
            .height(44)
            .layoutWeight(1)
            .fontColor('#007AFF')
            .backgroundColor('#EAF4FF')
            .borderRadius(22)
            .onClick(() => {
              router.pushUrl({ url: 'pages/PaperLibrary' });
            });
          Button('话题广场')
            .height(44)
            .layoutWeight(1)
            .fontColor('#374151')
            .backgroundColor('#F3F4F6')
            .borderRadius(22)
            .onClick(() => {
              this.tabsController.changeIndex(2);
            });
        }
        .width('100%');

        if (this.myPosts.length > 0) {
          Text('我的日报')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .width('100%');
          ForEach(this.myPosts, (post: DailyPost) => {
            Row({ space: 10 }) {
              Column({ space: 4 }) {
                Text(post.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#111827')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%');
                Text(post.status === 'published' ? '已发布' : '草稿')
                  .fontSize(12)
                  .fontColor(post.status === 'published' ? '#007AFF' : '#8B8F98');
              }
              .layoutWeight(1);
              Button('删除')
                .height(32)
                .fontSize(12)
                .fontColor('#007AFF')
                .backgroundColor('#EAF4FF')
                .borderRadius(16)
                .onClick(() => {
                  this.deletePost(post.id);
                });
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(16);
          }, (post: DailyPost) => post.id);
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 16, bottom: 28 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F8FB');
  }
  @Builder
  private topicsTab(): void {
    Scroll() {
      Column({ space: 12 }) {
        Text('科研话题')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .width('100%');
        Row({ space: 8 }) {
          TextInput({ placeholder: '新增学科分类，例如 计算化学', text: this.newCategoryName })
            .height(42)
            .backgroundColor('#FFFFFF')
            .borderRadius(10)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.newCategoryName = value;
            });
          Button('新增分类')
            .height(42)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor('#007AFF')
            .borderRadius(21)
            .onClick(() => {
              this.addTopicCategory();
            });
        }
        .width('100%');

        Row({ space: 8 }) {
          TextInput({ placeholder: '自定义添加科研标签', text: this.newTagName })
            .height(42)
            .backgroundColor('#FFFFFF')
            .borderRadius(10)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.newTagName = value;
            });
          Button('添加')
            .height(42)
            .fontColor('#FFFFFF')
            .backgroundColor('#007AFF')
            .borderRadius(21)
            .onClick(() => {
              this.addTopicTag();
            });
        }
        .width('100%');

        ForEach(this.categories.filter((item: TopicCategory) => item.id !== 'all'), (category: TopicCategory) => {
          Column({ space: 8 }) {
            Row() {
              Column({ space: 3 }) {
                Text(category.name)
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#202124');
                Text(category.description)
                  .fontSize(12)
                  .fontColor('#6B7280')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }
              .layoutWeight(1);
              Text(`${category.postCount}篇`)
                .fontSize(12)
                .fontColor('#007AFF');
            }
            .width('100%');
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.tags.filter((tag: TopicTag) => tag.categoryId === category.id), (tag: TopicTag) => {
                Row({ space: 4 }) {
                  Button(`#${tag.name} ${tag.postCount}`)
                    .height(32)
                    .fontSize(12)
                    .fontColor(this.selectedTagId === tag.id ? '#FFFFFF' : '#333333')
                    .backgroundColor(this.selectedTagId === tag.id ? '#007AFF' : '#F1F5F9')
                    .borderRadius(16)
                    .onClick(() => {
                      router.pushUrl({
                        url: 'pages/TopicDetail',
                        params: {
                          tagId: tag.id,
                          tagName: tag.name,
                          categoryName: category.name
                        }
                      });
                    });
                  Button('x')
                    .width(30)
                    .height(30)
                    .fontSize(14)
                    .fontColor('#007AFF')
                    .backgroundColor('#EAF4FF')
                    .borderRadius(15)
                    .onClick(() => {
                      this.deleteTopicTag(tag);
                    });
                }
                .margin({ right: 8, bottom: 8 });
              }, (tag: TopicTag) => tag.id);
            }
            .width('100%');
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(12);
        }, (category: TopicCategory) => category.id);
      }
      .padding({ left: 12, right: 12, top: 14, bottom: 24 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F8FB');
  }

  @Builder
  private profileTab(): void {
    Column({ space: 14 }) {
      Text('我的')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .width('100%');
      if (this.currentUser) {
        Column({ space: 8 }) {
          Text(this.currentUser.nickname)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .width('100%');
          Text(this.currentUser.researchField.length > 0 ? this.currentUser.researchField : '未设置研究方向')
            .fontSize(13)
            .fontColor('#6B7280')
            .width('100%');
          Row({ space: 8 }) {
            this.statTile('发布', this.profileStats.postCount);
            this.statTile('收藏', this.profileStats.collectionCount);
            this.statTile('点赞', this.profileStats.likeCount);
            this.statTile('连续', this.profileStats.continuousDays);
          }
          .width('100%');
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(12);
        Button('科研数据看板')
          .height(44)
          .width('100%')
          .backgroundColor('#FFFFFF')
          .fontColor('#111111')
          .borderRadius(22)
          .onClick(() => {
            router.pushUrl({ url: 'pages/ResearchDashboard' });
          });
        Button('文献 PDF 库')
          .height(44)
          .width('100%')
          .backgroundColor('#FFFFFF')
          .fontColor('#111111')
          .borderRadius(22)
          .onClick(() => {
            router.pushUrl({ url: 'pages/PaperLibrary' });
          });
        Button(this.unreadCount > 0 ? `消息通知（${this.unreadCount}）` : '消息通知')
          .height(44)
          .width('100%')
          .backgroundColor(this.unreadCount > 0 ? '#EEF6FF' : '#FFFFFF')
          .fontColor(this.unreadCount > 0 ? '#007AFF' : '#111111')
          .borderRadius(22)
          .onClick(() => {
            router.pushUrl({ url: 'pages/Messages' });
          });
        Button('账号设置')
          .height(44)
          .width('100%')
          .backgroundColor('#FFFFFF')
          .fontColor('#111111')
          .borderRadius(22)
          .onClick(() => {
            router.pushUrl({ url: 'pages/Settings' });
          });
      } else {
        Column({ space: 12 }) {
          Text('登录后可保存草稿、发布日报、管理标签')
            .fontSize(15)
            .fontColor('#555555')
            .textAlign(TextAlign.Center);
          Button('登录 / 注册')
            .height(44)
            .width('100%')
            .fontColor('#FFFFFF')
            .backgroundColor('#007AFF')
            .borderRadius(22)
            .onClick(() => {
              router.pushUrl({ url: 'pages/Login' });
            });
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(12);
      }
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor('#F6F8FB');
  }

  @Builder
  private statTile(label: string, value: number): void {
    Column({ space: 3 }) {
      Text(value.toString())
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111111');
      Text(label)
        .fontSize(11)
        .fontColor('#777777');
    }
    .height(58)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F6F8FB')
    .borderRadius(10);
  }

  build() {
    Tabs({
      barPosition: BarPosition.End,
      controller: this.tabsController
    }) {
      TabContent() {
        this.feedTab();
      }
      .tabBar(this.tabLabel('首页'));

      TabContent() {
        this.editorTab();
      }
      .tabBar(this.tabLabel('创作'));

      TabContent() {
        this.topicsTab();
      }
      .tabBar(this.tabLabel('话题'));

      TabContent() {
        this.profileTab();
      }
      .tabBar(this.tabLabel('我的'));
    }
    .width('100%')
    .height('100%')
    .width('100%');
  }
}




