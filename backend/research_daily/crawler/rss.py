from __future__ import annotations

from datetime import datetime
from email.utils import parsedate_to_datetime
from typing import Any

import feedparser
import requests

from research_daily.models import PaperRecord


def _parse_time(entry: dict[str, Any]) -> datetime:
    if "published" in entry:
        try:
            return parsedate_to_datetime(entry["published"])
        except (TypeError, ValueError):
            pass
    if "updated" in entry:
        try:
            return parsedate_to_datetime(entry["updated"])
        except (TypeError, ValueError):
            pass
    return datetime.now()


def fetch_feed(url: str, source: str, category: str, max_items: int = 80) -> list[PaperRecord]:
    try:
        resp = requests.get(url, timeout=20, headers={"User-Agent": "Mozilla/5.0"})
        resp.raise_for_status()
        feed = feedparser.parse(resp.text)
    except requests.RequestException:
        feed = feedparser.parse(url)
    papers: list[PaperRecord] = []
    for entry in feed.entries[:max_items]:
        paper_id = (
            entry.get("id")
            or entry.get("arxiv_id")
            or entry.get("link", "").rstrip("/").split("/")[-1]
            or entry.get("title", "").strip().lower().replace(" ", "-")
        )
        authors = [a.get("name", "").strip() for a in entry.get("authors", []) if a.get("name")]
        abstract = (entry.get("summary") or entry.get("description") or "").strip()
        papers.append(
            PaperRecord(
                id=str(paper_id),
                title=(entry.get("title") or "").strip(),
                authors=authors,
                abstract=abstract,
                url=(entry.get("link") or "").strip(),
                source=source,
                publish_time=_parse_time(entry),
                category=category,
            )
        )
    return papers
