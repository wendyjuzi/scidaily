import { router } from '@kit.ArkUI';
import { authService } from '../services/AuthService';
import { AppColor, Space, Radius, Font } from '../theme/AppTheme';

@Entry
@Component
struct SecuritySettings {
  @State oldPassword: string = '';
  @State newPassword: string = '';
  @State confirmPassword: string = '';
  @State errorMessage: string = '';

  aboutToAppear(): void {
    if (!authService.isLoggedIn()) {
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
  }

  private async save(): Promise<void> {
    if (this.newPassword !== this.confirmPassword) {
      this.errorMessage = '两次输入的新密码不一致。';
      return;
    }
    try {
      await authService.resetPassword(this.oldPassword, this.newPassword);
      router.back();
    } catch (error) {
      if (error instanceof Error) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '密码更新失败，请稍后重试。';
      }
    }
  }

  build() {
    Column({ space: Space.lg }) {
      Row() {
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
      }
      .width('100%');

      Text('账号安全')
        .fontSize(Font.h1)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textTitle)
        .width('100%');

      Column({ space: Space.md }) {
        TextInput({ placeholder: '旧密码', text: this.oldPassword })
          .height(48)
          .fontSize(Font.body)
          .type(InputType.Password)
          .backgroundColor(AppColor.surface)
          .border({ width: 1, color: AppColor.border })
          .borderRadius(Radius.md)
          .onChange((value: string) => {
            this.oldPassword = value;
          });

        TextInput({ placeholder: '新密码', text: this.newPassword })
          .height(48)
          .fontSize(Font.body)
          .type(InputType.Password)
          .backgroundColor(AppColor.surface)
          .border({ width: 1, color: AppColor.border })
          .borderRadius(Radius.md)
          .onChange((value: string) => {
            this.newPassword = value;
          });

        TextInput({ placeholder: '确认新密码', text: this.confirmPassword })
          .height(48)
          .fontSize(Font.body)
          .type(InputType.Password)
          .backgroundColor(AppColor.surface)
          .border({ width: 1, color: AppColor.border })
          .borderRadius(Radius.md)
          .onChange((value: string) => {
            this.confirmPassword = value;
          });

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(Font.small)
            .fontColor(AppColor.danger)
            .width('100%');
        }

        Button('更新密码')
          .height(48)
          .width('100%')
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textOnPrimary)
          .borderRadius(Radius.md)
          .backgroundColor(AppColor.primary)
          .onClick(() => {
            this.save();
          });
      }
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.bg);
  }
}
