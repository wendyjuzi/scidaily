import { router } from '@kit.ArkUI';
import { ResearchNews } from '../models/ResearchNews';
import { newsService } from '../services/NewsService';

@Entry
@Component
struct Detail {
  @State news: ResearchNews | undefined = undefined;
  @State isBookmarked: boolean = false;

  aboutToAppear(): void {
    const params = (router.getParams() as Record<string, string> | undefined) ?? {};
    const id = params.id;
    if (!id) {
      return;
    }
    this.news = newsService.getById(id);
    if (this.news) {
      this.isBookmarked = newsService.isBookmarked(this.news.id);
    }
  }

  private toggleBookmark(): void {
    if (!this.news) {
      return;
    }
    this.isBookmarked = newsService.toggleBookmark(this.news.id);
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Button('Back')
          .type(ButtonType.Capsule)
          .onClick(() => {
            router.back();
          });
        Blank();
      }
      .width('100%');

      if (!this.news) {
        Text('Article not found')
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

        Text(`Authors: ${this.news.authors.join(', ')}`)
          .fontSize(14)
          .fontColor('#475467')
          .width('100%');

        Text('Highlight')
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

        Text('Abstract')
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

        Text(`Source URL: ${this.news.sourceUrl}`)
          .fontSize(13)
          .fontColor('#1E88E5')
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Button(this.isBookmarked ? 'Remove Bookmark' : 'Bookmark')
          .width('100%')
          .margin({ top: 12 })
          .onClick(() => {
            this.toggleBookmark();
          });
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#F5F7FB');
  }
}
