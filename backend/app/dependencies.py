from __future__ import annotations

from typing import Optional

from fastapi import Header, HTTPException, status

from app.schemas import UserProfile
from app.storage import store


def get_current_user(authorization: Optional[str] = Header(default=None)) -> UserProfile:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Login required")
    token = authorization[len("Bearer "):].strip()
    user = store.get_user_by_token(token)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Session expired")
    return user
