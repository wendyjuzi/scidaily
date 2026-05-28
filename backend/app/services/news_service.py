from app.data import MOCK_NEWS
from app.schemas import NewsItem


def get_daily_news() -> list[NewsItem]:
    return MOCK_NEWS


def get_news_by_id(news_id: str) -> NewsItem | None:
    return next((item for item in MOCK_NEWS if item.id == news_id), None)


def get_categories() -> list[str]:
    return ["Computer Science", "Biology", "Materials", "Medicine"]
