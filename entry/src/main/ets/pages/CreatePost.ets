import { router } from '@kit.ArkUI';
import buffer from '@ohos.buffer';
import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import { DailyPostDraft, TopicCategory, TopicTag } from '../models/DailyPost';
import { PaperItem, PaperPage } from '../models/Paper';
import { AiCreatorContext, AiCreatorResult, aiService } from '../services/AiService';
import { dailyPostService } from '../services/DailyPostService';
import { paperService } from '../services/PaperService';
import { AppColor, Space, Radius, Font } from '../theme/AppTheme';

interface PickedFilePayload {
  filename: string;
  contentBase64: string;
  size: number;
  uri: string;
}

@Entry
@Component
struct CreatePost {
  @State title: string = '';
  @State summary: string = '';
  @State content: string = '';
  @State coverUrl: string = 'https://images.unsplash.com/photo-1677442136019-21780ecad995?auto=format&fit=crop&w=900&q=80';
  @State imageUrls: string[] = [];
  @State uploadedPdfName: string = '';
  @State uploadedPdfUrl: string = '';
  @State mediaStatusText: string = '';
  @State imageUploading: boolean = false;
  @State pdfUploading: boolean = false;
  @State categories: TopicCategory[] = [];
  @State tags: TopicTag[] = [];
  @State categoryId: string = 'ai';
  @State tagIds: string[] = [];
  @State visibleScope: string = '公开可见';
  @State statusText: string = '';
  @State aiMode: string = 'draft';
  @State aiPrompt: string = '';
  @State aiStatusText: string = '';
  @State aiGenerating: boolean = false;
  @State aiResult: AiCreatorResult | undefined = undefined;
  @State papers: PaperItem[] = [];
  @State selectedPaperId: string = '';

  aboutToAppear(): void {
    this.applyRouteDraft();
    dailyPostService.listCategories().then((items: TopicCategory[]) => {
      this.categories = items.filter((item: TopicCategory) => item.id !== 'all');
      if (this.categories.length > 0 && this.categoryId.length === 0) {
        this.categoryId = this.categories[0].id;
      }
    });
    dailyPostService.listTags().then((items: TopicTag[]) => {
      this.tags = items;
    });
    paperService.listPapers(0, 8).then((page: PaperPage) => {
      this.papers = page.items;
    }).catch(() => {
      this.papers = [];
    });
  }

  private applyRouteDraft(): void {
    const params = (router.getParams() as Record<string, string> | undefined) ?? {};
    const title = params.title ?? '';
    const summary = params.summary ?? '';
    const content = params.content ?? '';
    const categoryId = params.categoryId ?? '';
    const tagIds = params.tagIds ?? '';
    if (title.length > 0) {
      this.title = title;
    }
    if (summary.length > 0) {
      this.summary = summary;
    }
    if (content.length > 0) {
      this.content = content;
    }
    if (categoryId.length > 0) {
      this.categoryId = categoryId;
    }
    if (tagIds.length > 0) {
      this.tagIds = tagIds.split(',').filter((id: string) => id.length > 0);
    }
  }

  private selectedCategoryName(): string {
    const item = this.categories.find((category: TopicCategory) => category.id === this.categoryId);
    return item !== undefined ? item.name : '人工智能';
  }

  private selectedTagNames(): string[] {
    return this.tags
      .filter((tag: TopicTag) => this.tagIds.includes(tag.id))
      .map((tag: TopicTag) => tag.name);
  }

  private selectedPaper(): PaperItem | undefined {
    return this.papers.find((paper: PaperItem) => paper.id === this.selectedPaperId);
  }

  private toggleTag(tagId: string): void {
    if (this.tagIds.includes(tagId)) {
      this.tagIds = this.tagIds.filter((id: string) => id !== tagId);
      return;
    }
    this.tagIds = this.tagIds.concat([tagId]);
  }

  private pickImages(): void {
    if (this.imageUploading) {
      return;
    }
    if (this.imageUrls.length >= 9) {
      this.mediaStatusText = '最多添加 9 张图片';
      return;
    }
    const options = new picker.PhotoSelectOptions();
    options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = Math.max(1, 9 - this.imageUrls.length);
    const photoPicker = new picker.PhotoViewPicker();
    this.imageUploading = true;
    this.mediaStatusText = '正在选择图片...';
    photoPicker.select(options)
      .then((result: picker.PhotoSelectResult) => this.uploadSelectedImages(result.photoUris))
      .catch(() => {
        this.mediaStatusText = '未选择图片';
      })
      .finally(() => {
        this.imageUploading = false;
      });
  }

  private async uploadSelectedImages(uris: string[]): Promise<void> {
    if (uris.length === 0) {
      this.mediaStatusText = '未选择图片';
      return;
    }
    const uploaded: string[] = [];
    for (let index = 0; index < uris.length; index += 1) {
      const picked = await this.readPickedFile(uris[index], `image-${Date.now()}-${index}.jpg`, 12 * 1024 * 1024);
      const url = await dailyPostService.uploadImage(picked.filename, picked.contentBase64);
      uploaded.push(url);
    }
    if (this.imageUrls.length === 0 && uploaded.length > 0) {
      this.coverUrl = uploaded[0];
    }
    this.imageUrls = this.imageUrls.concat(uploaded);
    this.mediaStatusText = `已添加 ${uploaded.length} 张图片`;
  }

  private pickPdf(): void {
    if (this.pdfUploading) {
      return;
    }
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['PDF|.pdf'];
    options.maxSelectNumber = 1;
    const documentPicker = new picker.DocumentViewPicker();
    this.pdfUploading = true;
    this.mediaStatusText = '正在选择 PDF...';
    documentPicker.select(options)
      .then((uris: string[]) => this.uploadSelectedPdf(uris))
      .catch(() => {
        this.mediaStatusText = '未选择 PDF';
      })
      .finally(() => {
        this.pdfUploading = false;
      });
  }

  private async uploadSelectedPdf(uris: string[]): Promise<void> {
    if (uris.length === 0) {
      this.mediaStatusText = '未选择 PDF';
      return;
    }
    const picked = await this.readPickedFile(uris[0], `paper-${Date.now()}.pdf`, 30 * 1024 * 1024);
    const url = await dailyPostService.uploadPdf(picked.filename, picked.contentBase64);
    this.uploadedPdfName = picked.filename;
    this.uploadedPdfUrl = url;
    this.selectedPaperId = '';
    this.aiMode = 'pdf_daily';
    this.aiPrompt = `请基于我上传的 PDF《${picked.filename}》生成一篇阅读日报。`;
    this.mediaStatusText = 'PDF 已上传';
    this.aiStatusText = 'PDF 已加入 AI 上下文，点击生成即可';
  }

  private async readPickedFile(uri: string, fallbackName: string, maxBytes: number): Promise<PickedFilePayload> {
    let file: fs.File | undefined = undefined;
    try {
      file = await fs.open(uri, fs.OpenMode.READ_ONLY);
      const stat = await fs.stat(file.fd);
      if (stat.size <= 0) {
        throw new Error('文件内容为空');
      }
      if (stat.size > maxBytes) {
        throw new Error(`文件不能超过 ${Math.round(maxBytes / 1024 / 1024)}MB`);
      }
      const fileBuffer = new ArrayBuffer(stat.size);
      const readBytes = await fs.read(file.fd, fileBuffer, { offset: 0, length: stat.size });
      const contentBase64 = buffer.from(fileBuffer, 0, readBytes).toString('base64');
      return {
        filename: this.pickedFilename(file.name, uri, fallbackName),
        contentBase64,
        size: readBytes,
        uri
      };
    } finally {
      if (file !== undefined) {
        await fs.close(file);
      }
    }
  }

  private pickedFilename(name: string, uri: string, fallbackName: string): string {
    const cleanName = name.trim();
    if (cleanName.length > 0) {
      return cleanName;
    }
    const parts = uri.split('/');
    const tail = parts.length > 0 ? parts[parts.length - 1].trim() : '';
    if (tail.length > 0 && tail.indexOf('.') >= 0) {
      return tail;
    }
    return fallbackName;
  }

  private draftPayload(): DailyPostDraft {
    const fallbackSummary = this.content.length > 42 ? `${this.content.substring(0, 42)}...` : this.content;
    const draftSummary = this.summary.trim().length > 0 ? this.summary.trim() : fallbackSummary;
    return {
      title: this.title,
      summary: draftSummary.length > 0 ? draftSummary : '一条新的科研日报',
      content: this.content,
      coverUrl: this.coverUrl,
      imageUrls: this.imageUrls,
      categoryId: this.categoryId,
      tagIds: this.tagIds,
      status: 'draft'
    };
  }

  private aiModeName(mode: string): string {
    if (mode === 'organize') {
      return '整理记录';
    }
    if (mode === 'meta') {
      return '标题摘要';
    }
    if (mode === 'polish_academic') {
      return '学术润色';
    }
    if (mode === 'polish_brief') {
      return '简洁润色';
    }
    if (mode === 'polish_share') {
      return '分享润色';
    }
    if (mode === 'experiment_template') {
      return '实验模板';
    }
    if (mode === 'literature_template') {
      return '文献模板';
    }
    if (mode === 'review_template') {
      return '复盘模板';
    }
    if (mode === 'preflight') {
      return '发布检查';
    }
    if (mode === 'pdf_daily') {
      return 'PDF 日报';
    }
    return '生成草稿';
  }

  private aiPlaceholder(): string {
    if (this.aiMode === 'organize') {
      return '粘贴实验日志、会议记录或阅读笔记';
    }
    if (this.aiMode === 'meta') {
      return '可留空，AI 会根据当前正文生成标题、摘要和标签';
    }
    if (this.aiMode === 'polish_academic' || this.aiMode === 'polish_brief' || this.aiMode === 'polish_share') {
      return '可留空，AI 会润色当前正文';
    }
    if (this.aiMode === 'preflight') {
      return '可留空，AI 会检查当前草稿缺少什么';
    }
    if (this.aiMode === 'pdf_daily') {
      return '上传 PDF 或选择下方文献，也可以补充阅读重点';
    }
    return '输入研究想法、实验目标或论文标题';
  }

  private aiCreatorContext(): AiCreatorContext {
    const paper = this.selectedPaper();
    return {
      title: this.title,
      summary: this.summary,
      content: this.content,
      categoryName: this.selectedCategoryName(),
      tags: this.selectedTagNames(),
      paperTitle: paper !== undefined ? paper.title : this.uploadedPdfName,
      paperAbstract: paper !== undefined ? paper.abstract : '',
      paperDoi: paper !== undefined && paper.doi !== undefined ? paper.doi : '',
      paperSourceUrl: paper !== undefined ? paper.sourceUrl : '',
      paperPdfUrl: paper !== undefined ? paper.pdfUrl : this.uploadedPdfUrl
    };
  }

  private generateAiDraft(): void {
    if (this.aiGenerating) {
      return;
    }
    const hasDraftContext = this.title.trim().length > 0 || this.summary.trim().length > 0 || this.content.trim().length > 0;
    const hasPrompt = this.aiPrompt.trim().length > 0;
    const hasPaper = this.selectedPaper() !== undefined;
    if (!hasDraftContext && !hasPrompt && !hasPaper) {
      this.aiStatusText = '先输入一点想法、草稿或选择一篇 PDF';
      return;
    }
    this.aiGenerating = true;
    this.aiStatusText = 'AI 正在整理...';
    this.aiResult = undefined;
    aiService.createDailyDraft(this.aiMode, this.aiPrompt, this.aiCreatorContext())
      .then((result: AiCreatorResult) => {
        this.aiResult = result;
        this.aiStatusText = result.source;
      })
      .catch((error: Error) => {
        this.aiStatusText = error.message.length > 0 ? error.message : 'AI 生成失败，请检查后端和 Key';
      })
      .finally(() => {
        this.aiGenerating = false;
      });
  }

  private applyAiResult(): void {
    if (this.aiResult === undefined) {
      return;
    }
    if (this.aiResult.title.length > 0) {
      this.title = this.aiResult.title;
    }
    if (this.aiResult.summary.length > 0) {
      this.summary = this.aiResult.summary;
    }
    if (this.aiResult.content.length > 0) {
      this.content = this.aiResult.content;
    }
    this.applyAiTopicAndTags();
    this.aiStatusText = 'AI 内容已应用到草稿';
  }

  private appendAiContent(): void {
    if (this.aiResult === undefined || this.aiResult.content.length === 0) {
      return;
    }
    this.content = this.content.trim().length > 0 ? `${this.content.trim()}\n\n${this.aiResult.content}` : this.aiResult.content;
    this.aiStatusText = 'AI 内容已追加到正文';
  }

  private clearAiResult(): void {
    this.aiResult = undefined;
    this.aiStatusText = '';
  }

  private applyAiTopicAndTags(): void {
    if (this.aiResult === undefined) {
      return;
    }
    const topicText = this.aiResult.topic.trim();
    if (topicText.length > 0) {
      const category = this.categories.find((item: TopicCategory) => topicText.indexOf(item.name) >= 0 || item.name.indexOf(topicText) >= 0);
      if (category !== undefined) {
        this.categoryId = category.id;
      }
    }
    const matchedIds: string[] = [];
    this.aiResult.tags.forEach((name: string) => {
      const cleanName = name.replace('#', '').trim().toLowerCase();
      const tag = this.tags.find((item: TopicTag) => item.name.toLowerCase() === cleanName);
      if (tag !== undefined) {
        matchedIds.push(tag.id);
      }
    });
    if (matchedIds.length > 0) {
      const merged = this.tagIds.concat(matchedIds);
      this.tagIds = merged.filter((id: string, index: number) => merged.indexOf(id) === index);
    }
  }

  private selectAiPaper(paper: PaperItem): void {
    this.selectedPaperId = paper.id;
    this.uploadedPdfName = '';
    this.uploadedPdfUrl = '';
    if (this.aiMode !== 'pdf_daily') {
      return;
    }
    this.aiPrompt = `请基于文献《${paper.title}》生成一篇阅读日报。PDF：${paper.pdfUrl}`;
  }

  private openUploadedPdf(): void {
    if (this.uploadedPdfUrl.length === 0) {
      this.mediaStatusText = '请先上传 PDF';
      return;
    }
    router.pushUrl({
      url: 'pages/PDFReader',
      params: {
        pdfUrl: this.uploadedPdfUrl,
        pdfTitle: this.uploadedPdfName.length > 0 ? this.uploadedPdfName : '上传 PDF'
      }
    });
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
    .borderRadius(Radius.lg)
    .onClick(() => {
      this.pickImages();
    });
  }

  @Builder
  private attachmentPanel(): void {
    Column({ space: Space.sm }) {
      Button(this.pdfUploading ? 'PDF 上传中...' : '上传 PDF')
        .height(42)
        .width('100%')
        .fontSize(Font.body)
        .fontColor(AppColor.textOnPrimary)
        .backgroundColor(this.pdfUploading ? AppColor.textMuted : AppColor.primary)
        .borderRadius(Radius.lg)
        .enabled(!this.pdfUploading)
        .onClick(() => {
          this.pickPdf();
        });

      if (this.uploadedPdfName.length > 0) {
        Row({ space: Space.sm }) {
          Text('PDF')
            .fontSize(Font.caption)
            .fontColor(AppColor.textOnPrimary)
            .backgroundColor(AppColor.accent)
            .borderRadius(Radius.sm)
            .padding({ left: Space.sm, right: Space.sm, top: 3, bottom: 3 });
          Text(this.uploadedPdfName)
            .fontSize(Font.small)
            .fontColor(AppColor.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1);
          Button('移除')
            .height(30)
            .fontSize(Font.small)
            .fontColor(AppColor.textSecondary)
            .backgroundColor(AppColor.surface)
            .border({ width: 1, color: AppColor.border })
            .borderRadius(Radius.md)
            .onClick(() => {
              this.uploadedPdfName = '';
              this.uploadedPdfUrl = '';
              this.mediaStatusText = 'PDF 已移除';
            });
          Button('阅读')
            .height(30)
            .fontSize(Font.small)
            .fontColor(AppColor.accentStrong)
            .backgroundColor(AppColor.accentSoft)
            .borderRadius(Radius.md)
            .onClick(() => {
              this.openUploadedPdf();
            });
        }
        .width('100%');
      }

      if (this.mediaStatusText.length > 0) {
        Text(this.mediaStatusText)
          .fontSize(Font.small)
          .fontColor(AppColor.textSecondary)
          .width('100%');
      }
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surfaceSoft)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border });
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

  @Builder
  private aiModeChip(mode: string, title: string): void {
    Text(title)
      .fontSize(Font.small)
      .fontWeight(this.aiMode === mode ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.aiMode === mode ? AppColor.textOnPrimary : AppColor.textBody)
      .backgroundColor(this.aiMode === mode ? AppColor.primary : AppColor.surface)
      .border({ width: 1, color: this.aiMode === mode ? AppColor.primary : AppColor.border })
      .borderRadius(Radius.pill)
      .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm })
      .margin({ right: Space.sm, bottom: Space.sm })
      .onClick(() => {
        this.aiMode = mode;
        this.aiStatusText = '';
      });
  }

  @Builder
  private aiPaperChip(paper: PaperItem): void {
    Text(paper.title)
      .fontSize(Font.small)
      .fontColor(this.selectedPaperId === paper.id ? AppColor.textOnPrimary : AppColor.textBody)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .backgroundColor(this.selectedPaperId === paper.id ? AppColor.accent : AppColor.surface)
      .border({ width: 1, color: this.selectedPaperId === paper.id ? AppColor.accent : AppColor.border })
      .borderRadius(Radius.pill)
      .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm })
      .margin({ right: Space.sm, bottom: Space.sm })
      .onClick(() => {
        this.selectAiPaper(paper);
      });
  }

  @Builder
  private aiResultPanel(result: AiCreatorResult): void {
    Column({ space: Space.sm }) {
      Row() {
        Text(this.aiModeName(result.mode))
          .fontSize(Font.sub)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle);
        Blank();
        Text(result.source)
          .fontSize(Font.caption)
          .fontColor(AppColor.accentStrong)
          .backgroundColor(AppColor.accentSoft)
          .borderRadius(Radius.sm)
          .padding({ left: Space.sm, right: Space.sm, top: 2, bottom: 2 });
      }
      .width('100%');

      if (result.title.length > 0) {
        Text(result.title)
          .fontSize(Font.body)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle)
          .width('100%');
      }
      if (result.summary.length > 0) {
        Text(result.summary)
          .fontSize(Font.small)
          .fontColor(AppColor.textSecondary)
          .lineHeight(20)
          .width('100%');
      }
      if (result.content.length > 0) {
        Text(result.content)
          .fontSize(Font.body)
          .fontColor(AppColor.textBody)
          .lineHeight(24)
          .maxLines(10)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
      }
      if (result.tags.length > 0 || result.topic.length > 0) {
        Text(`${result.topic}${result.tags.length > 0 ? ' · #' + result.tags.join(' #') : ''}`)
          .fontSize(Font.small)
          .fontColor(AppColor.accentStrong)
          .width('100%');
      }
      if (result.note.length > 0) {
        Text(result.note)
          .fontSize(Font.small)
          .fontColor(AppColor.textMuted)
          .lineHeight(20)
          .width('100%');
      }

      Row({ space: Space.sm }) {
        Button('应用到草稿')
          .height(38)
          .layoutWeight(1)
          .fontColor(AppColor.textOnPrimary)
          .backgroundColor(AppColor.primary)
          .borderRadius(Radius.lg)
          .onClick(() => {
            this.applyAiResult();
          });
        Button('追加正文')
          .height(38)
          .layoutWeight(1)
          .fontColor(AppColor.textBody)
          .backgroundColor(AppColor.surfaceSoft)
          .borderRadius(Radius.lg)
          .onClick(() => {
            this.appendAiContent();
          });
        Button('清除')
          .height(38)
          .layoutWeight(1)
          .fontColor(AppColor.textSecondary)
          .backgroundColor(AppColor.surfaceSoft)
          .borderRadius(Radius.lg)
          .onClick(() => {
            this.clearAiResult();
          });
      }
      .width('100%');
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border });
  }

  @Builder
  private aiAssistantPanel(): void {
    Column({ space: Space.md }) {
      Row() {
        Text('AI 辅助')
          .fontSize(Font.sub)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle);
        Blank();
        Text(this.aiModeName(this.aiMode))
          .fontSize(Font.caption)
          .fontColor(AppColor.accentStrong)
          .backgroundColor(AppColor.accentSoft)
          .borderRadius(Radius.sm)
          .padding({ left: Space.sm, right: Space.sm, top: 2, bottom: 2 });
      }
      .width('100%');

      Flex({ wrap: FlexWrap.Wrap }) {
        this.aiModeChip('draft', '从零生成');
        this.aiModeChip('organize', '整理记录');
        this.aiModeChip('meta', '标题摘要');
        this.aiModeChip('polish_academic', '学术润色');
        this.aiModeChip('polish_brief', '简洁润色');
        this.aiModeChip('polish_share', '分享润色');
        this.aiModeChip('experiment_template', '实验记录');
        this.aiModeChip('literature_template', '文献阅读');
        this.aiModeChip('review_template', '复盘模板');
        this.aiModeChip('preflight', '发布检查');
        this.aiModeChip('pdf_daily', 'PDF 日报');
      }
      .width('100%');

      if (this.aiMode === 'pdf_daily' && this.uploadedPdfName.length > 0) {
        Row({ space: Space.sm }) {
          Text('已上传')
            .fontSize(Font.caption)
            .fontColor(AppColor.textOnPrimary)
            .backgroundColor(AppColor.accent)
            .borderRadius(Radius.sm)
            .padding({ left: Space.sm, right: Space.sm, top: 3, bottom: 3 });
          Text(this.uploadedPdfName)
            .fontSize(Font.small)
            .fontColor(AppColor.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1);
        }
        .width('100%');
      }

      if (this.aiMode === 'pdf_daily' && this.papers.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.papers.slice(0, 4), (paper: PaperItem) => {
            this.aiPaperChip(paper);
          }, (paper: PaperItem) => paper.id);
        }
        .width('100%');
      }

      TextArea({ placeholder: this.aiPlaceholder(), text: this.aiPrompt })
        .height(92)
        .fontSize(Font.body)
        .fontColor(AppColor.textBody)
        .placeholderColor(AppColor.textMuted)
        .lineHeight(22)
        .backgroundColor(AppColor.surface)
        .border({ width: 1, color: AppColor.border })
        .borderRadius(Radius.lg)
        .padding(Space.md)
        .onChange((value: string) => {
          this.aiPrompt = value;
        });

      Row({ space: Space.sm }) {
        Button('清空输入')
          .height(42)
          .layoutWeight(1)
          .fontColor(AppColor.textBody)
          .backgroundColor(AppColor.surface)
          .border({ width: 1, color: AppColor.border })
          .borderRadius(Radius.lg)
          .onClick(() => {
            this.aiPrompt = '';
            this.aiStatusText = '';
          });
        Button(this.aiGenerating ? '生成中...' : '生成')
          .height(42)
          .layoutWeight(2)
          .fontColor(AppColor.textOnPrimary)
          .backgroundColor(this.aiGenerating ? AppColor.textMuted : AppColor.primary)
          .borderRadius(Radius.lg)
          .enabled(!this.aiGenerating)
          .onClick(() => {
            this.generateAiDraft();
          });
      }
      .width('100%');

      if (this.aiStatusText.length > 0) {
        Text(this.aiStatusText)
          .fontSize(Font.small)
          .fontColor(this.aiStatusText === 'AI 生成' ? AppColor.accentStrong : AppColor.textSecondary)
          .width('100%');
      }

      if (this.aiResult !== undefined) {
        this.aiResultPanel(this.aiResult);
      }
    }
    .width('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.surfaceSoft)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border });
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

          this.attachmentPanel();

          TextInput({ placeholder: '添加标题', text: this.title })
            .height(58)
            .fontSize(28)
            .fontColor(AppColor.textTitle)
            .placeholderColor(AppColor.textMuted)
            .backgroundColor(AppColor.surface)
            .onChange((value: string) => {
              this.title = value;
            });

          TextArea({ placeholder: '添加摘要（选填）', text: this.summary })
            .height(82)
            .fontSize(Font.body)
            .fontColor(AppColor.textBody)
            .placeholderColor(AppColor.textMuted)
            .lineHeight(22)
            .backgroundColor(AppColor.surface)
            .onChange((value: string) => {
              this.summary = value;
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

          this.aiAssistantPanel();

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
