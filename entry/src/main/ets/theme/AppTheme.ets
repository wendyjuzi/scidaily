/**
 * 科研日报 · 设计 Token（单一数据源）
 *
 * 视觉方向：学术石板（Slate）主色 + Teal 翡翠点缀，沉稳克制、现代科技、高组织性。
 * 用法：在页面内 `import { AppColor, Space, Radius, Font, Elevation } from '../theme/AppTheme';`
 *      然后以 `AppColor.primary` 等语义名替代硬编码色值。
 *
 * 采用 class + static readonly 形式，以满足 ArkTS 对对象字面量的静态约束。
 * 深色模式扩展位：后续在本文件追加 `AppColorDark` 并在页面按主题切换即可，语义名保持不变。
 */
export class AppColor {
  // 主色 / 点缀
  static readonly primary: string = '#334155';        // Slate 700 — 主色（标题、主按钮、激活态）
  static readonly primaryStrong: string = '#1E293B';  // Slate 800 — 强调墨色
  static readonly primarySoft: string = '#EEF2F6';    // 主色浅底（chip 选中底、信息卡底）
  static readonly accent: string = '#0D9488';         // Teal 600 — 点缀（链接、关键数字、主图序列）
  static readonly accentStrong: string = '#0F766E';   // Teal 700 — 点缀按下/深态
  static readonly accentSoft: string = '#E6F4F2';     // Teal 浅底

  // 中性
  static readonly bg: string = '#F6F8FA';             // 页面背景（统一替代 F6F8FB / F5F7FB）
  static readonly surface: string = '#FFFFFF';        // 卡片面
  static readonly surfaceSoft: string = '#F1F4F8';    // 次级面（输入框、内嵌块）
  static readonly border: string = '#E6EAF0';         // 发丝描边（hairline）
  static readonly scrim: string = '#B30F172A';        // 图片上的深色蒙层（70% 石板，AARRGGBB）
  static readonly heroStart: string = '#1E293B';      // 顶部品牌渐变起（深石板）
  static readonly heroEnd: string = '#0D9488';        // 顶部品牌渐变止（Teal）

  // 文本层级
  static readonly textTitle: string = '#0F172A';      // 一级标题
  static readonly textBody: string = '#334155';       // 正文
  static readonly textSecondary: string = '#64748B';  // 次要
  static readonly textMuted: string = '#94A3B8';      // 弱化 / 占位
  static readonly textOnPrimary: string = '#FFFFFF';
  static readonly onHeroSoft: string = '#CCFFFFFF';   // 渐变头部上的次要白字
  static readonly glass: string = '#33FFFFFF';         // 渐变上的玻璃拟态底（20% 白）
  static readonly glassStrong: string = '#4DFFFFFF';   // 渐变上的玻璃拟态底（30% 白）

  // 状态
  static readonly success: string = '#0D9488';
  static readonly warning: string = '#D97706';
  static readonly danger: string = '#DC2626';
  static readonly dangerSoft: string = '#FBEAEA';

  // 图表序列（slate / teal / amber）
  static readonly series1: string = '#334155';        // 日报
  static readonly series2: string = '#0D9488';        // 实验
  static readonly series3: string = '#D97706';        // 文献
}

export class Space {
  static readonly xs: number = 4;
  static readonly sm: number = 8;
  static readonly md: number = 12;
  static readonly lg: number = 16;
  static readonly xl: number = 20;
  static readonly xxl: number = 24;
}

export class Radius {
  static readonly sm: number = 8;
  static readonly md: number = 12;
  static readonly lg: number = 16;
  static readonly pill: number = 999;
}

export class Font {
  static readonly caption: number = 11;
  static readonly small: number = 12;
  static readonly body: number = 14;
  static readonly sub: number = 16;
  static readonly title: number = 18;
  static readonly h2: number = 22;
  static readonly h1: number = 26;
}

export class Elevation {
  /** 标准卡片阴影：石板冷调、低透明、柔和。 */
  static readonly card: ShadowOptions = {
    radius: 16,
    color: '#14101828',
    offsetX: 0,
    offsetY: 6
  };
}
