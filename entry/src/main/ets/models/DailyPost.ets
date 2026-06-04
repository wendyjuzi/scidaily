export interface DailyTemplate {
  id: string;
  title: string;
  description: string;
  blocks: string[];
}

export interface TopicCategory {
  id: string;
  name: string;
  description: string;
  postCount: number;
}

export interface TopicTag {
  id: string;
  name: string;
  categoryId: string;
  categoryName: string;
  description: string;
  postCount: number;
}

export interface DailyPost {
  id: string;
  authorId: number;
  authorName: string;
  title: string;
  summary: string;
  content: string;
  coverUrl: string;
  imageUrls: string[];
  categoryId: string;
  categoryName: string;
  tags: string[];
  tagIds: string[];
  status: string;
  createdAt: string;
  updatedAt: string;
  publishedAt?: string;
}

export interface DailyPostDraft {
  id?: string;
  title: string;
  summary: string;
  content: string;
  coverUrl: string;
  imageUrls: string[];
  categoryId: string;
  tagIds: string[];
  status: string;
}
