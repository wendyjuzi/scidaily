from __future__ import annotations

from research_daily.crawler.rss import fetch_feed
from research_daily.models import PaperRecord


def fetch_arxiv(categories: list[str], max_items_per_feed: int = 80) -> list[PaperRecord]:
    all_papers: list[PaperRecord] = []
    for category in categories:
        url = category if category.startswith("http") else f"https://export.arxiv.org/rss/{category}"
        all_papers.extend(
            fetch_feed(
                url=url,
                source="arXiv",
                category=category,
                max_items=max_items_per_feed,
            )
        )
    return all_papers

