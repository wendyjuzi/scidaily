import { router } from '@kit.ArkUI';
import { CommentItem, InteractionSummary } from '../models/Community';
import { DailyPost } from '../models/DailyPost';
import { authService } from '../services/AuthService';
import { communityService } from '../services/CommunityService';
import { dailyPostService } from '../services/DailyPostService';
import { personalCenterService } from '../services/PersonalCenterService';
import { AppColor, Space, Radius, Font, Elevation } from '../theme/AppTheme';

@Entry
@Component
struct DailyPostDetail {
  @State post: DailyPost | undefined = undefined;
  @State loading: boolean = true;
  @State errorText: string = '';
  @State liked: boolean = false;
  @State collected: boolean = false;
  @State following: boolean = false;
  @State likeCount: number = 0;
  @State collectionCount: number = 0;
  @State commentCount: number = 0;
  @State comments: CommentItem[] = [];
  @State commentInput: string = '';
  @State commentSort: string = 'latest';
  @State commentPage: number = 1;
  @State commentHasMore: boolean = false;
  @State commentLoadingMore: boolean = false;
  @State replyToComment: CommentItem | undefined = undefined;
  @State likedCommentIds: number[] = [];
  @State expandedReplyParentIds: number[] = [];
  @State onlyAuthorReplies: boolean = false;
  @State pendingDeleteComment: CommentItem | undefined = undefined;
  @State reportedCommentIds: number[] = [];
  @State laterRead: boolean = false;
  @State readingProgress: number = 25;
  @State collectionFolder: string = '默认收藏';
  @State showCollectionPanel: boolean = false;
  @State showReviewPanel: boolean = false;
  @State showForwardPanel: boolean = false;
  @State previewImageUrl: string = '';
  @State toastText: string = '';
  private likeInteractionTouched: boolean = false;
  private collectionInteractionTouched: boolean = false;

  aboutToAppear(): void {
    const params = (router.getParams() as Record<string, string> | undefined) ?? {};
    const id = params.id ?? '';
    if (id.length === 0) {
      this.loading = false;
      this.errorText = '内容不存在';
      return;
    }
    dailyPostService.getById(id).then((item: DailyPost) => {
      this.post = item;
      this.loading = false;
      this.loadInteractionState(item);
    }).catch((error: Error) => {
      this.loading = false;
      this.errorText = error.message;
    });
  }

  private loadInteractionState(item: DailyPost): void {
    this.likeInteractionTouched = false;
    this.collectionInteractionTouched = false;
    communityService.setCommentContext(item.id, item.title, item.summary, item.tags.concat(item.tagIds));
    this.reloadInteractions(item.id);
    this.reloadComments(item.id);
    if (!authService.isLoggedIn()) {
      return;
    }
    personalCenterService.isLikedItem(item.id).then((active: boolean) => {
      if (!this.likeInteractionTouched) {
        this.liked = active;
        if (active) {
          this.likeCount = Math.max(this.likeCount, 1);
        }
      }
    });
    personalCenterService.isCollectedItem(item.id).then((active: boolean) => {
      if (!this.collectionInteractionTouched) {
        this.collected = active;
        if (active) {
          this.collectionCount = Math.max(this.collectionCount, 1);
        }
      }
    });
    personalCenterService.isFollowingItem(this.authorFollowId(item)).then((active: boolean) => {
      this.following = active;
    });
    personalCenterService.addHistoryItem(item.id, item.title, item.summary).catch((error: Error) => {
      this.toastText = error.message;
    });
  }

  private reloadInteractions(postId: string): void {
    communityService.getInteractionSummary(postId).then((summary: InteractionSummary) => {
      if (!this.likeInteractionTouched) {
        this.likeCount = summary.likeCount;
      }
      if (!this.collectionInteractionTouched) {
        this.collectionCount = summary.collectionCount;
      }
      this.commentCount = Math.max(this.commentCount, summary.commentCount, this.comments.length);
    });
  }

  private reloadComments(postId: string): void {
    this.commentPage = 1;
    communityService.getComments(postId, this.commentSort, 1, 20).then((items: CommentItem[]) => {
      this.comments = items;
      this.commentCount = Math.max(items.length, this.commentCount);
      this.commentHasMore = items.length === 20;
    }).catch((error: Error) => {
      this.toastText = error.message;
    });
  }

  private displayedCommentCount(): number {
    return Math.max(this.commentCount, this.comments.length);
  }

  private loadMoreComments(): void {
    const item = this.post;
    if (item === undefined || this.commentLoadingMore || !this.commentHasMore) {
      return;
    }
    const nextPage = this.commentPage + 1;
    this.commentLoadingMore = true;
    communityService.getComments(item.id, this.commentSort, nextPage, 20).then((items: CommentItem[]) => {
      this.comments = this.comments.concat(items);
      this.commentPage = nextPage;
      this.commentHasMore = items.length === 20;
      this.commentLoadingMore = false;
    }).catch((error: Error) => {
      this.commentLoadingMore = false;
      this.toastText = error.message;
    });
  }

  private authorFollowId(item: DailyPost): string {
    return `author-${item.authorId}`;
  }

  private ensureLoggedIn(): boolean {
    if (!authService.isLoggedIn()) {
      router.pushUrl({ url: 'pages/Login' });
      return false;
    }
    return true;
  }

  private coverUrl(item: DailyPost): string {
    const url = item.coverUrl.trim();
    if (url.length > 0 && url.startsWith('http')) {
      return url;
    }
    if (item.categoryId === 'bio') {
      return 'https://images.unsplash.com/photo-1576086213369-97a306d36557?auto=format&fit=crop&w=900&q=80';
    }
    if (item.categoryId === 'materials') {
      return 'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?auto=format&fit=crop&w=900&q=80';
    }
    return 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=900&q=80';
  }

  private toggleLike(): void {
    const item = this.post;
    if (item === undefined) {
      return;
    }
    const nextLiked = !this.liked;
    this.likeInteractionTouched = true;
    this.liked = nextLiked;
    this.likeCount = Math.max(0, this.likeCount + (nextLiked ? 1 : -1));
    if (!authService.isLoggedIn()) {
      return;
    }
    if (!nextLiked) {
      personalCenterService.removeLikeItem(item.id).then(() => {
        this.toastText = '已取消点赞，消息通知已更新';
      }).catch((error: Error) => {
        this.liked = true;
        this.likeCount += 1;
        this.toastText = error.message;
      });
      return;
    }
    personalCenterService.addLikeItem(item.id, item.title, item.summary).then(() => {
      this.toastText = '已点赞，消息通知已更新';
    }).catch((error: Error) => {
      this.liked = false;
      this.likeCount = Math.max(0, this.likeCount - 1);
      this.toastText = error.message;
    });
  }

  private toggleCollection(): void {
    const item = this.post;
    if (item === undefined) {
      return;
    }
    const nextCollected = !this.collected;
    this.collectionInteractionTouched = true;
    this.collected = nextCollected;
    this.collectionCount = Math.max(0, this.collectionCount + (nextCollected ? 1 : -1));
    if (!authService.isLoggedIn()) {
      return;
    }
    if (!nextCollected) {
      personalCenterService.removeCollectionItem(item.id).then(() => {
        this.toastText = '已取消收藏，消息通知已更新';
      }).catch((error: Error) => {
        this.collected = true;
        this.collectionCount += 1;
        this.toastText = error.message;
      });
      return;
    }
    personalCenterService.addCollectionItem(item.id, item.title, item.summary).then(() => {
      this.toastText = `已收藏到${this.collectionFolder}`;
    }).catch((error: Error) => {
      this.collected = false;
      this.collectionCount = Math.max(0, this.collectionCount - 1);
      this.toastText = error.message;
    });
  }

  private toggleLaterRead(): void {
    this.laterRead = !this.laterRead;
    this.toastText = this.laterRead ? '已加入稍后读' : '已移出稍后读';
  }

  private updateReadingProgress(progress: number): void {
    this.readingProgress = progress;
    this.toastText = `阅读进度已记录到 ${progress}%`;
  }

  private selectCollectionFolder(folder: string): void {
    this.collectionFolder = folder;
    this.showCollectionPanel = false;
    if (!this.collected) {
      this.toggleCollection();
      return;
    }
    this.toastText = `已移动到${folder}`;
  }

  private openMyCollections(): void {
    router.pushUrl({ url: 'pages/PersonalList', params: { type: 'collections' } });
  }

  private openAuthorProfile(): void {
    const item = this.post;
    if (item === undefined) {
      return;
    }
    router.pushUrl({
      url: 'pages/AuthorProfile',
      params: {
        authorId: item.authorId.toString(),
        authorName: item.authorName,
        categoryName: item.categoryName
      }
    });
  }

  private openTag(tag: string): void {
    const item = this.post;
    if (item === undefined) {
      return;
    }
    const index = item.tags.indexOf(tag);
    const tagId = index >= 0 && index < item.tagIds.length ? item.tagIds[index] : tag;
    router.pushUrl({
      url: 'pages/TopicDetail',
      params: {
        tagId,
        tagName: tag,
        categoryName: item.categoryName
      }
    });
  }

  private forwardTo(target: string): void {
    this.showForwardPanel = false;
    this.toastText = `已转发到${target}`;
  }

  private atCollaborator(name: string): void {
    this.commentInput = `@${name} `;
    this.toastText = `已准备 @${name} 讨论`;
  }

  private toggleFollow(): void {
    const item = this.post;
    if (item === undefined || !this.ensureLoggedIn()) {
      return;
    }
    const followId = this.authorFollowId(item);
    if (this.following) {
      personalCenterService.removeFollowItem(followId).then(() => {
        this.following = false;
      });
      return;
    }
    personalCenterService.addFollowItem(followId, item.authorName, item.categoryName).then(() => {
      this.following = true;
    });
  }

  private switchCommentSort(sort: string): void {
    const item = this.post;
    if (item === undefined) {
      return;
    }
    this.commentSort = sort;
    this.reloadComments(item.id);
  }

  private submitComment(): void {
    const item = this.post;
    if (item === undefined || !this.ensureLoggedIn()) {
      return;
    }
    const text = this.commentInput.trim();
    if (text.length === 0) {
      this.toastText = '请输入评论内容';
      return;
    }
    const parentId = this.replyToComment === undefined ? undefined : this.threadParentId(this.replyToComment);
    communityService.addCommentById(item.id, text, parentId).then((comment: CommentItem) => {
      this.commentInput = '';
      this.replyToComment = undefined;
      this.comments = [comment].concat(this.comments);
      if (comment.parentId !== undefined && !this.isRepliesExpanded(comment.parentId)) {
        this.expandedReplyParentIds = this.expandedReplyParentIds.concat([comment.parentId]);
      }
      this.commentCount += 1;
      this.reloadInteractions(item.id);
      this.toastText = '评论已发布';
    }).catch((error: Error) => {
      this.toastText = error.message;
    });
  }

  private deleteComment(comment: CommentItem): void {
    const item = this.post;
    if (item === undefined || !this.ensureLoggedIn()) {
      return;
    }
    communityService.deleteComment(comment.id, item.id).then(() => {
      this.reloadComments(item.id);
      this.reloadInteractions(item.id);
    }).catch((error: Error) => {
      this.toastText = error.message;
    });
  }

  private askDeleteComment(comment: CommentItem): void {
    this.pendingDeleteComment = comment;
  }

  private confirmDeleteComment(): void {
    const comment = this.pendingDeleteComment;
    if (comment === undefined) {
      return;
    }
    this.pendingDeleteComment = undefined;
    this.deleteComment(comment);
  }

  private cancelDeleteComment(): void {
    this.pendingDeleteComment = undefined;
  }

  private reportComment(comment: CommentItem): void {
    if (this.reportedCommentIds.indexOf(comment.id) < 0) {
      this.reportedCommentIds = this.reportedCommentIds.concat([comment.id]);
    }
    this.toastText = '已收到举报，会优先检查这条讨论';
  }

  private canDeleteComment(comment: CommentItem): boolean {
    const currentUser = authService.getCurrentUser();
    return currentUser !== undefined && currentUser.id === comment.userId;
  }

  private hasParent(comment: CommentItem): boolean {
    return comment.parentId !== undefined;
  }

  private threadParentId(comment: CommentItem): number {
    return comment.parentId === undefined ? comment.id : comment.parentId;
  }

  private topLevelComments(): CommentItem[] {
    let items = this.comments.filter((comment: CommentItem) => !this.hasParent(comment));
    if (this.onlyAuthorReplies) {
      items = items.filter((comment: CommentItem) => this.threadHasAuthorComment(comment.id));
    }
    if (this.commentSort === 'peer') {
      return items.filter((comment: CommentItem) => this.isPeerDiscussion(comment));
    }
    return items;
  }

  private isAuthorComment(comment: CommentItem): boolean {
    const item = this.post;
    if (item === undefined) {
      return false;
    }
    return comment.userId === item.authorId || comment.nickname === item.authorName;
  }

  private threadHasAuthorComment(commentId: number): boolean {
    const top = this.comments.find((comment: CommentItem) => comment.id === commentId);
    if (top !== undefined && this.isAuthorComment(top)) {
      return true;
    }
    return this.repliesForComment(commentId).some((reply: CommentItem) => this.isAuthorComment(reply));
  }

  private isPeerDiscussion(comment: CommentItem): boolean {
    const text = `${comment.nickname} ${comment.content}`;
    return text.includes('同门') || text.includes('师兄') || text.includes('导师') || text.includes('实验') || text.includes('复现');
  }

  private isPinnedComment(comment: CommentItem): boolean {
    const top = this.topLevelComments();
    if (top.length === 0) {
      return false;
    }
    return comment.id === top[0].id && comment.likeCount >= 10;
  }

  private isAuthorSelected(comment: CommentItem): boolean {
    return this.isAuthorComment(comment) || comment.content.includes('复现') || comment.content.includes('建议');
  }

  private repliesForComment(commentId: number): CommentItem[] {
    return this.comments.filter((comment: CommentItem) => comment.parentId === commentId);
  }

  private visibleRepliesForComment(commentId: number): CommentItem[] {
    const replies = this.repliesForComment(commentId);
    if (this.isRepliesExpanded(commentId)) {
      return replies;
    }
    return replies.slice(0, 1);
  }

  private isRepliesExpanded(commentId: number): boolean {
    return this.expandedReplyParentIds.indexOf(commentId) >= 0;
  }

  private toggleReplies(commentId: number): void {
    if (this.isRepliesExpanded(commentId)) {
      this.expandedReplyParentIds = this.expandedReplyParentIds.filter((id: number) => id !== commentId);
      return;
    }
    this.expandedReplyParentIds = this.expandedReplyParentIds.concat([commentId]);
  }

  private isCommentLiked(commentId: number): boolean {
    return this.likedCommentIds.indexOf(commentId) >= 0;
  }

  private toggleCommentLike(comment: CommentItem): void {
    if (!this.ensureLoggedIn()) {
      return;
    }
    const item = this.post;
    const active = this.isCommentLiked(comment.id);
    this.likedCommentIds = active
      ? this.likedCommentIds.filter((id: number) => id !== comment.id)
      : this.likedCommentIds.concat([comment.id]);
    this.comments = this.comments.map((item: CommentItem) => {
      if (item.id === comment.id) {
        item.likeCount = Math.max(0, item.likeCount + (active ? -1 : 1));
      }
      return item;
    });
    if (item !== undefined) {
      communityService.setCommentLiked(item.id, comment.id, !active).then((synced: CommentItem | undefined) => {
        if (synced !== undefined) {
          this.comments = this.comments.map((current: CommentItem) => current.id === synced.id ? synced : current);
        }
      });
    }
  }

  @Builder
  private tagChip(tag: string): void {
    Text(`#${tag}`)
      .fontSize(Font.caption)
      .fontColor(AppColor.accentStrong)
      .backgroundColor(AppColor.accentSoft)
      .borderRadius(Radius.md)
      .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
      .margin({ right: Space.sm, bottom: Space.sm })
      .onClick(() => {
        this.openTag(tag);
      });
  }

  private contentBlocks(): string[] {
    const item = this.post;
    if (item === undefined) {
      return [];
    }
    const blocks = item.content.split('\n').filter((block: string) => block.trim().length > 0);
    if (blocks.length === 0) {
      return [item.content];
    }
    return blocks;
  }

  private keywordText(): string {
    const item = this.post;
    if (item === undefined) {
      return '方法、数据、复现';
    }
    const tags = item.tags.slice(0, 3);
    if (tags.length > 0) {
      return tags.join(' / ');
    }
    return `${item.categoryName} / 复现 / 实验设计`;
  }

  private reusableMethodText(): string {
    const item = this.post;
    if (item === undefined) {
      return '整理可复用方法、数据处理步骤和评估指标。';
    }
    return `围绕“${item.title}”沉淀检索、实验记录、结果复盘三段式流程。`;
  }

  private nextSuggestionText(): string {
    const item = this.post;
    if (item === undefined) {
      return '补充对照实验，明确指标和失败原因。';
    }
    if (item.categoryId === 'bio') {
      return '补充样本来源、质控阈值和关键 marker 验证，形成可复用分析脚本。';
    }
    if (item.categoryId === 'materials') {
      return '补充制备条件、稳定性曲线和重复实验批次，定位误差来源。';
    }
    return '补充 baseline、消融实验和错误案例，整理成下一轮复现计划。';
  }

  private relatedPdfTitle(): string {
    const item = this.post;
    if (item === undefined) {
      return '相关论文 PDF';
    }
    if (item.categoryId === 'bio') {
      return 'Single-cell atlas methods reading pack';
    }
    if (item.categoryId === 'materials') {
      return 'Perovskite stability benchmark notes';
    }
    return 'Tree of Thoughts / RAG 复现论文包';
  }

  private relatedDailyTitle(): string {
    const item = this.post;
    if (item === undefined) {
      return '相关科研日报';
    }
    return `${item.categoryName}方向的复盘与实验设计记录`;
  }

  @Builder
  private contentBlock(block: string): void {
    if (block.startsWith('##')) {
      Text(block.replace('##', '').trim())
        .fontSize(Font.title)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textTitle)
        .width('100%');
    } else if (block.startsWith('>')) {
      Text(block.replace('>', '').trim())
        .fontSize(Font.body)
        .fontColor(AppColor.textSecondary)
        .lineHeight(22)
        .width('100%')
        .padding(Space.md)
        .backgroundColor(AppColor.surfaceSoft)
        .borderRadius(Radius.md)
        .border({ width: 1, color: AppColor.border });
    } else if (block.startsWith('-') || block.startsWith('1.')) {
      Text(block)
        .fontSize(Font.body)
        .fontColor(AppColor.textBody)
        .lineHeight(23)
        .width('100%');
    } else {
      Text(block)
        .fontSize(Font.body)
        .fontColor(AppColor.textBody)
        .lineHeight(24)
        .width('100%');
    }
  }

  @Builder
  private likeActionButton(): void {
    Row() {
      Text(this.liked ? `已点赞 ${this.likeCount}` : `点赞 ${this.likeCount}`)
        .fontSize(Font.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.liked ? AppColor.textOnPrimary : AppColor.textBody);
    }
      .height(42)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.liked ? AppColor.primary : AppColor.surfaceSoft)
      .borderRadius(Radius.lg)
      .onClick(() => {
        this.toggleLike();
      });
  }

  @Builder
  private collectionActionButton(): void {
    Row() {
      Text(this.collected ? `已收藏 ${this.collectionCount}` : `收藏 ${this.collectionCount}`)
        .fontSize(Font.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.collected ? AppColor.textOnPrimary : AppColor.textBody);
    }
      .height(42)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.collected ? AppColor.primary : AppColor.surfaceSoft)
      .borderRadius(Radius.lg)
      .onClick(() => {
        this.toggleCollection();
      });
  }

  @Builder
  private quickActionChip(title: string, active: boolean, action: () => void): void {
    Text(title)
      .fontSize(Font.small)
      .fontWeight(active ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(active ? AppColor.textOnPrimary : AppColor.textBody)
      .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm })
      .backgroundColor(active ? AppColor.primary : AppColor.surfaceSoft)
      .borderRadius(Radius.pill)
      .onClick(action);
  }

  @Builder
  private readingManagementCard(): void {
    Column({ space: Space.md }) {
      Row() {
        Text('阅读管理')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle);
        Blank();
        Text(`${this.readingProgress}%`)
          .fontSize(Font.small)
          .fontColor(AppColor.accentStrong);
      }
      .width('100%');
      Row({ space: Space.sm }) {
        this.quickActionChip(this.laterRead ? '已稍后读' : '稍后读', this.laterRead, () => {
          this.toggleLaterRead();
        });
        this.quickActionChip('我的收藏', false, () => {
          this.openMyCollections();
        });
        this.quickActionChip('收藏夹', this.showCollectionPanel, () => {
          this.showCollectionPanel = !this.showCollectionPanel;
        });
      }
      .width('100%');
      Row({ space: Space.sm }) {
        this.quickActionChip('标记 25%', this.readingProgress === 25, () => {
          this.updateReadingProgress(25);
        });
        this.quickActionChip('标记 50%', this.readingProgress === 50, () => {
          this.updateReadingProgress(50);
        });
        this.quickActionChip('已读完', this.readingProgress === 100, () => {
          this.updateReadingProgress(100);
        });
      }
      .width('100%');
      if (this.showCollectionPanel) {
        Row({ space: Space.sm }) {
          this.quickActionChip('RAG 复现', this.collectionFolder === 'RAG 复现', () => {
            this.selectCollectionFolder('RAG 复现');
          });
          this.quickActionChip('单细胞论文', this.collectionFolder === '单细胞论文', () => {
            this.selectCollectionFolder('单细胞论文');
          });
          this.quickActionChip('实验设计', this.collectionFolder === '实验设计', () => {
            this.selectCollectionFolder('实验设计');
          });
        }
        .width('100%');
      }
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border });
  }

  @Builder
  private aiReviewCard(): void {
    Column({ space: Space.md }) {
      Row() {
        Text('AI 科研复盘')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle);
        Blank();
        this.quickActionChip(this.showReviewPanel ? '收起' : '生成', this.showReviewPanel, () => {
          this.showReviewPanel = !this.showReviewPanel;
        });
      }
      .width('100%');
      if (this.showReviewPanel) {
        Column({ space: Space.sm }) {
          this.reviewLine('研究问题', (this.post as DailyPost).summary);
          this.reviewLine('方法', this.reusableMethodText());
          this.reviewLine('数据', `围绕 ${((this.post as DailyPost).tags.length > 0 ? (this.post as DailyPost).tags[0] : (this.post as DailyPost).categoryName)} 组织实验材料。`);
          this.reviewLine('结论', '把当前进展沉淀为可复盘日报，并保留后续验证入口。');
          this.reviewLine('可复现实验', '整理环境、数据、脚本、指标、失败样例五项 checklist。');
          this.reviewLine('关键词', this.keywordText());
          this.reviewLine('下一步建议', this.nextSuggestionText());
        }
        .width('100%');
      } else {
        Text('一键生成研究问题、方法、数据、结论、复现实验和下一步建议。')
          .fontSize(Font.small)
          .fontColor(AppColor.textSecondary)
          .lineHeight(20)
          .width('100%');
      }
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border });
  }

  @Builder
  private reviewLine(label: string, value: string): void {
    Column({ space: Space.xs }) {
      Text(label)
        .fontSize(Font.caption)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.accentStrong);
      Text(value)
        .fontSize(Font.small)
        .fontColor(AppColor.textBody)
        .lineHeight(20)
        .width('100%');
    }
    .width('100%')
    .padding(Space.sm)
    .backgroundColor(AppColor.surfaceSoft)
    .borderRadius(Radius.md);
  }

  @Builder
  private socialActionCard(): void {
    Column({ space: Space.md }) {
      Row() {
        Text('社交互动')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle);
        Blank();
        this.quickActionChip(this.showForwardPanel ? '收起' : '转发', this.showForwardPanel, () => {
          this.showForwardPanel = !this.showForwardPanel;
        });
      }
      .width('100%');
      Row({ space: Space.sm }) {
        this.quickActionChip('@导师', false, () => {
          this.atCollaborator('导师');
        });
        this.quickActionChip('@师兄', false, () => {
          this.atCollaborator('师兄');
        });
        this.quickActionChip('@同门', false, () => {
          this.atCollaborator('同门');
        });
      }
      .width('100%');
      if (this.showForwardPanel) {
        Row({ space: Space.sm }) {
          this.quickActionChip('高校圈', false, () => {
            this.forwardTo('高校圈');
          });
          this.quickActionChip('CRT 课题组', false, () => {
            this.forwardTo('CRT 课题组');
          });
          this.quickActionChip('AI 智能体群', false, () => {
            this.forwardTo('AI 智能体群');
          });
        }
        .width('100%');
      }
      Text('点赞、收藏、评论会同步消息通知；关注作者后下方显示相关推荐。')
        .fontSize(Font.caption)
        .fontColor(AppColor.textMuted)
        .width('100%');
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border });
  }

  @Builder
  private relatedContentCard(): void {
    Column({ space: Space.md }) {
      Row() {
        Text('相关内容')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle);
        Blank();
        Text(this.following ? '已关注推荐' : '关注作者后更新')
          .fontSize(Font.caption)
          .fontColor(AppColor.textMuted);
      }
      .width('100%');
      this.relatedRow('相关日报', this.relatedDailyTitle(), '同作者/同标签');
      this.relatedRow('PDF 附件', this.relatedPdfTitle(), '可进入文献 PDF 库');
      this.relatedRow('复现实验', '实验 checklist 与下一步计划', '由 AI 复盘生成');
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border });
  }

  @Builder
  private relatedRow(label: string, title: string, meta: string): void {
    Row({ space: Space.md }) {
      Text(label.substring(0, 1))
        .width(36)
        .height(36)
        .fontSize(Font.small)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.accentStrong)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppColor.accentSoft)
        .borderRadius(18);
      Column({ space: 2 }) {
        Text(title)
          .fontSize(Font.small)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Text(meta)
          .fontSize(Font.caption)
          .fontColor(AppColor.textMuted)
          .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text('›')
        .fontSize(24)
        .fontColor(AppColor.textMuted);
    }
    .width('100%')
    .padding({ top: Space.sm, bottom: Space.sm })
    .onClick(() => {
      if (label === 'PDF 附件') {
        router.pushUrl({ url: 'pages/PaperLibrary' });
      } else {
        this.toastText = `${label}已加入当前复盘上下文`;
      }
    });
  }

  @Builder
  private imagePreviewCard(): void {
    if (this.previewImageUrl.length > 0) {
      Column({ space: Space.sm }) {
        Row() {
          Text('图片预览')
            .fontSize(Font.title)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textTitle);
          Blank();
          Button('关闭')
            .height(30)
            .fontSize(Font.small)
            .fontColor(AppColor.textSecondary)
            .backgroundColor(AppColor.surfaceSoft)
            .borderRadius(Radius.pill)
            .onClick(() => {
              this.previewImageUrl = '';
            });
        }
        .width('100%');
        Image(this.previewImageUrl)
          .width('100%')
          .height(260)
          .objectFit(ImageFit.Contain)
          .backgroundColor(AppColor.surfaceSoft)
          .borderRadius(Radius.lg);
      }
      .width('100%')
      .padding(Space.md)
      .backgroundColor(AppColor.surface)
      .borderRadius(Radius.lg)
      .border({ width: 1, color: AppColor.border });
    }
  }

  @Builder
  private commentSortButton(title: string, sort: string): void {
    Text(title)
      .fontSize(Font.small)
      .fontWeight(this.commentSort === sort ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.commentSort === sort ? AppColor.accentStrong : AppColor.textMuted)
      .padding({ left: Space.md, right: Space.md, top: Space.xs, bottom: Space.xs })
      .backgroundColor(this.commentSort === sort ? AppColor.accentSoft : AppColor.surfaceSoft)
      .borderRadius(Radius.pill)
      .onClick(() => {
        this.switchCommentSort(sort);
      });
  }

  @Builder
  private commentLikeAction(comment: CommentItem): void {
    Column({ space: 2 }) {
      Text(this.isCommentLiked(comment.id) ? '♥' : '♡')
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isCommentLiked(comment.id) ? AppColor.danger : AppColor.textMuted)
        .lineHeight(22);
      Text(comment.likeCount.toString())
        .fontSize(Font.caption)
        .fontColor(this.isCommentLiked(comment.id) ? AppColor.danger : AppColor.textMuted);
    }
    .width(42)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.toggleCommentLike(comment);
    });
  }

  @Builder
  private commentRow(comment: CommentItem, isReply: boolean): void {
    Row({ space: isReply ? Space.sm : Space.md }) {
      Text(comment.nickname.length > 0 ? comment.nickname.substring(0, 1) : '研')
        .width(isReply ? 28 : 34)
        .height(isReply ? 28 : 34)
        .fontSize(Font.small)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textOnPrimary)
        .textAlign(TextAlign.Center)
        .backgroundColor(isReply ? AppColor.textMuted : AppColor.accent)
        .borderRadius(isReply ? 14 : 17);
      Column({ space: Space.xs }) {
        Row() {
          Text(comment.nickname)
            .fontSize(Font.small)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textTitle)
            .layoutWeight(1);
          if (!isReply && this.isPinnedComment(comment)) {
            Text('置顶')
              .fontSize(Font.caption)
              .fontColor(AppColor.danger)
              .padding({ left: Space.xs, right: Space.xs, top: 2, bottom: 2 })
              .backgroundColor('#FEE2E2')
              .borderRadius(Radius.sm)
              .margin({ right: Space.xs });
          }
          if (this.isAuthorSelected(comment)) {
            Text('作者精选')
              .fontSize(Font.caption)
              .fontColor(AppColor.accentStrong)
              .padding({ left: Space.xs, right: Space.xs, top: 2, bottom: 2 })
              .backgroundColor(AppColor.accentSoft)
              .borderRadius(Radius.sm)
              .margin({ right: Space.xs });
          }
          Text(comment.createdAt)
            .fontSize(Font.caption)
            .fontColor(AppColor.textMuted);
        }
        .width('100%');
        if (comment.replyToNickname !== undefined) {
          Text(`回复 @${comment.replyToNickname}`)
            .fontSize(Font.caption)
            .fontColor(AppColor.accentStrong);
        }
        Text(comment.content)
          .fontSize(isReply ? Font.small : Font.body)
          .fontColor(AppColor.textBody)
          .lineHeight(isReply ? 19 : 20)
          .width('100%');
        Row({ space: Space.md }) {
          Text('回复')
            .fontSize(Font.caption)
            .fontColor(AppColor.accentStrong)
            .onClick(() => {
              this.replyToComment = comment;
              this.commentInput = `回复 @${comment.nickname}：`;
            });
          if (this.canDeleteComment(comment)) {
            Text('删除')
              .fontSize(Font.caption)
              .fontColor(AppColor.danger)
              .onClick(() => {
                this.askDeleteComment(comment);
              });
          } else {
            Text(this.reportedCommentIds.indexOf(comment.id) >= 0 ? '已举报' : '举报')
              .fontSize(Font.caption)
              .fontColor(AppColor.textMuted)
              .onClick(() => {
                this.reportComment(comment);
              });
          }
        }
        .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      this.commentLikeAction(comment);
    }
    .width('100%')
    .padding({ top: isReply ? Space.sm : Space.md, bottom: isReply ? Space.sm : Space.md });
  }

  @Builder
  private commentThread(comment: CommentItem): void {
    Column({ space: Space.xs }) {
      this.commentRow(comment, false);
      if (this.repliesForComment(comment.id).length > 0) {
        Column({ space: Space.xs }) {
          ForEach(this.visibleRepliesForComment(comment.id), (reply: CommentItem) => {
            this.commentRow(reply, true);
          }, (reply: CommentItem) => reply.id.toString());
          if (this.repliesForComment(comment.id).length > 1) {
            Text(this.isRepliesExpanded(comment.id) ? '收起回复' : `展开 ${this.repliesForComment(comment.id).length - 1} 条回复`)
              .fontSize(Font.small)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.textMuted)
              .padding({ top: Space.xs, bottom: Space.xs })
              .onClick(() => {
                this.toggleReplies(comment.id);
              });
          }
        }
        .width('100%')
        .padding({ left: 46 });
      }
    }
    .width('100%');
  }

  build() {
    Column() {
      Row() {
        Button('‹')
          .width(40)
          .height(40)
          .fontSize(28)
          .fontColor(AppColor.textTitle)
          .backgroundColor(AppColor.surface)
          .borderRadius(Radius.pill)
          .onClick(() => {
            router.back();
          });
        Text('日报详情')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle)
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        Blank()
          .width(40);
      }
      .width('100%')
      .padding({ left: Space.md, right: Space.md, top: Space.md, bottom: Space.sm })
      .backgroundColor(AppColor.surface);

      if (this.loading) {
        Column() {
          Text('加载中...')
            .fontSize(Font.body)
            .fontColor(AppColor.textSecondary);
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else if (this.post === undefined) {
        Column() {
          Text(this.errorText.length > 0 ? this.errorText : '内容不存在')
            .fontSize(Font.body)
            .fontColor(AppColor.textSecondary);
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else {
        Scroll() {
          Column({ space: Space.lg }) {
            Image(this.coverUrl(this.post as DailyPost))
              .width('100%')
              .height(250)
              .objectFit(ImageFit.Cover)
              .borderRadius(Radius.lg)
              .onClick(() => {
                this.previewImageUrl = this.coverUrl(this.post as DailyPost);
              });
            this.imagePreviewCard();
            Text((this.post as DailyPost).title)
              .fontSize(Font.h2)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textTitle)
              .lineHeight(30)
              .width('100%');
            Row({ space: Space.md }) {
              Text((this.post as DailyPost).authorName.length > 0 ? (this.post as DailyPost).authorName.substring(0, 1) : '研')
                .width(40)
                .height(40)
                .fontSize(Font.sub)
                .fontColor(AppColor.textOnPrimary)
                .textAlign(TextAlign.Center)
                .backgroundColor(AppColor.primary)
                .borderRadius(20)
                .onClick(() => {
                  this.openAuthorProfile();
                });
              Column({ space: 2 }) {
                Text((this.post as DailyPost).authorName)
                  .fontSize(Font.body)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColor.textTitle)
                  .onClick(() => {
                    this.openAuthorProfile();
                  });
                Text(`${(this.post as DailyPost).categoryName} · ${(this.post as DailyPost).publishedAt ?? (this.post as DailyPost).createdAt}`)
                  .fontSize(Font.caption)
                  .fontColor(AppColor.textMuted);
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);
              Button(this.following ? '已关注' : '关注')
                .height(32)
                .fontSize(Font.small)
                .fontColor(this.following ? AppColor.textSecondary : AppColor.textOnPrimary)
                .backgroundColor(this.following ? AppColor.surfaceSoft : AppColor.primary)
                .borderRadius(Radius.pill)
                .onClick(() => {
                  this.toggleFollow();
                });
            }
            .width('100%')
            .alignItems(VerticalAlign.Center);

            Text((this.post as DailyPost).summary)
              .fontSize(Font.body)
              .fontColor(AppColor.textSecondary)
              .lineHeight(22)
              .width('100%');
            Column({ space: Space.sm }) {
              ForEach(this.contentBlocks(), (block: string) => {
                this.contentBlock(block);
              }, (block: string) => block);
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start);

            if ((this.post as DailyPost).tags.length > 0) {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach((this.post as DailyPost).tags, (tag: string) => {
                  this.tagChip(tag);
                }, (tag: string) => tag);
              }
              .width('100%');
            }

            this.readingManagementCard();
            this.aiReviewCard();
            this.socialActionCard();
            this.relatedContentCard();

            Column({ space: Space.md }) {
              Row() {
                Text(`评论 ${this.displayedCommentCount()}`)
                  .fontSize(Font.title)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppColor.textTitle);
                Blank();
                Row({ space: Space.sm }) {
                  this.commentSortButton('最新', 'latest');
                  this.commentSortButton('热门', 'hot');
                  this.commentSortButton('同门讨论', 'peer');
                }
              }
              .width('100%')
              .alignItems(VerticalAlign.Center);

              Row() {
                this.quickActionChip(this.onlyAuthorReplies ? '已筛作者回复' : '只看作者回复', this.onlyAuthorReplies, () => {
                  this.onlyAuthorReplies = !this.onlyAuthorReplies;
                });
                Blank();
                Text(`${this.topLevelComments().length} 条讨论`)
                  .fontSize(Font.caption)
                  .fontColor(AppColor.textMuted);
              }
              .width('100%');

              if (this.pendingDeleteComment !== undefined) {
                Row({ space: Space.sm }) {
                  Text('确认删除这条评论？')
                    .fontSize(Font.small)
                    .fontColor(AppColor.textBody)
                    .layoutWeight(1);
                  Button('取消')
                    .height(30)
                    .fontSize(Font.small)
                    .fontColor(AppColor.textSecondary)
                    .backgroundColor(AppColor.surfaceSoft)
                    .borderRadius(Radius.pill)
                    .onClick(() => {
                      this.cancelDeleteComment();
                    });
                  Button('删除')
                    .height(30)
                    .fontSize(Font.small)
                    .fontColor(AppColor.textOnPrimary)
                    .backgroundColor(AppColor.danger)
                    .borderRadius(Radius.pill)
                    .onClick(() => {
                      this.confirmDeleteComment();
                    });
                }
                .width('100%')
                .padding(Space.sm)
                .backgroundColor('#FEF2F2')
                .borderRadius(Radius.md);
              }

              if (this.replyToComment !== undefined) {
                Row() {
                  Text(`回复 @${(this.replyToComment as CommentItem).nickname}`)
                    .fontSize(Font.small)
                    .fontColor(AppColor.accentStrong);
                  Blank();
                  Button('取消')
                    .height(28)
                    .fontSize(Font.small)
                    .fontColor(AppColor.textSecondary)
                    .backgroundColor(AppColor.surfaceSoft)
                    .borderRadius(Radius.pill)
                    .onClick(() => {
                      this.replyToComment = undefined;
                      this.commentInput = '';
                    });
                }
                .width('100%');
              }

              Row({ space: Space.sm }) {
                TextInput({ placeholder: '写下你的科研想法或复盘建议', text: this.commentInput })
                  .height(42)
                  .fontSize(Font.body)
                  .fontColor(AppColor.textBody)
                  .placeholderColor(AppColor.textMuted)
                  .backgroundColor(AppColor.surfaceSoft)
                  .border({ width: 1, color: AppColor.border })
                  .borderRadius(Radius.md)
                  .layoutWeight(1)
                  .onChange((value: string) => {
                    this.commentInput = value;
                  });
                Button('发布')
                  .height(42)
                  .width(72)
                  .fontSize(Font.body)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColor.textOnPrimary)
                  .backgroundColor(AppColor.primary)
                  .borderRadius(Radius.md)
                  .onClick(() => {
                    this.submitComment();
                  });
              }
              .width('100%');

              Row() {
                Text(this.replyToComment === undefined ? '支持评论、回复和热门排序' : '当前评论会作为回复发布')
                  .fontSize(Font.caption)
                  .fontColor(AppColor.textMuted);
                Blank();
                Text(`${this.commentInput.length}/200`)
                  .fontSize(Font.caption)
                  .fontColor(this.commentInput.length > 200 ? AppColor.danger : AppColor.textMuted);
              }
              .width('100%');

              if (this.topLevelComments().length === 0) {
                Text(this.comments.length === 0 ? '暂无评论，来发布第一条科研讨论吧。' : '当前筛选下暂无讨论。')
                  .fontSize(Font.small)
                  .fontColor(AppColor.textMuted)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding(Space.md);
              } else {
                ForEach(this.topLevelComments(), (comment: CommentItem) => {
                  this.commentThread(comment);
                }, (comment: CommentItem) => comment.id.toString());
                if (this.commentHasMore) {
                  Button(this.commentLoadingMore ? '加载中...' : '加载更多评论')
                    .height(38)
                    .fontSize(Font.small)
                    .fontColor(AppColor.textSecondary)
                    .backgroundColor(AppColor.surfaceSoft)
                    .borderRadius(Radius.pill)
                    .enabled(!this.commentLoadingMore)
                    .onClick(() => {
                      this.loadMoreComments();
                    });
                }
              }
            }
            .width('100%')
            .padding(Space.md)
            .backgroundColor(AppColor.surface)
            .borderRadius(Radius.lg)
            .border({ width: 1, color: AppColor.border });

            if (this.toastText.length > 0) {
              Text(this.toastText)
                .fontSize(Font.small)
                .fontColor(AppColor.textSecondary)
                .width('100%');
            }
          }
          .width('100%')
          .padding(Space.md);
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off);

        Row({ space: Space.sm }) {
          this.likeActionButton();
          this.collectionActionButton();
        }
        .width('100%')
        .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.md })
        .backgroundColor(AppColor.surface)
        .shadow(Elevation.card);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.bg);
  }
}
