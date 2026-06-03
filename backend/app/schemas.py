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
