import { router } from '@kit.ArkUI';
import { DailyPost } from '../models/DailyPost';
import { dailyPostService } from '../services/DailyPostService';
import { AppColor, Space, Radius, Font, Elevation } from '../theme/AppTheme';

@Entry
@Component
struct TopicDetail {
  @State tagId: string = '';
  @State tagName: string = '';
  @State categoryName: string = '';
  @State posts: DailyPost[] = [];
  @State loading: boolean = true;
  @State hasMore: boolean = false;
  @State nextOffset: number = 0;

  aboutToAppear(): void {
    const params = (router.getParams() as Record<string, string> | undefined) ?? {};
    this.tagId = params.tagId ?? '';
    this.tagName = params.tagName ?? '话题';
    this.categoryName = params.categoryName ?? '科研';
    this.loadFirstPage();
  }

  private loadFirstPage(): void {
    this.loading = true;
    dailyPostService.listPublished('all', this.tagId, 0, 20).then((page) => {
      this.posts = page.items;
      this.nextOffset = page.nextOffset;
      this.hasMore = page.hasMore;
    }).finally(() => {
      this.loading = false;
    });
  }

  private loadMore(): void {
    if (!this.hasMore) {
      return;
    }
    dailyPostService.listPublished('all', this.tagId, this.nextOffset, 20).then((page) => {
      this.posts = this.posts.concat(page.items);
      this.nextOffset = page.nextOffset;
      this.hasMore = page.hasMore;
    });
  }

  @Builder
  private postRow(post: DailyPost): void {
    Row({ space: Space.md }) {
      Image(post.coverUrl)
        .width(92)
        .height(116)
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
        Row() {
          Text(post.authorName)
            .fontSize(Font.caption)
            .fontColor(AppColor.textMuted);
          Blank();
          Text(post.categoryName)
            .fontSize(Font.caption)
            .fontColor(AppColor.accent);
        }
        .width('100%');
      }
      .layoutWeight(1);
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border });
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

      Column({ space: Space.sm }) {
        Text(`#${this.tagName}`)
          .fontSize(Font.h1)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle)
          .width('100%');
        Text(`${this.categoryName} · ${this.posts.length} 篇科研日报`)
          .fontSize(Font.small)
          .fontColor(AppColor.textSecondary)
          .width('100%');
      }
      .width('100%')
      .padding(Space.lg)
      .backgroundColor(AppColor.surface)
      .borderRadius(Radius.lg)
      .border({ width: 1, color: AppColor.border })
      .shadow(Elevation.card);

      Scroll() {
        if (this.loading) {
          Text('正在加载话题内容...')
            .fontSize(Font.body)
            .fontColor(AppColor.textMuted)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 80 });
        } else if (this.posts.length === 0) {
          Column({ space: Space.sm }) {
            Text('这个话题还没有日报')
              .fontSize(Font.title)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textTitle);
            Text('回到创作页，发布第一篇带话题标签的科研日报。')
              .fontSize(Font.small)
              .fontColor(AppColor.textSecondary)
              .textAlign(TextAlign.Center);
          }
          .width('100%')
          .height(240)
          .justifyContent(FlexAlign.Center);
        } else {
          Column({ space: Space.md }) {
            ForEach(this.posts, (post: DailyPost) => {
              this.postRow(post);
            }, (post: DailyPost) => post.id);
            Button(this.hasMore ? '加载更多' : '已展示全部')
              .height(42)
              .width('100%')
              .enabled(this.hasMore)
              .fontColor(this.hasMore ? AppColor.textOnPrimary : AppColor.textMuted)
              .backgroundColor(this.hasMore ? AppColor.primary : AppColor.surfaceSoft)
              .borderRadius(Radius.lg)
              .onClick(() => {
                this.loadMore();
              });
          }
        }
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
