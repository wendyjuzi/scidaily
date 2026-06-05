import { router } from '@kit.ArkUI';
import { DailyPost, TopicTag } from '../models/DailyPost';
import { PaperItem } from '../models/Paper';
import { dailyPostService } from '../services/DailyPostService';
import { paperService } from '../services/PaperService';
import { AppColor, Space, Radius, Font } from '../theme/AppTheme';

@Entry
@Component
struct SearchPage {
  @State keyword: string = '';
  @State allPosts: DailyPost[] = [];
  @State allPapers: PaperItem[] = [];
  @State allTags: TopicTag[] = [];
  @State loading: boolean = true;

  aboutToAppear(): void {
    dailyPostService.listPublished('all', '', 0, 50).then((page) => {
      this.allPosts = page.items;
    }).finally(() => {
      this.loading = false;
    });
    paperService.listPapers(0, 50).then((page) => {
      this.allPapers = page.items;
    });
    dailyPostService.listTags().then((items: TopicTag[]) => {
      this.allTags = items;
    });
  }

  private kw(): string {
    return this.keyword.trim().toLowerCase();
  }

  private hit(text: string): boolean {
    return text.toLowerCase().includes(this.kw());
  }

  private matchedTags(): TopicTag[] {
    const k = this.kw();
    if (k.length === 0) {
      return [];
    }
    return this.allTags.filter((t: TopicTag) => this.hit(t.name) || this.hit(t.categoryName));
  }

  private matchedPosts(): DailyPost[] {
    const k = this.kw();
    if (k.length === 0) {
      return [];
    }
    return this.allPosts.filter((p: DailyPost) =>
      this.hit(p.title) || this.hit(p.summary) || this.hit(p.authorName) ||
      this.hit(p.categoryName) || this.hit(p.tags.join(' ')));
  }

  private matchedPapers(): PaperItem[] {
    const k = this.kw();
    if (k.length === 0) {
      return [];
    }
    return this.allPapers.filter((p: PaperItem) =>
      this.hit(p.title) || this.hit(p.abstract) || this.hit(p.authors.join(' ')) ||
      this.hit(p.categoryName) || this.hit(p.tags.join(' ')));
  }

  private hotTags(): TopicTag[] {
    return this.allTags.slice()
      .sort((a: TopicTag, b: TopicTag) => b.postCount - a.postCount)
      .slice(0, 12);
  }

  private resultCount(): number {
    return this.matchedTags().length + this.matchedPosts().length + this.matchedPapers().length;
  }

  private initial(name: string): string {
    return name.length > 0 ? name.substring(0, 1).toUpperCase() : '研';
  }

  private avatarColor(seed: string): string {
    const palette: string[] = [AppColor.primary, AppColor.accent, AppColor.accentStrong, AppColor.series3, AppColor.primaryStrong];
    let sum = 0;
    for (let i = 0; i < seed.length; i++) {
      sum += seed.charCodeAt(i);
    }
    return palette[sum % palette.length];
  }

  private openTag(tag: TopicTag): void {
    router.pushUrl({
      url: 'pages/TopicDetail',
      params: { tagId: tag.id, tagName: tag.name, categoryName: tag.categoryName }
    });
  }

  private openPost(post: DailyPost): void {
    if (post.tagIds.length > 0) {
      router.pushUrl({
        url: 'pages/TopicDetail',
        params: {
          tagId: post.tagIds[0],
          tagName: post.tags.length > 0 ? post.tags[0] : '话题',
          categoryName: post.categoryName
        }
      });
    }
  }

  @Builder
  private sectionLabel(text: string, count: number): void {
    Row({ space: Space.sm }) {
      Text(text)
        .fontSize(Font.body)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textTitle);
      Text(count.toString())
        .fontSize(Font.caption)
        .fontColor(AppColor.accent)
        .backgroundColor(AppColor.accentSoft)
        .borderRadius(Radius.pill)
        .padding({ left: Space.sm, right: Space.sm, top: 1, bottom: 1 });
      Blank();
    }
    .width('100%');
  }

  @Builder
  private tagRow(tag: TopicTag): void {
    Row({ space: Space.md }) {
      Text('#')
        .fontSize(Font.title)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.accent)
        .width(34)
        .height(34)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppColor.accentSoft)
        .borderRadius(Radius.md);
      Column({ space: 2 }) {
        Text(tag.name)
          .fontSize(Font.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textTitle)
          .width('100%');
        Text(`${tag.categoryName} · ${tag.postCount} 篇`)
          .fontSize(Font.caption)
          .fontColor(AppColor.textMuted)
          .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text('›')
        .fontSize(Font.title)
        .fontColor(AppColor.textMuted);
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border })
    .onClick(() => {
      this.openTag(tag);
    });
  }

  @Builder
  private postRow(post: DailyPost): void {
    Row({ space: Space.md }) {
      Image(post.coverUrl)
        .width(64)
        .height(64)
        .objectFit(ImageFit.Cover)
        .borderRadius(Radius.md)
        .backgroundColor(AppColor.surfaceSoft);
      Column({ space: Space.xs }) {
        Text(post.title)
          .fontSize(Font.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textTitle)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Row({ space: Space.sm }) {
          Text(this.initial(post.authorName))
            .width(18)
            .height(18)
            .borderRadius(9)
            .backgroundColor(this.avatarColor(post.authorName))
            .fontColor(AppColor.textOnPrimary)
            .fontSize(10)
            .textAlign(TextAlign.Center);
          Text(post.authorName)
            .fontSize(Font.caption)
            .fontColor(AppColor.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1);
          Text(post.categoryName)
            .fontSize(Font.caption)
            .fontColor(AppColor.accent);
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border })
    .onClick(() => {
      this.openPost(post);
    });
  }

  @Builder
  private paperRow(paper: PaperItem): void {
    Row({ space: Space.md }) {
      Text('PDF')
        .fontSize(Font.caption)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textOnPrimary)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppColor.warning)
        .borderRadius(Radius.md);
      Column({ space: Space.xs }) {
        Text(paper.title)
          .fontSize(Font.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textTitle)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Text(paper.authors.join(', '))
          .fontSize(Font.caption)
          .fontColor(AppColor.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border })
    .onClick(() => {
      router.pushUrl({ url: 'pages/PDFReader', params: { paperId: paper.id } });
    });
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Button('返回')
          .type(ButtonType.Capsule)
          .fontSize(Font.body)
          .fontColor(AppColor.textBody)
          .backgroundColor(AppColor.surface)
          .border({ width: 1, color: AppColor.border })
          .onClick(() => {
            router.back();
          });
        Row({ space: Space.sm }) {
          Text('⌕')
            .fontSize(Font.title)
            .fontColor(AppColor.textMuted);
          TextInput({ placeholder: '搜索论文、话题、研究者', text: this.keyword })
            .fontSize(Font.body)
            .backgroundColor('#00000000')
            .layoutWeight(1)
            .onChange((value: string) => {
              this.keyword = value;
            });
          if (this.keyword.length > 0) {
            Text('✕')
              .fontSize(Font.body)
              .fontColor(AppColor.textMuted)
              .onClick(() => {
                this.keyword = '';
              });
          }
        }
        .layoutWeight(1)
        .height(42)
        .padding({ left: Space.md, right: Space.md })
        .backgroundColor(AppColor.surfaceSoft)
        .borderRadius(Radius.pill)
        .alignItems(VerticalAlign.Center);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Scroll() {
        Column({ space: Space.lg }) {
          if (this.kw().length === 0) {
            this.sectionLabel('热门话题', this.hotTags().length);
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.hotTags(), (tag: TopicTag) => {
                Text(`# ${tag.name}`)
                  .fontSize(Font.small)
                  .fontColor(AppColor.textBody)
                  .backgroundColor(AppColor.surface)
                  .border({ width: 1, color: AppColor.border })
                  .borderRadius(Radius.pill)
                  .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm })
                  .margin({ right: Space.sm, bottom: Space.sm })
                  .onClick(() => {
                    this.openTag(tag);
                  });
              }, (tag: TopicTag) => tag.id);
            }
            .width('100%');
          } else if (this.resultCount() === 0 && !this.loading) {
            Column({ space: Space.sm }) {
              Text('没有找到相关内容')
                .fontSize(Font.sub)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColor.textBody);
              Text(`试试别的关键词，或浏览热门话题。`)
                .fontSize(Font.small)
                .fontColor(AppColor.textMuted);
            }
            .width('100%')
            .height(220)
            .justifyContent(FlexAlign.Center);
          } else {
            if (this.matchedTags().length > 0) {
              this.sectionLabel('话题', this.matchedTags().length);
              ForEach(this.matchedTags(), (tag: TopicTag) => {
                this.tagRow(tag);
              }, (tag: TopicTag) => tag.id);
            }
            if (this.matchedPosts().length > 0) {
              this.sectionLabel('科研日报', this.matchedPosts().length);
              ForEach(this.matchedPosts(), (post: DailyPost) => {
                this.postRow(post);
              }, (post: DailyPost) => post.id);
            }
            if (this.matchedPapers().length > 0) {
              this.sectionLabel('文献 PDF', this.matchedPapers().length);
              ForEach(this.matchedPapers(), (paper: PaperItem) => {
                this.paperRow(paper);
              }, (paper: PaperItem) => paper.id);
            }
          }
        }
        .width('100%')
        .padding({ bottom: Space.xxl });
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.bg);
  }
}
