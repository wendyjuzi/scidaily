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
    return [
      NewsCategory.ComputerScience,
      NewsCategory.Biology,
      NewsCategory.Materials,
      NewsCategory.Medicine
    ];
  }

  getById(id: string): ResearchNews | undefined {
    return MOCK_NEWS.find((item) => item.id === id);
  }

  getBookmarkedNews(): ResearchNews[] {
    const ids = bookmarkStore.list(MOCK_NEWS.map((item) => item.id));
    const result: ResearchNews[] = [];
    ids.forEach((id: string) => {
      const item = this.getById(id);
      if (item !== undefined) {
        result.push(item);
      }
    });
    return result;
  }

  toggleBookmark(id: string): boolean {
    return bookmarkStore.toggle(id);
  }

  setBookmark(id: string, active: boolean): void {
    if (active) {
      bookmarkStore.add(id);
      return;
    }
    bookmarkStore.remove(id);
  }

  isBookmarked(id: string): boolean {
    return bookmarkStore.has(id);
  }
}

export const newsService = new NewsService();
