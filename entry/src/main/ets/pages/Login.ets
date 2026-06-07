import { router } from '@kit.ArkUI';
import { API_BASE_URL } from '../config/AppConfig';
import { authService } from '../services/AuthService';
import { AppColor, Space, Radius, Font } from '../theme/AppTheme';

@Entry
@Component
struct Login {
  @State isRegister: boolean = false;
  @State username: string = 'demo';
  @State password: string = '123456';
  @State errorMessage: string = '';
  @State backendChecked: boolean = false;
  @State backendConnected: boolean = false;

  aboutToAppear(): void {
    this.refreshBackendStatus();
  }

  private async refreshBackendStatus(): Promise<void> {
    this.backendChecked = false;
    this.backendConnected = await authService.checkBackendAvailable();
    this.backendChecked = true;
  }

  private async submit(): Promise<void> {
    try {
      if (this.isRegister) {
        await authService.register(this.username, this.password, '', '');
      } else {
        await authService.login(this.username, this.password);
      }
      this.errorMessage = '';
      router.back();
    } catch (error) {
      if (error instanceof Error) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '操作失败，请稍后重试。';
      }
    }
  }

  private switchMode(): void {
    this.isRegister = !this.isRegister;
    this.errorMessage = '';
    if (this.isRegister) {
      this.username = '';
      this.password = '';
    } else {
      this.username = 'demo';
      this.password = '123456';
    }
  }

  build() {
    Column({ space: Space.xl }) {
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

      Column({ space: Space.sm }) {
        Text(this.isRegister ? '创建账号' : '欢迎回来')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle)
          .width('100%');
        Text(this.isRegister ? '只需设置用户名和密码，昵称和邮箱可在个人资料中补充。' : '可使用 demo / 123456 快速体验。')
          .fontSize(Font.body)
          .fontColor(AppColor.textSecondary)
          .width('100%');
        Row({ space: Space.sm }) {
          Text('●')
            .fontSize(Font.small)
            .fontColor(this.backendChecked ? (this.backendConnected ? AppColor.success : AppColor.warning) : AppColor.textSecondary);
          Text(this.backendChecked ? (this.backendConnected ? '后端已连接，账号将保存到数据库。' : '后端未连接，当前为本地演示模式。') : '正在检测后端连接...')
            .fontSize(Font.small)
            .fontColor(AppColor.textSecondary)
            .layoutWeight(1);
          Button('刷新')
            .type(ButtonType.Normal)
            .fontSize(Font.small)
            .fontColor(AppColor.accent)
            .backgroundColor(AppColor.accentSoft)
            .height(28)
            .borderRadius(Radius.sm)
            .onClick(() => {
              this.refreshBackendStatus();
            });
        }
        .width('100%')
        .padding({ top: 6, right: Space.md, bottom: 6, left: Space.md })
        .backgroundColor(AppColor.surface)
        .borderRadius(Radius.md)
        .border({ width: 1, color: AppColor.border });
        Text(API_BASE_URL)
          .fontSize(Font.caption)
          .fontColor(AppColor.textMuted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
      }
      .width('100%');

      Column({ space: Space.md }) {
        TextInput({ placeholder: this.isRegister ? '用户名（必填）' : '用户名', text: this.username })
          .height(48)
          .fontSize(Font.body)
          .backgroundColor(AppColor.surface)
          .border({ width: 1, color: AppColor.border })
          .borderRadius(Radius.md)
          .onChange((value: string) => {
            this.username = value;
          });

        TextInput({ placeholder: this.isRegister ? '密码（至少 6 位）' : '密码', text: this.password })
          .height(48)
          .fontSize(Font.body)
          .type(InputType.Password)
          .backgroundColor(AppColor.surface)
          .border({ width: 1, color: AppColor.border })
          .borderRadius(Radius.md)
          .onChange((value: string) => {
            this.password = value;
          });

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(Font.small)
            .fontColor(AppColor.danger)
            .width('100%');
        }

        Button(this.isRegister ? '注册并登录' : '登录')
          .height(48)
          .width('100%')
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textOnPrimary)
          .borderRadius(Radius.md)
          .backgroundColor(AppColor.primary)
          .onClick(() => {
            this.submit();
          });

        Button(this.isRegister ? '已有账号，去登录' : '创建新账号')
          .type(ButtonType.Normal)
          .fontColor(AppColor.accentStrong)
          .backgroundColor(AppColor.accentSoft)
          .width('100%')
          .height(44)
          .borderRadius(Radius.md)
          .onClick(() => {
            this.switchMode();
          });
      }
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .padding(Space.xl)
    .backgroundColor(AppColor.bg);
  }
}
