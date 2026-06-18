export interface InspirationItem {
  id: string;
  content: string;
  scene: string;
  source: string;
  status: string;
  createdAt: string;
  updatedAt: string;
}

export interface InspirationDraft {
  title: string;
  summary: string;
  content: string;
  categoryId: string;
  tagIds: string[];
}
