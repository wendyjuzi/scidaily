import { router } from '@kit.ArkUI';
import { PersonalItem } from '../models/User';
import { authService } from '../services/AuthService';
import { personalCenterService } from '../services/PersonalCenterService';
import { AppColor, Space, Radius, Font } from '../theme/AppTheme';

@Entry
@Component
struct PersonalList {
  @State listType: string = 'posts';
  @State listTitle: string = '个人列表';
  @State items: PersonalItem[] = [];
  @State errorMessage: string = '';

  aboutToAppear(): void {
    if (!authService.isLoggedIn()) {
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
    const params = (router.getParams() as Record<string, string> | undefined) ?? {};
    this.listType = params.type ?? 'posts';
    this.listTitle = personalCenterService.getTitle(this.listType);
    this.reload();
  }

  private reload(): void {
    personalCenterService.getItems(this.listType).then((items: PersonalItem[]) => {
      this.items = items;
      this.errorMessage = '';
    }).catch((error: Error) => {
      this.items = [];
      this.errorMessage = error.message;
    });
  }

  private clearHistory(): void {
    personalCenterService.clearHistory().then(() => {
      this.reload();
    }).catch((error: Error) => {
      this.errorMessage = error.message;
    });
  }

  @Builder
  private itemCard(item: PersonalItem): void {
    Column({ space: Space.sm }) {
      Row() {
        Text(item.status)
          .fontSize(Font.small)
          .fontColor(AppColor.accent)
          .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
          .backgroundColor(AppColor.accentSoft)
          .borderRadius(Radius.sm);
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
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');

      Text(item.summary)
        .fontSize(Font.body)
        .fontColor(AppColor.textSecondary)
        .lineHeight(20)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');
    }
    .width('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border });
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
        if (this.listType === 'history' && this.items.length > 0) {
          Button('清空')
            .type(ButtonType.Capsule)
            .fontColor(AppColor.danger)
            .backgroundColor(AppColor.dangerSoft)
            .onClick(() => {
              this.clearHistory();
            });
        }
      }
      .width('100%');

      Text(this.listTitle)
        .fontSize(Font.h1)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textTitle)
        .width('100%');

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(Font.small)
          .fontColor(AppColor.danger)
          .width('100%');
      }

      if (this.items.length === 0) {
        Column({ space: Space.sm }) {
          Text('暂无内容')
            .fontSize(Font.sub)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textBody);
          Text('与当前账号相关的内容会显示在这里。')
            .fontSize(Font.body)
            .fontColor(AppColor.textMuted)
            .textAlign(TextAlign.Center);
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else {
        List({ space: Space.md }) {
          ForEach(this.items, (item: PersonalItem) => {
            ListItem() {
              this.itemCard(item);
            }
          }, (item: PersonalItem) => item.id);
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
