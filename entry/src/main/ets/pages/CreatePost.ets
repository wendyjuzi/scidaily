import { router } from '@kit.ArkUI';
import { DailyPostDraft, TopicCategory, TopicTag } from '../models/DailyPost';
import { dailyPostService } from '../services/DailyPostService';
import { AppColor, Space, Radius, Font } from '../theme/AppTheme';

@Entry
@Component
struct CreatePost {
  @State title: string = '';
  @State content: string = '';
  @State coverUrl: string = 'https://images.unsplash.com/photo-1677442136019-21780ecad995?auto=format&fit=crop&w=900&q=80';
  @State imageUrl: string = '';
  @State imageUrls: string[] = [];
  @State categories: TopicCategory[] = [];
  @State tags: TopicTag[] = [];
  @State categoryId: string = 'ai';
  @State tagIds: string[] = [];
  @State visibleScope: string = '公开可见';
  @State statusText: string = '';

  aboutToAppear(): void {
    dailyPostService.listCategories().then((items: TopicCategory[]) => {
      this.categories = items.filter((item: TopicCategory) => item.id !== 'all');
      if (this.categories.length > 0) {
        this.categoryId = this.categories[0].id;
      }
    });
    dailyPostService.listTags().then((items: TopicTag[]) => {
      this.tags = items;
    });
  }

  private selectedCategoryName(): string {
    const item = this.categories.find((category: TopicCategory) => category.id === this.categoryId);
    return item !== undefined ? item.name : '人工智能';
  }

  private toggleTag(tagId: string): void {
    if (this.tagIds.includes(tagId)) {
      this.tagIds = this.tagIds.filter((id: string) => id !== tagId);
      return;
    }
    this.tagIds = this.tagIds.concat([tagId]);
  }

  private addImage(): void {
    const url = this.imageUrl.trim();
    if (url.length === 0) {
      return;
    }
    if (this.imageUrls.length === 0) {
      this.coverUrl = url;
    }
    this.imageUrls = this.imageUrls.concat([url]);
    this.imageUrl = '';
  }

  private draftPayload(): DailyPostDraft {
    const summary = this.content.length > 42 ? `${this.content.substring(0, 42)}...` : this.content;
    return {
      title: this.title,
      summary: summary.length > 0 ? summary : '一条新的科研日报',
      content: this.content,
      coverUrl: this.coverUrl,
      imageUrls: this.imageUrls,
      categoryId: this.categoryId,
      tagIds: this.tagIds,
      status: 'draft'
    };
  }

  private saveDraft(): void {
    dailyPostService.saveDraft(this.draftPayload()).then(() => {
      this.statusText = '草稿已保存';
    }).catch((error: Error) => {
      this.statusText = error.message;
    });
  }

  private publish(): void {
    if (this.title.trim().length === 0 || this.content.trim().length === 0) {
      this.statusText = '请先填写标题和正文';
      return;
    }
    dailyPostService.publish(this.draftPayload()).then(() => {
      this.statusText = '科研日报已发布';
      router.back();
    }).catch((error: Error) => {
      this.statusText = error.message;
    });
  }

  @Builder
  private imageSlot(url: string): void {
    Image(url)
      .width(96)
      .height(96)
      .objectFit(ImageFit.Cover)
      .borderRadius(Radius.lg);
  }

  @Builder
  private addImageSlot(): void {
    Column() {
      Text('+')
        .fontSize(32)
        .fontColor(AppColor.textMuted);
      Text('添加图片')
        .fontSize(Font.small)
        .fontColor(AppColor.textMuted);
    }
    .width(96)
    .height(96)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppColor.surfaceSoft)
    .border({ width: 1, color: AppColor.border })
    .borderRadius(Radius.lg);
  }

  @Builder
  private optionRow(icon: string, title: string, value: string): void {
    Row({ space: Space.md }) {
      Text(icon)
        .fontSize(Font.h2)
        .fontColor(AppColor.accent)
        .width(28);
      Text(title)
        .fontSize(Font.sub)
        .fontColor(AppColor.textBody);
      Blank();
      Text(value)
        .fontSize(Font.body)
        .fontColor(AppColor.textMuted);
      Text('>')
        .fontSize(Font.h2)
        .fontColor(AppColor.textMuted);
    }
    .width('100%')
    .height(56)
    .border({ width: 1, color: AppColor.border })
    .borderRadius(Radius.md)
    .padding({ left: Space.md, right: Space.md });
  }

  build() {
    Column() {
      Row() {
        Button('<')
          .width(42)
          .height(42)
          .fontSize(28)
          .fontColor(AppColor.textSecondary)
          .backgroundColor('#00000000')
          .onClick(() => {
            router.back();
          });
        Blank();
        Text('发布科研日报')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle);
        Blank();
        Text('预览')
          .fontSize(Font.body)
          .fontColor(AppColor.accent);
      }
      .width('100%')
      .height(58)
      .padding({ left: Space.md, right: Space.xl });

      Scroll() {
        Column({ space: Space.xxl }) {
          Row({ space: Space.lg }) {
            if (this.imageUrls.length > 0) {
              ForEach(this.imageUrls.slice(0, 2), (url: string) => {
                this.imageSlot(url);
              }, (url: string) => url);
            } else {
              this.imageSlot(this.coverUrl);
            }
            this.addImageSlot();
          }
          .width('100%');

          TextInput({ placeholder: '添加标题', text: this.title })
            .height(58)
            .fontSize(28)
            .fontColor(AppColor.textTitle)
            .placeholderColor(AppColor.textMuted)
            .backgroundColor(AppColor.surface)
            .onChange((value: string) => {
              this.title = value;
            });

          TextArea({ placeholder: '添加正文或发语音', text: this.content })
            .height(170)
            .fontSize(Font.h2)
            .fontColor(AppColor.textBody)
            .placeholderColor(AppColor.textMuted)
            .lineHeight(32)
            .backgroundColor(AppColor.surface)
            .onChange((value: string) => {
              this.content = value;
            });

          Row({ space: Space.md }) {
            TextInput({ placeholder: '粘贴图片 URL 后点击添加', text: this.imageUrl })
              .height(44)
              .fontSize(Font.body)
              .backgroundColor(AppColor.surfaceSoft)
              .border({ width: 1, color: AppColor.border })
              .borderRadius(Radius.lg)
              .layoutWeight(1)
              .onChange((value: string) => {
                this.imageUrl = value;
              });
            Button('+')
              .width(44)
              .height(44)
              .fontSize(Font.h2)
              .fontColor(AppColor.textOnPrimary)
              .backgroundColor(AppColor.primary)
              .borderRadius(Radius.pill)
              .onClick(() => {
                this.addImage();
              });
          }
          .width('100%');

          Text('选择话题')
            .fontSize(Font.sub)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textTitle)
            .width('100%');

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.tags.filter((tag: TopicTag) => tag.categoryId === this.categoryId).slice(0, 8), (tag: TopicTag) => {
              Text(`# ${tag.name}`)
                .fontSize(Font.body)
                .fontColor(this.tagIds.includes(tag.id) ? AppColor.accentStrong : AppColor.textSecondary)
                .backgroundColor(this.tagIds.includes(tag.id) ? AppColor.accentSoft : AppColor.surfaceSoft)
                .borderRadius(Radius.lg)
                .padding({ left: Space.lg, right: Space.lg, top: Space.sm, bottom: Space.sm })
                .margin({ right: Space.sm, bottom: Space.sm })
                .onClick(() => {
                  this.toggleTag(tag.id);
                });
            }, (tag: TopicTag) => tag.id);
          }
          .width('100%');

          Text('选择分类')
            .fontSize(Font.sub)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textTitle)
            .width('100%');

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.categories, (category: TopicCategory) => {
              Text(category.name)
                .fontSize(Font.body)
                .fontColor(this.categoryId === category.id ? AppColor.textOnPrimary : AppColor.textBody)
                .backgroundColor(this.categoryId === category.id ? AppColor.primary : AppColor.surfaceSoft)
                .borderRadius(Radius.lg)
                .padding({ left: Space.lg, right: Space.lg, top: 9, bottom: 9 })
                .margin({ right: Space.sm, bottom: Space.sm })
                .onClick(() => {
                  this.categoryId = category.id;
                  this.tagIds = [];
                });
            }, (category: TopicCategory) => category.id);
          }
          .width('100%');

          Column({ space: Space.md }) {
            this.optionRow('◎', '标记方向', this.selectedCategoryName());
            this.optionRow('◌', '公开可见', this.visibleScope);
            this.optionRow('□', '添加组件', '可添加文献 PDF');
            this.optionRow('⚙', '高级选项', '');
          }
          .width('100%');

          Text('笔记内容声明 >')
            .fontSize(Font.body)
            .fontColor(AppColor.textSecondary)
            .width('100%');

          if (this.statusText.length > 0) {
            Text(this.statusText)
              .fontSize(Font.small)
              .fontColor(AppColor.accent)
              .width('100%')
              .textAlign(TextAlign.Center);
          }
        }
        .width('100%')
        .padding({ left: Space.xl, right: Space.xl, bottom: 120 });
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off);

      Row({ space: Space.lg }) {
        Button('存草稿')
          .height(56)
          .layoutWeight(1)
          .fontSize(Font.h2)
          .fontColor(AppColor.textBody)
          .backgroundColor(AppColor.surface)
          .border({ width: 1, color: AppColor.border })
          .borderRadius(28)
          .onClick(() => {
            this.saveDraft();
          });
        Button('发布笔记')
          .height(56)
          .layoutWeight(2)
          .fontSize(Font.h2)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textOnPrimary)
          .backgroundColor(AppColor.primary)
          .borderRadius(28)
          .onClick(() => {
            this.publish();
          });
      }
      .width('100%')
      .padding({ left: Space.xl, right: Space.xl, bottom: 22, top: Space.md })
      .backgroundColor(AppColor.surface);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.surface);
  }
}
