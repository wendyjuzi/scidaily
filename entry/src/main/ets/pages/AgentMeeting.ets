import { router } from '@kit.ArkUI';
import { AgentMeetingBundle, AgentMeetingMessage, AgentMeetingSession } from '../models/AgentMeeting';
import { agentMeetingService } from '../services/AgentMeetingService';
import { authService } from '../services/AuthService';
import { AppColor, Elevation, Font, Radius, Space } from '../theme/AppTheme';

@Entry
@Component
struct AgentMeeting {
  @State prompt: string = '';
  @State statusText: string = '';
  @State loading: boolean = false;
  @State polling: boolean = false;
  @State currentSession: AgentMeetingSession | undefined = undefined;
  @State sessions: AgentMeetingSession[] = [];
  @State messages: AgentMeetingMessage[] = [];
  private pollToken: number = 0;

  aboutToAppear(): void {
    const params = (router.getParams() as Record<string, string> | undefined) ?? {};
    const seededPrompt = params.prompt ?? '';
    if (seededPrompt.length > 0) {
      this.prompt = seededPrompt;
    }
    if (!authService.isLoggedIn()) {
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
    this.loadSessions();
  }

  aboutToDisappear(): void {
    this.pollToken += 1;
    this.polling = false;
  }

  private loadSessions(): void {
    agentMeetingService.list().then((items: AgentMeetingSession[]) => {
      this.sessions = items;
    }).catch((error: Error) => {
      this.statusText = error.message;
    });
  }

  private startMeeting(): void {
    const text = this.prompt.trim();
    if (text.length === 0) {
      this.statusText = '先写下想让大家讨论的问题。';
      return;
    }
    if (this.loading) {
      return;
    }
    if (this.currentSession !== undefined) {
      this.continueMeeting((this.currentSession as AgentMeetingSession).id, text);
      return;
    }
    this.loading = true;
    this.statusText = '正在拉起多角色组会...';
    agentMeetingService.create(text, this.meetingTitle(text)).then((session: AgentMeetingSession) => {
      this.currentSession = session;
      this.messages = [];
      this.prompt = '';
      this.statusText = '组会已开始，完成的意见会陆续出现。';
      this.loadSessions();
      this.startPolling(session.id);
    }).catch((error: Error) => {
      this.statusText = error.message.length > 0 ? error.message : '组会创建失败，请检查后端。';
    }).finally(() => {
      this.loading = false;
    });
  }

  private continueMeeting(sessionId: string, text: string): void {
    this.loading = true;
    this.statusText = '正在把追问加入本次组会...';
    agentMeetingService.continueSession(sessionId, text).then((session: AgentMeetingSession) => {
      this.currentSession = session;
      this.prompt = '';
      this.statusText = '追问已加入，新的意见会继续出现在当前组会里。';
      this.loadSessions();
      this.startPolling(session.id);
    }).catch((error: Error) => {
      this.statusText = error.message.length > 0 ? error.message : '追问发送失败，请稍后重试。';
    }).finally(() => {
      this.loading = false;
    });
  }

  private stopCurrentGeneration(): void {
    if (this.currentSession === undefined || this.loading) {
      return;
    }
    const sessionId = (this.currentSession as AgentMeetingSession).id;
    this.loading = true;
    this.statusText = '正在停止当前输出...';
    agentMeetingService.stop(sessionId).then((session: AgentMeetingSession) => {
      this.pollToken += 1;
      this.polling = false;
      this.currentSession = session;
      this.statusText = '已停止当前输出，可以继续追问。';
      this.fetchMessages(session.id, this.pollToken);
    }).catch((error: Error) => {
      this.statusText = error.message.length > 0 ? error.message : '停止失败，请稍后重试。';
    }).finally(() => {
      this.loading = false;
    });
  }

  private openSession(session: AgentMeetingSession): void {
    this.currentSession = session;
    this.statusText = '';
    this.startPolling(session.id);
  }

  private startPolling(sessionId: string): void {
    this.pollToken += 1;
    const token = this.pollToken;
    this.polling = true;
    this.fetchMessages(sessionId, token);
  }

  private fetchMessages(sessionId: string, token: number): void {
    if (token !== this.pollToken) {
      return;
    }
    agentMeetingService.messages(sessionId).then((bundle: AgentMeetingBundle) => {
      if (token !== this.pollToken) {
        return;
      }
      this.currentSession = bundle.session;
      this.messages = bundle.messages;
      if (this.isSessionFinished(bundle.session.status)) {
        this.polling = false;
        if (bundle.session.status === 'completed') {
          this.statusText = '本次组会已整理完成，可以继续追问。';
        } else if (bundle.session.status === 'partial') {
          this.statusText = '当前输出已收住，已有内容会保留，可以继续追问。';
        } else {
          this.statusText = '本次组会暂未整理完成，可以稍后重试或继续追问。';
        }
        this.loadSessions();
        return;
      }
      setTimeout(() => {
        this.fetchMessages(sessionId, token);
      }, 1200);
    }).catch((error: Error) => {
      this.polling = false;
      this.statusText = error.message;
    });
  }

  private isSessionFinished(status: string): boolean {
    return status === 'completed' || status === 'partial' || status === 'failed';
  }

  private meetingTitle(text: string): string {
    const first = text.split('\n')[0].trim();
    if (first.length <= 18) {
      return first.length > 0 ? first : '多角色组会';
    }
    return `${first.substring(0, 18)}...`;
  }

  private fillPrompt(text: string): void {
    this.prompt = text;
  }

  private newDiscussion(): void {
    this.pollToken += 1;
    this.polling = false;
    this.currentSession = undefined;
    this.messages = [];
    this.statusText = '已切换到新讨论。';
  }

  private statusLabel(status: string): string {
    if (status === 'completed') {
      return '已完成';
    }
    if (status === 'partial') {
      return '阶段结论';
    }
    if (status === 'failed') {
      return '需重试';
    }
    return '进行中';
  }

  private messageSubline(message: AgentMeetingMessage): string {
    if (message.role === 'user') {
      return message.round <= 0 ? '发起问题' : '继续追问';
    }
    if (message.role === 'coordinator' || message.agentName.indexOf('主持') >= 0) {
      return '综合已完成意见';
    }
    if (message.agentName.indexOf('补充') >= 0 || message.agentName.indexOf('写作') >= 0) {
      return '已参考前一轮意见';
    }
    if (message.contextVersionStarted > 1) {
      return '已参考前一轮意见';
    }
    return '同轮独立判断';
  }

  private visibleMessages(): AgentMeetingMessage[] {
    return this.messages.filter((item: AgentMeetingMessage) => {
      if (item.role === 'system') {
        return false;
      }
      if (item.role === 'user') {
        return item.content.trim().length > 0;
      }
      return item.status === 'done' && item.content.trim().length > 0;
    });
  }

  private isMineMessage(message: AgentMeetingMessage): boolean {
    return message.role === 'user';
  }

  private isAssistantRole(role: string): boolean {
    return role === 'assistant' || role === 'agent' || role === 'coordinator';
  }

  private activeNames(): string {
    const names: string[] = [];
    this.messages.forEach((item: AgentMeetingMessage) => {
      if (
        this.isAssistantRole(item.role) &&
        (item.status === 'pending' || item.status === 'running') &&
        names.indexOf(item.agentName) < 0
      ) {
        names.push(item.agentName);
      }
    });
    if (names.length === 0) {
      return this.polling ? '正在等待新的意见' : '可以发起新的讨论';
    }
    return `${names.join('、')}正在整理`;
  }

  private agentAccent(name: string): string {
    if (name.indexOf('导师') >= 0) {
      return AppColor.primary;
    }
    if (name.indexOf('评审') >= 0) {
      return AppColor.danger;
    }
    if (name.indexOf('实验') >= 0) {
      return AppColor.accent;
    }
    if (name.indexOf('文献') >= 0) {
      return AppColor.warning;
    }
    if (name.indexOf('写作') >= 0) {
      return '#7C3AED';
    }
    if (name.indexOf('主持') >= 0) {
      return AppColor.primaryStrong;
    }
    return AppColor.textSecondary;
  }

  @Builder
  private topBar(): void {
    Row() {
      Text('‹')
        .fontSize(30)
        .fontColor(AppColor.textTitle)
        .width(44)
        .textAlign(TextAlign.Start)
        .onClick(() => {
          router.back();
        });
      Column() {
        Text('多角色组会')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle);
        Text(this.activeNames())
          .fontSize(Font.caption)
          .fontColor(AppColor.textSecondary);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center);
      Text(this.currentSession === undefined ? '新讨论' : this.statusLabel((this.currentSession as AgentMeetingSession).status))
        .fontSize(Font.caption)
        .fontColor(AppColor.accentStrong)
        .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
        .backgroundColor(AppColor.accentSoft)
        .borderRadius(Radius.pill)
        .onClick(() => {
          if (this.currentSession !== undefined) {
            this.newDiscussion();
          }
        });
    }
    .width('100%')
    .padding({ left: Space.md, right: Space.md, top: Space.md, bottom: Space.sm })
    .backgroundColor(AppColor.surface);
  }

  @Builder
  private roleStrip(): void {
    Scroll() {
      Row({ space: Space.sm }) {
        this.roleChip('导师', '方向判断');
        this.roleChip('评审老师', '漏洞追问');
        this.roleChip('实验设计', '变量指标');
        this.roleChip('文献整理', '背景对比');
        this.roleChip('写作编辑', '日报表达');
        this.roleChip('主持总结', '收口建议');
      }
      .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm });
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .backgroundColor(AppColor.surface);
  }

  @Builder
  private roleChip(name: string, label: string): void {
    Row({ space: Space.xs }) {
      Text(name.substring(0, 1))
        .fontSize(Font.caption)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textOnPrimary)
        .width(22)
        .height(22)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.agentAccent(name))
        .borderRadius(Radius.pill);
      Column({ space: 1 }) {
        Text(name)
          .fontSize(Font.small)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textBody);
        Text(label)
          .fontSize(Font.caption)
          .fontColor(AppColor.textMuted);
      }
      .alignItems(HorizontalAlign.Start);
    }
    .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
    .backgroundColor(AppColor.surfaceSoft)
    .borderRadius(Radius.lg);
  }

  @Builder
  private shortcutPanel(): void {
    Column({ space: Space.sm }) {
      Row() {
        Text('常用入口')
          .fontSize(Font.body)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle);
        Blank();
        Text('先独立判断，再交叉整理')
          .fontSize(Font.caption)
          .fontColor(AppColor.textMuted);
      }
      .width('100%');
      Flex({ wrap: FlexWrap.Wrap }) {
        this.shortcutChip('这个想法能发展成课题吗？');
        this.shortcutChip('帮我从评审角度挑实验漏洞');
        this.shortcutChip('把这段灵感拆成实验方案');
        this.shortcutChip('帮我整理成组会汇报');
      }
      .width('100%');
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(AppColor.surface)
    .borderRadius(Radius.lg)
    .shadow(Elevation.card);
  }

  @Builder
  private shortcutChip(text: string): void {
    Text(text)
      .fontSize(Font.small)
      .fontColor(AppColor.accentStrong)
      .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
      .margin({ right: Space.sm, bottom: Space.sm })
      .backgroundColor(AppColor.accentSoft)
      .borderRadius(Radius.pill)
      .onClick(() => {
        this.fillPrompt(text);
      });
  }

  @Builder
  private historyPanel(): void {
    if (this.sessions.length > 0) {
      Column({ space: Space.sm }) {
        Text('最近组会')
          .fontSize(Font.body)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textTitle)
          .width('100%');
        Scroll() {
          Row({ space: Space.sm }) {
            ForEach(this.sessions, (session: AgentMeetingSession) => {
              this.sessionChip(session);
            }, (session: AgentMeetingSession) => session.id);
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off);
      }
      .width('100%');
    }
  }

  @Builder
  private sessionChip(session: AgentMeetingSession): void {
    Column({ space: Space.xs }) {
      Text(session.title)
        .fontSize(Font.small)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textBody)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(this.statusLabel(session.status))
        .fontSize(Font.caption)
        .fontColor(AppColor.textMuted);
    }
    .width(128)
    .padding(Space.sm)
    .backgroundColor(this.currentSession !== undefined && (this.currentSession as AgentMeetingSession).id === session.id ? AppColor.accentSoft : AppColor.surface)
    .borderRadius(Radius.lg)
    .onClick(() => {
      this.openSession(session);
    });
  }

  @Builder
  private messageBubble(message: AgentMeetingMessage): void {
    Row() {
      if (this.isMineMessage(message)) {
        Blank();
      } else {
        Text(message.agentName.substring(0, 1))
          .fontSize(Font.small)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textOnPrimary)
          .width(34)
          .height(34)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.agentAccent(message.agentName))
          .borderRadius(Radius.pill)
          .margin({ right: Space.sm });
      }
      Column({ space: Space.xs }) {
        if (!this.isMineMessage(message)) {
          Row({ space: Space.xs }) {
            Text(message.agentName)
              .fontSize(Font.caption)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.textSecondary);
            Text(this.messageSubline(message))
              .fontSize(Font.caption)
              .fontColor(AppColor.textMuted);
          }
        }
        Text(this.bubbleContent(message))
          .fontSize(Font.body)
          .lineHeight(22)
          .fontColor(this.isMineMessage(message) ? AppColor.textOnPrimary : AppColor.textBody)
          .padding(Space.md)
          .backgroundColor(this.isMineMessage(message) ? AppColor.primary : AppColor.surface)
          .borderRadius(Radius.lg)
          .constraintSize({ maxWidth: 290 });
      }
      .alignItems(this.isMineMessage(message) ? HorizontalAlign.End : HorizontalAlign.Start);
      if (!this.isMineMessage(message)) {
        Blank();
      }
    }
    .width('100%')
    .padding({ left: Space.md, right: Space.md, top: Space.xs, bottom: Space.xs });
  }

  private bubbleContent(message: AgentMeetingMessage): string {
    const content = message.content.trim();
    if (content.length > 0) {
      return content;
    }
    return '';
  }

  @Builder
  private messageList(): void {
    Column({ space: Space.sm }) {
      if (this.visibleMessages().length === 0) {
        Column({ space: Space.sm }) {
          Text('把一个选题、帖子启发、实验问题或日报草稿发进来。')
            .fontSize(Font.body)
            .fontColor(AppColor.textSecondary)
            .textAlign(TextAlign.Center);
          Text('系统会先让不同视角独立判断，再整理成一个可执行结论。')
            .fontSize(Font.small)
            .fontColor(AppColor.textMuted)
            .textAlign(TextAlign.Center);
        }
        .width('100%')
        .padding({ top: 40, bottom: 40 });
      } else {
        ForEach(this.visibleMessages(), (message: AgentMeetingMessage) => {
          this.messageBubble(message);
        }, (message: AgentMeetingMessage) => message.id.toString());
      }
    }
    .width('100%');
  }

  @Builder
  private inputBar(): void {
    Row({ space: Space.sm }) {
      TextArea({ placeholder: '输入要讨论的研究问题、灵感或日报草稿', text: this.prompt })
        .fontSize(Font.body)
        .fontColor(AppColor.textBody)
        .placeholderColor(AppColor.textMuted)
        .backgroundColor(AppColor.surfaceSoft)
        .borderRadius(Radius.lg)
        .height(56)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.prompt = value;
        });
      Text(this.loading ? '处理中' : (this.polling ? '停止' : (this.currentSession === undefined ? '发起' : '追问')))
        .fontSize(Font.body)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textOnPrimary)
        .width(72)
        .height(48)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.loading ? AppColor.textMuted : (this.polling ? AppColor.danger : AppColor.primary))
        .borderRadius(Radius.lg)
        .onClick(() => {
          if (this.polling) {
            this.stopCurrentGeneration();
          } else {
            this.startMeeting();
          }
        });
    }
    .width('100%')
    .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.md })
    .backgroundColor(AppColor.surface)
    .shadow(Elevation.card);
  }

  build() {
    Column() {
      this.topBar();
      this.roleStrip();
      Scroll() {
        Column({ space: Space.md }) {
          this.shortcutPanel();
          this.historyPanel();
          this.messageList();
          if (this.statusText.length > 0) {
            Text(this.statusText)
              .fontSize(Font.caption)
              .fontColor(AppColor.textMuted)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: Space.sm, bottom: Space.sm });
          }
        }
        .width('100%')
        .padding({ left: Space.md, right: Space.md, top: Space.md, bottom: Space.xl });
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off);
      this.inputBar();
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.bg);
  }
}
