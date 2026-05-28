class BookmarkStore {
  private bookmarks: Set<string> = new Set<string>();

  has(id: string): boolean {
    return this.bookmarks.has(id);
  }

  toggle(id: string): boolean {
    if (this.bookmarks.has(id)) {
      this.bookmarks.delete(id);
      return false;
    }
    this.bookmarks.add(id);
    return true;
  }

  list(ids: string[]) {
    return ids.filter((id) => this.bookmarks.has(id));
  }
}

export const bookmarkStore = new BookmarkStore();
