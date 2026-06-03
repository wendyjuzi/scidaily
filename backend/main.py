from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware

from app.dependencies import get_current_user
from app.schemas import (
    ApiMessage,
    AuthResponse,
    CategoryResponse,
    LoginRequest,
    MessageSettings,
    NewsItem,
    NewsListResponse,
    PasswordResetRequest,
    InteractionState,
    PersonalItem,
    PersonalItemActionRequest,
    PersonalListResponse,
    PersonalStats,
    PrivacySettings,
    RegisterRequest,
    SettingsResponse,
    UserListResponse,
    UserProfile,
    UserUpdateRequest,
)
from app.services.news_service import get_categories, get_daily_news, get_news_by_id
from app.storage import store

app = FastAPI(title="SciDaily API", version="0.2.0")

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


@app.get("/api/v1/health", response_model=ApiMessage)
def health():
    return ApiMessage(message="SciDaily API is running")


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


@app.get("/api/v1/users/me/posts", response_model=PersonalListResponse)
def my_posts(current_user: UserProfile = Depends(get_current_user)):
    return PersonalListResponse(items=store.get_personal_items("posts", current_user.id))


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
