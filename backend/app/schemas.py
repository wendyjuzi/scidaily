from typing import List, Optional

from pydantic import BaseModel, Field


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


class AiChatMessage(BaseModel):
    role: str
    content: str


class AiWorkbenchRequest(BaseModel):
    mode: str
    prompt: str
    history: List[AiChatMessage] = Field(default_factory=list)


class AiWorkbenchResponse(BaseModel):
    mode: str
    title: str
    answer: str
    source: str


class AiCreatorRequest(BaseModel):
    mode: str
    prompt: str
    title: Optional[str] = None
    summary: Optional[str] = None
    content: Optional[str] = None
    category_name: Optional[str] = None
    tags: List[str] = Field(default_factory=list)
    paper_title: Optional[str] = None
    paper_abstract: Optional[str] = None
    paper_doi: Optional[str] = None
    paper_source_url: Optional[str] = None
    paper_pdf_url: Optional[str] = None


class AiCreatorResponse(BaseModel):
    mode: str
    title: str
    summary: str
    content: str
    tags: List[str]
    topic: str
    note: str
    source: str


class ImageUploadRequest(BaseModel):
    filename: str
    content_base64: str


class ImageUploadResponse(BaseModel):
    url: str


class PdfUploadRequest(BaseModel):
    filename: str
    content_base64: str


class PdfUploadResponse(BaseModel):
    url: str


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


class DailyTemplate(BaseModel):
    id: str
    title: str
    description: str
    blocks: List[str]


class DailyPostBase(BaseModel):
    title: str
    summary: str
    content: str
    cover_url: Optional[str] = None
    image_urls: List[str] = []
    category_id: str
    tag_ids: List[str] = []


class DailyPostCreateRequest(DailyPostBase):
    status: str = "draft"


class DailyPostUpdateRequest(BaseModel):
    title: Optional[str] = None
    summary: Optional[str] = None
    content: Optional[str] = None
    cover_url: Optional[str] = None
    image_urls: Optional[List[str]] = None
    category_id: Optional[str] = None
    tag_ids: Optional[List[str]] = None
    status: Optional[str] = None


class DailyPost(BaseModel):
    id: str
    author_id: int
    author_name: str
    title: str
    summary: str
    content: str
    cover_url: str
    image_urls: List[str]
    category_id: str
    category_name: str
    tags: List[str]
    tag_ids: List[str]
    status: str
    created_at: str
    updated_at: str
    published_at: Optional[str] = None


class DailyPostListResponse(BaseModel):
    items: List[DailyPost]
    next_offset: int
    has_more: bool


class DailyPostResponse(BaseModel):
    item: DailyPost


class TopicCategory(BaseModel):
    id: str
    name: str
    description: str
    post_count: int = 0


class TopicCategoryRequest(BaseModel):
    id: Optional[str] = None
    name: str
    description: Optional[str] = None


class TopicTag(BaseModel):
    id: str
    name: str
    category_id: str
    category_name: str
    description: str
    post_count: int = 0


class TopicTagRequest(BaseModel):
    id: Optional[str] = None
    name: str
    category_id: str
    description: Optional[str] = None


class TopicCategoryListResponse(BaseModel):
    items: List[TopicCategory]


class TopicTagListResponse(BaseModel):
    items: List[TopicTag]


class PaperItem(BaseModel):
    id: str
    title: str
    abstract: str
    authors: List[str]
    category_id: str
    category_name: str
    tags: List[str]
    tag_ids: List[str]
    source_url: str
    pdf_url: str
    local_pdf_path: Optional[str] = None
    doi: Optional[str] = None
    published_at: str
    created_at: str


class PaperCreateRequest(BaseModel):
    title: str
    abstract: str
    authors: List[str]
    category_id: str
    tag_ids: List[str] = []
    source_url: str
    pdf_url: str
    local_pdf_path: Optional[str] = None
    doi: Optional[str] = None
    published_at: str


class PaperListResponse(BaseModel):
    items: List[PaperItem]
    next_offset: int
    has_more: bool


class ReadingProgress(BaseModel):
    paper_id: str
    current_page: int
    progress: float
    updated_at: str


class ReadingProgressRequest(BaseModel):
    current_page: int
    progress: float


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
