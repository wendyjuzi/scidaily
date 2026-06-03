from typing import List, Optional

from app.data import MOCK_NEWS
from app.schemas import NewsItem


def get_daily_news() -> List[NewsItem]:
    return MOCK_NEWS


def get_news_by_id(news_id: str) -> Optional[NewsItem]:
    return next((item for item in MOCK_NEWS if item.id == news_id), None)


def get_categories() -> List[str]:
    return ["计算机科学", "生物学", "材料科学", "医学"]
