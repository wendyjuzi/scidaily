import { router } from '@kit.ArkUI';
import { NotificationBundle, NotificationItem } from '../models/Community';
import { authService } from '../services/AuthService';
import { communityService } from '../services/CommunityService';

@Entry
@Component
struct Messages {
  @State items: NotificationItem[] = [];
  @State unreadCount: number = 0;
  @State errorMessage: string = '';

  aboutToAppear(): void {
    if (!authService.isLoggedIn()) {
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
    this.reload();
  }

  private reload(): void {
    communityService.getNotifications().then((bundle: NotificationBundle) => {
      this.items = bundle.items;
      this.unreadCount = bundle.unreadCount;
      this.errorMessage = '';
    }).catch((error: Error) => {
      this.items = [];
      this.unreadCount = 0;
      this.errorMessage = error.message;
    });
  }

  private readOne(id: number): void {
    communityService.markNotificationRead(id).then(() => {
      this.reload();
    }).catch((error: Error) => {
      this.errorMessage = error.message;
    });
  }

  private readAll(): void {
    communityService.markAllNotificationsRead().then(() => {
      this.reload();
    }).catch((error: Error) => {
      this.errorMessage = error.message;
    });
  }

  private clearAll(): void {
    communityService.clearNotifications().then(() => {
      this.reload();
    }).catch((error: Error) => {
      this.errorMessage = error.message;
    });
  }

  private typeText(type: string): string {
    if (type === 'like') {
      return '点赞';
    }
    if (type === 'comment') {
      return '评论';
    }
    return '系统';
  }

  private typeColor(type: string): string {
    if (type === 'like') {
      return '#E31B54';
    }
    if (type === 'comment') {
      return '#1E88E5';
    }
    return '#12B76A';
  }

  @Builder
  private noticeCard(item: NotificationItem): void {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.typeText(item.type))
          .fontSize(12)
          .fontColor(this.typeColor(item.type))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(item.isRead ? '#F2F4F7' : '#EEF6FF')
          .borderRadius(8);
        Text(item.isRead ? '已读' : '未读')
          .fontSize(12)
          .fontColor(item.isRead ? '#98A2B3' : '#F79009');
        Blank();
        Text(item.createdAt)
          .fontSize(12)
          .fontColor('#8A94A6');
      }
      .width('100%');

      Text(item.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1D2939')
        .width('100%');

      Text(item.content)
        .fontSize(14)
        .fontColor('#667085')
        .lineHeight(20)
        .width('100%');
    }
    .width('100%')
    .padding(14)
    .backgroundColor(item.isRead ? '#FFFFFF' : '#FFFDF5')
    .borderRadius(12)
    .onClick(() => {
      if (!item.isRead) {
        this.readOne(item.id);
      }
    });
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Button('返回')
          .type(ButtonType.Capsule)
          .onClick(() => {
            router.back();
          });
        Blank();
        if (this.items.length > 0) {
          Button('全已读')
            .type(ButtonType.Capsule)
            .fontSize(12)
            .backgroundColor('#1E88E5')
            .onClick(() => {
              this.readAll();
            });
          Button('清空')
            .type(ButtonType.Capsule)
            .fontSize(12)
            .backgroundColor('#F04438')
            .onClick(() => {
              this.clearAll();
            });
        }
      }
      .width('100%');

      Row() {
        Text('消息通知')
          .fontSize(26)
          .fontWeight(FontWeight.Bold);
        Blank();
        if (this.unreadCount > 0) {
          Text(`${this.unreadCount} 条未读`)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor('#F79009')
            .borderRadius(12);
        }
      }
      .width('100%');

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(13)
          .fontColor('#D92D20')
          .width('100%');
      }

      if (this.items.length === 0) {
        Column({ space: 8 }) {
          Text('暂无消息')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#475467');
          Text('点赞、评论回复和系统公告会显示在这里。')
            .fontSize(14)
            .fontColor('#8A94A6')
            .textAlign(TextAlign.Center);
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else {
        List({ space: 10 }) {
          ForEach(this.items, (item: NotificationItem) => {
            ListItem() {
              this.noticeCard(item);
            }
          }, (item: NotificationItem) => item.id.toString());
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
}
