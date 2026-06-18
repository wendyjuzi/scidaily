import { router } from '@kit.ArkUI';
import webview from '@ohos.web.webview';
import { PaperItem, ReadingProgress } from '../models/Paper';
import { AiConversationMessage, aiService } from '../services/AiService';
import { paperService } from '../services/PaperService';
import { AppColor, Space, Radius, Font, Elevation } from '../theme/AppTheme';

interface PaperSection {
  title: string;
  page: number;
}

interface OutlineDto {
  title: string;
  page: number;
  depth?: number;
}

interface PdfAnnotation {
  id: string;
  page: number;
  kind: string;
  tag: string;
  text: string;
  rects?: string;   // JSON of AnnotRect[] in normalized page coords; empty for note-only marks
}

interface AnnotRect {
  x: number;
  y: number;
  w: number;
  h: number;
}

interface AnnotPayload {
  id: string;
  page: number;
  kind: string;
  rects: AnnotRect[];
}

interface SelectionRectDto {
  page: number;
  rects: AnnotRect[];
}

@Entry
@Component
struct PDFReader {
  @State paper: PaperItem | undefined = undefined;
  @State basePdfUrl: string = '';
  @State currentPage: number = 1;
  @State totalPages: number = 1;
  @State progress: number = 0;
  @State statusText: string = '';
  @State activePanel: string = '目录';
  @State chromeShown: boolean = false;
  @State sheetShown: boolean = false;
  @State zoomScale: number = 1;
  @State isNightMode: boolean = true;
  @State isEyeCareMode: boolean = false;
  @State selectedTag: string = '方法';
  @State noteDraft: string = '';
  @State aiResult: string = '';
  @State aiLoading: boolean = false;
  @State annotations: PdfAnnotation[] = [];
  @State viewerReady: boolean = false;
  @State pdfOutline: PaperSection[] = [];
  @State currentPageText: string = '';
  @State selectedPdfText: string = '';
  private selectedRectsJson: string = '';
  private selectedRectPage: number = 0;
  private htmlLoaded: boolean = false;
  private docRequested: boolean = false;
  private lastSavedPage: number = -1;
  private controller: webview.WebviewController = new webview.WebviewController();
  // Bridge exposed to pdf_viewer.html as `scidailyNative` (continuous-scroll pdf.js viewer).
  private viewerBridge: Record<string, (value: number | string) => void> = {
    'onReady': (value: number | string) => {
      this.handleViewerReady(Number(value));
    },
    'onPageChange': (value: number | string) => {
      this.handleViewerPageChange(Number(value));
    },
    'onError': (value: number | string) => {
      this.handleViewerError(String(value));
    },
    'onTap': (value: number | string) => {
      this.toggleChrome();
    },
    'onOutline': (value: number | string) => {
      this.handleOutline(String(value));
    },
    'onPageText': (value: number | string) => {
      this.currentPageText = String(value);
    },
    'onSelection': (value: number | string) => {
      this.selectedPdfText = String(value);
    },
    'onSelectionRect': (value: number | string) => {
      this.handleSelectionRect(String(value));
    },
    'onBoot': (value: number | string) => {
      // viewer script booted; load is triggered from onPageEnd
    }
  };
  private sections: PaperSection[] = [
    { title: 'Abstract', page: 1 },
    { title: 'Introduction', page: 2 },
    { title: 'Method', page: 5 },
    { title: 'Experiment', page: 9 },
    { title: 'Conclusion', page: 16 }
  ];
  private tags: string[] = ['方法', '数据集', '指标', '创新点', '局限'];

  aboutToAppear(): void {
    const params = (router.getParams() as Record<string, string> | undefined) ?? {};
    const paperId = params.paperId ?? '';
    const pdfUrl = params.pdfUrl ?? '';
    const pdfTitle = params.pdfTitle ?? '上传 PDF';
    if (paperId.length === 0) {
      if (pdfUrl.length > 0) {
        const item: PaperItem = {
          id: this.uploadedPdfId(pdfUrl),
          title: pdfTitle,
          abstract: '用户上传的 PDF。可在阅读器中选择文字、记录标注，再生成阅读日报。',
          authors: ['本地上传'],
          categoryId: 'ai',
          categoryName: '人工智能',
          tags: ['PDF'],
          tagIds: [],
          sourceUrl: pdfUrl,
          pdfUrl: pdfUrl,
          publishedAt: '',
          createdAt: ''
        };
        this.paper = item;
        this.basePdfUrl = paperService.normalizePdfUrl(pdfUrl);
        this.loadAnnotations(item.id);
        this.loadLastProgress(item.id);
        return;
      }
      this.statusText = '未找到论文 ID';
      return;
    }
    paperService.getPaper(paperId).then((item: PaperItem | undefined) => {
      if (item === undefined) {
        this.statusText = '未找到论文';
        return;
      }
      this.paper = item;
      this.basePdfUrl = paperService.normalizePdfUrl(item.pdfUrl);
      this.loadAnnotations(item.id);
      this.loadLastProgress(item.id);
    });
  }

  private uploadedPdfId(url: string): string {
    let hash = 0;
    for (let index = 0; index < url.length; index += 1) {
      hash = ((hash * 31) + url.charCodeAt(index)) % 1000000007;
    }
    return `uploaded-${hash}`;
  }

  private loadAnnotations(paperId: string): void {
    const json = paperService.getAnnotations(paperId);
    if (json.length === 0) {
      return;
    }
    try {
      const stored = JSON.parse(json) as PdfAnnotation[];
      if (stored.length > 0) {
        this.annotations = stored;
      }
    } catch (error) {
      // ignore corrupt cache
    }
  }

  private persistAnnotations(): void {
    const item = this.paper;
    if (item === undefined) {
      return;
    }
    paperService.saveAnnotations(item.id, JSON.stringify(this.annotations));
  }

  private loadLastProgress(paperId: string): void {
    paperService.getProgress(paperId).then((item: ReadingProgress | undefined) => {
      if (item !== undefined) {
        this.currentPage = Math.max(1, Math.round(item.currentPage));
        this.progress = this.clampProgress(item.progress);
        this.statusText = `已恢复到第 ${this.currentPage} 页`;
      }
      this.maybeLoadDocument();
    }).catch(() => {
      this.maybeLoadDocument();
    });
  }

  // Trigger the one-time pdf.js load once both the viewer html and the PDF url are ready.
  private maybeLoadDocument(): void {
    if (this.docRequested || !this.htmlLoaded || this.basePdfUrl.length === 0) {
      return;
    }
    this.docRequested = true;
    const url = JSON.stringify(this.basePdfUrl);
    const page = Math.max(1, Math.round(this.currentPage));
    this.runViewer(`SciViewer.load(${url}, ${page}, ${this.isNightMode}, 'width')`);
  }

  // Fire-and-forget JS into the viewer. No-op until the html has finished loading.
  private runViewer(script: string): void {
    if (!this.htmlLoaded) {
      return;
    }
    try {
      this.controller.runJavaScript(script);
    } catch (error) {
      // viewer not attached yet; ignore
    }
  }

  private handleViewerReady(total: number): void {
    if (total > 0) {
      this.totalPages = Math.round(total);
    }
    this.currentPage = this.clampPage(this.currentPage);
    this.progress = this.progressFromPage(this.currentPage);
    this.viewerReady = true;
    this.lastSavedPage = this.currentPage;
    this.statusText = `共 ${this.totalPages} 页`;
    this.requestPageText();
    this.syncAnnotationsToViewer();
  }

  private handleViewerPageChange(page: number): void {
    const next = this.clampPage(page);
    if (next === this.currentPage) {
      return;
    }
    this.currentPage = next;
    this.progress = this.progressFromPage(next);
    this.requestPageText();
    this.persistProgressThrottled();
  }

  private handleViewerError(message: string): void {
    this.statusText = message.length > 0 ? `PDF 加载失败：${message}` : 'PDF 加载失败';
  }

  // Ask the viewer for the current page's plain text (used as real AI context).
  private requestPageText(): void {
    this.runViewer(`SciViewer.requestPageText(${this.currentPage})`);
  }

  private handleOutline(json: string): void {
    if (json.length === 0) {
      return;
    }
    try {
      const items = JSON.parse(json) as OutlineDto[];
      const parsed: PaperSection[] = items
        .filter((item: OutlineDto) => item.title.length > 0 && item.page > 0)
        .map((item: OutlineDto) => {
          const indent = (item.depth !== undefined && item.depth > 0) ? '   ' : '';
          const section: PaperSection = { title: `${indent}${item.title}`, page: item.page };
          return section;
        });
      if (parsed.length > 0) {
        this.pdfOutline = parsed;
      }
    } catch (error) {
      // keep the fallback sections
    }
  }

  // Real outline from the PDF when available, otherwise the curated fallback.
  private effectiveSections(): PaperSection[] {
    return this.pdfOutline.length > 0 ? this.pdfOutline : this.sections;
  }

  private clampPage(page: number): number {
    return Math.max(1, Math.min(this.totalPages, Math.round(page)));
  }

  private clampProgress(progress: number): number {
    return Math.max(0, Math.min(1, progress));
  }

  private readingPercent(): number {
    return Math.round(this.progress * 100);
  }

  private progressFromPage(page: number): number {
    if (this.totalPages <= 1) {
      return 1;
    }
    return this.clampProgress((page - 1) / (this.totalPages - 1));
  }

  private jumpToPage(page: number, message: string = '阅读位置已保存', closeTools: boolean = false): void {
    this.currentPage = this.clampPage(page);
    this.progress = this.progressFromPage(this.currentPage);
    this.runViewer(`SciViewer.goToPage(${this.currentPage}, true)`);
    if (closeTools) {
      this.sheetShown = false;
      this.chromeShown = false;
    }
    this.persistProgress(message);
  }

  private toggleChrome(): void {
    this.chromeShown = !this.chromeShown;
    if (!this.chromeShown) {
      this.sheetShown = false;
    }
  }

  private openPanel(panel: string): void {
    this.activePanel = panel;
    this.chromeShown = true;
    this.sheetShown = true;
  }

  private previewProgress(value: number, commit: boolean): void {
    const page = this.clampPage(Math.round(value / 100 * (this.totalPages - 1)) + 1);
    this.currentPage = page;
    this.progress = this.progressFromPage(page);
    // smooth-scroll only on release; live ticks jump instantly to stay responsive
    this.runViewer(`SciViewer.goToPage(${page}, ${commit})`);
    if (commit) {
      this.persistProgress('阅读位置已保存');
    }
  }

  private persistProgress(message: string): void {
    const item = this.paper;
    if (item === undefined) {
      return;
    }
    this.lastSavedPage = this.currentPage;
    paperService.saveProgress(item.id, this.currentPage, this.progress).then(() => {
      this.statusText = message;
    }).catch((error: Error) => {
      this.statusText = error.message;
    });
  }

  // Scroll-driven page updates: only persist when the page actually changed.
  private persistProgressThrottled(): void {
    if (this.currentPage === this.lastSavedPage) {
      return;
    }
    this.persistProgress(`已读到第 ${this.currentPage} 页`);
  }

  private adjustZoom(delta: number): void {
    const next = Math.round(this.zoomScale * (1 + delta) * 100) / 100;
    this.zoomScale = Math.max(0.6, Math.min(3, next));
    this.runViewer(`SciViewer.zoomBy(${delta})`);
    this.statusText = `缩放 ${Math.round(this.zoomScale * 100)}%`;
  }

  private resetZoom(): void {
    this.zoomScale = 1;
    this.runViewer(`SciViewer.setScale('width')`);
    this.statusText = '已适应宽度';
  }

  private fitPage(): void {
    this.zoomScale = 0.9;
    this.runViewer(`SciViewer.setScale('page')`);
    this.statusText = '已适应页面';
  }

  private toggleNight(): void {
    this.isNightMode = !this.isNightMode;
    this.runViewer(`SciViewer.setNight(${this.isNightMode})`);
  }

  private addAnnotation(kind: string): void {
    // priority: typed note > current PDF selection > a page placeholder
    let text = this.noteDraft.trim();
    if (text.length === 0) {
      text = this.selectedPdfText.trim();
    }
    if (text.length === 0) {
      text = `${kind}：第 ${this.currentPage} 页关键内容`;
    }
    const hasRects = this.selectedRectsJson.length > 0;
    const page = hasRects && this.selectedRectPage > 0 ? this.selectedRectPage : this.currentPage;
    const item: PdfAnnotation = {
      id: `${Date.now()}-${this.annotations.length}`,
      page,
      kind,
      tag: this.selectedTag,
      text,
      rects: hasRects ? this.selectedRectsJson : ''
    };
    this.annotations = [item].concat(this.annotations);
    this.noteDraft = '';
    this.selectedRectsJson = '';
    this.selectedRectPage = 0;
    this.selectedPdfText = '';
    this.persistAnnotations();
    if (hasRects) {
      this.syncAnnotationsToViewer();
      this.runViewer('SciViewer.clearSelection()');
      this.statusText = `${kind}已绘制到 P${page}`;
    } else {
      this.statusText = `${kind}已加入标注列表（未选中文字，仅记录）`;
    }
  }

  private removeAnnotation(id: string): void {
    this.annotations = this.annotations.filter((item: PdfAnnotation) => item.id !== id);
    this.persistAnnotations();
    this.syncAnnotationsToViewer();
    this.statusText = '已删除标注';
  }

  // Selection geometry from the viewer; attached to the next 高亮/划线/框选 mark.
  private handleSelectionRect(json: string): void {
    if (json.length === 0) {
      this.selectedRectsJson = '';
      this.selectedRectPage = 0;
      return;
    }
    try {
      const dto = JSON.parse(json) as SelectionRectDto;
      if (dto.rects.length > 0 && dto.page > 0) {
        this.selectedRectsJson = JSON.stringify(dto.rects);
        this.selectedRectPage = dto.page;
      }
    } catch (error) {
      // ignore malformed geometry
    }
  }

  // Push the drawable annotations (those with geometry) into the viewer to paint.
  private syncAnnotationsToViewer(): void {
    const payload: AnnotPayload[] = [];
    this.annotations.forEach((item: PdfAnnotation) => {
      const raw = item.rects ?? '';
      if (raw.length === 0) {
        return;
      }
      try {
        const rects = JSON.parse(raw) as AnnotRect[];
        if (rects.length > 0) {
          payload.push({ id: item.id, page: item.page, kind: item.kind, rects });
        }
      } catch (error) {
        // skip malformed geometry
      }
    });
    const json = JSON.stringify(payload);
    this.runViewer(`SciViewer.setAnnotations(${JSON.stringify(json)})`);
  }

  private useSelectionAsDraft(): void {
    const text = this.selectedPdfText.trim();
    if (text.length === 0) {
      this.statusText = '请先在 PDF 上长按选择文字';
      return;
    }
    this.noteDraft = text;
    this.statusText = '已引用选中文字';
  }

  private annotationsNote(): string {
    if (this.annotations.length === 0) {
      return '暂无标注。';
    }
    return this.annotations.map((item: PdfAnnotation) => {
      return `- P${item.page} [${item.tag}/${item.kind}] ${item.text}`;
    }).join('\n');
  }

  private paperPrompt(task: string): string {
    const item = this.paper;
    if (item === undefined) {
      return task;
    }
    const blocks: string[] = [
      task,
      `论文标题：${item.title}`,
      `作者：${item.authors.join(', ')}`,
      `摘要：${item.abstract}`,
      `当前阅读：第 ${this.currentPage}/${this.totalPages} 页，进度 ${this.readingPercent()}%`
    ];
    const selection = this.selectedPdfText.trim();
    if (selection.length > 0) {
      blocks.push(`用户选中的文字：\n${selection}`);
    }
    const pageText = this.currentPageText.trim();
    if (pageText.length > 0) {
      blocks.push(`当前页正文（OCR/文本层提取）：\n${pageText}`);
    }
    blocks.push(`标注：\n${this.annotationsNote()}`);
    return blocks.join('\n\n');
  }

  private runAi(mode: string, task: string): void {
    if (this.aiLoading) {
      return;
    }
    this.activePanel = 'AI';
    this.aiLoading = true;
    this.aiResult = '正在生成...';
    const history: AiConversationMessage[] = [];
    aiService.generate(mode, this.paperPrompt(task), history).then((result) => {
      this.aiResult = result.answer;
      this.statusText = result.title;
    }).catch((error: Error) => {
      this.aiResult = `AI 暂不可用：${error.message}`;
    }).finally(() => {
      this.aiLoading = false;
    });
  }

  private buildDailyDraft(): string {
    const item = this.paper;
    if (item === undefined) {
      return '';
    }
    return [
      `## 今日阅读记录`,
      '',
      `论文：${item.title}`,
      `作者：${item.authors.join(', ')}`,
      `阅读进度：${this.currentPage}/${this.totalPages}（${this.readingPercent()}%）`,
      '',
      `## 摘要`,
      '',
      item.abstract,
      '',
      `## 标注与笔记`,
      '',
      this.annotationsNote(),
      '',
      `## 下一步`,
      '',
      '- 补充方法细节和可复现实验配置',
      '- 检查数据集、指标和 baseline 是否充分'
    ].join('\n');
  }

  private openDailyEditor(): void {
    const item = this.paper;
    if (item === undefined) {
      return;
    }
    router.pushUrl({
      url: 'pages/CreatePost',
      params: {
        title: `阅读：${item.title}`,
        content: this.buildDailyDraft(),
        categoryId: item.categoryId,
        tagIds: item.tagIds.join(',')
      }
    });
  }

  @Builder
  private modeChip(title: string, active: boolean, action: () => void): void {
    Text(title)
      .fontSize(Font.caption)
      .fontColor(active ? AppColor.textOnPrimary : this.readerTextColor())
      .backgroundColor(active ? AppColor.primary : this.readerSurfaceColor())
      .border({ width: 1, color: active ? AppColor.primary : this.readerBorderColor() })
      .borderRadius(Radius.md)
      .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
      .margin({ right: Space.sm, bottom: Space.sm })
      .onClick(action);
  }

  @Builder
  private pdfCanvas(): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        this.pdfPane();
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.readerPaperColor())
      .border({ width: this.sheetShown ? 1 : 0, color: this.readerBorderColor() })
      .borderRadius(this.sheetShown ? Radius.lg : 0);

      if (this.chromeShown) {
        this.readingChrome();
      }
    }
    .layoutWeight(1)
    .width('100%');
  }

  @Builder
  private readingChrome(): void {
    Column() {
      this.readerTopHud();
      Blank();
      this.readerBottomHud();
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#00000000');
  }

  @Builder
  private readerTopHud(): void {
    Row({ space: Space.sm }) {
      Button('返回')
        .height(38)
        .fontSize(Font.small)
        .fontColor(AppColor.textOnPrimary)
        .backgroundColor('#99334155')
        .borderRadius(Radius.lg)
        .onClick(() => {
          router.back();
        });
      Column({ space: 2 }) {
        Text(this.paper !== undefined ? this.paper.title : 'PDF 阅读')
          .fontSize(Font.body)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textOnPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Text(`${this.currentPage} / ${this.totalPages} · ${this.readingPercent()}%`)
          .fontSize(Font.caption)
          .fontColor('#CCFFFFFF')
          .width('100%');
      }
      .layoutWeight(1);
      Button(this.isNightMode ? '日间' : '夜间')
        .height(38)
        .fontSize(Font.small)
        .fontColor(AppColor.textOnPrimary)
        .backgroundColor('#80334155')
        .borderRadius(Radius.lg)
        .onClick(() => {
          this.toggleNight();
        });
      Button('隐藏')
        .height(38)
        .fontSize(Font.small)
        .fontColor(AppColor.textOnPrimary)
        .backgroundColor('#80334155')
        .borderRadius(Radius.lg)
        .onClick(() => {
          this.chromeShown = false;
          this.sheetShown = false;
        });
    }
    .width('100%')
    .padding({ left: Space.md, right: Space.md, top: Space.md, bottom: Space.sm })
    .backgroundColor('#66111827');
  }

  @Builder
  private readerBottomHud(): void {
    Column({ space: Space.sm }) {
      Slider({
        value: this.readingPercent(),
        min: 0,
        max: 100,
        step: 1,
        style: SliderStyle.OutSet
      })
        .blockColor(AppColor.accent)
        .trackColor('#55FFFFFF')
        .selectedColor(AppColor.accent)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.previewProgress(value, mode === SliderChangeMode.End || mode === SliderChangeMode.Click);
        });
      Row({ space: Space.sm }) {
        this.zoomHudButton('−', () => {
          this.adjustZoom(-0.1);
        });
        this.zoomHudButton('+', () => {
          this.adjustZoom(0.1);
        });
        this.zoomHudButton('适宽', () => {
          this.resetZoom();
        });
        this.zoomHudButton('适页', () => {
          this.fitPage();
        });
        Text(`${Math.round(this.zoomScale * 100)}%`)
          .fontSize(Font.caption)
          .fontColor('#CCFFFFFF')
          .layoutWeight(1)
          .textAlign(TextAlign.End);
      }
      .width('100%');
      Row({ space: Space.sm }) {
        this.readerHudButton('目录', '目录');
        this.readerHudButton('标注', '标注');
        this.readerHudButton('AI', 'AI');
        this.readerHudButton('日报', '日报');
      }
      .width('100%');
    }
    .width('100%')
    .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.md })
    .backgroundColor('#66111827');
  }

  @Builder
  private zoomHudButton(label: string, action: () => void): void {
    Button(label)
      .height(34)
      .constraintSize({ minWidth: 44 })
      .fontSize(Font.small)
      .fontColor(AppColor.textOnPrimary)
      .backgroundColor('#80334155')
      .borderRadius(Radius.lg)
      .onClick(action);
  }

  @Builder
  private readerHudButton(title: string, panel: string): void {
    Button(title)
      .height(40)
      .layoutWeight(1)
      .fontSize(Font.body)
      .fontColor(this.activePanel === panel && this.sheetShown ? AppColor.textOnPrimary : AppColor.textOnPrimary)
      .backgroundColor(this.activePanel === panel && this.sheetShown ? '#CC334155' : '#80334155')
      .borderRadius(Radius.lg)
      .onClick(() => {
        this.openPanel(panel);
      });
  }

  @Builder
  private pdfPane(): void {
    Web({ src: $rawfile('pdf_viewer.html'), controller: this.controller })
      .width('100%')
      .height('100%')
      .backgroundColor(this.readerPaperColor())
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .fileAccess(true)
      .imageAccess(true)
      .zoomAccess(false)
      .horizontalScrollBarAccess(false)
      .javaScriptProxy({
        object: this.viewerBridge,
        name: 'scidailyNative',
        methodList: ['onReady', 'onPageChange', 'onError', 'onTap', 'onOutline', 'onPageText', 'onSelection', 'onSelectionRect', 'onBoot'],
        controller: this.controller
      })
      .onPageEnd(() => {
        this.htmlLoaded = true;
        this.maybeLoadDocument();
      });
  }

  @Builder
  private panelTabs(): void {
    Row({ space: Space.sm }) {
      this.panelTab('目录');
      this.panelTab('标注');
      this.panelTab('AI');
      this.panelTab('日报');
    }
    .width('100%');
  }

  @Builder
  private panelTab(title: string): void {
    Button(title)
      .height(34)
      .layoutWeight(1)
      .fontSize(Font.small)
      .fontColor(this.activePanel === title ? AppColor.textOnPrimary : this.readerTextColor())
      .backgroundColor(this.activePanel === title ? AppColor.primary : this.readerSurfaceColor())
      .border({ width: 1, color: this.activePanel === title ? AppColor.primary : this.readerBorderColor() })
      .borderRadius(Radius.lg)
      .onClick(() => {
        this.activePanel = title;
      });
  }

  @Builder
  private sheetContent(): void {
    Column({ space: Space.md }) {
      this.panelTabs();
      if (this.activePanel === '目录') {
        this.outlinePanel();
      } else if (this.activePanel === '标注') {
        this.annotationPanel();
      } else if (this.activePanel === 'AI') {
        this.aiPanel();
      } else {
        this.dailyPanel();
      }
    }
    .width('100%')
    .height('100%')
    .padding(Space.md)
    .backgroundColor(this.readerSurfaceColor());
  }

  @Builder
  private sidePanel(): void {
    Column() {
      this.sheetContent();
    }
    .width('100%')
    .height(252)
    .backgroundColor(this.readerSurfaceColor())
    .border({ width: 1, color: this.readerBorderColor() })
    .borderRadius(Radius.lg)
    .shadow(Elevation.card);
  }

  @Builder
  private outlinePanel(): void {
    Column({ space: Space.xs }) {
      Row() {
        Text(this.pdfOutline.length > 0 ? '文献目录（自动识别章节）' : '文献目录（参考结构）')
          .fontSize(Font.caption)
          .fontColor(this.readerMutedColor());
        Blank();
        Text(`${this.totalPages} 页`)
          .fontSize(Font.caption)
          .fontColor(this.readerMutedColor());
      }
      .width('100%');
      Scroll() {
        Column({ space: Space.sm }) {
          ForEach(this.effectiveSections(), (item: PaperSection) => {
            Row() {
              Text(item.title)
                .fontSize(Font.body)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.readerTitleColor())
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1);
              Text(`P${item.page}`)
                .fontSize(Font.caption)
                .fontColor(AppColor.accent);
              Text('定位')
                .fontSize(Font.caption)
                .fontColor(this.currentPage === item.page ? AppColor.accentStrong : this.readerMutedColor())
                .margin({ left: Space.sm });
            }
            .width('100%')
            .height(38)
            .padding({ left: Space.sm, right: Space.sm })
            .backgroundColor(this.currentPage === item.page ? AppColor.accentSoft : this.readerPanelColor())
            .borderRadius(Radius.md)
            .onClick(() => {
              this.jumpToPage(item.page, `已定位到 ${item.title.trim()} · P${item.page}`, true);
            });
          }, (item: PaperSection, index: number) => `${index}-${item.title}-${item.page}`);
        }
        .width('100%');
      }
      .height(200)
      .scrollBar(BarState.Off);
    }
    .width('100%');
  }

  @Builder
  private annotationPanel(): void {
    Column({ space: Space.md }) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.tags, (tag: string) => {
          this.modeChip(tag, this.selectedTag === tag, () => {
            this.selectedTag = tag;
          });
        }, (tag: string) => tag);
      }
      .width('100%');
      if (this.selectedPdfText.length > 0) {
        Row({ space: Space.sm }) {
          Text(`已选中：${this.selectedPdfText}`)
            .fontSize(Font.caption)
            .fontColor(this.readerTextColor())
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1);
          Button('引用')
            .height(30)
            .fontSize(Font.caption)
            .fontColor(AppColor.accent)
            .backgroundColor(AppColor.accentSoft)
            .borderRadius(Radius.md)
            .onClick(() => {
              this.useSelectionAsDraft();
            });
        }
        .width('100%')
        .padding(Space.sm)
        .backgroundColor(this.readerPanelColor())
        .borderRadius(Radius.md);
      }
      TextArea({ placeholder: '长按 PDF 选中文字后点“引用”，或直接手写批注', text: this.noteDraft })
        .height(64)
        .fontSize(Font.body)
        .fontColor(this.readerTextColor())
        .placeholderColor(this.readerMutedColor())
        .backgroundColor(this.readerPanelColor())
        .border({ width: 1, color: this.readerBorderColor() })
        .borderRadius(Radius.md)
        .onChange((value: string) => {
          this.noteDraft = value;
        });
      Row({ space: Space.sm }) {
        this.annotationButton('高亮');
        this.annotationButton('划线');
        this.annotationButton('框选');
        this.annotationButton('批注');
      }
      .width('100%');
      Scroll() {
        Column({ space: Space.sm }) {
          ForEach(this.annotations, (item: PdfAnnotation) => {
            this.annotationRow(item);
          }, (item: PdfAnnotation) => item.id);
        }
      }
      .height(132)
      .scrollBar(BarState.Off);
    }
    .width('100%');
  }

  @Builder
  private annotationButton(title: string): void {
    Button(title)
      .height(34)
      .layoutWeight(1)
      .fontSize(Font.small)
      .fontColor(AppColor.accent)
      .backgroundColor(AppColor.accentSoft)
      .borderRadius(Radius.lg)
      .onClick(() => {
        this.addAnnotation(title);
      });
  }

  @Builder
  private annotationRow(item: PdfAnnotation): void {
    Column({ space: Space.xs }) {
      Row() {
        Text(`P${item.page} ${item.kind}`)
          .fontSize(Font.caption)
          .fontColor(AppColor.accent);
        Text(item.tag)
          .fontSize(Font.caption)
          .fontColor(this.readerMutedColor())
          .margin({ left: Space.sm });
        Blank();
        Text('定位')
          .fontSize(Font.caption)
          .fontColor(AppColor.accent)
          .padding({ left: Space.sm, right: Space.sm })
          .onClick(() => {
            this.jumpToPage(item.page, `已定位到标注 · P${item.page}`, true);
          });
        Text('删除')
          .fontSize(Font.caption)
          .fontColor(this.readerMutedColor())
          .padding({ left: Space.sm })
          .onClick(() => {
            this.removeAnnotation(item.id);
          });
      }
      .width('100%');
      Text(item.text)
        .fontSize(Font.small)
        .fontColor(this.readerTextColor())
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');
    }
    .width('100%')
    .padding(Space.sm)
    .backgroundColor(this.readerPanelColor())
    .borderRadius(Radius.md);
  }

  @Builder
  private aiPanel(): void {
    Column({ space: Space.sm }) {
      Flex({ wrap: FlexWrap.Wrap }) {
        this.aiAction('总结当前页', 'paper', '只总结当前页可见内容，重点提炼研究问题、方法和结果。');
        this.aiAction('总结全文', 'paper', '输出研究问题、方法、实验、结论和局限。');
        this.aiAction('解释段落', 'qa', '用中文解释当前选中段落或批注，说明术语和上下文。');
        this.aiAction('图表信息', 'qa', '提取当前页 figure/table 可能表达的实验信息和结论。');
        this.aiAction('复现 checklist', 'reproduce', '从论文里提取实验步骤、数据、代码依赖和评估方式。');
        this.aiAction('Reviewer 提问', 'review', '从 reviewer 视角指出实验漏洞、baseline 缺失和可追问点。');
        this.aiAction('相关论文对比', 'compare', '和文献库里已读论文做方法差异对比。');
      }
      .width('100%');
      Scroll() {
        Text(this.aiResult.length > 0 ? this.aiResult : '选择一个 AI 阅读动作后，结果会显示在这里。')
          .fontSize(Font.small)
          .fontColor(this.readerTextColor())
          .lineHeight(20)
          .width('100%');
      }
      .height(142)
      .padding(Space.sm)
      .backgroundColor(this.readerPanelColor())
      .borderRadius(Radius.md)
      .scrollBar(BarState.Off);
    }
    .width('100%');
  }

  @Builder
  private aiAction(title: string, mode: string, task: string): void {
    Text(title)
      .fontSize(Font.caption)
      .fontColor(this.aiLoading ? this.readerMutedColor() : AppColor.accent)
      .backgroundColor(AppColor.accentSoft)
      .borderRadius(Radius.md)
      .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
      .margin({ right: Space.sm, bottom: Space.sm })
      .onClick(() => {
        this.runAi(mode, task);
      });
  }

  @Builder
  private dailyPanel(): void {
    Column({ space: Space.sm }) {
      Text('阅读日报草稿')
        .fontSize(Font.body)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.readerTitleColor())
        .width('100%');
      Text(this.buildDailyDraft())
        .fontSize(Font.small)
        .fontColor(this.readerTextColor())
        .lineHeight(20)
        .maxLines(8)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding(Space.sm)
        .backgroundColor(this.readerPanelColor())
        .borderRadius(Radius.md)
        .width('100%');
      Button('写日报')
        .height(38)
        .width('100%')
        .fontSize(Font.body)
        .fontColor(AppColor.textOnPrimary)
        .backgroundColor(AppColor.primary)
        .borderRadius(Radius.lg)
        .onClick(() => {
          this.openDailyEditor();
        });
    }
    .width('100%');
  }

  @Builder
  private toolsOverlay(): void {
    Column() {
      Blank();
      Column({ space: Space.md }) {
        Row() {
          Column()
            .width(44)
            .height(4)
            .backgroundColor(this.readerBorderColor())
            .borderRadius(2);
        }
        .width('100%')
        .justifyContent(FlexAlign.Center);
        this.sidePanel();
        if (this.statusText.length > 0) {
          Text(this.statusText)
            .fontSize(Font.small)
            .fontColor(this.readerMutedColor())
            .width('100%')
            .textAlign(TextAlign.Center);
        }
      }
      .width('100%')
      .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.md })
      .backgroundColor(this.readerSurfaceColor())
      .borderRadius({ topLeft: 24, topRight: 24 })
      .shadow(Elevation.card);
    }
    .width('100%')
    .height('100%');
  }

  private readerBackgroundColor(): string {
    if (this.isNightMode) {
      return '#111827';
    }
    if (this.isEyeCareMode) {
      return '#F4F0E6';
    }
    return AppColor.bg;
  }

  private readerSurfaceColor(): string {
    return this.isNightMode ? '#1F2937' : AppColor.surface;
  }

  private readerPanelColor(): string {
    if (this.isNightMode) {
      return '#111827';
    }
    if (this.isEyeCareMode) {
      return '#FFF8EA';
    }
    return AppColor.surfaceSoft;
  }

  private readerPaperColor(): string {
    if (this.isNightMode) {
      return '#0B1220';
    }
    if (this.isEyeCareMode) {
      return '#FFF8EA';
    }
    return AppColor.surface;
  }

  private readerTitleColor(): string {
    return this.isNightMode ? '#F8FAFC' : AppColor.textTitle;
  }

  private readerTextColor(): string {
    return this.isNightMode ? '#CBD5E1' : AppColor.textBody;
  }

  private readerMutedColor(): string {
    return this.isNightMode ? '#94A3B8' : AppColor.textMuted;
  }

  private readerBorderColor(): string {
    return this.isNightMode ? '#334155' : AppColor.border;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.pdfCanvas();
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.readerBackgroundColor());

      if (this.sheetShown) {
        this.toolsOverlay();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.readerBackgroundColor());
  }
}
