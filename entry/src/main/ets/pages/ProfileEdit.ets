import { router } from '@kit.ArkUI';
import { UserProfile } from '../models/User';
import { authService } from '../services/AuthService';
import { AppColor, Space, Radius, Font } from '../theme/AppTheme';

@Entry
@Component
struct ProfileEdit {
  @State nickname: string = '';
  @State avatarUrl: string = '';
  @State email: string = '';
  @State bio: string = '';
  @State institution: string = '';
  @State researchField: string = '';
  @State errorMessage: string = '';

  aboutToAppear(): void {
    const user = authService.getCurrentUser();
    if (!user) {
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
    this.fillForm(user);
  }

  private fillForm(user: UserProfile): void {
    this.nickname = user.nickname;
    this.avatarUrl = user.avatarUrl;
    this.email = user.email;
    this.bio = user.bio;
    this.institution = user.institution;
    this.researchField = user.researchField;
  }

  private async save(): Promise<void> {
    try {
      await authService.updateProfile({
        nickname: this.nickname,
        avatarUrl: this.avatarUrl,
        email: this.email,
        bio: this.bio,
        institution: this.institution,
        researchField: this.researchField
      });
      router.back();
    } catch (error) {
      if (error instanceof Error) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '保存失败，请稍后重试。';
      }
    }
  }

  @Builder
  private inputRow(label: string, value: string, placeholder: string, change: (value: string) => void): void {
    Column({ space: Space.sm }) {
      Text(label)
        .fontSize(Font.small)
        .fontColor(AppColor.textSecondary)
        .width('100%');
      TextInput({ placeholder, text: value })
        .height(46)
        .fontSize(Font.body)
        .backgroundColor(AppColor.surface)
        .border({ width: 1, color: AppColor.border })
        .borderRadius(Radius.md)
        .onChange(change);
    }
    .width('100%');
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
        Button('保存')
          .type(ButtonType.Capsule)
          .fontColor(AppColor.textOnPrimary)
          .backgroundColor(AppColor.primary)
          .onClick(() => {
            this.save();
          });
      }
      .width('100%');

      Text('编辑资料')
        .fontSize(Font.h1)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textTitle)
        .width('100%');

      Scroll() {
        Column({ space: Space.md }) {
          this.inputRow('昵称', this.nickname, '请输入昵称', (value: string) => {
            this.nickname = value;
          });
          this.inputRow('头像链接', this.avatarUrl, 'https://...', (value: string) => {
            this.avatarUrl = value;
          });
          this.inputRow('邮箱', this.email, 'name@example.com', (value: string) => {
            this.email = value;
          });
          this.inputRow('所属机构', this.institution, '实验室或学校', (value: string) => {
            this.institution = value;
          });
          this.inputRow('研究方向', this.researchField, '请输入研究方向', (value: string) => {
            this.researchField = value;
          });

          Column({ space: Space.sm }) {
            Text('个人简介')
              .fontSize(Font.small)
              .fontColor(AppColor.textSecondary)
              .width('100%');
            TextArea({ placeholder: '简单介绍一下你的科研方向', text: this.bio })
              .height(92)
              .fontSize(Font.body)
              .backgroundColor(AppColor.surface)
              .border({ width: 1, color: AppColor.border })
              .borderRadius(Radius.md)
              .onChange((value: string) => {
                this.bio = value;
              });
          }
          .width('100%');

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(Font.small)
              .fontColor(AppColor.danger)
              .width('100%');
          }
        }
        .width('100%')
        .padding({ bottom: Space.xxl });
      }
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.bg);
  }
}
