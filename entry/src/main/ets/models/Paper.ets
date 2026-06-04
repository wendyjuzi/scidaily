export interface PaperItem {
  id: string;
  title: string;
  abstract: string;
  authors: string[];
  categoryId: string;
  categoryName: string;
  tags: string[];
  tagIds: string[];
  sourceUrl: string;
  pdfUrl: string;
  localPdfPath?: string;
  doi?: string;
  publishedAt: string;
  createdAt: string;
}

export interface PaperPage {
  items: PaperItem[];
  nextOffset: number;
  hasMore: boolean;
}

export interface ReadingProgress {
  paperId: string;
  currentPage: number;
  progress: number;
  updatedAt: string;
}
