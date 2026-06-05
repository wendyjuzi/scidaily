import { router } from '@kit.ArkUI';
import { PaperItem } from '../models/Paper';
import { paperService } from '../services/PaperService';
import { AppColor, Space, Radius, Font, Elevation } from '../theme/AppTheme';

@Entry
@Component
struct PaperLibrary {
  @State papers: PaperItem[] = [];
  @State loading: boolean = true;
  @State nextOffset: number = 0;
  @State hasMore: boolean = true;

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.loading = true;
    paperService.listPapers(0, 12).then((page) => {
      this.papers = page.items;
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
    paperService.listPapers(this.nextOffset, 12).then((page) => {
      this.papers = this.papers.concat(page.items);
      this.nextOffset = page.nextOffset;
      this.hasMore = page.hasMore;
    });
  }

  @Builder
  private paperCard(item: PaperItem): void {
    Column({ space: Space.md }) {
      Row() {
        Text(item.categoryName)
          .fontSize(Font.small)
          .fontColor(AppColor.accent)
          .backgroundColor(AppColor.accentSoft)
          .borderRadius(Radius.md)
          .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs });
        Blank();
        Text(item.publishedAt)
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
      Text(item.abstract)
        .fontSize(Font.small)
        .fontColor(AppColor.textSecondary)
        .lineHeight(20)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');
      Text(item.authors.join(', '))
        .fontSize(Font.small)
        .fontColor(AppColor.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(item.tags, (tag: string) => {
          Text(`#${tag}`)
            .fontSize(Font.caption)
            .fontColor(AppColor.textSecondary)
            .backgroundColor(AppColor.surfaceSoft)
            .border({ width: 1, color: AppColor.border })
            .borderRadius(Radius.md)
            .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
            .margin({ right: Space.sm, bottom: Space.sm });
        }, (tag: string) => tag);
      }
      .width('100%');
      Button('阅读 PDF')
        .height(40)
        .width('100%')
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textOnPrimary)
        .backgroundColor(AppColor.primary)
        .borderRadius(Radius.lg)
        .onClick(() => {
          router.pushUrl({
            url: 'pages/PDFReader',
            params: { paperId: item.id }
          });
        });
    }
    .width('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border })
    .shadow(Elevation.card);
  }

  build() {
    Column({ space: Space.lg }) {
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
        Button('刷新')
          .height(34)
          .fontSize(Font.small)
          .fontColor(AppColor.accent)
          .backgroundColor(AppColor.accentSoft)
          .borderRadius(Radius.lg)
          .onClick(() => {
            this.reload();
          });
      }
      .width('100%');

      Text('文献 PDF 库')
        .fontSize(Font.h1)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textTitle)
        .width('100%');

      Scroll() {
        if (this.loading) {
          Text('正在加载开放论文...')
            .fontSize(Font.body)
            .fontColor(AppColor.textMuted)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 96 });
        } else {
          Column({ space: Space.lg }) {
            ForEach(this.papers, (item: PaperItem) => {
              this.paperCard(item);
            }, (item: PaperItem) => item.id);
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
