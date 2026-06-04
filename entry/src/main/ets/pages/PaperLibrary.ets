import { router } from '@kit.ArkUI';
import { PaperItem } from '../models/Paper';
import { paperService } from '../services/PaperService';

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
    Column({ space: 10 }) {
      Row() {
        Text(item.categoryName)
          .fontSize(12)
          .fontColor('#007AFF')
          .backgroundColor('#EAF4FF')
          .borderRadius(12)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 });
        Blank();
        Text(item.publishedAt)
          .fontSize(11)
          .fontColor('#8B8F98');
      }
      .width('100%');
      Text(item.title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');
      Text(item.abstract)
        .fontSize(13)
        .fontColor('#5F6368')
        .lineHeight(20)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');
      Text(item.authors.join(', '))
        .fontSize(12)
        .fontColor('#64748B')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(item.tags, (tag: string) => {
          Text(`#${tag}`)
            .fontSize(11)
            .fontColor('#475569')
            .backgroundColor('#F8FAFC')
            .border({ width: 1, color: '#E2E8F0' })
            .borderRadius(12)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .margin({ right: 6, bottom: 6 });
        }, (tag: string) => tag);
      }
      .width('100%');
      Button('阅读 PDF')
        .height(40)
        .width('100%')
        .fontColor('#FFFFFF')
        .backgroundColor('#007AFF')
        .borderRadius(20)
        .onClick(() => {
          router.pushUrl({
            url: 'pages/PDFReader',
            params: { paperId: item.id }
          });
        });
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({ radius: 18, color: '#0D000000', offsetY: 6 });
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Button('返回')
          .height(34)
          .fontSize(13)
          .fontColor('#111827')
          .backgroundColor('#FFFFFF')
          .borderRadius(17)
          .onClick(() => {
            router.back();
          });
        Blank();
        Button('刷新')
          .height(34)
          .fontSize(13)
          .fontColor('#007AFF')
          .backgroundColor('#EAF4FF')
          .borderRadius(17)
          .onClick(() => {
            this.reload();
          });
      }
      .width('100%');

      Text('文献 PDF 库')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .width('100%');

      Scroll() {
        if (this.loading) {
          Text('正在加载开放论文...')
            .fontSize(14)
            .fontColor('#8B8F98')
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 96 });
        } else {
          Column({ space: 14 }) {
            ForEach(this.papers, (item: PaperItem) => {
              this.paperCard(item);
            }, (item: PaperItem) => item.id);
            Button(this.hasMore ? '加载更多' : '已展示全部')
              .height(42)
              .width('100%')
              .enabled(this.hasMore)
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
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor('#F6F8FB');
  }
}
