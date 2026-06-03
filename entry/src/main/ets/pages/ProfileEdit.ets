import { router } from '@kit.ArkUI';
import { UserProfile } from '../models/User';
import { authService } from '../services/AuthService';

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
    Column({ space: 6 }) {
      Text(label)
        .fontSize(13)
        .fontColor('#667085')
        .width('100%');
      TextInput({ placeholder, text: value })
        .height(46)
        .fontSize(15)
        .backgroundColor('#FFFFFF')
        .borderRadius(10)
        .onChange(change);
    }
    .width('100%');
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
        Button('保存')
          .type(ButtonType.Capsule)
          .backgroundColor('#1E88E5')
          .onClick(() => {
            this.save();
          });
      }
      .width('100%');

      Text('编辑资料')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .width('100%');

      Scroll() {
        Column({ space: 12 }) {
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

          Column({ space: 6 }) {
            Text('个人简介')
              .fontSize(13)
              .fontColor('#667085')
              .width('100%');
            TextArea({ placeholder: '简单介绍一下你的科研方向', text: this.bio })
              .height(92)
              .fontSize(15)
              .backgroundColor('#FFFFFF')
              .borderRadius(10)
              .onChange((value: string) => {
                this.bio = value;
              });
          }
          .width('100%');

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(13)
              .fontColor('#D92D20')
              .width('100%');
          }
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
