import { router } from '@kit.ArkUI';
import { CommentItem, InteractionSummary } from '../models/Community';
import { ResearchNews } from '../models/ResearchNews';
import { authService } from '../services/AuthService';
import { communityService } from '../services/CommunityService';
import { newsService } from '../services/NewsService';
import { personalCenterService } from '../services/PersonalCenterService';
import { AppColor, Space, Radius, Font, Elevation } from '../theme/AppTheme';

@Entry
@Component
struct Detail {
  @State news: ResearchNews | undefined = undefined;
  @State isBookmarked: boolean = false;
  @State isLiked: boolean = false;
  @State errorMessage: string = '';
  @State comments: CommentItem[] = [];
  @State commentInput: string = '';
  @State commentSort: string = 'latest';
  @State replyToId: number = 0;
  @State replyHint: string = '';
  @State summary: InteractionSummary = {
    likeCount: 0,
    collectionCount: 0,
    commentCount: 0
  };

  aboutToAppear(): void {
    const params = (router.getParams() as Record<string, string> | undefined) ?? {};
    const id = params.id;
    if (!id) {
      return;
    }
    this.news = newsService.getById(id);
    const currentNews = this.news;
    if (currentNews !== undefined) {
      this.isBookmarked = newsService.isBookmarked(currentNews.id);
      if (authService.isLoggedIn()) {
        personalCenterService.addHistory(currentNews).catch((error: Error) => {
          this.errorMessage = error.message;
        });
        personalCenterService.isCollected(currentNews.id).then((active: boolean) => {
          this.isBookmarked = active;
          newsService.setBookmark(currentNews.id, active);
        }).catch((error: Error) => {
          this.errorMessage = error.message;
        });
        personalCenterService.isLiked(currentNews.id).then((active: boolean) => {
          this.isLiked = active;
        }).catch((error: Error) => {
          this.errorMessage = error.message;
        });
      }
      this.reloadCommunity(currentNews.id);
    }
  }

  private reloadCommunity(newsId: string): void {
    communityService.getInteractionSummary(newsId).then((summary: InteractionSummary) => {
      this.summary = summary;
    }).catch((error: Error) => {
      this.summary = {
        likeCount: 0,
        collectionCount: 0,
        commentCount: this.comments.length
      };
    });
    communityService.getComments(newsId, this.commentSort).then((items: CommentItem[]) => {
      this.comments = items;
      this.summary = {
        likeCount: this.summary.likeCount,
        collectionCount: this.summary.collectionCount,
        commentCount: items.length
      };
    }).catch((error: Error) => {
      this.errorMessage = error.message;
    });
  }

  private async toggleBookmark(): Promise<void> {
    if (!this.news) {
      return;
    }
    if (!authService.isLoggedIn()) {
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
    try {
      if (this.isBookmarked) {
        await personalCenterService.removeCollection(this.news.id);
        this.isBookmarked = false;
      } else {
        await personalCenterService.addCollection(this.news);
        this.isBookmarked = true;
      }
      this.reloadCommunity(this.news.id);
      this.errorMessage = '';
    } catch (error) {
      if (error instanceof Error) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '收藏操作失败，请稍后重试。';
      }
    }
  }

  private async toggleLike(): Promise<void> {
    if (!this.news) {
      return;
    }
    if (!authService.isLoggedIn()) {
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
    try {
      if (this.isLiked) {
        await personalCenterService.removeLike(this.news.id);
        this.isLiked = false;
      } else {
        await personalCenterService.addLike(this.news);
        this.isLiked = true;
      }
      this.reloadCommunity(this.news.id);
      this.errorMessage = '';
    } catch (error) {
      if (error instanceof Error) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '点赞操作失败，请稍后重试。';
      }
    }
  }

  private async submitComment(): Promise<void> {
    if (!this.news) {
      return;
    }
    if (!authService.isLoggedIn()) {
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
    try {
      const parentId = this.replyToId > 0 ? this.replyToId : undefined;
      await communityService.addComment(this.news, this.commentInput, parentId);
      this.commentInput = '';
      this.replyToId = 0;
      this.replyHint = '';
      this.reloadCommunity(this.news.id);
      this.errorMessage = '';
    } catch (error) {
      if (error instanceof Error) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '评论发布失败，请稍后重试。';
      }
    }
  }

  private async deleteComment(commentId: number): Promise<void> {
    if (!this.news) {
      return;
    }
    try {
      await communityService.deleteComment(commentId, this.news.id);
      this.reloadCommunity(this.news.id);
      this.errorMessage = '';
    } catch (error) {
      if (error instanceof Error) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '评论删除失败，请稍后重试。';
      }
    }
  }

  private startReply(item: CommentItem): void {
    if (!authService.isLoggedIn()) {
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
    this.replyToId = item.id;
    this.replyHint = `回复 ${item.nickname}`;
  }

  private switchSort(sort: string): void {
    if (!this.news) {
      return;
    }
    this.commentSort = sort;
    this.reloadCommunity(this.news.id);
  }

  private canDelete(item: CommentItem): boolean {
    const user = authService.getCurrentUser();
    return user !== undefined && user.id === item.userId;
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

  @Builder
  private avatarInitial(name: string, size: number): void {
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

  @Builder
  private summaryTile(label: string, value: number): void {
    Column({ space: Space.xs }) {
      Text(value.toString())
        .fontSize(Font.title)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textTitle);
      Text(label)
        .fontSize(Font.small)
        .fontColor(AppColor.textSecondary);
    }
    .layoutWeight(1)
    .height(64)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.md)
    .border({ width: 1, color: AppColor.border });
  }

  @Builder
  private sortButton(title: string, sort: string): void {
    Button(title)
      .type(ButtonType.Capsule)
      .fontSize(Font.small)
      .fontColor(this.commentSort === sort ? AppColor.textOnPrimary : AppColor.textBody)
      .backgroundColor(this.commentSort === sort ? AppColor.primary : AppColor.primarySoft)
      .onClick(() => {
        this.switchSort(sort);
      });
  }

  @Builder
  private commentCard(item: CommentItem): void {
    Column({ space: Space.sm }) {
      Row() {
        Column({ space: 2 }) {
          Text(item.nickname)
            .fontSize(Font.body)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textTitle);
          Text(item.createdAt)
            .fontSize(Font.caption)
            .fontColor(AppColor.textMuted);
        }
        .layoutWeight(1);
        Text(`${item.likeCount} 热度`)
          .fontSize(Font.caption)
          .fontColor(AppColor.warning);
      }
      .width('100%');

      if (item.replyToNickname !== undefined && item.replyToNickname.length > 0) {
        Text(`回复 @${item.replyToNickname}`)
          .fontSize(Font.small)
          .fontColor(AppColor.accent)
          .width('100%');
      }

      Text(item.content)
        .fontSize(Font.body)
        .fontColor(AppColor.textBody)
        .lineHeight(20)
        .width('100%');

      Row({ space: Space.sm }) {
        Button('回复')
          .type(ButtonType.Normal)
          .fontSize(Font.small)
          .height(28)
          .fontColor(AppColor.accent)
          .backgroundColor(AppColor.accentSoft)
          .borderRadius(Radius.sm)
          .onClick(() => {
            this.startReply(item);
          });
        if (this.canDelete(item)) {
          Button('删除')
            .type(ButtonType.Normal)
            .fontSize(Font.small)
            .height(28)
            .fontColor(AppColor.danger)
            .backgroundColor(AppColor.dangerSoft)
            .borderRadius(Radius.sm)
            .onClick(() => {
              this.deleteComment(item.id);
            });
        }
        Blank();
      }
      .width('100%');
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.md)
    .border({ width: 1, color: AppColor.border });
  }

  build() {
    Scroll() {
      Column({ space: Space.md }) {
      Row() {
        Button('返回')
          .type(ButtonType.Capsule)
          .fontSize(Font.body)
          .fontColor(AppColor.textBody)
          .backgroundColor(AppColor.surface)
          .border({ width: 1, color: AppColor.border })
          .onClick(() => {
            router.back();
          });
        Blank();
      }
      .width('100%');

      if (!this.news) {
        Text('未找到该日报内容')
          .fontSize(Font.sub)
          .fontColor(AppColor.textMuted);
      } else {
        Text(this.news.title)
          .fontSize(Font.h2)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle)
          .width('100%');

        Row({ space: Space.md }) {
          Text(this.news.category)
            .fontSize(Font.small)
            .fontColor(AppColor.accent)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(AppColor.accentSoft)
            .borderRadius(Radius.sm)
            .padding({ left: Space.sm, right: Space.sm, top: 3, bottom: 3 });
          Text(this.news.publishedDate)
            .fontSize(Font.small)
            .fontColor(AppColor.textMuted);
        }
        .width('100%');

        Row({ space: Space.md }) {
          this.avatarInitial(this.news.authors.length > 0 ? this.news.authors[0] : '研', 38);
          Column({ space: 2 }) {
            Text(this.news.authors.join('、'))
              .fontSize(Font.body)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.textTitle)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%');
            Text(`${this.news.category} · ${this.news.publishedDate}`)
              .fontSize(Font.caption)
              .fontColor(AppColor.textMuted)
              .width('100%');
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width('100%')
        .padding(Space.md)
        .backgroundColor(AppColor.surface)
        .borderRadius(Radius.md)
        .border({ width: 1, color: AppColor.border });

        Text('核心摘要')
          .fontSize(Font.sub)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textTitle)
          .margin({ top: Space.xs })
          .width('100%');

        Row({ space: Space.md }) {
          Column()
            .width(3)
            .height('100%')
            .backgroundColor(AppColor.accent)
            .borderRadius(2);
          Text(this.news.aiSummary)
            .fontSize(Font.sub)
            .fontColor(AppColor.textBody)
            .lineHeight(23)
            .layoutWeight(1);
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding(Space.md)
        .backgroundColor(AppColor.accentSoft)
        .borderRadius(Radius.md);

        Text('论文摘要')
          .fontSize(Font.sub)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textTitle)
          .margin({ top: Space.sm })
          .width('100%');

        Text(this.news.abstract)
          .fontSize(Font.body)
          .lineHeight(22)
          .fontColor(AppColor.textBody)
          .width('100%');

        if (this.news.doi) {
          Text(`DOI: ${this.news.doi}`)
            .fontSize(Font.small)
            .fontColor(AppColor.textSecondary)
            .width('100%')
            .margin({ top: Space.sm });
        }

        Text(`来源链接：${this.news.sourceUrl}`)
          .fontSize(Font.small)
          .fontColor(AppColor.accent)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(Font.small)
            .fontColor(AppColor.danger)
            .width('100%');
        }

        Row({ space: Space.md }) {
          Button(this.isBookmarked ? '取消收藏' : '收藏')
            .layoutWeight(1)
            .height(44)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.isBookmarked ? AppColor.primarySoft : AppColor.primary)
            .fontColor(this.isBookmarked ? AppColor.primary : AppColor.textOnPrimary)
            .onClick(() => {
              this.toggleBookmark();
            });
          Button(this.isLiked ? '取消点赞' : '点赞')
            .layoutWeight(1)
            .height(44)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.isLiked ? AppColor.accentSoft : AppColor.accent)
            .fontColor(this.isLiked ? AppColor.accentStrong : AppColor.textOnPrimary)
            .onClick(() => {
              this.toggleLike();
            });
        }
        .width('100%')
        .margin({ top: Space.md });

        Row({ space: Space.sm }) {
          this.summaryTile('点赞', this.summary.likeCount);
          this.summaryTile('收藏', this.summary.collectionCount);
          this.summaryTile('评论', this.summary.commentCount);
        }
        .width('100%');

        Column({ space: Space.md }) {
          Row() {
            Text('社区评论')
              .fontSize(Font.title)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.textTitle);
            Blank();
            this.sortButton('最新', 'latest');
            this.sortButton('热门', 'hot');
          }
          .width('100%');

          if (this.replyHint.length > 0) {
            Row() {
              Text(this.replyHint)
                .fontSize(Font.small)
                .fontColor(AppColor.accent);
              Blank();
              Button('取消')
                .type(ButtonType.Normal)
                .fontSize(Font.small)
                .height(28)
                .backgroundColor(AppColor.surfaceSoft)
                .fontColor(AppColor.textSecondary)
                .onClick(() => {
                  this.replyToId = 0;
                  this.replyHint = '';
                });
            }
            .width('100%');
          }

          Row({ space: Space.sm }) {
            TextInput({ placeholder: '写下你的科研想法或复盘建议', text: this.commentInput })
              .height(42)
              .fontSize(Font.body)
              .backgroundColor(AppColor.surface)
              .border({ width: 1, color: AppColor.border })
              .borderRadius(Radius.md)
              .layoutWeight(1)
              .onChange((value: string) => {
                this.commentInput = value;
              });
            Button('发布')
              .height(42)
              .width(72)
              .borderRadius(Radius.md)
              .backgroundColor(AppColor.primary)
              .fontColor(AppColor.textOnPrimary)
              .onClick(() => {
                this.submitComment();
              });
          }
          .width('100%');

          Row() {
            Text(this.replyHint.length > 0 ? '当前评论会作为回复发布' : '支持评论与楼中楼回复')
              .fontSize(Font.caption)
              .fontColor(AppColor.textMuted);
            Blank();
            Text(`${this.commentInput.length}/200`)
              .fontSize(Font.caption)
              .fontColor(this.commentInput.length > 200 ? AppColor.danger : AppColor.textMuted);
          }
          .width('100%');

          if (this.comments.length === 0) {
            Text('暂无评论，来发布第一条科研讨论吧。')
              .fontSize(Font.small)
              .fontColor(AppColor.textMuted)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(Space.md);
          } else {
            ForEach(this.comments, (item: CommentItem) => {
              this.commentCard(item);
            }, (item: CommentItem) => item.id.toString());
          }
        }
        .width('100%')
        .padding(Space.md)
        .backgroundColor(AppColor.bg)
        .borderRadius(Radius.lg)
        .border({ width: 1, color: AppColor.border });
      }
    }
    .width('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.bg);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.bg);
  }
}
