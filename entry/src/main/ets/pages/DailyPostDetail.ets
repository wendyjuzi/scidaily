import { router } from '@kit.ArkUI';
import { DailyPost } from '../models/DailyPost';
import { authService } from '../services/AuthService';
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
  @State toastText: string = '';

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
    if (!authService.isLoggedIn()) {
      return;
    }
    personalCenterService.isLikedItem(item.id).then((active: boolean) => {
      this.liked = active;
    });
    personalCenterService.isCollectedItem(item.id).then((active: boolean) => {
      this.collected = active;
    });
    personalCenterService.isFollowingItem(this.authorFollowId(item)).then((active: boolean) => {
      this.following = active;
    });
    personalCenterService.addHistoryItem(item.id, item.title, item.summary).catch((error: Error) => {
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
    if (item === undefined || !this.ensureLoggedIn()) {
      return;
    }
    if (this.liked) {
      personalCenterService.removeLikeItem(item.id).then(() => {
        this.liked = false;
      });
      return;
    }
    personalCenterService.addLikeItem(item.id, item.title, item.summary).then(() => {
      this.liked = true;
    });
  }

  private toggleCollection(): void {
    const item = this.post;
    if (item === undefined || !this.ensureLoggedIn()) {
      return;
    }
    if (this.collected) {
      personalCenterService.removeCollectionItem(item.id).then(() => {
        this.collected = false;
      });
      return;
    }
    personalCenterService.addCollectionItem(item.id, item.title, item.summary).then(() => {
      this.collected = true;
    });
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

  @Builder
  private tagChip(tag: string): void {
    Text(`#${tag}`)
      .fontSize(Font.caption)
      .fontColor(AppColor.accentStrong)
      .backgroundColor(AppColor.accentSoft)
      .borderRadius(Radius.md)
      .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
      .margin({ right: Space.sm, bottom: Space.sm });
  }

  @Builder
  private actionButton(title: string, active: boolean, action: () => void): void {
    Button(title)
      .height(42)
      .layoutWeight(1)
      .fontSize(Font.body)
      .fontWeight(FontWeight.Medium)
      .fontColor(active ? AppColor.textOnPrimary : AppColor.textBody)
      .backgroundColor(active ? AppColor.primary : AppColor.surfaceSoft)
      .borderRadius(Radius.lg)
      .onClick(action);
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
              .borderRadius(Radius.lg);
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
                .borderRadius(20);
              Column({ space: 2 }) {
                Text((this.post as DailyPost).authorName)
                  .fontSize(Font.body)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColor.textTitle);
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
            Text((this.post as DailyPost).content)
              .fontSize(Font.body)
              .fontColor(AppColor.textBody)
              .lineHeight(24)
              .width('100%');

            if ((this.post as DailyPost).tags.length > 0) {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach((this.post as DailyPost).tags, (tag: string) => {
                  this.tagChip(tag);
                }, (tag: string) => tag);
              }
              .width('100%');
            }

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
          this.actionButton(this.liked ? '已点赞' : '点赞', this.liked, () => {
            this.toggleLike();
          });
          this.actionButton(this.collected ? '已收藏' : '收藏', this.collected, () => {
            this.toggleCollection();
          });
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
