import { router } from '@kit.ArkUI';
import { NewsCategory, ResearchNews } from '../models/ResearchNews';
import { newsService } from '../services/NewsService';

@Entry
@Component
struct Index {
  @State categories: string[] = ['All'];
  @State allNews: ResearchNews[] = [];
  @State visibleNews: ResearchNews[] = [];
  @State bookmarkedNews: ResearchNews[] = [];
  @State selectedCategory: string = 'All';
  private tabsController: TabsController = new TabsController();

  aboutToAppear(): void {
    this.categories = ['All', ...newsService.getCategories()];
    this.reloadNews();
  }

  onPageShow(): void {
    this.reloadNews();
  }

  private reloadNews(): void {
    this.allNews = newsService.getDailyNews();
    this.bookmarkedNews = newsService.getBookmarkedNews();
    this.applyCategoryFilter(this.selectedCategory);
  }

  private applyCategoryFilter(category: string): void {
    this.selectedCategory = category;
    if (category === 'All') {
      this.visibleNews = this.allNews;
      return;
    }
    this.visibleNews = this.allNews.filter((item: ResearchNews) => item.category === category);
  }

  @Builder
  private categoryChip(category: string): void {
    Button(category)
      .type(ButtonType.Capsule)
      .fontSize(14)
      .fontColor(this.selectedCategory === category ? '#FFFFFF' : '#333333')
      .backgroundColor(this.selectedCategory === category ? '#1E88E5' : '#EEF3F8')
      .onClick(() => {
        this.applyCategoryFilter(category);
      });
  }

  @Builder
  private newsCard(item: ResearchNews): void {
    Column({ space: 8 }) {
      Text(item.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Text(item.aiSummary)
        .fontSize(14)
        .fontColor('#5A6572')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Row() {
        Text(item.category)
          .fontSize(12)
          .fontColor('#1E88E5');
        Blank();
        Text(item.publishedDate)
          .fontSize(12)
          .fontColor('#8A94A6');
      }
      .width('100%');
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor('#FFFFFF')
    .onClick(() => {
      router.pushUrl({
        url: 'pages/Detail',
        params: { id: item.id }
      });
    });
  }

  @Builder
  private tabLabel(title: string): void {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium);
  }

  build() {
    Column() {
      Tabs({
        barPosition: BarPosition.End,
        controller: this.tabsController
      }) {
        TabContent() {
          Column({ space: 10 }) {
            Text('SciDaily')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .textAlign(TextAlign.Start);

            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.categories, (category: string) => {
                  this.categoryChip(category);
                });
              }
              .padding({ right: 16 });
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%');

            if (this.visibleNews.length === 0) {
              Text('No data yet. Please refresh later.')
                .fontSize(14)
                .fontColor('#8A94A6')
                .margin({ top: 20 });
            } else {
              List({ space: 10 }) {
                ForEach(this.visibleNews, (item: ResearchNews) => {
                  ListItem() {
                    this.newsCard(item);
                  }
                }, (item: ResearchNews) => item.id);
              }
              .edgeEffect(EdgeEffect.Spring)
              .width('100%')
              .layoutWeight(1);
            }
          }
          .width('100%')
          .height('100%')
          .padding(16)
          .backgroundColor('#F5F7FB');
        }
        .tabBar(this.tabLabel('Daily'));

        TabContent() {
          Column({ space: 10 }) {
            Text('Bookmarks')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .textAlign(TextAlign.Start);

            if (this.bookmarkedNews.length === 0) {
              Text('No bookmarks yet. Save papers from the Daily tab.')
                .fontSize(14)
                .fontColor('#8A94A6')
                .margin({ top: 20 });
            } else {
              List({ space: 10 }) {
                ForEach(this.bookmarkedNews, (item: ResearchNews) => {
                  ListItem() {
                    this.newsCard(item);
                  }
                }, (item: ResearchNews) => item.id);
              }
              .edgeEffect(EdgeEffect.Spring)
              .width('100%')
              .layoutWeight(1);
            }
          }
          .width('100%')
          .height('100%')
          .padding(16)
          .backgroundColor('#F5F7FB');
        }
        .tabBar(this.tabLabel('Bookmarks'));
      }
      .width('100%')
      .height('100%');
    }
    .height('100%')
    .width('100%');
  }
}
