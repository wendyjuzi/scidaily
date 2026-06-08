import { router } from '@kit.ArkUI';
import { DailyPost } from '../models/DailyPost';
import { authService } from '../services/AuthService';
import { DailyPostPage, dailyPostService } from '../services/DailyPostService';
import { personalCenterService } from '../services/PersonalCenterService';
import { AppColor, Space, Radius, Font, Elevation } from '../theme/AppTheme';

@Entry
@Component
struct AuthorProfile {
  @State authorId: number = 0;
  @State authorName: string = '科研作者';
  @State categoryName: string = '科研';
  @State posts: DailyPost[] = [];
  @State loading: boolean = true;
  @State following: boolean = false;
  @State toastText: string = '';

  aboutToAppear(): void {
    const params = (router.getParams() as Record<string, string> | undefined) ?? {};
    this.authorId = Number(params.authorId ?? '0');
    this.authorName = params.authorName ?? '科研作者';
    this.categoryName = params.categoryName ?? '科研';
    this.loadAuthorPosts();
    if (authService.isLoggedIn()) {
      personalCenterService.isFollowingItem(this.followId()).then((active: boolean) => {
        this.following = active;
      });
    }
  }

  private followId(): string {
    return `author-${this.authorId}`;
  }

  private loadAuthorPosts(): void {
    dailyPostService.listPublished('all', '', 0, 50).then((page: DailyPostPage) => {
      this.posts = page.items.filter((post: DailyPost) => post.authorId === this.authorId);
    }).finally(() => {
      this.loading = false;
    });
  }

  private toggleFollow(): void {
    if (!authService.isLoggedIn()) {
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
    if (this.following) {
      personalCenterService.removeFollowItem(this.followId()).then(() => {
        this.following = false;
        this.toastText = '已取消关注';
      });
      return;
    }
    personalCenterService.addFollowItem(this.followId(), this.authorName, this.categoryName).then(() => {
      this.following = true;
      this.toastText = '已关注作者';
    });
  }

  @Builder
  private postRow(post: DailyPost): void {
    Row({ space: Space.md }) {
      Image(post.coverUrl)
        .width(86)
        .height(108)
        .objectFit(ImageFit.Cover)
        .borderRadius(Radius.md);
      Column({ space: Space.sm }) {
        Text(post.title)
          .fontSize(Font.sub)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Text(post.summary)
          .fontSize(Font.small)
          .fontColor(AppColor.textSecondary)
          .lineHeight(19)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Text(post.publishedAt ?? post.createdAt)
          .fontSize(Font.caption)
          .fontColor(AppColor.textMuted);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border })
    .onClick(() => {
      router.pushUrl({ url: 'pages/DailyPostDetail', params: { id: post.id } });
    });
  }

  build() {
    Column({ space: Space.md }) {
      Row() {
        Button('返回')
          .height(34)
          .fontSize(Font.small)
          .fontColor(AppColor.textBody)
          .backgroundColor(AppColor.surface)
          .border({ width: 1, color: AppColor.border })
          .borderRadius(Radius.lg)
          .onClick(() => {
            router.back();
          });
        Blank();
      }
      .width('100%');

      Column({ space: Space.md }) {
        Row({ space: Space.md }) {
          Text(this.authorName.length > 0 ? this.authorName.substring(0, 1) : '研')
            .width(58)
            .height(58)
            .fontSize(Font.h2)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textOnPrimary)
            .textAlign(TextAlign.Center)
            .backgroundColor(AppColor.primary)
            .borderRadius(29);
          Column({ space: Space.xs }) {
            Text(this.authorName)
              .fontSize(Font.h2)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textTitle);
            Text(`${this.categoryName} · ${this.posts.length} 篇日报`)
              .fontSize(Font.small)
              .fontColor(AppColor.textSecondary);
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
          Button(this.following ? '已关注' : '关注')
            .height(34)
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
        Text('作者主页汇总其公开科研日报、研究方向和可继续跟进的复盘记录。')
          .fontSize(Font.small)
          .fontColor(AppColor.textSecondary)
          .lineHeight(20)
          .width('100%');
      }
      .width('100%')
      .padding(Space.lg)
      .backgroundColor(AppColor.surface)
      .borderRadius(Radius.lg)
      .border({ width: 1, color: AppColor.border })
      .shadow(Elevation.card);

      Scroll() {
        Column({ space: Space.md }) {
          if (this.loading) {
            Text('正在加载作者日报...')
              .fontSize(Font.body)
              .fontColor(AppColor.textMuted)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(Space.xl);
          } else if (this.posts.length === 0) {
            Text('暂无公开日报')
              .fontSize(Font.body)
              .fontColor(AppColor.textMuted)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(Space.xl);
          } else {
            ForEach(this.posts, (post: DailyPost) => {
              this.postRow(post);
            }, (post: DailyPost) => post.id);
          }
          if (this.toastText.length > 0) {
            Text(this.toastText)
              .fontSize(Font.small)
              .fontColor(AppColor.textSecondary)
              .width('100%');
          }
        }
        .width('100%');
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.bg);
  }
}
