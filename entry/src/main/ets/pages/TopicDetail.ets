import { router } from '@kit.ArkUI';
import { DailyPost } from '../models/DailyPost';
import { dailyPostService } from '../services/DailyPostService';

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
    Row({ space: 10 }) {
      Image(post.coverUrl)
        .width(92)
        .height(116)
        .objectFit(ImageFit.Cover)
        .borderRadius(10);
      Column({ space: 6 }) {
        Text(post.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#202124')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Text(post.summary)
          .fontSize(13)
          .fontColor('#5F6368')
          .lineHeight(19)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Row() {
          Text(post.authorName)
            .fontSize(11)
            .fontColor('#8B8F98');
          Blank();
          Text(post.categoryName)
            .fontSize(11)
            .fontColor('#1E88E5');
        }
        .width('100%');
      }
      .layoutWeight(1);
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#FFFFFF')
    .borderRadius(12);
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Button('返回')
          .height(34)
          .fontSize(13)
          .fontColor('#111111')
          .backgroundColor('#FFFFFF')
          .borderRadius(17)
          .onClick(() => {
            router.back();
          });
        Blank();
      }
      .width('100%');

      Column({ space: 6 }) {
        Text(`#${this.tagName}`)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111111')
          .width('100%');
        Text(`${this.categoryName} · ${this.posts.length} 篇科研日报`)
          .fontSize(13)
          .fontColor('#6B7280')
          .width('100%');
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12);

      Scroll() {
        if (this.loading) {
          Text('正在加载话题内容...')
            .fontSize(14)
            .fontColor('#8B8F98')
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 80 });
        } else if (this.posts.length === 0) {
          Column({ space: 8 }) {
            Text('这个话题还没有日报')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333');
            Text('回到创作页，发布第一篇带话题标签的科研日报。')
              .fontSize(13)
              .fontColor('#777777')
              .textAlign(TextAlign.Center);
          }
          .width('100%')
          .height(240)
          .justifyContent(FlexAlign.Center);
        } else {
          Column({ space: 10 }) {
            ForEach(this.posts, (post: DailyPost) => {
              this.postRow(post);
            }, (post: DailyPost) => post.id);
            Button(this.hasMore ? '加载更多' : '已展示全部')
              .height(42)
              .width('100%')
              .enabled(this.hasMore)
              .fontColor(this.hasMore ? '#FFFFFF' : '#8B8F98')
              .backgroundColor(this.hasMore ? '#111111' : '#EEEEEE')
              .borderRadius(21)
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
    .padding(14)
    .backgroundColor('#F7F7F7');
  }
}
