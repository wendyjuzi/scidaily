import { router } from '@kit.ArkUI';
import { InspirationDraft, InspirationItem } from '../models/Inspiration';
import { authService } from '../services/AuthService';
import { inspirationService } from '../services/InspirationService';
import { AppColor, Space, Radius, Font, Elevation } from '../theme/AppTheme';

@Entry
@Component
struct InspirationBox {
  @State items: InspirationItem[] = [];
  @State content: string = '';
  @State source: string = '';
  @State scene: string = 'idea';
  @State loading: boolean = false;
  @State errorMessage: string = '';
  @State statusText: string = '';
  @State generatingId: string = '';

  aboutToAppear(): void {
    if (!authService.isLoggedIn()) {
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
    this.reload();
  }

  private reload(): void {
    this.loading = true;
    inspirationService.list().then((items: InspirationItem[]) => {
      this.items = items;
      this.errorMessage = '';
    }).catch((error: Error) => {
      this.errorMessage = error.message;
      this.items = [];
    }).finally(() => {
      this.loading = false;
    });
  }

  private resetInput(): void {
    this.content = '';
    this.source = '';
    this.scene = 'idea';
    this.statusText = '';
  }

  private saveItem(): void {
    const text = this.content.trim();
    if (text.length === 0) {
      this.statusText = '先写一条灵感';
      return;
    }
    this.loading = true;
    inspirationService.create(text, this.scene, this.source.trim()).then(() => {
      this.statusText = '灵感已保存';
      this.resetInput();
      this.reload();
    }).catch((error: Error) => {
      this.statusText = error.message;
    }).finally(() => {
      this.loading = false;
    });
  }

  private deleteItem(itemId: string): void {
    inspirationService.remove(itemId).then(() => {
      this.reload();
    }).catch((error: Error) => {
      this.statusText = error.message;
    });
  }

  private openDraft(item: InspirationItem): void {
    if (this.generatingId.length > 0) {
      return;
    }
    this.generatingId = item.id;
    this.statusText = '日报模板已生成';
    this.items = this.items.map((current: InspirationItem) => {
      if (current.id !== item.id) {
        return current;
      }
      return {
        id: current.id,
        content: current.content,
        scene: current.scene,
        source: current.source,
        status: 'used',
        createdAt: current.createdAt,
        updatedAt: current.updatedAt
      };
    });
    this.pushDraft(this.localDraftFromItem(item));
    this.generatingId = '';
  }

  private pushDraft(draft: InspirationDraft): void {
    router.pushUrl({
      url: 'pages/CreatePost',
      params: {
        title: draft.title,
        summary: draft.summary,
        content: draft.content,
        categoryId: draft.categoryId,
        tagIds: draft.tagIds.join(',')
      }
    });
  }

  private localDraftFromItem(item: InspirationItem): InspirationDraft {
    const firstLine = item.content.split('\n')[0].trim();
    const titleSeed = firstLine.length > 22 ? `${firstLine.substring(0, 22)}...` : firstLine;
    const summary = item.content.length > 68 ? `${item.content.substring(0, 68)}...` : item.content;
    return {
      title: `${this.sceneTitle(item.scene)}：${titleSeed}`,
      summary,
      content: `${item.source.length > 0 ? '来源：' + item.source + '\n\n' : ''}一、原始灵感\n${item.content}\n\n二、可以展开的问题\n- 这个想法想解决什么科研问题？\n- 目前已有证据、数据或现象是什么？\n- 还缺少哪些实验、文献或对照？\n\n三、今日推进\n- 已完成：\n- 新发现：\n- 遇到的问题：\n\n四、下一步计划\n- 优先验证：\n- 需要补充的数据/材料：\n- 可发布到社区讨论的问题：`,
      categoryId: this.categoryFromText(item.content),
      tagIds: this.tagIdsFromText(item.content)
    };
  }

  private sceneTitle(scene: string): string {
    if (scene === 'experiment') {
      return '实验想法';
    }
    if (scene === 'paper') {
      return '文献启发';
    }
    if (scene === 'meeting') {
      return '组会记录';
    }
    if (scene === 'question') {
      return '待验证问题';
    }
    return '科研灵感';
  }

  private categoryFromText(text: string): string {
    if (text.indexOf('单细胞') >= 0 || text.indexOf('免疫') >= 0 || text.indexOf('基因') >= 0 || text.indexOf('细胞') >= 0) {
      return 'bio';
    }
    if (text.indexOf('材料') >= 0 || text.indexOf('钙钛矿') >= 0 || text.indexOf('催化') >= 0 || text.indexOf('光伏') >= 0) {
      return 'materials';
    }
    if (text.indexOf('临床') >= 0 || text.indexOf('医学') >= 0 || text.indexOf('诊断') >= 0 || text.indexOf('患者') >= 0) {
      return 'medicine';
    }
    return 'ai';
  }

  private tagIdsFromText(text: string): string[] {
    const tags: string[] = [];
    if (text.indexOf('Agent') >= 0 || text.indexOf('智能体') >= 0 || text.indexOf('工具调用') >= 0) {
      tags.push('ai-agent');
    }
    if (text.indexOf('大模型') >= 0 || text.indexOf('论文') >= 0 || text.indexOf('RAG') >= 0 || text.indexOf('Transformer') >= 0) {
      tags.push('llm-paper');
    }
    if (text.indexOf('单细胞') >= 0 || text.indexOf('细胞') >= 0) {
      tags.push('single-cell');
    }
    if (text.indexOf('免疫') >= 0) {
      tags.push('immunology');
    }
    if (text.indexOf('钙钛矿') >= 0 || text.indexOf('材料') >= 0) {
      tags.push('perovskite');
    }
    return tags;
  }

  @Builder
  private sceneChip(value: string, title: string): void {
    Text(title)
      .fontSize(Font.small)
      .fontWeight(this.scene === value ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.scene === value ? AppColor.textOnPrimary : AppColor.textBody)
      .backgroundColor(this.scene === value ? AppColor.primary : AppColor.surface)
      .border({ width: 1, color: this.scene === value ? AppColor.primary : AppColor.border })
      .borderRadius(Radius.pill)
      .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm })
      .margin({ right: Space.sm, bottom: Space.sm })
      .onClick(() => {
        this.scene = value;
      });
  }

  @Builder
  private itemCard(item: InspirationItem): void {
    Column({ space: Space.sm }) {
      Row() {
        Text(this.sceneLabel(item.scene))
          .fontSize(Font.caption)
          .fontColor(AppColor.accentStrong)
          .backgroundColor(AppColor.accentSoft)
          .borderRadius(Radius.sm)
          .padding({ left: Space.sm, right: Space.sm, top: 2, bottom: 2 });
        Blank();
        Text(item.createdAt.substring(0, 10))
          .fontSize(Font.caption)
          .fontColor(AppColor.textMuted);
      }
      .width('100%');

      Text(item.content)
        .fontSize(Font.body)
        .fontColor(AppColor.textBody)
        .lineHeight(21)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');

      if (item.source.length > 0) {
        Text(`来源：${item.source}`)
          .fontSize(Font.small)
          .fontColor(AppColor.textSecondary)
          .width('100%');
      }

      Row({ space: Space.sm }) {
        Button(item.status === 'used' ? '已生成' : '生成日报模板')
          .height(34)
          .layoutWeight(1)
          .fontColor(AppColor.textOnPrimary)
          .backgroundColor(item.status === 'used' ? AppColor.textMuted : AppColor.primary)
          .borderRadius(Radius.lg)
          .enabled(item.status !== 'used' && this.generatingId.length === 0)
          .onClick(() => {
            this.openDraft(item);
          });
        Button('删除')
          .height(34)
          .fontColor(AppColor.danger)
          .backgroundColor(AppColor.dangerSoft)
          .borderRadius(Radius.lg)
          .onClick(() => {
            this.deleteItem(item.id);
          });
      }
      .width('100%');
    }
    .width('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border })
    .shadow(Elevation.card);
  }

  private sceneLabel(scene: string): string {
    if (scene === 'experiment') {
      return '实验';
    }
    if (scene === 'paper') {
      return '文献';
    }
    if (scene === 'meeting') {
      return '组会';
    }
    if (scene === 'question') {
      return '问题';
    }
    return '灵感';
  }

  build() {
    Column({ space: Space.lg }) {
      Row() {
        Button('返回')
          .height(34)
          .fontSize(Font.small)
          .fontColor(AppColor.textBody)
          .backgroundColor(AppColor.surface)
          .border({ width: 1, color: AppColor.border })
          .borderRadius(Radius.lg)
          .onClick(() => {
            router.back();
          });
        Blank();
        Button('刷新')
          .height(34)
          .fontSize(Font.small)
          .fontColor(AppColor.accent)
          .backgroundColor(AppColor.accentSoft)
          .borderRadius(Radius.lg)
          .onClick(() => {
            this.reload();
          });
      }
      .width('100%');

      Column({ space: Space.xs }) {
        Text('科研灵感箱')
          .fontSize(Font.h1)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle);
        Text('随手记下想法，之后一键整理成科研日报模板。')
          .fontSize(Font.small)
          .fontColor(AppColor.textSecondary);
      }
      .width('100%');

      Column({ space: Space.md }) {
        TextArea({ placeholder: '写下实验现象、论文启发、组会想法或待验证问题', text: this.content })
          .height(112)
          .fontSize(Font.body)
          .fontColor(AppColor.textBody)
          .placeholderColor(AppColor.textMuted)
          .lineHeight(22)
          .backgroundColor(AppColor.surface)
          .border({ width: 1, color: AppColor.border })
          .borderRadius(Radius.lg)
          .padding(Space.md)
          .onChange((value: string) => {
            this.content = value;
          });

        TextInput({ placeholder: '来源（选填，如：组会、文献、实验台）', text: this.source })
          .height(48)
          .fontSize(Font.body)
          .fontColor(AppColor.textBody)
          .placeholderColor(AppColor.textMuted)
          .backgroundColor(AppColor.surface)
          .border({ width: 1, color: AppColor.border })
          .borderRadius(Radius.lg)
          .padding({ left: Space.md, right: Space.md })
          .onChange((value: string) => {
            this.source = value;
          });

        Flex({ wrap: FlexWrap.Wrap }) {
          this.sceneChip('idea', '灵感');
          this.sceneChip('experiment', '实验');
          this.sceneChip('paper', '文献');
          this.sceneChip('meeting', '组会');
          this.sceneChip('question', '问题');
        }
        .width('100%');

        Row({ space: Space.sm }) {
          Button('清空')
            .height(42)
            .layoutWeight(1)
            .fontColor(AppColor.textBody)
            .backgroundColor(AppColor.surface)
            .border({ width: 1, color: AppColor.border })
            .borderRadius(Radius.lg)
            .onClick(() => {
              this.resetInput();
            });
          Button('保存灵感')
            .height(42)
            .layoutWeight(2)
            .fontColor(AppColor.textOnPrimary)
            .backgroundColor(AppColor.primary)
            .borderRadius(Radius.lg)
            .enabled(!this.loading)
            .onClick(() => {
              this.saveItem();
            });
        }
        .width('100%');
      }
      .width('100%')
      .padding(Space.lg)
      .backgroundColor(AppColor.surfaceSoft)
      .borderRadius(Radius.lg)
      .border({ width: 1, color: AppColor.border });

      if (this.statusText.length > 0) {
        Text(this.statusText)
          .fontSize(Font.small)
          .fontColor(AppColor.textSecondary)
          .width('100%');
      }

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(Font.small)
          .fontColor(AppColor.danger)
          .width('100%');
      }

      if (this.loading) {
        Text('正在加载灵感...')
          .fontSize(Font.body)
          .fontColor(AppColor.textMuted)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: Space.xl, bottom: Space.xl });
      } else if (this.items.length === 0) {
        Column({ space: Space.sm }) {
          Text('还没有灵感')
            .fontSize(Font.sub)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textBody);
          Text('先记一条，再一键生成日报模板。')
            .fontSize(Font.small)
            .fontColor(AppColor.textMuted);
        }
        .width('100%')
        .padding({ top: Space.xl, bottom: Space.xl })
        .alignItems(HorizontalAlign.Center);
      } else {
        List({ space: Space.md }) {
          ForEach(this.items, (item: InspirationItem) => {
            ListItem() {
              this.itemCard(item);
            }
          }, (item: InspirationItem) => item.id);
        }
        .edgeEffect(EdgeEffect.Spring)
        .layoutWeight(1)
        .width('100%');
      }
    }
    .width('100%')
    .height('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.bg);
  }
}
