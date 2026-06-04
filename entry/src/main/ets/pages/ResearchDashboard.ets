import { router } from '@kit.ArkUI';
import { ResearchStatsBundle, ResearchStatsPoint } from '../models/Community';
import { authService } from '../services/AuthService';
import { communityService } from '../services/CommunityService';

@Entry
@Component
struct ResearchDashboard {
  @State range: string = 'week';
  @State stats: ResearchStatsBundle = {
    range: 'week',
    totalDaily: 0,
    totalExperiment: 0,
    totalLiterature: 0,
    points: []
  };
  @State errorMessage: string = '';

  aboutToAppear(): void {
    if (!authService.isLoggedIn()) {
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
    this.reload();
  }

  private reload(): void {
    communityService.getResearchStats(this.range).then((stats: ResearchStatsBundle) => {
      this.stats = stats;
      this.errorMessage = '';
    }).catch((error: Error) => {
      this.errorMessage = error.message;
    });
  }

  private selectRange(range: string): void {
    this.range = range;
    this.reload();
  }

  private maxValue(): number {
    let max = 1;
    this.stats.points.forEach((item: ResearchStatsPoint) => {
      max = Math.max(max, item.dailyCount, item.experimentCount, item.literatureCount);
    });
    return max;
  }

  private barHeight(value: number): number {
    return Math.max(8, Math.round(value * 96 / this.maxValue()));
  }

  @Builder
  private rangeButton(title: string, value: string): void {
    Button(title)
      .type(ButtonType.Capsule)
      .fontSize(14)
      .fontColor(this.range === value ? '#FFFFFF' : '#1D2939')
      .backgroundColor(this.range === value ? '#1E88E5' : '#EAF1F8')
      .onClick(() => {
        this.selectRange(value);
      });
  }

  @Builder
  private metricCard(title: string, value: number, color: string): void {
    Column({ space: 6 }) {
      Text(value.toString())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color);
      Text(title)
        .fontSize(12)
        .fontColor('#667085')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .layoutWeight(1)
    .height(86)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFFFFF')
    .borderRadius(12);
  }

  @Builder
  private chartColumn(point: ResearchStatsPoint): void {
    Column({ space: 6 }) {
      Row({ space: 4 }) {
        Column()
          .width(8)
          .height(this.barHeight(point.dailyCount))
          .backgroundColor('#1E88E5')
          .borderRadius(4);
        Column()
          .width(8)
          .height(this.barHeight(point.experimentCount))
          .backgroundColor('#12B76A')
          .borderRadius(4);
        Column()
          .width(8)
          .height(this.barHeight(point.literatureCount))
          .backgroundColor('#F79009')
          .borderRadius(4);
      }
      .height(104)
      .alignItems(VerticalAlign.Bottom);

      Text(point.label)
        .fontSize(10)
        .fontColor('#8A94A6')
        .width(44)
        .textAlign(TextAlign.Center);
    }
    .width(44)
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private legend(label: string, color: string): void {
    Row({ space: 6 }) {
      Column()
        .width(8)
        .height(8)
        .backgroundColor(color)
        .borderRadius(4);
      Text(label)
        .fontSize(12)
        .fontColor('#667085');
    }
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
      }
      .width('100%');

      Text('科研数据看板')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .width('100%');

      Row({ space: 8 }) {
        this.rangeButton('今日', 'day');
        this.rangeButton('本周', 'week');
        this.rangeButton('本月', 'month');
      }
      .width('100%');

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(13)
          .fontColor('#D92D20')
          .width('100%');
      }

      Row({ space: 8 }) {
        this.metricCard('日报数量', this.stats.totalDaily, '#1E88E5');
        this.metricCard('实验记录', this.stats.totalExperiment, '#12B76A');
        this.metricCard('文献学习', this.stats.totalLiterature, '#F79009');
      }
      .width('100%');

      Column({ space: 12 }) {
        Row() {
          Text('趋势统计')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1D2939');
          Blank();
        }
        .width('100%');

        Row({ space: 12 }) {
          this.legend('日报', '#1E88E5');
          this.legend('实验', '#12B76A');
          this.legend('文献', '#F79009');
        }
        .width('100%');

        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.stats.points, (point: ResearchStatsPoint) => {
              this.chartColumn(point);
            }, (point: ResearchStatsPoint) => point.label);
          }
          .padding({ top: 4, right: 8 });
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%');
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#FFFFFF')
      .borderRadius(12);
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#F5F7FB');
  }
}
