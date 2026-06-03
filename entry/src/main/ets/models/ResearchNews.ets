export enum NewsCategory {
  ComputerScience = '计算机科学',
  Biology = '生物学',
  Materials = '材料科学',
  Medicine = '医学'
}

export interface ResearchNews {
  id: string;
  title: string;
  abstract: string;
  aiSummary: string;
  authors: string[];
  publishedDate: string;
  category: NewsCategory;
  doi?: string;
  sourceUrl: string;
}
