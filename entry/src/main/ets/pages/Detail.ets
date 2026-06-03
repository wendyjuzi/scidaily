import { router } from '@kit.ArkUI';
import { ResearchNews } from '../models/ResearchNews';
import { authService } from '../services/AuthService';
import { newsService } from '../services/NewsService';
import { personalCenterService } from '../services/PersonalCenterService';

@Entry
@Component
struct Detail {
  @State news: ResearchNews | undefined = undefined;
  @State isBookmarked: boolean = false;
  @State isLiked: boolean = false;
  @State errorMessage: string = '';

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
    }
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
      this.errorMessage = '';
    } catch (error) {
      if (error instanceof Error) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '点赞操作失败，请稍后重试。';
      }
    }
  }

  build() {
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
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#F5F7FB');
  }
}
