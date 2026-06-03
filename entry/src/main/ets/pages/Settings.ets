import { router } from '@kit.ArkUI';
import { authService } from '../services/AuthService';
import { SettingsBundle } from '../models/User';
import { personalCenterService } from '../services/PersonalCenterService';

@Entry
@Component
struct Settings {
  @State showEmail: boolean = false;
  @State showResearchStats: boolean = true;
  @State allowRecommendations: boolean = true;
  @State likeNotice: boolean = true;
  @State commentNotice: boolean = true;
  @State systemNotice: boolean = true;
  @State errorMessage: string = '';

  aboutToAppear(): void {
    if (!authService.isLoggedIn()) {
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
    try {
      personalCenterService.getSettings().then((settings: SettingsBundle) => {
        this.applySettings(settings);
        this.errorMessage = '';
      }).catch((error: Error) => {
        this.errorMessage = error.message;
      });
    } catch (error) {
      router.pushUrl({ url: 'pages/Login' });
    }
  }

  private applySettings(settings: SettingsBundle): void {
    this.showEmail = settings.privacy.showEmail;
    this.showResearchStats = settings.privacy.showResearchStats;
    this.allowRecommendations = settings.privacy.allowRecommendations;
    this.likeNotice = settings.messages.likeNotice;
    this.commentNotice = settings.messages.commentNotice;
    this.systemNotice = settings.messages.systemNotice;
  }

  private savePrivacy(): void {
    personalCenterService.updatePrivacy({
      showEmail: this.showEmail,
      showResearchStats: this.showResearchStats,
      allowRecommendations: this.allowRecommendations
    }).then((settings: SettingsBundle) => {
      this.applySettings(settings);
      this.errorMessage = '';
    }).catch((error: Error) => {
      this.errorMessage = error.message;
    });
  }

  private saveMessages(): void {
    personalCenterService.updateMessages({
      likeNotice: this.likeNotice,
      commentNotice: this.commentNotice,
      systemNotice: this.systemNotice
    }).then((settings: SettingsBundle) => {
      this.applySettings(settings);
      this.errorMessage = '';
    }).catch((error: Error) => {
      this.errorMessage = error.message;
    });
  }

  @Builder
  private switchRow(title: string, subtitle: string, isOn: boolean, onChange: (value: boolean) => void): void {
    Row() {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1D2939')
          .width('100%');
        Text(subtitle)
          .fontSize(12)
          .fontColor('#667085')
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .layoutWeight(1);

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange(onChange);
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(10);
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
      }
      .width('100%');

      Text('设置')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .width('100%');

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(13)
          .fontColor('#D92D20')
          .width('100%');
      }

      Scroll() {
        Column({ space: 14 }) {
          Text('隐私设置')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width('100%');
          this.switchRow('展示邮箱', '允许其他用户查看个人资料中的邮箱。', this.showEmail, (value: boolean) => {
            this.showEmail = value;
            this.savePrivacy();
          });
          this.switchRow('展示科研统计', '在个人中心展示科研日报、收藏、点赞等数据。', this.showResearchStats, (value: boolean) => {
            this.showResearchStats = value;
            this.savePrivacy();
          });
          this.switchRow('科研内容推荐', '根据研究方向推荐更相关的日报内容。', this.allowRecommendations, (value: boolean) => {
            this.allowRecommendations = value;
            this.savePrivacy();
          });

          Text('消息设置')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ top: 8 });
          this.switchRow('点赞通知', '当日报被点赞时接收提醒。', this.likeNotice, (value: boolean) => {
            this.likeNotice = value;
            this.saveMessages();
          });
          this.switchRow('评论通知', '接收评论和回复提醒。', this.commentNotice, (value: boolean) => {
            this.commentNotice = value;
            this.saveMessages();
          });
          this.switchRow('系统通知', '接收系统公告和账号消息。', this.systemNotice, (value: boolean) => {
            this.systemNotice = value;
            this.saveMessages();
          });
        }
        .width('100%')
        .padding({ bottom: 24 });
      }
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#F5F7FB');
  }
}
