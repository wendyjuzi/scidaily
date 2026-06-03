import { router } from '@kit.ArkUI';
import { authService } from '../services/AuthService';

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
    Column({ space: 16 }) {
      Row() {
        Button('返回')
          .type(ButtonType.Capsule)
          .onClick(() => {
            router.back();
          });
        Blank();
      }
      .width('100%');

      Text('账号安全')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .width('100%');

      Column({ space: 12 }) {
        TextInput({ placeholder: '旧密码', text: this.oldPassword })
          .height(48)
          .fontSize(15)
          .type(InputType.Password)
          .backgroundColor('#FFFFFF')
          .borderRadius(10)
          .onChange((value: string) => {
            this.oldPassword = value;
          });

        TextInput({ placeholder: '新密码', text: this.newPassword })
          .height(48)
          .fontSize(15)
          .type(InputType.Password)
          .backgroundColor('#FFFFFF')
          .borderRadius(10)
          .onChange((value: string) => {
            this.newPassword = value;
          });

        TextInput({ placeholder: '确认新密码', text: this.confirmPassword })
          .height(48)
          .fontSize(15)
          .type(InputType.Password)
          .backgroundColor('#FFFFFF')
          .borderRadius(10)
          .onChange((value: string) => {
            this.confirmPassword = value;
          });

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor('#D92D20')
            .width('100%');
        }

        Button('更新密码')
          .height(48)
          .width('100%')
          .borderRadius(10)
          .backgroundColor('#1E88E5')
          .onClick(() => {
            this.save();
          });
      }
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#F5F7FB');
  }
}
