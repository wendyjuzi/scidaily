export interface InteractionSummary {
  likeCount: number;
  collectionCount: number;
  commentCount: number;
}

export interface CommentItem {
  id: number;
  newsId: string;
  userId: number;
  nickname: string;
  content: string;
  parentId?: number;
  replyToNickname?: string;
  likeCount: number;
  createdAt: string;
}

export interface ResearchStatsPoint {
  label: string;
  dailyCount: number;
  experimentCount: number;
  literatureCount: number;
}

export interface ResearchStatsBundle {
  range: string;
  totalDaily: number;
  totalExperiment: number;
  totalLiterature: number;
  points: ResearchStatsPoint[];
}

export interface NotificationItem {
  id: number;
  type: string;
  title: string;
  content: string;
  relatedItemId?: string;
  isRead: boolean;
  createdAt: string;
}

export interface NotificationBundle {
  items: NotificationItem[];
  unreadCount: number;
}
