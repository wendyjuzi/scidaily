import { router } from '@kit.ArkUI';
import { authService } from '../services/AuthService';

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
    Column({ space: 18 }) {
      Row() {
        Button('返回')
          .type(ButtonType.Capsule)
          .onClick(() => {
            router.back();
          });
        Blank();
      }
      .width('100%');

      Column({ space: 8 }) {
        Text(this.isRegister ? '创建账号' : '欢迎回来')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .width('100%');
        Text(this.isRegister ? '只需设置用户名和密码，昵称和邮箱可在个人资料中补充。' : '可使用 demo / 123456 快速体验。')
          .fontSize(14)
          .fontColor('#667085')
          .width('100%');
        Row({ space: 8 }) {
          Text('●')
            .fontSize(12)
            .fontColor(this.backendChecked ? (this.backendConnected ? '#12B76A' : '#F79009') : '#667085');
          Text(this.backendChecked ? (this.backendConnected ? '后端已连接，账号将保存到数据库。' : '后端未连接，当前为本地演示模式。') : '正在检测后端连接...')
            .fontSize(12)
            .fontColor('#667085')
            .layoutWeight(1);
          Button('刷新')
            .type(ButtonType.Normal)
            .fontSize(12)
            .fontColor('#1E88E5')
            .backgroundColor('#EAF4FF')
            .height(28)
            .borderRadius(8)
            .onClick(() => {
              this.refreshBackendStatus();
            });
        }
        .width('100%')
        .padding({ top: 6, right: 10, bottom: 6, left: 10 })
        .backgroundColor('#FFFFFF')
        .borderRadius(10);
      }
      .width('100%');

      Column({ space: 12 }) {
        TextInput({ placeholder: this.isRegister ? '用户名（必填）' : '用户名', text: this.username })
          .height(48)
          .fontSize(15)
          .backgroundColor('#FFFFFF')
          .borderRadius(10)
          .onChange((value: string) => {
            this.username = value;
          });

        TextInput({ placeholder: this.isRegister ? '密码（至少 6 位）' : '密码', text: this.password })
          .height(48)
          .fontSize(15)
          .type(InputType.Password)
          .backgroundColor('#FFFFFF')
          .borderRadius(10)
          .onChange((value: string) => {
            this.password = value;
          });

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor('#D92D20')
            .width('100%');
        }

        Button(this.isRegister ? '注册并登录' : '登录')
          .height(48)
          .width('100%')
          .borderRadius(10)
          .backgroundColor('#1E88E5')
          .onClick(() => {
            this.submit();
          });

        Button(this.isRegister ? '已有账号，去登录' : '创建新账号')
          .type(ButtonType.Normal)
          .fontColor('#1E88E5')
          .backgroundColor('#EEF6FF')
          .width('100%')
          .height(44)
          .borderRadius(10)
          .onClick(() => {
            this.switchMode();
          });
      }
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#F5F7FB');
  }
}
