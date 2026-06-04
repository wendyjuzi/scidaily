import { router } from '@kit.ArkUI';
import webview from '@ohos.web.webview';
import { PaperItem } from '../models/Paper';
import { paperService } from '../services/PaperService';

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
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Button('返回')
          .height(34)
          .fontSize(13)
          .fontColor('#111827')
          .backgroundColor('#FFFFFF')
          .borderRadius(17)
          .onClick(() => {
            router.back();
          });
        Column({ space: 2 }) {
          Text(this.paper !== undefined ? this.paper.title : 'PDF 阅读')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');
          Text(this.paper !== undefined ? this.paper.authors.join(', ') : '正在加载文献...')
            .fontSize(11)
            .fontColor('#64748B')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');
        }
        .layoutWeight(1);
      }
      .width('100%');

      if (this.pdfUrl.length === 0) {
        Text(this.statusText.length > 0 ? this.statusText : '正在加载 PDF...')
          .fontSize(14)
          .fontColor('#8B8F98')
          .layoutWeight(1)
          .width('100%')
          .textAlign(TextAlign.Center);
      } else {
        Web({ src: this.pdfUrl, controller: this.controller })
          .layoutWeight(1)
          .width('100%')
          .borderRadius(16);
      }

      Row({ space: 8 }) {
        Button('标记 25%')
          .height(38)
          .layoutWeight(1)
          .fontSize(12)
          .fontColor('#007AFF')
          .backgroundColor('#EAF4FF')
          .borderRadius(19)
          .onClick(() => {
            this.saveProgress(0.25);
          });
        Button('标记 50%')
          .height(38)
          .layoutWeight(1)
          .fontSize(12)
          .fontColor('#007AFF')
          .backgroundColor('#EAF4FF')
          .borderRadius(19)
          .onClick(() => {
            this.saveProgress(0.5);
          });
        Button('已读完')
          .height(38)
          .layoutWeight(1)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .backgroundColor('#007AFF')
          .borderRadius(19)
          .onClick(() => {
            this.saveProgress(1);
          });
      }
      .width('100%');

      if (this.statusText.length > 0) {
        Text(this.statusText)
          .fontSize(12)
          .fontColor('#64748B')
          .width('100%')
          .textAlign(TextAlign.Center);
      }
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#F6F8FB');
  }
}
