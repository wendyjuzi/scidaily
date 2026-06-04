import { router } from '@kit.ArkUI';
import { CommentItem, InteractionSummary } from '../models/Community';
import { ResearchNews } from '../models/ResearchNews';
import { authService } from '../services/AuthService';
import { communityService } from '../services/CommunityService';
import { newsService } from '../services/NewsService';
import { personalCenterService } from '../services/PersonalCenterService';

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

  @Builder
  private summaryTile(label: string, value: number): void {
    Column({ space: 4 }) {
      Text(value.toString())
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D2939');
      Text(label)
        .fontSize(12)
        .fontColor('#667085');
    }
    .layoutWeight(1)
    .height(62)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFFFFF')
    .borderRadius(10);
  }

  @Builder
  private sortButton(title: string, sort: string): void {
    Button(title)
      .type(ButtonType.Capsule)
      .fontSize(12)
      .fontColor(this.commentSort === sort ? '#FFFFFF' : '#1D2939')
      .backgroundColor(this.commentSort === sort ? '#1E88E5' : '#EAF1F8')
      .onClick(() => {
        this.switchSort(sort);
      });
  }

  @Builder
  private commentCard(item: CommentItem): void {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 2 }) {
          Text(item.nickname)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1D2939');
          Text(item.createdAt)
            .fontSize(11)
            .fontColor('#98A2B3');
        }
        .layoutWeight(1);
        Text(`${item.likeCount} 热度`)
          .fontSize(11)
          .fontColor('#F79009');
      }
      .width('100%');

      if (item.replyToNickname !== undefined && item.replyToNickname.length > 0) {
        Text(`回复 @${item.replyToNickname}`)
          .fontSize(12)
          .fontColor('#1E88E5')
          .width('100%');
      }

      Text(item.content)
        .fontSize(14)
        .fontColor('#344054')
        .lineHeight(20)
        .width('100%');

      Row({ space: 8 }) {
        Button('回复')
          .type(ButtonType.Normal)
          .fontSize(12)
          .height(28)
          .fontColor('#1E88E5')
          .backgroundColor('#EEF6FF')
          .borderRadius(8)
          .onClick(() => {
            this.startReply(item);
          });
        if (this.canDelete(item)) {
          Button('删除')
            .type(ButtonType.Normal)
            .fontSize(12)
            .height(28)
            .fontColor('#D92D20')
            .backgroundColor('#FFEFEF')
            .borderRadius(8)
            .onClick(() => {
              this.deleteComment(item.id);
            });
        }
        Blank();
      }
      .width('100%');
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(10);
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
      Row() {
        Button('返回')
          .type(ButtonType.Capsule)
          .onClick(() => {
            router.back();
          });
        Blank();
      }
      .width('100%');

      if (!this.news) {
        Text('未找到该日报内容')
          .fontSize(16)
          .fontColor('#8A94A6');
      } else {
        Text(this.news.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .width('100%');

        Row({ space: 10 }) {
          Text(this.news.category)
            .fontSize(13)
            .fontColor('#1E88E5');
          Text(this.news.publishedDate)
            .fontSize(13)
            .fontColor('#8A94A6');
        }
        .width('100%');

        Text(`作者：${this.news.authors.join('、')}`)
          .fontSize(14)
          .fontColor('#475467')
          .width('100%');

        Text('核心摘要')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 6 })
          .width('100%');

        Text(this.news.aiSummary)
          .fontSize(15)
          .fontColor('#1E2A3A')
          .width('100%')
          .padding(12)
          .backgroundColor('#ECF5FF')
          .borderRadius(10);

        Text('论文摘要')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 8 })
          .width('100%');

        Text(this.news.abstract)
          .fontSize(14)
          .lineHeight(22)
          .fontColor('#344054')
          .width('100%');

        if (this.news.doi) {
          Text(`DOI: ${this.news.doi}`)
            .fontSize(13)
            .fontColor('#475467')
            .width('100%')
            .margin({ top: 8 });
        }

        Text(`来源链接：${this.news.sourceUrl}`)
          .fontSize(13)
          .fontColor('#1E88E5')
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor('#D92D20')
            .width('100%');
        }

        Row({ space: 10 }) {
          Button(this.isBookmarked ? '取消收藏' : '收藏')
            .layoutWeight(1)
            .height(44)
            .backgroundColor(this.isBookmarked ? '#EEF6FF' : '#1E88E5')
            .fontColor(this.isBookmarked ? '#1E88E5' : '#FFFFFF')
            .onClick(() => {
              this.toggleBookmark();
            });
          Button(this.isLiked ? '取消点赞' : '点赞')
            .layoutWeight(1)
            .height(44)
            .backgroundColor(this.isLiked ? '#FFF1F3' : '#12B76A')
            .fontColor(this.isLiked ? '#E31B54' : '#FFFFFF')
            .onClick(() => {
              this.toggleLike();
            });
        }
        .width('100%')
        .margin({ top: 12 });

        Row({ space: 8 }) {
          this.summaryTile('点赞', this.summary.likeCount);
          this.summaryTile('收藏', this.summary.collectionCount);
          this.summaryTile('评论', this.summary.commentCount);
        }
        .width('100%');

        Column({ space: 10 }) {
          Row() {
            Text('社区评论')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1D2939');
            Blank();
            this.sortButton('最新', 'latest');
            this.sortButton('热门', 'hot');
          }
          .width('100%');

          if (this.replyHint.length > 0) {
            Row() {
              Text(this.replyHint)
                .fontSize(12)
                .fontColor('#1E88E5');
              Blank();
              Button('取消')
                .type(ButtonType.Normal)
                .fontSize(12)
                .height(28)
                .backgroundColor('#F2F4F7')
                .fontColor('#667085')
                .onClick(() => {
                  this.replyToId = 0;
                  this.replyHint = '';
                });
            }
            .width('100%');
          }

          Row({ space: 8 }) {
            TextInput({ placeholder: '写下你的科研想法或复盘建议', text: this.commentInput })
              .height(42)
              .fontSize(14)
              .backgroundColor('#F8FAFC')
              .borderRadius(10)
              .layoutWeight(1)
              .onChange((value: string) => {
                this.commentInput = value;
              });
            Button('发布')
              .height(42)
              .width(72)
              .borderRadius(10)
              .backgroundColor('#1E88E5')
              .onClick(() => {
                this.submitComment();
              });
          }
          .width('100%');

          if (this.comments.length === 0) {
            Text('暂无评论，来发布第一条科研讨论吧。')
              .fontSize(13)
              .fontColor('#8A94A6')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(12);
          } else {
            ForEach(this.comments, (item: CommentItem) => {
              this.commentCard(item);
            }, (item: CommentItem) => item.id.toString());
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#F8FAFC')
        .borderRadius(12);
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F5F7FB');
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FB');
  }
}
