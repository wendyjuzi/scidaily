import { router } from '@kit.ArkUI';
import { DailyPostDraft, TopicCategory, TopicTag } from '../models/DailyPost';
import { dailyPostService } from '../services/DailyPostService';

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
      .borderRadius(16);
  }

  @Builder
  private addImageSlot(): void {
    Column() {
      Text('+')
        .fontSize(32)
        .fontColor('#8A8F98');
      Text('添加图片')
        .fontSize(12)
        .fontColor('#8A8F98');
    }
    .width(96)
    .height(96)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F8FAFC')
    .border({ width: 1, color: '#E5E7EB' })
    .borderRadius(16);
  }

  @Builder
  private optionRow(icon: string, title: string, value: string): void {
    Row({ space: 12 }) {
      Text(icon)
        .fontSize(20)
        .fontColor('#007AFF')
        .width(28);
      Text(title)
        .fontSize(17)
        .fontColor('#2F3337');
      Blank();
      Text(value)
        .fontSize(15)
        .fontColor('#A0A4AA');
      Text('>')
        .fontSize(20)
        .fontColor('#C7CBD1');
    }
    .width('100%')
    .height(56)
    .border({ width: 1, color: '#F0F1F3' })
    .borderRadius(14)
    .padding({ left: 12, right: 12 });
  }

  build() {
    Column() {
      Row() {
        Button('<')
          .width(42)
          .height(42)
          .fontSize(28)
          .fontColor('#8A8F98')
          .backgroundColor('#00000000')
          .onClick(() => {
            router.back();
          });
        Blank();
        Text('发布科研日报')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827');
        Blank();
        Text('预览')
          .fontSize(15)
          .fontColor('#007AFF');
      }
      .width('100%')
      .height(58)
      .padding({ left: 12, right: 20 });

      Scroll() {
        Column({ space: 22 }) {
          Row({ space: 14 }) {
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
            .fontColor('#1F2328')
            .placeholderColor('#B8BDC7')
            .backgroundColor('#FFFFFF')
            .onChange((value: string) => {
              this.title = value;
            });

          TextArea({ placeholder: '添加正文或发语音', text: this.content })
            .height(170)
            .fontSize(22)
            .fontColor('#374151')
            .placeholderColor('#B8BDC7')
            .lineHeight(32)
            .backgroundColor('#FFFFFF')
            .onChange((value: string) => {
              this.content = value;
            });

          Row({ space: 10 }) {
            TextInput({ placeholder: '粘贴图片 URL 后点击添加', text: this.imageUrl })
              .height(44)
              .fontSize(14)
              .backgroundColor('#F9FAFB')
              .border({ width: 1, color: '#E5E7EB' })
              .borderRadius(16)
              .layoutWeight(1)
              .onChange((value: string) => {
                this.imageUrl = value;
              });
            Button('+')
              .width(44)
              .height(44)
              .fontSize(24)
              .fontColor('#FFFFFF')
              .backgroundColor('#007AFF')
              .borderRadius(22)
              .onClick(() => {
                this.addImage();
              });
          }
          .width('100%');

          Text('选择话题')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .width('100%');

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.tags.filter((tag: TopicTag) => tag.categoryId === this.categoryId).slice(0, 8), (tag: TopicTag) => {
              Text(`# ${tag.name}`)
                .fontSize(14)
                .fontColor(this.tagIds.includes(tag.id) ? '#007AFF' : '#8A8F98')
                .backgroundColor(this.tagIds.includes(tag.id) ? '#EAF4FF' : '#F3F4F6')
                .borderRadius(18)
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .margin({ right: 8, bottom: 8 })
                .onClick(() => {
                  this.toggleTag(tag.id);
                });
            }, (tag: TopicTag) => tag.id);
          }
          .width('100%');

          Text('选择分类')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .width('100%');

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.categories, (category: TopicCategory) => {
              Text(category.name)
                .fontSize(15)
                .fontColor(this.categoryId === category.id ? '#FFFFFF' : '#374151')
                .backgroundColor(this.categoryId === category.id ? '#007AFF' : '#F3F4F6')
                .borderRadius(19)
                .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                .margin({ right: 8, bottom: 8 })
                .onClick(() => {
                  this.categoryId = category.id;
                  this.tagIds = [];
                });
            }, (category: TopicCategory) => category.id);
          }
          .width('100%');

          Column({ space: 10 }) {
            this.optionRow('◎', '标记方向', this.selectedCategoryName());
            this.optionRow('◌', '公开可见', this.visibleScope);
            this.optionRow('□', '添加组件', '可添加文献 PDF');
            this.optionRow('⚙', '高级选项', '');
          }
          .width('100%');

          Text('笔记内容声明 >')
            .fontSize(15)
            .fontColor('#6B7280')
            .width('100%');

          if (this.statusText.length > 0) {
            Text(this.statusText)
              .fontSize(13)
              .fontColor('#007AFF')
              .width('100%')
              .textAlign(TextAlign.Center);
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 120 });
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off);

      Row({ space: 14 }) {
        Button('存草稿')
          .height(56)
          .layoutWeight(1)
          .fontSize(20)
          .fontColor('#2F3337')
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#E5E7EB' })
          .borderRadius(28)
          .onClick(() => {
            this.saveDraft();
          });
        Button('发布笔记')
          .height(56)
          .layoutWeight(2)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor('#007AFF')
          .borderRadius(28)
          .onClick(() => {
            this.publish();
          });
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 22, top: 12 })
      .backgroundColor('#FFFFFF');
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF');
  }
}
