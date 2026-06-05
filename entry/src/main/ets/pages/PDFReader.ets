import { router } from '@kit.ArkUI';
import webview from '@ohos.web.webview';
import { PaperItem } from '../models/Paper';
import { paperService } from '../services/PaperService';
import { AppColor, Space, Radius, Font } from '../theme/AppTheme';

@Entry
@Component
struct PDFReader {
  @State paper: PaperItem | undefined = undefined;
  @State pdfUrl: string = '';
  @State progress: number = 0;
  @State statusText: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params = (router.getParams() as Record<string, string> | undefined) ?? {};
    const paperId = params.paperId ?? '';
    if (paperId.length === 0) {
      this.statusText = '未找到论文 ID';
      return;
    }
    paperService.getPaper(paperId).then((item: PaperItem | undefined) => {
      if (item === undefined) {
        this.statusText = '未找到论文';
        return;
      }
      this.paper = item;
      this.pdfUrl = paperService.normalizePdfUrl(item.pdfUrl);
    });
  }

  private saveProgress(progress: number): void {
    const item = this.paper;
    if (item === undefined) {
      return;
    }
    this.progress = progress;
    paperService.saveProgress(item.id, 1, progress).then(() => {
      this.statusText = '阅读进度已保存';
    }).catch((error: Error) => {
      this.statusText = '登录后可保存阅读进度';
    });
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
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
        Column({ space: 2 }) {
          Text(this.paper !== undefined ? this.paper.title : 'PDF 阅读')
            .fontSize(Font.body)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textTitle)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');
          Text(this.paper !== undefined ? this.paper.authors.join(', ') : '正在加载文献...')
            .fontSize(Font.caption)
            .fontColor(AppColor.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');
        }
        .layoutWeight(1);
      }
      .width('100%');

      if (this.pdfUrl.length === 0) {
        Text(this.statusText.length > 0 ? this.statusText : '正在加载 PDF...')
          .fontSize(Font.body)
          .fontColor(AppColor.textMuted)
          .layoutWeight(1)
          .width('100%')
          .textAlign(TextAlign.Center);
      } else {
        Web({ src: this.pdfUrl, controller: this.controller })
          .layoutWeight(1)
          .width('100%')
          .borderRadius(Radius.lg);
      }

      Row({ space: Space.sm }) {
        Button('标记 25%')
          .height(38)
          .layoutWeight(1)
          .fontSize(Font.small)
          .fontColor(AppColor.accent)
          .backgroundColor(AppColor.accentSoft)
          .borderRadius(Radius.lg)
          .onClick(() => {
            this.saveProgress(0.25);
          });
        Button('标记 50%')
          .height(38)
          .layoutWeight(1)
          .fontSize(Font.small)
          .fontColor(AppColor.accent)
          .backgroundColor(AppColor.accentSoft)
          .borderRadius(Radius.lg)
          .onClick(() => {
            this.saveProgress(0.5);
          });
        Button('已读完')
          .height(38)
          .layoutWeight(1)
          .fontSize(Font.small)
          .fontColor(AppColor.textOnPrimary)
          .backgroundColor(AppColor.primary)
          .borderRadius(Radius.lg)
          .onClick(() => {
            this.saveProgress(1);
          });
      }
      .width('100%');

      if (this.statusText.length > 0) {
        Text(this.statusText)
          .fontSize(Font.small)
          .fontColor(AppColor.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center);
      }
    }
    .width('100%')
    .height('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.bg);
  }
}
