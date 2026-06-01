from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime


@dataclass(slots=True)
class PaperRecord:
    id: str
    title: str
    authors: list[str]
    abstract: str
    url: str
    source: str
    publish_time: datetime
    category: str
    matched_keywords: list[str] = field(default_factory=list)
    section: str = "General"


@dataclass(slots=True)
class ProjectRecord:
    id: str
    name: str
    url: str
    description: str
    language: str
    stars: int
    source: str
    publish_time: datetime

