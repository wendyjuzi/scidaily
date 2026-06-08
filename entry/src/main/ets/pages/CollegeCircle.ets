import { router } from '@kit.ArkUI';
import { AppColor, Space, Radius, Font, Elevation } from '../theme/AppTheme';

interface CollegeInfo {
  id: string;
  name: string;
  city: string;
  tagLine: string;
  activeCount: number;
  followerText: string;
  coverUrl: string;
}

interface CollegeNewsItem {
  id: string;
  collegeId: string;
  title: string;
  summary: string;
  source: string;
  time: string;
  topic: string;
  heat: number;
}

@Entry
@Component
struct CollegeCircle {
  private collegeScroller: Scroller = new Scroller();
  @State selectedCollegeId: string = 'tsinghua';
  @State colleges: CollegeInfo[] = [
    {
      id: 'tsinghua',
      name: '清华大学',
      city: '北京',
      tagLine: 'AI、材料与交叉学科动态密集更新',
      activeCount: 128,
      followerText: '3.8 万同学关注',
      coverUrl: 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=900&q=80'
    },
    {
      id: 'pku',
      name: '北京大学',
      city: '北京',
      tagLine: '生命科学、医学与基础研究资讯',
      activeCount: 96,
      followerText: '3.1 万同学关注',
      coverUrl: 'https://images.unsplash.com/photo-1576086213369-97a306d36557?auto=format&fit=crop&w=900&q=80'
    },
    {
      id: 'zju',
      name: '浙江大学',
      city: '杭州',
      tagLine: '机器人、农业科学与数据智能前沿',
      activeCount: 72,
      followerText: '2.2 万同学关注',
      coverUrl: 'https://images.unsplash.com/photo-1497366811353-6870744d04b2?auto=format&fit=crop&w=900&q=80'
    },
    {
      id: 'sjtu',
      name: '上海交通大学',
      city: '上海',
      tagLine: '工程、医工交叉与创新项目集合',
      activeCount: 84,
      followerText: '2.6 万同学关注',
      coverUrl: 'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?auto=format&fit=crop&w=900&q=80'
    },
    {
      id: 'csu',
      name: '中南大学',
      city: '长沙',
      tagLine: '医学、材料与智能制造科研动态',
      activeCount: 66,
      followerText: '1.9 万同学关注',
      coverUrl: 'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?auto=format&fit=crop&w=900&q=80'
    }
  ];
  @State newsItems: CollegeNewsItem[] = [
    {
      id: 'tsinghua-1',
      collegeId: 'tsinghua',
      title: '交叉信息院团队开源多模态科研助手评测集',
      summary: '覆盖论文检索、实验设计和结果复核等场景，适合做组会分享与课程项目基线。',
      source: '清华科研快讯',
      time: '今天 09:20',
      topic: '人工智能',
      heat: 86
    },
    {
      id: 'tsinghua-2',
      collegeId: 'tsinghua',
      title: '材料学院发布柔性传感器最新进展',
      summary: '新结构提升了低温环境下的稳定性，相关论文已开放预印本。',
      source: '材料学院',
      time: '昨天 18:40',
      topic: '材料科学',
      heat: 62
    },
    {
      id: 'pku-1',
      collegeId: 'pku',
      title: '生命科学学院举办单细胞组学方法训练营',
      summary: '训练营面向研究生开放，课程覆盖数据质控、聚类注释和疾病队列分析。',
      source: '北大生科',
      time: '今天 10:05',
      topic: '生命科学',
      heat: 78
    },
    {
      id: 'pku-2',
      collegeId: 'pku',
      title: '医学部临床 AI 读书会更新本周论文清单',
      summary: '重点讨论真实世界数据中的偏倚校正与模型外部验证。',
      source: '医学部研会',
      time: '昨天 16:10',
      topic: '医学 AI',
      heat: 55
    },
    {
      id: 'sjtu-1',
      collegeId: 'sjtu',
      title: '电院智能机器人方向开放联合课题报名',
      summary: '项目聚焦具身智能、工业巡检和低成本机械臂控制，支持跨院系组队。',
      source: '交大电院',
      time: '今天 08:30',
      topic: '机器人',
      heat: 74
    },
    {
      id: 'sjtu-2',
      collegeId: 'sjtu',
      title: '医学院团队分享多中心队列数据治理经验',
      summary: '报告将结合临床数据脱敏、数据字典和模型复现流程展开。',
      source: '医学院科研办',
      time: '周三 14:00',
      topic: '数据治理',
      heat: 48
    },
    {
      id: 'zju-1',
      collegeId: 'zju',
      title: '计算机学院发布农业智能感知挑战赛赛题',
      summary: '赛题包含田间图像分割、病虫害识别和时序预测三个方向。',
      source: '浙大 CS',
      time: '今天 11:25',
      topic: '数据智能',
      heat: 69
    },
    {
      id: 'zju-2',
      collegeId: 'zju',
      title: '机器人研究院招募暑期科研助理',
      summary: '岗位面向本校和外校学生开放，要求具备基础控制或视觉项目经验。',
      source: '机器人研究院',
      time: '昨天 20:15',
      topic: '科研机会',
      heat: 51
    },
    {
      id: 'csu-1',
      collegeId: 'csu',
      title: '湘雅医学团队发布临床多模态数据治理指南',
      summary: '面向课题组数据采集、脱敏标注和模型复现实验，提供可直接落地的流程模板。',
      source: '湘雅科研办',
      time: '今天 09:45',
      topic: '医学 AI',
      heat: 71
    },
    {
      id: 'csu-2',
      collegeId: 'csu',
      title: '粉末冶金研究院开放材料智能设计课题报名',
      summary: '项目聚焦高性能合金、实验数据管理和机器学习辅助成分筛选，支持跨院系组队。',
      source: '中南材料学院',
      time: '昨天 17:30',
      topic: '材料科学',
      heat: 63
    }
  ];

  private selectedCollege(): CollegeInfo {
    const college = this.colleges.find((item: CollegeInfo) => item.id === this.selectedCollegeId);
    return college === undefined ? this.colleges[0] : college;
  }

  private currentNews(): CollegeNewsItem[] {
    return this.newsItems.filter((item: CollegeNewsItem) => item.collegeId === this.selectedCollegeId);
  }

  private rankText(index: number): string {
    if (index === 0) {
      return '置顶';
    }
    return `动态 ${index + 1}`;
  }

  @Builder
  private collegeChip(college: CollegeInfo): void {
    Column({ space: 2 }) {
      Text(college.name)
        .fontSize(Font.body)
        .fontWeight(this.selectedCollegeId === college.id ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selectedCollegeId === college.id ? AppColor.textOnPrimary : AppColor.textBody)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(college.city)
        .fontSize(Font.caption)
        .fontColor(this.selectedCollegeId === college.id ? AppColor.onHeroSoft : AppColor.textMuted);
    }
    .width(116)
    .height(58)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.selectedCollegeId === college.id ? AppColor.primary : AppColor.surface)
    .border({ width: 1, color: this.selectedCollegeId === college.id ? AppColor.primary : AppColor.border })
    .borderRadius(Radius.lg)
    .onClick(() => {
      this.selectedCollegeId = college.id;
    });
  }

  @Builder
  private statPill(label: string, value: string): void {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(Font.sub)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textTitle);
      Text(label)
        .fontSize(Font.caption)
        .fontColor(AppColor.textMuted);
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private collegeSummary(): void {
    Column({ space: Space.md }) {
      Image(this.selectedCollege().coverUrl)
        .width('100%')
        .height(154)
        .objectFit(ImageFit.Cover)
        .borderRadius(Radius.md)
        .backgroundColor(AppColor.surfaceSoft);

      Column({ space: Space.sm }) {
        Row() {
          Column({ space: Space.xs }) {
            Text(this.selectedCollege().name)
              .fontSize(Font.h2)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textTitle)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            Text(this.selectedCollege().tagLine)
              .fontSize(Font.body)
              .fontColor(AppColor.textSecondary)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .lineHeight(20);
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
          Text('关注')
            .fontSize(Font.small)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.accentStrong)
            .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm })
            .backgroundColor(AppColor.accentSoft)
            .borderRadius(Radius.pill);
        }
        .width('100%')
        .alignItems(VerticalAlign.Top);

        Row() {
          this.statPill('活跃资讯', this.selectedCollege().activeCount.toString());
          this.statPill('关注热度', this.selectedCollege().followerText);
          this.statPill('今日更新', this.currentNews().length.toString());
        }
        .width('100%')
        .padding({ top: Space.md, bottom: Space.md })
        .backgroundColor(AppColor.surfaceSoft)
        .borderRadius(Radius.md);
      }
      .width('100%');
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border })
    .shadow(Elevation.card);
  }

  @Builder
  private newsCard(item: CollegeNewsItem, index: number): void {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        Text(this.rankText(index))
          .fontSize(Font.caption)
          .fontColor(index === 0 ? AppColor.textOnPrimary : AppColor.accentStrong)
          .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
          .backgroundColor(index === 0 ? AppColor.accent : AppColor.accentSoft)
          .borderRadius(Radius.sm);
        Text(item.topic)
          .fontSize(Font.caption)
          .fontColor(AppColor.textSecondary)
          .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
          .backgroundColor(AppColor.surfaceSoft)
          .borderRadius(Radius.sm);
        Blank();
        Text(item.time)
          .fontSize(Font.caption)
          .fontColor(AppColor.textMuted);
      }
      .width('100%');

      Text(item.title)
        .fontSize(Font.sub)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textTitle)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');

      Text(item.summary)
        .fontSize(Font.body)
        .fontColor(AppColor.textSecondary)
        .lineHeight(20)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');

      Row({ space: Space.sm }) {
        Text(item.source)
          .fontSize(Font.small)
          .fontColor(AppColor.textMuted)
          .layoutWeight(1);
        Text(`${item.heat} 热度`)
          .fontSize(Font.small)
          .fontColor(AppColor.warning);
      }
      .width('100%');
    }
    .width('100%')
    .padding(Space.lg)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .border({ width: 1, color: AppColor.border });
  }

  build() {
    Column({ space: Space.md }) {
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
        Text('高校圈')
          .fontSize(Font.h2)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle);
        Blank();
      }
      .width('100%')
      .height(44)
      .alignItems(VerticalAlign.Center);

      Scroll(this.collegeScroller) {
        Row({ space: Space.sm }) {
          ForEach(this.colleges, (college: CollegeInfo) => {
            this.collegeChip(college);
          }, (college: CollegeInfo) => college.id);
        }
        .padding({ left: Space.lg, right: Space.lg })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center);
      }
      .width('100%')
      .height(66)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);

      Scroll() {
        Column({ space: Space.lg }) {
          this.collegeSummary();

          Row() {
            Text('校园资讯')
              .fontSize(Font.title)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textTitle);
            Blank();
            Text('按学校更新')
              .fontSize(Font.small)
              .fontColor(AppColor.textMuted);
          }
          .width('100%');

          ForEach(this.currentNews(), (item: CollegeNewsItem, index: number) => {
            this.newsCard(item, index);
          }, (item: CollegeNewsItem) => item.id);

          Column({ space: Space.xs }) {
            Text('更多高校即将开放')
              .fontSize(Font.sub)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.textTitle);
            Text('后续可接入学校官方 RSS、学院公众号与校内活动接口。')
              .fontSize(Font.small)
              .fontColor(AppColor.textSecondary)
              .textAlign(TextAlign.Center)
              .lineHeight(20);
          }
          .width('100%')
          .padding(Space.lg)
          .backgroundColor(AppColor.surfaceSoft)
          .borderRadius(Radius.lg);
        }
        .width('100%')
        .padding({ left: Space.lg, right: Space.lg, top: Space.sm, bottom: Space.xxl })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start);
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .backgroundColor(AppColor.bg);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppColor.bg);
  }
}
