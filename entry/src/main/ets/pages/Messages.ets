import { router } from '@kit.ArkUI';
import { NotificationBundle, NotificationItem } from '../models/Community';
import { authService } from '../services/AuthService';
import { communityService } from '../services/CommunityService';
import { AppColor, Space, Radius, Font } from '../theme/AppTheme';

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
      return AppColor.series3;
    }
    if (type === 'comment') {
      return AppColor.series2;
    }
    return AppColor.series1;
  }

  @Builder
  private noticeCard(item: NotificationItem): void {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        Text(this.typeText(item.type))
          .fontSize(Font.small)
          .fontColor(this.typeColor(item.type))
          .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
          .backgroundColor(item.isRead ? AppColor.surfaceSoft : AppColor.accentSoft)
          .borderRadius(Radius.sm);
        Text(item.isRead ? '已读' : '未读')
          .fontSize(Font.small)
          .fontColor(item.isRead ? AppColor.textMuted : AppColor.warning);
        Blank();
        Text(item.createdAt)
          .fontSize(Font.small)
          .fontColor(AppColor.textMuted);
      }
      .width('100%');

      Text(item.title)
        .fontSize(Font.sub)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textTitle)
        .width('100%');

      Text(item.content)
        .fontSize(Font.body)
        .fontColor(AppColor.textSecondary)
        .lineHeight(20)
        .width('100%');
    }
    .width('100%')
    .padding(Space.lg)
    .backgroundColor(item.isRead ? AppColor.surface : AppColor.accentSoft)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: item.isRead ? AppColor.border : AppColor.accent })
    .onClick(() => {
      if (!item.isRead) {
        this.readOne(item.id);
      }
    });
  }

  build() {
    Column({ space: Space.lg }) {
      Row({ space: Space.sm }) {
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
        if (this.items.length > 0) {
          Button('全已读')
            .type(ButtonType.Capsule)
            .fontSize(Font.small)
            .fontColor(AppColor.textOnPrimary)
            .backgroundColor(AppColor.primary)
            .onClick(() => {
              this.readAll();
            });
          Button('清空')
            .type(ButtonType.Capsule)
            .fontSize(Font.small)
            .fontColor(AppColor.danger)
            .backgroundColor(AppColor.dangerSoft)
            .onClick(() => {
              this.clearAll();
            });
        }
      }
      .width('100%');

      Row() {
        Text('消息通知')
          .fontSize(Font.h1)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle);
        Blank();
        if (this.unreadCount > 0) {
          Text(`${this.unreadCount} 条未读`)
            .fontSize(Font.small)
            .fontColor(AppColor.textOnPrimary)
            .padding({ left: Space.md, right: Space.md, top: 5, bottom: 5 })
            .backgroundColor(AppColor.warning)
            .borderRadius(Radius.md);
        }
      }
      .width('100%');

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(Font.small)
          .fontColor(AppColor.danger)
          .width('100%');
      }

      if (this.items.length === 0) {
        Column({ space: Space.sm }) {
          Text('暂无消息')
            .fontSize(Font.sub)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textBody);
          Text('点赞、评论回复和系统公告会显示在这里。')
            .fontSize(Font.body)
            .fontColor(AppColor.textMuted)
            .textAlign(TextAlign.Center);
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else {
        List({ space: Space.md }) {
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
    .padding(Space.lg)
    .backgroundColor(AppColor.bg);
  }
}
