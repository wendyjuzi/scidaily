import { router } from '@kit.ArkUI';
import { PersonalItem } from '../models/User';
import { authService } from '../services/AuthService';
import { personalCenterService } from '../services/PersonalCenterService';

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
    Column({ space: 8 }) {
      Row() {
        Text(item.status)
          .fontSize(12)
          .fontColor('#1E88E5')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#EEF6FF')
          .borderRadius(8);
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
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');

      Text(item.summary)
        .fontSize(14)
        .fontColor('#667085')
        .lineHeight(20)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12);
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
        if (this.listType === 'history' && this.items.length > 0) {
          Button('清空')
            .type(ButtonType.Capsule)
            .backgroundColor('#F04438')
            .onClick(() => {
              this.clearHistory();
            });
        }
      }
      .width('100%');

      Text(this.listTitle)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .width('100%');

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(13)
          .fontColor('#D92D20')
          .width('100%');
      }

      if (this.items.length === 0) {
        Column({ space: 8 }) {
          Text('暂无内容')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#475467');
          Text('与当前账号相关的内容会显示在这里。')
            .fontSize(14)
            .fontColor('#8A94A6')
            .textAlign(TextAlign.Center);
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else {
        List({ space: 10 }) {
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
    .padding(16)
    .backgroundColor('#F5F7FB');
  }
}
