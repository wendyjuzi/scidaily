import { router } from '@kit.ArkUI';
import { ResearchStatsBundle, ResearchStatsPoint } from '../models/Community';
import { authService } from '../services/AuthService';
import { communityService } from '../services/CommunityService';
import { AppColor, Space, Radius, Font, Elevation } from '../theme/AppTheme';

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
      .fontSize(Font.body)
      .fontWeight(this.range === value ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.range === value ? AppColor.textOnPrimary : AppColor.textBody)
      .backgroundColor(this.range === value ? AppColor.primary : AppColor.primarySoft)
      .onClick(() => {
        this.selectRange(value);
      });
  }

  @Builder
  private metricCard(title: string, value: number, color: string): void {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        Column()
          .width(4)
          .height(18)
          .backgroundColor(color)
          .borderRadius(2);
        Text(value.toString())
          .fontSize(Font.h1)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle);
      }
      .alignItems(VerticalAlign.Center);
      Text(title)
        .fontSize(Font.small)
        .fontColor(AppColor.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .layoutWeight(1)
    .height(92)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .padding({ left: Space.md, right: Space.md })
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border });
  }

  @Builder
  private chartColumn(point: ResearchStatsPoint): void {
    Column({ space: Space.sm }) {
      Row({ space: Space.xs }) {
        Column()
          .width(8)
          .height(this.barHeight(point.dailyCount))
          .backgroundColor(AppColor.series1)
          .borderRadius(4);
        Column()
          .width(8)
          .height(this.barHeight(point.experimentCount))
          .backgroundColor(AppColor.series2)
          .borderRadius(4);
        Column()
          .width(8)
          .height(this.barHeight(point.literatureCount))
          .backgroundColor(AppColor.series3)
          .borderRadius(4);
      }
      .height(104)
      .alignItems(VerticalAlign.Bottom);

      Text(point.label)
        .fontSize(Font.caption)
        .fontColor(AppColor.textMuted)
        .width(44)
        .textAlign(TextAlign.Center);
    }
    .width(44)
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private legend(label: string, color: string): void {
    Row({ space: Space.xs }) {
      Column()
        .width(8)
        .height(8)
        .backgroundColor(color)
        .borderRadius(4);
      Text(label)
        .fontSize(Font.small)
        .fontColor(AppColor.textSecondary);
    }
  }

  build() {
    Column({ space: Space.lg }) {
      Row() {
        Button('返回')
          .type(ButtonType.Capsule)
          .fontSize(Font.body)
          .fontColor(AppColor.textBody)
          .backgroundColor(AppColor.surface)
          .border({ width: 1, color: AppColor.border })
          .onClick(() => {
            router.back();
          });
        Blank();
      }
      .width('100%');

      Column({ space: Space.xs }) {
        Text('科研数据看板')
          .fontSize(Font.h1)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle)
          .width('100%');
        Text('追踪你的科研产出节奏')
          .fontSize(Font.small)
          .fontColor(AppColor.textSecondary)
          .width('100%');
      }
      .width('100%');

      Row({ space: Space.sm }) {
        this.rangeButton('今日', 'day');
        this.rangeButton('本周', 'week');
        this.rangeButton('本月', 'month');
      }
      .width('100%');

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(Font.body)
          .fontColor(AppColor.danger)
          .width('100%');
      }

      Row({ space: Space.md }) {
        this.metricCard('日报数量', this.stats.totalDaily, AppColor.series1);
        this.metricCard('实验记录', this.stats.totalExperiment, AppColor.series2);
        this.metricCard('文献学习', this.stats.totalLiterature, AppColor.series3);
      }
      .width('100%');

      Column({ space: Space.md }) {
        Row() {
          Text('趋势统计')
            .fontSize(Font.title)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textTitle);
          Blank();
        }
        .width('100%');

        Row({ space: Space.lg }) {
          this.legend('日报', AppColor.series1);
          this.legend('实验', AppColor.series2);
          this.legend('文献', AppColor.series3);
        }
        .width('100%');

        Scroll() {
          Row({ space: Space.sm }) {
            ForEach(this.stats.points, (point: ResearchStatsPoint) => {
              this.chartColumn(point);
            }, (point: ResearchStatsPoint) => point.label);
          }
          .padding({ top: Space.xs, right: Space.sm });
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%');
      }
      .width('100%')
      .padding(Space.lg)
      .backgroundColor(AppColor.surface)
      .borderRadius(Radius.lg)
      .border({ width: 1, color: AppColor.border })
      .shadow(Elevation.card);
    }
    .width('100%')
    .height('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.bg);
  }
}
