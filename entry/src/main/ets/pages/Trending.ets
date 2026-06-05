import { router } from '@kit.ArkUI';
import { DailyPost, TopicCategory, TopicTag } from '../models/DailyPost';
import { dailyPostService } from '../services/DailyPostService';
import { AppColor, Space, Radius, Font, Elevation } from '../theme/AppTheme';

@Entry
@Component
struct Trending {
  @State tags: TopicTag[] = [];
  @State categories: TopicCategory[] = [];
  @State posts: DailyPost[] = [];
  @State loading: boolean = true;

  aboutToAppear(): void {
    dailyPostService.listTags().then((items: TopicTag[]) => {
      this.tags = items;
    });
    dailyPostService.listCategories().then((items: TopicCategory[]) => {
      this.categories = items;
    });
    dailyPostService.listPublished('all', '', 0, 12).then((page) => {
      this.posts = page.items;
    }).finally(() => {
      this.loading = false;
    });
  }

  private hotTags(): TopicTag[] {
    return this.tags.slice()
      .sort((a: TopicTag, b: TopicTag) => b.postCount - a.postCount)
      .slice(0, 10);
  }

  private activeCategories(): TopicCategory[] {
    return this.categories.filter((c: TopicCategory) => c.id !== 'all').slice()
      .sort((a: TopicCategory, b: TopicCategory) => b.postCount - a.postCount);
  }

  private rankColor(rank: number): string {
    if (rank === 0) {
      return AppColor.danger;
    }
    if (rank === 1) {
      return AppColor.warning;
    }
    if (rank === 2) {
      return AppColor.accent;
    }
    return AppColor.textMuted;
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

  private openTag(tag: TopicTag): void {
    router.pushUrl({
      url: 'pages/TopicDetail',
      params: { tagId: tag.id, tagName: tag.name, categoryName: tag.categoryName }
    });
  }

  private openPost(post: DailyPost): void {
    if (post.tagIds.length > 0) {
      router.pushUrl({
        url: 'pages/TopicDetail',
        params: {
          tagId: post.tagIds[0],
          tagName: post.tags.length > 0 ? post.tags[0] : '话题',
          categoryName: post.categoryName
        }
      });
    }
  }

  @Builder
  private sectionTitle(text: string): void {
    Text(text)
      .fontSize(Font.title)
      .fontWeight(FontWeight.Bold)
      .fontColor(AppColor.textTitle)
      .width('100%');
  }

  @Builder
  private hotTagRow(tag: TopicTag, rank: number): void {
    Row({ space: Space.md }) {
      Text((rank + 1).toString())
        .fontSize(Font.title)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.rankColor(rank))
        .width(28)
        .textAlign(TextAlign.Center);
      Column({ space: 2 }) {
        Text(`# ${tag.name}`)
          .fontSize(Font.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textTitle)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Text(tag.categoryName)
          .fontSize(Font.caption)
          .fontColor(AppColor.textMuted)
          .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text(`${tag.postCount} 篇`)
        .fontSize(Font.small)
        .fontColor(AppColor.accent);
    }
    .width('100%')
    .height(54)
    .padding({ left: Space.md, right: Space.md })
    .onClick(() => {
      this.openTag(tag);
    });
  }

  @Builder
  private postRow(post: DailyPost): void {
    Row({ space: Space.md }) {
      Image(post.coverUrl)
        .width(56)
        .height(56)
        .objectFit(ImageFit.Cover)
        .borderRadius(Radius.md)
        .backgroundColor(AppColor.surfaceSoft);
      Column({ space: Space.xs }) {
        Text(post.title)
          .fontSize(Font.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textTitle)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Row({ space: Space.sm }) {
          Text(this.initial(post.authorName))
            .width(18)
            .height(18)
            .borderRadius(9)
            .backgroundColor(this.avatarColor(post.authorName))
            .fontColor(AppColor.textOnPrimary)
            .fontSize(10)
            .textAlign(TextAlign.Center);
          Text(post.authorName)
            .fontSize(Font.caption)
            .fontColor(AppColor.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1);
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);
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
      this.openPost(post);
    });
  }

  build() {
    Column({ space: Space.lg }) {
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

      Column({ space: Space.xs }) {
        Text('🔥 热门趋势')
          .fontSize(Font.h1)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle)
          .width('100%');
        Text('本周科研社区最受关注的话题与内容')
          .fontSize(Font.small)
          .fontColor(AppColor.textSecondary)
          .width('100%');
      }
      .width('100%');

      Scroll() {
        Column({ space: Space.lg }) {
          this.sectionTitle('热门话题榜');
          Column() {
            ForEach(this.hotTags(), (tag: TopicTag, index: number) => {
              this.hotTagRow(tag, index);
              if (index < this.hotTags().length - 1) {
                Divider().color(AppColor.border).margin({ left: 40, right: Space.md });
              }
            }, (tag: TopicTag) => tag.id);
          }
          .width('100%')
          .padding({ top: Space.sm, bottom: Space.sm })
          .backgroundColor(AppColor.surface)
          .borderRadius(Radius.lg)
          .border({ width: 1, color: AppColor.border })
          .shadow(Elevation.card);

          this.sectionTitle('活跃学科');
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.activeCategories(), (category: TopicCategory) => {
              Row({ space: Space.sm }) {
                Text(category.name)
                  .fontSize(Font.small)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColor.textBody);
                Text(`${category.postCount}`)
                  .fontSize(Font.caption)
                  .fontColor(AppColor.accent);
              }
              .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm })
              .backgroundColor(AppColor.surface)
              .border({ width: 1, color: AppColor.border })
              .borderRadius(Radius.pill)
              .margin({ right: Space.sm, bottom: Space.sm });
            }, (category: TopicCategory) => category.id);
          }
          .width('100%');

          this.sectionTitle('推荐日报');
          ForEach(this.posts, (post: DailyPost) => {
            this.postRow(post);
          }, (post: DailyPost) => post.id);
        }
        .width('100%')
        .padding({ bottom: Space.xxl });
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.bg);
  }
}
