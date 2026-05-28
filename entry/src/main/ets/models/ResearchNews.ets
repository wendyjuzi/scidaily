export enum NewsCategory {
  ComputerScience = 'Computer Science',
  Biology = 'Biology',
  Materials = 'Materials',
  Medicine = 'Medicine'
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
