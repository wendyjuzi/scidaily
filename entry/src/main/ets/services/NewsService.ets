import { MOCK_NEWS } from '../data/mockNews';
import { NewsCategory, ResearchNews } from '../models/ResearchNews';
import { bookmarkStore } from './BookmarkStore';

class NewsService {
  getDailyNews(category?: NewsCategory): ResearchNews[] {
    if (!category) {
      return MOCK_NEWS;
    }
    return MOCK_NEWS.filter((item) => item.category === category);
  }

  getCategories(): NewsCategory[] {
    return Object.values(NewsCategory);
  }

  getById(id: string): ResearchNews | undefined {
    return MOCK_NEWS.find((item) => item.id === id);
  }

  getBookmarkedNews(): ResearchNews[] {
    const ids = bookmarkStore.list(MOCK_NEWS.map((item) => item.id));
    return ids
      .map((id) => this.getById(id))
      .filter((item): item is ResearchNews => item !== undefined);
  }

  toggleBookmark(id: string): boolean {
    return bookmarkStore.toggle(id);
  }

  isBookmarked(id: string): boolean {
    return bookmarkStore.has(id);
  }
}

export const newsService = new NewsService();
