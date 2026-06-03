export interface UserProfile {
  id: number;
  username: string;
  nickname: string;
  avatarUrl: string;
  email: string;
  bio: string;
  institution: string;
  researchField: string;
  createdAt: string;
}

export interface AuthSession {
  token: string;
  user: UserProfile;
}

export interface PersonalStats {
  postCount: number;
  collectionCount: number;
  likeCount: number;
  historyCount: number;
  continuousDays: number;
}

export interface PersonalItem {
  id: string;
  title: string;
  summary: string;
  createdAt: string;
  status: string;
}

export interface PrivacySettings {
  showEmail: boolean;
  showResearchStats: boolean;
  allowRecommendations: boolean;
}

export interface MessageSettings {
  likeNotice: boolean;
  commentNotice: boolean;
  systemNotice: boolean;
}

export interface SettingsBundle {
  privacy: PrivacySettings;
  messages: MessageSettings;
}

export interface ProfileUpdatePayload {
  nickname: string;
  avatarUrl: string;
  email: string;
  bio: string;
  institution: string;
  researchField: string;
}
