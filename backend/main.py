from fastapi import FastAPI, HTTPException

from app.schemas import CategoryResponse, NewsItem, NewsListResponse
from app.services.news_service import get_categories, get_daily_news, get_news_by_id

app = FastAPI(title="SciDaily API", version="0.1.0")


@app.get("/api/v1/news/daily", response_model=NewsListResponse)
def daily_news():
    return NewsListResponse(items=get_daily_news())


@app.get("/api/v1/news/{news_id}", response_model=NewsItem)
def news_detail(news_id: str):
    item = get_news_by_id(news_id)
    if item is None:
        raise HTTPException(status_code=404, detail="News item not found")
    return item


@app.get("/api/v1/categories", response_model=CategoryResponse)
def categories():
    return CategoryResponse(items=get_categories())
