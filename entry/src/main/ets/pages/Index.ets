import { router } from '@kit.ArkUI';
import { ResearchNews } from '../models/ResearchNews';
import { PersonalStats, UserProfile } from '../models/User';
import { authService } from '../services/AuthService';
import { newsService } from '../services/NewsService';
import { personalCenterService } from '../services/PersonalCenterService';

@Entry
@Component
struct Index {
  @State categories: string[] = ['全部'];
  @State allNews: ResearchNews[] = [];
  @State visibleNews: ResearchNews[] = [];
  @State bookmarkedNews: ResearchNews[] = [];
  @State selectedCategory: string = '全部';
  @State currentUser: UserProfile | undefined = undefined;
  @State profileStats: PersonalStats = {
    postCount: 0,
    collectionCount: 0,
    likeCount: 0,
    historyCount: 0,
    continuousDays: 0
  };
  private tabsController: TabsController = new TabsController();

  aboutToAppear(): void {
    this.categories = ['全部', ...newsService.getCategories()];
    this.reloadProfile();
    this.reloadNews();
  }

  onPageShow(): void {
    this.reloadProfile();
    this.reloadNews();
  }

  private reloadNews(): void {
    this.allNews = newsService.getDailyNews();
    this.applyCategoryFilter(this.selectedCategory);
    if (authService.isLoggedIn()) {
      personalCenterService.getCollectedNews().then((items: ResearchNews[]) => {
        this.bookmarkedNews = items;
      }).catch((error: Error) => {
        this.bookmarkedNews = [];
      });
      return;
    }
    this.bookmarkedNews = newsService.getBookmarkedNews();
  }

  private reloadProfile(): void {
    this.currentUser = authService.getCurrentUser();
    if (this.currentUser) {
      personalCenterService.getStats().then((stats: PersonalStats) => {
        this.profileStats = stats;
      }).catch((error: Error) => {
        this.profileStats = this.emptyStats();
      });
      return;
    }
    this.profileStats = this.emptyStats();
  }

  private emptyStats(): PersonalStats {
    return {
      postCount: 0,
      collectionCount: 0,
      likeCount: 0,
      historyCount: 0,
      continuousDays: 0
    };
  }

  private applyCategoryFilter(category: string): void {
    this.selectedCategory = category;
    if (category === '全部') {
      this.visibleNews = this.allNews;
      return;
    }
    this.visibleNews = this.allNews.filter((item: ResearchNews) => item.category === category);
  }

  private openLogin(): void {
    router.pushUrl({ url: 'pages/Login' });
  }

  private openProtectedPage(url: string): void {
    if (!authService.isLoggedIn()) {
      this.openLogin();
      return;
    }
    router.pushUrl({ url });
  }

  private openPersonalList(type: string): void {
    if (!authService.isLoggedIn()) {
      this.openLogin();
      return;
    }
    router.pushUrl({
      url: 'pages/PersonalList',
      params: { type }
    });
  }

  private logout(): void {
    authService.logout();
    this.reloadProfile();
  }

  private avatarText(user: UserProfile): string {
    if (user.nickname.length > 0) {
      return user.nickname.substring(0, 1).toUpperCase();
    }
    return 'S';
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

  @Builder
  private statTile(label: string, value: number): void {
    Column({ space: 4 }) {
      Text(value.toString())
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D2939');
      Text(label)
        .fontSize(12)
        .fontColor('#667085')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .height(68)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFFFFF')
    .borderRadius(10);
  }

  @Builder
  private menuRow(title: string, subtitle: string, action: string): void {
    Row() {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1D2939')
          .width('100%');
        Text(subtitle)
          .fontSize(12)
          .fontColor('#8A94A6')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
      }
      .layoutWeight(1);
      Text('>')
        .fontSize(18)
        .fontColor('#98A2B3');
    }
    .width('100%')
    .height(64)
    .padding({ left: 14, right: 14 })
    .backgroundColor('#FFFFFF')
    .borderRadius(10)
    .onClick(() => {
      if (action === 'profile') {
        this.openProtectedPage('pages/ProfileEdit');
      } else if (action === 'security') {
        this.openProtectedPage('pages/SecuritySettings');
      } else if (action === 'settings') {
        this.openProtectedPage('pages/Settings');
      } else {
        this.openPersonalList(action);
      }
    });
  }

  @Builder
  private loginRequiredPanel(): void {
    Column({ space: 16 }) {
      Text('个人中心')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .textAlign(TextAlign.Start);

      Column({ space: 10 }) {
        Text('请先登录')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1D2939');
        Text('登录后可查看个人资料、发布内容、收藏、点赞、浏览记录和账号设置。')
          .fontSize(14)
          .fontColor('#667085')
          .textAlign(TextAlign.Center)
          .lineHeight(20);
        Button('登录 / 注册')
          .width('100%')
          .height(46)
          .borderRadius(10)
          .backgroundColor('#1E88E5')
          .onClick(() => {
            this.openLogin();
          });
      }
      .width('100%')
      .padding(18)
      .backgroundColor('#FFFFFF')
      .borderRadius(12);
    }
    .width('100%');
  }

  @Builder
  private profilePanel(user: UserProfile): void {
    Scroll() {
      Column({ space: 14 }) {
        Row({ space: 12 }) {
          Text(this.avatarText(user))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .width(58)
            .height(58)
            .textAlign(TextAlign.Center)
            .backgroundColor('#1E88E5')
            .borderRadius(29);
          Column({ space: 4 }) {
            Text(user.nickname)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1D2939')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%');
            Text(user.researchField.length > 0 ? user.researchField : '暂未设置研究方向')
              .fontSize(13)
              .fontColor('#667085')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%');
            Text(user.institution.length > 0 ? user.institution : '暂未设置机构')
              .fontSize(13)
              .fontColor('#98A2B3')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%');
          }
          .layoutWeight(1);
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(12);

        Row({ space: 8 }) {
          this.statTile('发布', this.profileStats.postCount);
          this.statTile('收藏', this.profileStats.collectionCount);
          this.statTile('点赞', this.profileStats.likeCount);
          this.statTile('连续', this.profileStats.continuousDays);
        }
        .width('100%');

        Column({ space: 10 }) {
          this.menuRow('我的发布', '已发布和草稿中的科研日报', 'posts');
          this.menuRow('我的收藏', '收藏的论文与日报内容', 'collections');
          this.menuRow('我的点赞', '点赞过的日报与论文卡片', 'likes');
          this.menuRow('浏览记录', '最近浏览过的科研内容', 'history');
        }
        .width('100%');

        Column({ space: 10 }) {
          this.menuRow('编辑资料', '头像、昵称、邮箱和科研资料', 'profile');
          this.menuRow('账号安全', '密码重置与登录状态保护', 'security');
          this.menuRow('隐私与消息', '资料可见性和通知开关', 'settings');
        }
        .width('100%');

        Button('退出登录')
          .height(46)
          .width('100%')
          .borderRadius(10)
          .fontColor('#D92D20')
          .backgroundColor('#FFEFEF')
          .onClick(() => {
            this.logout();
          });
      }
      .width('100%')
      .padding({ bottom: 24 });
    }
    .width('100%')
    .height('100%');
  }

  build() {
    Column() {
      Tabs({
        barPosition: BarPosition.End,
        controller: this.tabsController
      }) {
        TabContent() {
          Column({ space: 10 }) {
            Text('科研日报')
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
              Text('暂无日报内容，请稍后刷新。')
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
        .tabBar(this.tabLabel('日报'));

        TabContent() {
          Column({ space: 10 }) {
            Text('收藏')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .textAlign(TextAlign.Start);

            if (this.bookmarkedNews.length === 0) {
              Text('暂无收藏，可在日报详情中添加收藏。')
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
        .tabBar(this.tabLabel('收藏'));

        TabContent() {
          Column({ space: 10 }) {
            if (this.currentUser) {
              this.profilePanel(this.currentUser);
            } else {
              this.loginRequiredPanel();
            }
          }
          .width('100%')
          .height('100%')
          .padding(16)
          .backgroundColor('#F5F7FB');
        }
        .tabBar(this.tabLabel('我的'));
      }
      .width('100%')
      .height('100%');
    }
    .height('100%')
    .width('100%');
  }
}
