import base64
import re
import secrets
from pathlib import Path
from typing import List, Optional

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.dependencies import get_current_user
from app.schemas import (
    AgentMessageListResponse,
    AgentSessionCreateRequest,
    AgentSessionListResponse,
    AgentSessionResponse,
    ApiMessage,
    AiCreatorRequest,
    AiCreatorResponse,
    AiWorkbenchRequest,
    AiWorkbenchResponse,
    AuthResponse,
    CategoryResponse,
    CommentCreateRequest,
    CommentItem,
    CommentListResponse,
    InteractionSummary,
    DailyPost,
    DailyPostCreateRequest,
    DailyPostListResponse,
    DailyPostResponse,
    DailyPostUpdateRequest,
    DailyTemplate,
    ImageUploadRequest,
    ImageUploadResponse,
    InspirationCreateRequest,
    InspirationDraftResponse,
    InspirationItem,
    InspirationListResponse,
    InspirationUpdateRequest,
    LoginRequest,
    MessageSettings,
    NewsItem,
    NewsListResponse,
    NotificationListResponse,
    PaperCreateRequest,
    PaperItem,
    PaperListResponse,
    PasswordResetRequest,
    PdfUploadRequest,
    PdfUploadResponse,
    PostInspirationRequest,
    PostInspirationResponse,
    InteractionState,
    PersonalItem,
    PersonalItemActionRequest,
    PersonalListResponse,
    PersonalStats,
    PrivacySettings,
    RegisterRequest,
    ReadingProgress,
    ReadingProgressRequest,
    ResearchStatsResponse,
    SettingsResponse,
    TopicCategory,
    TopicCategoryListResponse,
    TopicCategoryRequest,
    TopicTag,
    TopicTagListResponse,
    TopicTagRequest,
    UserListResponse,
    UserProfile,
    UserUpdateRequest,
)
from app.services.ai_service import (
    AiProviderError,
    ai_mode_title,
    generate_creator_result,
    generate_post_inspiration,
    generate_workbench_answer,
)
from app.services.agent_service import AgentCoordinator
from app.services.news_service import get_categories, get_daily_news, get_news_by_id
from app.storage import store

app = FastAPI(title="SciDaily API", version="0.2.0")
agent_coordinator = AgentCoordinator(store)
UPLOAD_DIR = Path(__file__).resolve().parent / "data" / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def bearer_token_from_request(request: Request) -> str:
    authorization = request.headers.get("authorization", "")
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Login required")
    return authorization[len("Bearer "):].strip()


def bad_request(error: ValueError) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))


def image_extension(filename: str) -> str:
    safe_name = re.sub(r"[^a-zA-Z0-9_.-]+", "_", filename.strip())
    suffix = Path(safe_name).suffix.lower()
    if suffix not in [".jpg", ".jpeg", ".png", ".webp", ".gif"]:
        raise ValueError("Unsupported image type")
    return suffix


def pdf_extension(filename: str) -> str:
    safe_name = re.sub(r"[^a-zA-Z0-9_.-]+", "_", filename.strip())
    suffix = Path(safe_name).suffix.lower()
    if suffix != ".pdf":
        raise ValueError("Unsupported PDF type")
    return suffix


def decode_image_content(content_base64: str) -> bytes:
    if len(content_base64) > 16_000_000:
        raise ValueError("Image is too large")
    if "," in content_base64 and content_base64.split(",", 1)[0].startswith("data:image/"):
        content_base64 = content_base64.split(",", 1)[1]
    try:
        return base64.b64decode(content_base64, validate=True)
    except ValueError as exc:
        raise ValueError("Invalid image content") from exc


def decode_pdf_content(content_base64: str) -> bytes:
    if len(content_base64) > 40_000_000:
        raise ValueError("PDF is too large")
    if "," in content_base64 and content_base64.split(",", 1)[0].startswith("data:application/pdf"):
        content_base64 = content_base64.split(",", 1)[1]
    try:
        data = base64.b64decode(content_base64, validate=True)
    except ValueError as exc:
        raise ValueError("Invalid PDF content") from exc
    if not data.startswith(b"%PDF"):
        raise ValueError("Invalid PDF content")
    return data


@app.get("/api/v1/health", response_model=ApiMessage)
def health():
    return ApiMessage(message="SciDaily API is running")


@app.post("/api/v1/ai/workbench", response_model=AiWorkbenchResponse)
def ai_workbench(payload: AiWorkbenchRequest):
    try:
        title = ai_mode_title(payload.mode)
        history = [{"role": item.role, "content": item.content} for item in payload.history]
        answer = generate_workbench_answer(payload.mode, payload.prompt, history)
    except ValueError as exc:
        raise bad_request(exc) from exc
    except AiProviderError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc
    return AiWorkbenchResponse(
        mode=payload.mode,
        title=title,
        answer=answer,
        source="AI 生成",
    )


@app.post("/api/v1/ai/creator", response_model=AiCreatorResponse)
def ai_creator(payload: AiCreatorRequest):
    try:
        result = generate_creator_result(payload.mode, payload.prompt, {
            "title": payload.title or "",
            "summary": payload.summary or "",
            "content": payload.content or "",
            "category_name": payload.category_name or "",
            "tags": payload.tags,
            "paper_title": payload.paper_title or "",
            "paper_abstract": payload.paper_abstract or "",
            "paper_doi": payload.paper_doi or "",
            "paper_source_url": payload.paper_source_url or "",
            "paper_pdf_url": payload.paper_pdf_url or "",
        })
    except ValueError as exc:
        raise bad_request(exc) from exc
    except AiProviderError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc
    return AiCreatorResponse(
        mode=payload.mode,
        title=result["title"],
        summary=result["summary"],
        content=result["content"],
        tags=result["tags"],
        topic=result["topic"],
        note=result["note"],
        source="AI 生成",
    )


@app.post("/api/v1/agent-sessions", response_model=AgentSessionResponse, status_code=status.HTTP_201_CREATED)
def create_agent_session(
    payload: AgentSessionCreateRequest,
    current_user: UserProfile = Depends(get_current_user),
):
    try:
        session = store.create_agent_session(
            current_user.id,
            payload.title or "",
            payload.prompt,
            payload.source_type or "",
            payload.source_id or "",
        )
    except ValueError as exc:
        raise bad_request(exc) from exc
    agent_coordinator.start_session(session)
    return AgentSessionResponse(item=session)


@app.get("/api/v1/agent-sessions", response_model=AgentSessionListResponse)
def list_agent_sessions(current_user: UserProfile = Depends(get_current_user)):
    return AgentSessionListResponse(items=store.list_agent_sessions(current_user.id))


@app.get("/api/v1/agent-sessions/{session_id}/messages", response_model=AgentMessageListResponse)
def list_agent_session_messages(
    session_id: str,
    current_user: UserProfile = Depends(get_current_user),
):
    try:
        session = store.get_agent_session(current_user.id, session_id)
        messages = store.list_agent_messages(current_user.id, session_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return AgentMessageListResponse(session=session, messages=messages)


@app.get("/api/v1/news/daily", response_model=NewsListResponse)
def daily_news():
    return NewsListResponse(items=get_daily_news())


@app.get("/api/v1/news/{news_id}", response_model=NewsItem)
def news_detail(news_id: str):
    item = get_news_by_id(news_id)
    if item is None:
        raise HTTPException(status_code=404, detail="News item not found")
    return item


@app.get("/api/v1/news/{news_id}/interactions", response_model=InteractionSummary)
def news_interactions(news_id: str):
    return store.get_interaction_summary(news_id)


@app.get("/api/v1/news/{news_id}/comments", response_model=CommentListResponse)
def news_comments(news_id: str, page: int = 1, size: int = 20, sort: str = "latest"):
    return store.list_comments(news_id, page=page, size=size, sort=sort)


@app.post("/api/v1/news/{news_id}/comments", response_model=CommentItem, status_code=status.HTTP_201_CREATED)
def add_news_comment(
    news_id: str,
    payload: CommentCreateRequest,
    current_user: UserProfile = Depends(get_current_user),
):
    try:
        return store.add_comment(news_id, current_user.id, payload)
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.delete("/api/v1/comments/{comment_id}", response_model=ApiMessage)
def delete_news_comment(comment_id: int, current_user: UserProfile = Depends(get_current_user)):
    try:
        store.delete_comment(comment_id, current_user.id)
    except ValueError as exc:
        raise bad_request(exc) from exc
    return ApiMessage(message="Comment deleted")


@app.post("/api/v1/comments/{comment_id}/like", response_model=CommentItem)
def like_news_comment(comment_id: int, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.like_comment(comment_id, current_user.id)
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.delete("/api/v1/comments/{comment_id}/like", response_model=CommentItem)
def unlike_news_comment(comment_id: int, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.unlike_comment(comment_id, current_user.id)
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.get("/api/v1/categories", response_model=CategoryResponse)
def categories():
    return CategoryResponse(items=get_categories())


@app.get("/api/v1/daily-posts", response_model=DailyPostListResponse)
def list_daily_posts(
    category_id: Optional[str] = None,
    tag_id: Optional[str] = None,
    limit: int = 20,
    offset: int = 0,
):
    items, next_offset, has_more = store.list_daily_posts(
        status_filter="published",
        category_id=category_id,
        tag_id=tag_id,
        limit=limit,
        offset=offset,
    )
    return DailyPostListResponse(items=items, next_offset=next_offset, has_more=has_more)


@app.get("/api/v1/daily-posts/templates", response_model=List[DailyTemplate])
def daily_templates():
    return store.list_daily_templates()


@app.post("/api/v1/uploads/images", response_model=ImageUploadResponse, status_code=status.HTTP_201_CREATED)
def upload_image(payload: ImageUploadRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        extension = image_extension(payload.filename)
        image_bytes = decode_image_content(payload.content_base64)
    except ValueError as exc:
        raise bad_request(exc) from exc
    filename = f"u{current_user.id}-{secrets.token_hex(12)}{extension}"
    target = UPLOAD_DIR / filename
    target.write_bytes(image_bytes)
    return ImageUploadResponse(url=f"/uploads/{filename}")


@app.post("/api/v1/uploads/pdfs", response_model=PdfUploadResponse, status_code=status.HTTP_201_CREATED)
def upload_pdf(payload: PdfUploadRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        extension = pdf_extension(payload.filename)
        pdf_bytes = decode_pdf_content(payload.content_base64)
    except ValueError as exc:
        raise bad_request(exc) from exc
    filename = f"u{current_user.id}-{secrets.token_hex(12)}{extension}"
    target = UPLOAD_DIR / filename
    target.write_bytes(pdf_bytes)
    return PdfUploadResponse(url=f"/uploads/{filename}")


@app.get("/api/v1/daily-posts/{post_id}", response_model=DailyPost)
def daily_post_detail(post_id: str):
    try:
        return store.get_daily_post(post_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@app.get("/api/v1/papers", response_model=PaperListResponse)
def list_papers(
    category_id: Optional[str] = None,
    tag_id: Optional[str] = None,
    limit: int = 20,
    offset: int = 0,
):
    items, next_offset, has_more = store.list_papers(
        category_id=category_id,
        tag_id=tag_id,
        limit=limit,
        offset=offset,
    )
    return PaperListResponse(items=items, next_offset=next_offset, has_more=has_more)


@app.post("/api/v1/papers", response_model=PaperItem, status_code=status.HTTP_201_CREATED)
def create_paper(payload: PaperCreateRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.create_paper(payload)
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.get("/api/v1/papers/{paper_id}", response_model=PaperItem)
def paper_detail(paper_id: str):
    try:
        return store.get_paper(paper_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@app.get("/api/v1/papers/{paper_id}/progress", response_model=ReadingProgress)
def paper_progress(paper_id: str, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.get_reading_progress(current_user.id, paper_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@app.put("/api/v1/papers/{paper_id}/progress", response_model=ReadingProgress)
def update_paper_progress(paper_id: str, payload: ReadingProgressRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.update_reading_progress(current_user.id, paper_id, payload)
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.get("/api/v1/topics/categories", response_model=TopicCategoryListResponse)
def topic_categories():
    return TopicCategoryListResponse(items=store.list_topic_categories())


@app.post("/api/v1/topics/categories", response_model=TopicCategory, status_code=status.HTTP_201_CREATED)
def create_topic_category(payload: TopicCategoryRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.create_topic_category(payload)
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.put("/api/v1/topics/categories/{category_id}", response_model=TopicCategory)
def update_topic_category(category_id: str, payload: TopicCategoryRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.update_topic_category(category_id, payload)
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.delete("/api/v1/topics/categories/{category_id}", response_model=ApiMessage)
def delete_topic_category(category_id: str, current_user: UserProfile = Depends(get_current_user)):
    try:
        store.delete_topic_category(category_id)
    except ValueError as exc:
        raise bad_request(exc) from exc
    return ApiMessage(message="Category deleted")


@app.get("/api/v1/topics/tags", response_model=TopicTagListResponse)
def topic_tags(category_id: Optional[str] = None):
    return TopicTagListResponse(items=store.list_topic_tags(category_id))


@app.post("/api/v1/topics/tags", response_model=TopicTag, status_code=status.HTTP_201_CREATED)
def create_topic_tag(payload: TopicTagRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.create_topic_tag(payload)
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.put("/api/v1/topics/tags/{tag_id}", response_model=TopicTag)
def update_topic_tag(tag_id: str, payload: TopicTagRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.update_topic_tag(tag_id, payload)
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.delete("/api/v1/topics/tags/{tag_id}", response_model=ApiMessage)
def delete_topic_tag(tag_id: str, current_user: UserProfile = Depends(get_current_user)):
    try:
        store.delete_topic_tag(tag_id)
    except ValueError as exc:
        raise bad_request(exc) from exc
    return ApiMessage(message="Tag deleted")


@app.get("/api/v1/topics/tags/{tag_id}/posts", response_model=DailyPostListResponse)
def topic_tag_posts(tag_id: str, limit: int = 20, offset: int = 0):
    items, next_offset, has_more = store.list_daily_posts(
        status_filter="published",
        tag_id=tag_id,
        limit=limit,
        offset=offset,
    )
    return DailyPostListResponse(items=items, next_offset=next_offset, has_more=has_more)


@app.post("/api/v1/auth/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest):
    try:
        user = store.create_user(payload)
    except ValueError as exc:
        raise bad_request(exc) from exc
    token = store.create_session(user.id)
    return AuthResponse(token=token, user=user)


@app.post("/api/v1/auth/login", response_model=AuthResponse)
def login(payload: LoginRequest):
    user = store.authenticate(payload.username, payload.password)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid username or password")
    token = store.create_session(user.id)
    return AuthResponse(token=token, user=user)


@app.post("/api/v1/auth/logout", response_model=ApiMessage)
def logout(request: Request, current_user: UserProfile = Depends(get_current_user)):
    token = bearer_token_from_request(request)
    store.delete_session(token)
    return ApiMessage(message=f"{current_user.nickname} logged out")


@app.get("/api/v1/users", response_model=UserListResponse)
def list_users(current_user: UserProfile = Depends(get_current_user)):
    return UserListResponse(items=store.list_users())


@app.get("/api/v1/users/me", response_model=UserProfile)
def my_profile(current_user: UserProfile = Depends(get_current_user)):
    return current_user


@app.put("/api/v1/users/me", response_model=UserProfile)
def update_my_profile(payload: UserUpdateRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.update_user(current_user.id, payload)
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.put("/api/v1/users/me/password", response_model=ApiMessage)
def reset_my_password(payload: PasswordResetRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        store.update_password(current_user.id, payload.old_password, payload.new_password)
    except ValueError as exc:
        raise bad_request(exc) from exc
    return ApiMessage(message="Password updated. Please log in again.")


@app.get("/api/v1/users/me/settings", response_model=SettingsResponse)
def my_settings(current_user: UserProfile = Depends(get_current_user)):
    return store.get_settings(current_user.id)


@app.put("/api/v1/users/me/settings/privacy", response_model=SettingsResponse)
def update_my_privacy(settings: PrivacySettings, current_user: UserProfile = Depends(get_current_user)):
    return store.update_privacy_settings(current_user.id, settings)


@app.put("/api/v1/users/me/settings/messages", response_model=SettingsResponse)
def update_my_messages(settings: MessageSettings, current_user: UserProfile = Depends(get_current_user)):
    return store.update_message_settings(current_user.id, settings)


@app.get("/api/v1/users/me/stats", response_model=PersonalStats)
def my_stats(current_user: UserProfile = Depends(get_current_user)):
    return store.get_stats(current_user.id)


@app.get("/api/v1/users/me/research-stats", response_model=ResearchStatsResponse)
def my_research_stats(range: str = "week", current_user: UserProfile = Depends(get_current_user)):
    if range not in ("day", "week", "month"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported range")
    return store.get_research_stats(current_user.id, range)


@app.get("/api/v1/users/me/posts", response_model=PersonalListResponse)
def my_posts(current_user: UserProfile = Depends(get_current_user)):
    return PersonalListResponse(items=store.get_personal_items("posts", current_user.id))


@app.get("/api/v1/users/me/daily-posts", response_model=DailyPostListResponse)
def my_daily_posts(status_filter: str = "all", limit: int = 50, offset: int = 0, current_user: UserProfile = Depends(get_current_user)):
    items, next_offset, has_more = store.list_daily_posts(
        status_filter=status_filter,
        limit=limit,
        offset=offset,
        author_id=current_user.id,
    )
    return DailyPostListResponse(items=items, next_offset=next_offset, has_more=has_more)


@app.post("/api/v1/users/me/daily-posts", response_model=DailyPostResponse, status_code=status.HTTP_201_CREATED)
def create_my_daily_post(payload: DailyPostCreateRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return DailyPostResponse(item=store.create_daily_post(current_user.id, payload))
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.put("/api/v1/users/me/daily-posts/{post_id}", response_model=DailyPostResponse)
def update_my_daily_post(post_id: str, payload: DailyPostUpdateRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return DailyPostResponse(item=store.update_daily_post(current_user.id, post_id, payload))
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.post("/api/v1/users/me/daily-posts/{post_id}/publish", response_model=DailyPostResponse)
def publish_my_daily_post(post_id: str, current_user: UserProfile = Depends(get_current_user)):
    try:
        return DailyPostResponse(item=store.publish_daily_post(current_user.id, post_id))
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.delete("/api/v1/users/me/daily-posts/{post_id}", response_model=ApiMessage)
def delete_my_daily_post(post_id: str, current_user: UserProfile = Depends(get_current_user)):
    try:
        store.delete_daily_post(current_user.id, post_id)
    except ValueError as exc:
        raise bad_request(exc) from exc
    return ApiMessage(message="Daily post deleted")


@app.get("/api/v1/users/me/collections", response_model=PersonalListResponse)
def my_collections(current_user: UserProfile = Depends(get_current_user)):
    return PersonalListResponse(items=store.get_personal_items("collections", current_user.id))


@app.get("/api/v1/users/me/collections/{item_id}/state", response_model=InteractionState)
def my_collection_state(item_id: str, current_user: UserProfile = Depends(get_current_user)):
    return InteractionState(active=store.has_personal_item("collections", current_user.id, item_id))


@app.post("/api/v1/users/me/collections", response_model=PersonalItem)
def add_my_collection(payload: PersonalItemActionRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.add_personal_item("collections", current_user.id, payload, "已收藏")
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.delete("/api/v1/users/me/collections/{item_id}", response_model=ApiMessage)
def remove_my_collection(item_id: str, current_user: UserProfile = Depends(get_current_user)):
    store.remove_personal_item("collections", current_user.id, item_id)
    return ApiMessage(message="Collection removed")


@app.get("/api/v1/users/me/likes", response_model=PersonalListResponse)
def my_likes(current_user: UserProfile = Depends(get_current_user)):
    return PersonalListResponse(items=store.get_personal_items("likes", current_user.id))


@app.get("/api/v1/users/me/likes/{item_id}/state", response_model=InteractionState)
def my_like_state(item_id: str, current_user: UserProfile = Depends(get_current_user)):
    return InteractionState(active=store.has_personal_item("likes", current_user.id, item_id))


@app.post("/api/v1/users/me/likes", response_model=PersonalItem)
def add_my_like(payload: PersonalItemActionRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.add_personal_item("likes", current_user.id, payload, "已点赞")
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.delete("/api/v1/users/me/likes/{item_id}", response_model=ApiMessage)
def remove_my_like(item_id: str, current_user: UserProfile = Depends(get_current_user)):
    store.remove_personal_item("likes", current_user.id, item_id)
    return ApiMessage(message="Like removed")


@app.get("/api/v1/users/me/follows", response_model=PersonalListResponse)
def my_follows(current_user: UserProfile = Depends(get_current_user)):
    return PersonalListResponse(items=store.get_personal_items("follows", current_user.id))


@app.get("/api/v1/users/me/follows/{item_id}/state", response_model=InteractionState)
def my_follow_state(item_id: str, current_user: UserProfile = Depends(get_current_user)):
    return InteractionState(active=store.has_personal_item("follows", current_user.id, item_id))


@app.post("/api/v1/users/me/follows", response_model=PersonalItem)
def add_my_follow(payload: PersonalItemActionRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.add_personal_item("follows", current_user.id, payload, "已关注")
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.delete("/api/v1/users/me/follows/{item_id}", response_model=ApiMessage)
def remove_my_follow(item_id: str, current_user: UserProfile = Depends(get_current_user)):
    store.remove_personal_item("follows", current_user.id, item_id)
    return ApiMessage(message="Follow removed")


@app.get("/api/v1/users/me/history", response_model=PersonalListResponse)
def my_history(current_user: UserProfile = Depends(get_current_user)):
    return PersonalListResponse(items=store.get_personal_items("history", current_user.id))


@app.post("/api/v1/users/me/history", response_model=PersonalItem)
def add_my_history(payload: PersonalItemActionRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.add_personal_item("history", current_user.id, payload, "已浏览")
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.delete("/api/v1/users/me/history", response_model=ApiMessage)
def clear_my_history(current_user: UserProfile = Depends(get_current_user)):
    store.clear_history(current_user.id)
    return ApiMessage(message="Browsing history cleared")


@app.get("/api/v1/users/me/inspirations", response_model=InspirationListResponse)
def my_inspirations(current_user: UserProfile = Depends(get_current_user)):
    return InspirationListResponse(items=store.list_inspirations(current_user.id))


@app.post("/api/v1/users/me/inspirations", response_model=InspirationItem, status_code=status.HTTP_201_CREATED)
def create_my_inspiration(payload: InspirationCreateRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.create_inspiration(current_user.id, payload)
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.post("/api/v1/users/me/inspirations/from-post", response_model=PostInspirationResponse)
def create_my_inspiration_from_post(payload: PostInspirationRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        post = store.get_daily_post(payload.post_id, include_draft=False, user_id=current_user.id)
        result = generate_post_inspiration({
            "title": post.title,
            "summary": post.summary,
            "content": post.content,
            "author_name": post.author_name,
            "category_name": post.category_name,
            "tags": post.tags,
        })
        item = store.create_inspiration(
            current_user.id,
            InspirationCreateRequest(
                content=result["content"],
                scene=result["scene"],
                source=result["source"],
            ),
        )
        return PostInspirationResponse(item=item, source="AI 生成")
    except ValueError as exc:
        raise bad_request(exc) from exc
    except AiProviderError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc


@app.put("/api/v1/users/me/inspirations/{inspiration_id}", response_model=InspirationItem)
def update_my_inspiration(
    inspiration_id: str,
    payload: InspirationUpdateRequest,
    current_user: UserProfile = Depends(get_current_user),
):
    try:
        return store.update_inspiration(current_user.id, inspiration_id, payload)
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.post("/api/v1/users/me/inspirations/{inspiration_id}/draft", response_model=InspirationDraftResponse)
def build_my_inspiration_draft(inspiration_id: str, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.build_inspiration_draft(current_user.id, inspiration_id)
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.delete("/api/v1/users/me/inspirations/{inspiration_id}", response_model=ApiMessage)
def delete_my_inspiration(inspiration_id: str, current_user: UserProfile = Depends(get_current_user)):
    store.delete_inspiration(current_user.id, inspiration_id)
    return ApiMessage(message="Inspiration deleted")


@app.get("/api/v1/users/me/notifications", response_model=NotificationListResponse)
def my_notifications(current_user: UserProfile = Depends(get_current_user)):
    return store.list_notifications(current_user.id)


@app.put("/api/v1/users/me/notifications/{notice_id}/read", response_model=ApiMessage)
def read_my_notification(notice_id: int, current_user: UserProfile = Depends(get_current_user)):
    store.mark_notification_read(current_user.id, notice_id)
    return ApiMessage(message="Notification marked as read")


@app.put("/api/v1/users/me/notifications/read-all", response_model=ApiMessage)
def read_all_my_notifications(current_user: UserProfile = Depends(get_current_user)):
    store.mark_all_notifications_read(current_user.id)
    return ApiMessage(message="All notifications marked as read")


@app.delete("/api/v1/users/me/notifications", response_model=ApiMessage)
def clear_my_notifications(current_user: UserProfile = Depends(get_current_user)):
    store.clear_notifications(current_user.id)
    return ApiMessage(message="Notifications cleared")


@app.get("/api/v1/users/{user_id}", response_model=UserProfile)
def get_user(user_id: int, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.get_user(user_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@app.put("/api/v1/users/{user_id}", response_model=UserProfile)
def update_user(user_id: int, payload: UserUpdateRequest, current_user: UserProfile = Depends(get_current_user)):
    try:
        return store.update_user(user_id, payload)
    except ValueError as exc:
        raise bad_request(exc) from exc


@app.delete("/api/v1/users/{user_id}", response_model=ApiMessage)
def delete_user(user_id: int, current_user: UserProfile = Depends(get_current_user)):
    try:
        store.delete_user(user_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return ApiMessage(message="User deleted")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
