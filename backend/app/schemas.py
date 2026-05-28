from pydantic import BaseModel


class NewsItem(BaseModel):
    id: str
    title: str
    abstract: str
    ai_summary: str
    authors: list[str]
    published_date: str
    category: str
    doi: str | None = None
    source_url: str


class NewsListResponse(BaseModel):
    items: list[NewsItem]


class CategoryResponse(BaseModel):
    items: list[str]
