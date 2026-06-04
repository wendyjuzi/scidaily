from typing import List, Optional

from pydantic import BaseModel


class NewsItem(BaseModel):
    id: str
    title: str
    abstract: str
    ai_summary: str
    authors: List[str]
    published_date: str
    category: str
    doi: Optional[str] = None
    source_url: str


class NewsListResponse(BaseModel):
    items: List[NewsItem]


class CategoryResponse(BaseModel):
    items: List[str]


class ApiMessage(BaseModel):
    message: str


class RegisterRequest(BaseModel):
    username: str
    password: str
    nickname: Optional[str] = None
    email: Optional[str] = None


class LoginRequest(BaseModel):
    username: str
    password: str


class UserProfile(BaseModel):
    id: int
    username: str
    nickname: str
    avatar_url: str
    email: Optional[str] = None
    bio: str
    institution: str
    research_field: str
    created_at: str


class AuthResponse(BaseModel):
    token: str
    user: UserProfile


class UserListResponse(BaseModel):
    items: List[UserProfile]


class UserUpdateRequest(BaseModel):
    nickname: Optional[str] = None
    avatar_url: Optional[str] = None
    email: Optional[str] = None
    bio: Optional[str] = None
    institution: Optional[str] = None
    research_field: Optional[str] = None


class PasswordResetRequest(BaseModel):
    old_password: Optional[str] = None
    new_password: str


class PrivacySettings(BaseModel):
    show_email: bool
    show_research_stats: bool
    allow_recommendations: bool


class MessageSettings(BaseModel):
    like_notice: bool
    comment_notice: bool
    system_notice: bool


class SettingsResponse(BaseModel):
    privacy: PrivacySettings
    messages: MessageSettings


class PersonalStats(BaseModel):
    post_count: int
    collection_count: int
    like_count: int
    history_count: int
    continuous_days: int


class PersonalItem(BaseModel):
    id: str
    title: str
    summary: str
    created_at: str
    status: Optional[str] = None


class PersonalListResponse(BaseModel):
    items: List[PersonalItem]


class PersonalItemActionRequest(BaseModel):
    item_id: str
    title: str
    summary: str


class InteractionState(BaseModel):
    active: bool


class InteractionSummary(BaseModel):
    like_count: int
    collection_count: int
    comment_count: int


class CommentCreateRequest(BaseModel):
    content: str
    parent_id: Optional[int] = None


class CommentItem(BaseModel):
    id: int
    news_id: str
    user_id: int
    nickname: str
    content: str
    parent_id: Optional[int] = None
    reply_to_nickname: Optional[str] = None
    like_count: int
    created_at: str


class CommentListResponse(BaseModel):
    items: List[CommentItem]
    total: int
    page: int
    size: int


class ResearchStatsPoint(BaseModel):
    label: str
    daily_count: int
    experiment_count: int
    literature_count: int


class ResearchStatsResponse(BaseModel):
    range: str
    total_daily: int
    total_experiment: int
    total_literature: int
    points: List[ResearchStatsPoint]


class NotificationItem(BaseModel):
    id: int
    type: str
    title: str
    content: str
    related_item_id: Optional[str] = None
    is_read: bool
    created_at: str


class NotificationListResponse(BaseModel):
    items: List[NotificationItem]
    unread_count: int
