from __future__ import annotations

import hashlib
import hmac
import json
import re
import secrets
import sqlite3
import threading
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import List, Optional

from app.data import MOCK_NEWS
from app.schemas import (
    DailyPost,
    DailyPostCreateRequest,
    DailyPostUpdateRequest,
    DailyTemplate,
    CommentCreateRequest,
    CommentItem,
    CommentListResponse,
    InspirationCreateRequest,
    InspirationDraftResponse,
    InspirationItem,
    InspirationUpdateRequest,
    InteractionSummary,
    AgentMessage,
    AgentSession,
    MessageSettings,
    NotificationItem,
    NotificationListResponse,
    PaperCreateRequest,
    PaperItem,
    PersonalItem,
    PersonalItemActionRequest,
    PersonalStats,
    PrivacySettings,
    ReadingProgress,
    ReadingProgressRequest,
    RegisterRequest,
    ResearchStatsPoint,
    ResearchStatsResponse,
    SettingsResponse,
    TopicCategory,
    TopicCategoryRequest,
    TopicTag,
    TopicTagRequest,
    UserProfile,
    UserUpdateRequest,
)

DB_PATH = Path(__file__).resolve().parents[1] / "data" / "scidaily_app.db"


def now_text() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), 120000)
    return f"{salt}:{digest.hex()}"


def verify_password(password: str, stored_hash: str) -> bool:
    try:
        salt, expected = stored_hash.split(":", 1)
    except ValueError:
        return False
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), 120000)
    return hmac.compare_digest(digest.hex(), expected)


class AppStore:
    def __init__(self, db_path: Path = DB_PATH) -> None:
        self.db_path = db_path
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(self.db_path, check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("PRAGMA foreign_keys=ON;")
        self._lock = threading.RLock()
        self._create_tables()
        self._seed_demo_data()
        self._cleanup_placeholder_daily_posts()
        self._cleanup_placeholder_papers()
        self._seed_research_daily_data()
        self._seed_paper_library()

    def _create_tables(self) -> None:
        self.conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                nickname TEXT NOT NULL,
                avatar_url TEXT NOT NULL,
                email TEXT,
                bio TEXT NOT NULL DEFAULT '',
                institution TEXT NOT NULL DEFAULT '',
                research_field TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS sessions (
                token TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                expires_at TEXT NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS user_settings (
                user_id INTEGER PRIMARY KEY,
                show_email INTEGER NOT NULL DEFAULT 0,
                show_research_stats INTEGER NOT NULL DEFAULT 1,
                allow_recommendations INTEGER NOT NULL DEFAULT 1,
                like_notice INTEGER NOT NULL DEFAULT 1,
                comment_notice INTEGER NOT NULL DEFAULT 1,
                system_notice INTEGER NOT NULL DEFAULT 1,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS user_posts (
                id TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                summary TEXT NOT NULL,
                created_at TEXT NOT NULL,
                status TEXT NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS user_collections (
                id TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                summary TEXT NOT NULL,
                created_at TEXT NOT NULL,
                status TEXT NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS user_likes (
                id TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                summary TEXT NOT NULL,
                created_at TEXT NOT NULL,
                status TEXT NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS user_follows (
                id TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                summary TEXT NOT NULL,
                created_at TEXT NOT NULL,
                status TEXT NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS user_browsing_history (
                id TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                summary TEXT NOT NULL,
                created_at TEXT NOT NULL,
                status TEXT NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS user_inspirations (
                id TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                content TEXT NOT NULL,
                scene TEXT NOT NULL DEFAULT 'idea',
                source TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'active',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS agent_sessions (
                id TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                input TEXT NOT NULL,
                source_type TEXT NOT NULL DEFAULT '',
                source_id TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'running',
                current_round INTEGER NOT NULL DEFAULT 1,
                memory_version INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS agent_messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                agent_key TEXT NOT NULL,
                agent_name TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'pending',
                round INTEGER NOT NULL DEFAULT 1,
                context_version_started INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                started_at TEXT,
                completed_at TEXT,
                FOREIGN KEY(session_id) REFERENCES agent_sessions(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS topic_categories (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL UNIQUE,
                description TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS research_tags (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL UNIQUE,
                category_id TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(category_id) REFERENCES topic_categories(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS daily_posts (
                id TEXT PRIMARY KEY,
                author_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                summary TEXT NOT NULL,
                content TEXT NOT NULL,
                cover_url TEXT NOT NULL DEFAULT '',
                image_urls TEXT NOT NULL DEFAULT '[]',
                category_id TEXT NOT NULL,
                status TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                published_at TEXT,
                FOREIGN KEY(author_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY(category_id) REFERENCES topic_categories(id) ON DELETE RESTRICT
            );

            CREATE TABLE IF NOT EXISTS daily_post_tags (
                post_id TEXT NOT NULL,
                tag_id TEXT NOT NULL,
                PRIMARY KEY (post_id, tag_id),
                FOREIGN KEY(post_id) REFERENCES daily_posts(id) ON DELETE CASCADE,
                FOREIGN KEY(tag_id) REFERENCES research_tags(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS papers (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                abstract TEXT NOT NULL,
                authors TEXT NOT NULL DEFAULT '[]',
                category_id TEXT NOT NULL,
                source_url TEXT NOT NULL,
                pdf_url TEXT NOT NULL,
                local_pdf_path TEXT,
                doi TEXT,
                published_at TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(category_id) REFERENCES topic_categories(id) ON DELETE RESTRICT
            );

            CREATE TABLE IF NOT EXISTS paper_tags (
                paper_id TEXT NOT NULL,
                tag_id TEXT NOT NULL,
                PRIMARY KEY (paper_id, tag_id),
                FOREIGN KEY(paper_id) REFERENCES papers(id) ON DELETE CASCADE,
                FOREIGN KEY(tag_id) REFERENCES research_tags(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS reading_progress (
                user_id INTEGER NOT NULL,
                paper_id TEXT NOT NULL,
                current_page INTEGER NOT NULL DEFAULT 1,
                progress REAL NOT NULL DEFAULT 0,
                updated_at TEXT NOT NULL,
                PRIMARY KEY (user_id, paper_id),
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY(paper_id) REFERENCES papers(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS comments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                news_id TEXT NOT NULL,
                user_id INTEGER NOT NULL,
                parent_id INTEGER,
                content TEXT NOT NULL,
                like_count INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY(parent_id) REFERENCES comments(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS comment_likes (
                comment_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                PRIMARY KEY (comment_id, user_id),
                FOREIGN KEY(comment_id) REFERENCES comments(id) ON DELETE CASCADE,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS notifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                type TEXT NOT NULL,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                related_item_id TEXT,
                is_read INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );
            """
        )
        self.conn.commit()

    def _seed_demo_data(self) -> None:
        user_count = self.conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
        if user_count > 0:
            return
        user = self.create_user(
            RegisterRequest(
                username="demo",
                password="123456",
                nickname="科研日报体验号",
                email="demo@scidaily.local",
            ),
            seed_workspace=False,
        )
        self.update_user(
            user.id,
            UserUpdateRequest(
                avatar_url="https://example.com/avatar/scidaily.png",
                bio="每天记录一点科研进展，把灵感和进度都留住。",
                institution="科研日报实验室",
                research_field="人工智能辅助科研",
            ),
        )
        self._seed_user_workspace(user.id)

    def create_user(self, payload: RegisterRequest, seed_workspace: bool = False) -> UserProfile:
        username = payload.username.strip()
        nickname = (payload.nickname or username).strip()
        if not username:
            raise ValueError("Username is required")
        if len(payload.password) < 6:
            raise ValueError("Password must be at least 6 characters")
        existing = self.conn.execute("SELECT id FROM users WHERE username = ?", (username,)).fetchone()
        if existing:
            raise ValueError("Username already exists")

        created_at = now_text()
        cursor = self.conn.execute(
            """
            INSERT INTO users (
                username, password_hash, nickname, avatar_url, email, bio,
                institution, research_field, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                username,
                hash_password(payload.password),
                nickname,
                "https://example.com/avatar/default.png",
                payload.email,
                "",
                "",
                "",
                created_at,
                created_at,
            ),
        )
        user_id = int(cursor.lastrowid)
        self.conn.execute("INSERT INTO user_settings (user_id) VALUES (?)", (user_id,))
        self.conn.commit()
        self._add_notification(
            user_id=user_id,
            notice_type="system",
            title="欢迎使用科研日报社区",
            content="评论、科研统计看板和消息通知已准备就绪。",
            related_item_id="welcome",
        )
        if seed_workspace:
            self._seed_user_workspace(user_id)
        return self.get_user(user_id)

    def authenticate(self, username: str, password: str) -> Optional[UserProfile]:
        row = self.conn.execute("SELECT * FROM users WHERE username = ?", (username.strip(),)).fetchone()
        if row is None or not verify_password(password, row["password_hash"]):
            return None
        return self._profile_from_row(row)

    def create_session(self, user_id: int) -> str:
        token = secrets.token_urlsafe(32)
        created_at = now_text()
        expires_at = (datetime.now(timezone.utc) + timedelta(days=30)).isoformat(timespec="seconds")
        self.conn.execute(
            "INSERT INTO sessions (token, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)",
            (token, user_id, created_at, expires_at),
        )
        self.conn.commit()
        return token

    def delete_session(self, token: str) -> None:
        self.conn.execute("DELETE FROM sessions WHERE token = ?", (token,))
        self.conn.commit()

    def get_user_by_token(self, token: str) -> Optional[UserProfile]:
        row = self.conn.execute(
            """
            SELECT users.*
            FROM sessions
            JOIN users ON users.id = sessions.user_id
            WHERE sessions.token = ? AND sessions.expires_at > ?
            """,
            (token, now_text()),
        ).fetchone()
        if row is None:
            return None
        return self._profile_from_row(row)

    def list_users(self) -> List[UserProfile]:
        rows = self.conn.execute("SELECT * FROM users ORDER BY id ASC").fetchall()
        return [self._profile_from_row(row) for row in rows]

    def get_user(self, user_id: int) -> UserProfile:
        row = self.conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        if row is None:
            raise ValueError("User not found")
        return self._profile_from_row(row)

    def update_user(self, user_id: int, payload: UserUpdateRequest) -> UserProfile:
        fields = payload.model_dump(exclude_none=True)
        allowed_fields = ["nickname", "avatar_url", "email", "bio", "institution", "research_field"]
        update_fields = [field for field in allowed_fields if field in fields]
        if not update_fields:
            return self.get_user(user_id)
        assignments = ", ".join(f"{field} = ?" for field in update_fields)
        values = [fields[field] for field in update_fields]
        values.extend([now_text(), user_id])
        self.conn.execute(
            f"UPDATE users SET {assignments}, updated_at = ? WHERE id = ?",
            values,
        )
        self.conn.commit()
        return self.get_user(user_id)

    def update_password(self, user_id: int, old_password: Optional[str], new_password: str) -> None:
        if len(new_password) < 6:
            raise ValueError("New password must be at least 6 characters")
        row = self.conn.execute("SELECT password_hash FROM users WHERE id = ?", (user_id,)).fetchone()
        if row is None:
            raise ValueError("User not found")
        if old_password and not verify_password(old_password, row["password_hash"]):
            raise ValueError("Old password is incorrect")
        self.conn.execute(
            "UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?",
            (hash_password(new_password), now_text(), user_id),
        )
        self.conn.execute("DELETE FROM sessions WHERE user_id = ?", (user_id,))
        self.conn.commit()

    def delete_user(self, user_id: int) -> None:
        self.get_user(user_id)
        self.conn.execute("DELETE FROM users WHERE id = ?", (user_id,))
        self.conn.commit()

    def get_settings(self, user_id: int) -> SettingsResponse:
        row = self.conn.execute("SELECT * FROM user_settings WHERE user_id = ?", (user_id,)).fetchone()
        if row is None:
            self.conn.execute("INSERT INTO user_settings (user_id) VALUES (?)", (user_id,))
            self.conn.commit()
            row = self.conn.execute("SELECT * FROM user_settings WHERE user_id = ?", (user_id,)).fetchone()
        return SettingsResponse(
            privacy=PrivacySettings(
                show_email=bool(row["show_email"]),
                show_research_stats=bool(row["show_research_stats"]),
                allow_recommendations=bool(row["allow_recommendations"]),
            ),
            messages=MessageSettings(
                like_notice=bool(row["like_notice"]),
                comment_notice=bool(row["comment_notice"]),
                system_notice=bool(row["system_notice"]),
            ),
        )

    def update_privacy_settings(self, user_id: int, settings: PrivacySettings) -> SettingsResponse:
        self.conn.execute(
            """
            UPDATE user_settings
            SET show_email = ?, show_research_stats = ?, allow_recommendations = ?
            WHERE user_id = ?
            """,
            (
                int(settings.show_email),
                int(settings.show_research_stats),
                int(settings.allow_recommendations),
                user_id,
            ),
        )
        self.conn.commit()
        return self.get_settings(user_id)

    def update_message_settings(self, user_id: int, settings: MessageSettings) -> SettingsResponse:
        self.conn.execute(
            """
            UPDATE user_settings
            SET like_notice = ?, comment_notice = ?, system_notice = ?
            WHERE user_id = ?
            """,
            (
                int(settings.like_notice),
                int(settings.comment_notice),
                int(settings.system_notice),
                user_id,
            ),
        )
        self.conn.commit()
        return self.get_settings(user_id)

    def get_stats(self, user_id: int) -> PersonalStats:
        post_count = self._count_table("user_posts", user_id)
        collection_count = self._count_table("user_collections", user_id)
        like_count = self._count_table("user_likes", user_id)
        history_count = self._count_table("user_browsing_history", user_id)
        return PersonalStats(
            post_count=post_count + self.get_inspiration_count(user_id),
            collection_count=collection_count,
            like_count=like_count,
            history_count=history_count,
            continuous_days=self._continuous_days(user_id),
        )

    def get_inspiration_count(self, user_id: int) -> int:
        return self._count_table("user_inspirations", user_id)

    def get_personal_items(self, table_key: str, user_id: int) -> List[PersonalItem]:
        table = self._table_for_key(table_key)
        rows = self.conn.execute(
            f"""
            SELECT id, title, summary, created_at, status
            FROM {table}
            WHERE user_id = ?
            ORDER BY created_at DESC
            """,
            (user_id,),
        ).fetchall()
        return [
            PersonalItem(
                id=row["id"],
                title=row["title"],
                summary=row["summary"],
                created_at=row["created_at"],
                status=row["status"],
            )
            for row in rows
        ]

    def add_personal_item(
        self,
        table_key: str,
        user_id: int,
        payload: PersonalItemActionRequest,
        status_text: str,
    ) -> PersonalItem:
        item_id = payload.item_id.strip()
        title = payload.title.strip()
        summary = payload.summary.strip()
        if not item_id:
            raise ValueError("Item id is required")
        if not title:
            raise ValueError("Title is required")
        table = self._table_for_key(table_key)
        stored_id = self._stored_item_id(user_id, table_key, item_id)
        created_at = now_text()
        self.conn.execute(
            f"""
            INSERT OR REPLACE INTO {table}
            (id, user_id, title, summary, created_at, status)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (stored_id, user_id, title, summary, created_at, status_text),
        )
        self.conn.commit()
        if table_key == "likes":
            self._add_notification(
                user_id=user_id,
                notice_type="like",
                title="点赞成功",
                content=f"你点赞了《{title}》。",
                related_item_id=item_id,
            )
        elif table_key == "collections":
            self._add_notification(
                user_id=user_id,
                notice_type="collection",
                title="收藏已同步",
                content=f"《{title}》已加入你的收藏列表。",
                related_item_id=item_id,
            )
        elif table_key == "follows":
            self._add_notification(
                user_id=user_id,
                notice_type="follow",
                title="关注成功",
                content=f"你关注了 {title}。",
                related_item_id=item_id,
            )
        return PersonalItem(
            id=stored_id,
            title=title,
            summary=summary,
            created_at=created_at,
            status=status_text,
        )

    def remove_personal_item(self, table_key: str, user_id: int, item_id: str) -> None:
        table = self._table_for_key(table_key)
        stored_id = self._stored_item_id(user_id, table_key, item_id)
        self.conn.execute(
            f"DELETE FROM {table} WHERE user_id = ? AND id = ?",
            (user_id, stored_id),
        )
        self.conn.commit()

    def has_personal_item(self, table_key: str, user_id: int, item_id: str) -> bool:
        table = self._table_for_key(table_key)
        stored_id = self._stored_item_id(user_id, table_key, item_id)
        row = self.conn.execute(
            f"SELECT id FROM {table} WHERE user_id = ? AND id = ?",
            (user_id, stored_id),
        ).fetchone()
        return row is not None

    def clear_history(self, user_id: int) -> None:
        self.conn.execute("DELETE FROM user_browsing_history WHERE user_id = ?", (user_id,))
        self.conn.commit()

    def list_inspirations(self, user_id: int) -> List[InspirationItem]:
        rows = self.conn.execute(
            """
            SELECT *
            FROM user_inspirations
            WHERE user_id = ?
            ORDER BY updated_at DESC, created_at DESC
            """,
            (user_id,),
        ).fetchall()
        return [self._inspiration_from_row(row) for row in rows]

    def create_inspiration(self, user_id: int, payload: InspirationCreateRequest) -> InspirationItem:
        content = payload.content.strip()
        if not content:
            raise ValueError("Inspiration content is required")
        if len(content) > 1200:
            raise ValueError("Inspiration content is too long")
        scene = self._normalize_inspiration_scene(payload.scene)
        source = (payload.source or "").strip()[:120]
        created_at = now_text()
        inspiration_id = f"inspiration-{secrets.token_hex(8)}"
        self.conn.execute(
            """
            INSERT INTO user_inspirations (
                id, user_id, content, scene, source, status, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (inspiration_id, user_id, content, scene, source, "active", created_at, created_at),
        )
        self.conn.commit()
        return self.get_inspiration(user_id, inspiration_id)

    def get_inspiration(self, user_id: int, inspiration_id: str) -> InspirationItem:
        row = self.conn.execute(
            """
            SELECT *
            FROM user_inspirations
            WHERE user_id = ? AND id = ?
            """,
            (user_id, inspiration_id),
        ).fetchone()
        if row is None:
            raise ValueError("Inspiration not found")
        return self._inspiration_from_row(row)

    def update_inspiration(self, user_id: int, inspiration_id: str, payload: InspirationUpdateRequest) -> InspirationItem:
        self.get_inspiration(user_id, inspiration_id)
        fields = payload.model_dump(exclude_none=True)
        assignments = []
        values: list[object] = []
        if "content" in fields:
            content = str(fields["content"]).strip()
            if not content:
                raise ValueError("Inspiration content is required")
            if len(content) > 1200:
                raise ValueError("Inspiration content is too long")
            assignments.append("content = ?")
            values.append(content)
        if "scene" in fields:
            assignments.append("scene = ?")
            values.append(self._normalize_inspiration_scene(str(fields["scene"])))
        if "source" in fields:
            assignments.append("source = ?")
            values.append(str(fields["source"]).strip()[:120])
        if "status" in fields:
            assignments.append("status = ?")
            values.append(self._normalize_inspiration_status(str(fields["status"])))
        if assignments:
            assignments.append("updated_at = ?")
            values.append(now_text())
            values.extend([user_id, inspiration_id])
            self.conn.execute(
                f"UPDATE user_inspirations SET {', '.join(assignments)} WHERE user_id = ? AND id = ?",
                values,
            )
            self.conn.commit()
        return self.get_inspiration(user_id, inspiration_id)

    def delete_inspiration(self, user_id: int, inspiration_id: str) -> None:
        self.conn.execute(
            "DELETE FROM user_inspirations WHERE user_id = ? AND id = ?",
            (user_id, inspiration_id),
        )
        self.conn.commit()

    def create_agent_session(self, user_id: int, title: str, prompt: str, source_type: str = "", source_id: str = "") -> AgentSession:
        content = prompt.strip()
        if not content:
            raise ValueError("Discussion input is required")
        if len(content) > 8000:
            raise ValueError("Discussion input is too long")
        title_text = title.strip() if title.strip() else content.splitlines()[0].strip()
        if len(title_text) > 32:
            title_text = f"{title_text[:32]}..."
        session_id = f"agent-{secrets.token_hex(12)}"
        created_at = now_text()
        with self._lock:
            self.conn.execute(
                """
                INSERT INTO agent_sessions (
                    id, user_id, title, input, source_type, source_id, status,
                    current_round, memory_version, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    session_id,
                    user_id,
                    title_text or "多角色组会",
                    content,
                    source_type.strip(),
                    source_id.strip(),
                    "running",
                    0,
                    1,
                    created_at,
                    created_at,
                ),
            )
            self.conn.execute(
                """
                INSERT INTO agent_messages (
                    session_id, agent_key, agent_name, role, content, status, round,
                    context_version_started, created_at, started_at, completed_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (session_id, "user", "我", "user", content, "done", 0, 1, created_at, created_at, created_at),
            )
            self.conn.commit()
        return self.get_agent_session(user_id, session_id)

    def get_agent_session(self, user_id: int, session_id: str) -> AgentSession:
        with self._lock:
            row = self.conn.execute(
                """
                SELECT *
                FROM agent_sessions
                WHERE user_id = ? AND id = ?
                """,
                (user_id, session_id),
            ).fetchone()
        if row is None:
            raise ValueError("Discussion session not found")
        return self._agent_session_from_row(row)

    def list_agent_sessions(self, user_id: int) -> List[AgentSession]:
        with self._lock:
            rows = self.conn.execute(
                """
                SELECT *
                FROM agent_sessions
                WHERE user_id = ?
                ORDER BY updated_at DESC, created_at DESC
                LIMIT 30
                """,
                (user_id,),
            ).fetchall()
        return [self._agent_session_from_row(row) for row in rows]

    def list_agent_messages(self, user_id: int, session_id: str) -> List[AgentMessage]:
        self.get_agent_session(user_id, session_id)
        return self.list_agent_messages_for_session(session_id)

    def list_agent_messages_for_session(self, session_id: str) -> List[AgentMessage]:
        with self._lock:
            rows = self.conn.execute(
                """
                SELECT *
                FROM agent_messages
                WHERE session_id = ?
                ORDER BY
                    CASE
                        WHEN role = 'user' THEN 0
                        WHEN status IN ('done', 'error', 'timeout') THEN 1
                        ELSE 2
                    END ASC,
                    CASE
                        WHEN role = 'user' THEN created_at
                        WHEN status IN ('done', 'error', 'timeout') THEN COALESCE(completed_at, created_at)
                        ELSE created_at
                    END ASC,
                    id ASC
                """,
                (session_id,),
            ).fetchall()
        return [self._agent_message_from_row(row) for row in rows]

    def create_agent_message(
        self,
        session_id: str,
        agent_key: str,
        agent_name: str,
        role: str,
        round_number: int,
        context_version: int,
        content: str = "",
        status: str = "pending",
    ) -> AgentMessage:
        created_at = now_text()
        with self._lock:
            cursor = self.conn.execute(
                """
                INSERT INTO agent_messages (
                    session_id, agent_key, agent_name, role, content, status, round,
                    context_version_started, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    session_id,
                    agent_key,
                    agent_name,
                    role,
                    content,
                    status,
                    round_number,
                    context_version,
                    created_at,
                ),
            )
            message_id = int(cursor.lastrowid)
            self.conn.commit()
        return self.get_agent_message(message_id)

    def get_agent_message(self, message_id: int) -> AgentMessage:
        with self._lock:
            row = self.conn.execute(
                "SELECT * FROM agent_messages WHERE id = ?",
                (message_id,),
            ).fetchone()
        if row is None:
            raise ValueError("Discussion message not found")
        return self._agent_message_from_row(row)

    def mark_agent_message_running(self, message_id: int) -> AgentMessage:
        started_at = now_text()
        with self._lock:
            self.conn.execute(
                """
                UPDATE agent_messages
                SET status = ?, started_at = ?
                WHERE id = ?
                """,
                ("running", started_at, message_id),
            )
            self.conn.commit()
        return self.get_agent_message(message_id)

    def complete_agent_message(self, message_id: int, content: str, status: str = "done") -> AgentMessage:
        completed_at = now_text()
        with self._lock:
            self.conn.execute(
                """
                UPDATE agent_messages
                SET status = ?, content = ?, completed_at = ?
                WHERE id = ?
                """,
                (status, content.strip(), completed_at, message_id),
            )
            self.conn.commit()
        return self.get_agent_message(message_id)

    def mark_unfinished_agent_messages(self, session_id: str, role_keys: List[str], status: str = "timeout") -> None:
        if not role_keys:
            return
        completed_at = now_text()
        placeholders = ",".join("?" for _ in role_keys)
        with self._lock:
            self.conn.execute(
                f"""
                UPDATE agent_messages
                SET status = ?, completed_at = ?
                WHERE session_id = ?
                  AND role = 'assistant'
                  AND status IN ('pending', 'running')
                  AND agent_key IN ({placeholders})
                """,
                [status, completed_at, session_id] + role_keys,
            )
            self.conn.commit()

    def has_unfinished_agent_messages(self, session_id: str) -> bool:
        with self._lock:
            row = self.conn.execute(
                """
                SELECT COUNT(*) AS total
                FROM agent_messages
                WHERE session_id = ?
                  AND role = 'assistant'
                  AND status IN ('pending', 'running')
                """,
                (session_id,),
            ).fetchone()
        return bool(row and int(row["total"]) > 0)

    def update_agent_session_status(
        self,
        session_id: str,
        status: str,
        current_round: Optional[int] = None,
        memory_version: Optional[int] = None,
    ) -> None:
        assignments = ["status = ?", "updated_at = ?"]
        values: List[object] = [status, now_text()]
        if current_round is not None:
            assignments.append("current_round = ?")
            values.append(current_round)
        if memory_version is not None:
            assignments.append("memory_version = ?")
            values.append(memory_version)
        values.append(session_id)
        with self._lock:
            self.conn.execute(
                f"UPDATE agent_sessions SET {', '.join(assignments)} WHERE id = ?",
                values,
            )
            self.conn.commit()

    def completed_agent_role_names(self, session_id: str, max_round: int) -> List[str]:
        with self._lock:
            rows = self.conn.execute(
                """
                SELECT DISTINCT agent_name
                FROM agent_messages
                WHERE session_id = ? AND round <= ? AND role = 'assistant' AND status = 'done'
                ORDER BY id ASC
                """,
                (session_id, max_round),
            ).fetchall()
        return [row["agent_name"] for row in rows]

    def build_inspiration_draft(self, user_id: int, inspiration_id: str) -> InspirationDraftResponse:
        item = self.get_inspiration(user_id, inspiration_id)
        title_seed = item.content.splitlines()[0].strip()
        if len(title_seed) > 22:
            title_seed = f"{title_seed[:22]}..."
        scene_title = self._inspiration_scene_title(item.scene)
        title = f"{scene_title}：{title_seed}" if title_seed else scene_title
        summary = self._inspiration_summary(item.content)
        category_id = self._category_for_inspiration(item.content)
        tag_ids = self._tag_ids_for_inspiration(item.content, category_id)
        source_line = f"来源：{item.source}\n\n" if item.source else ""
        content = (
            f"{source_line}"
            f"一、原始灵感\n{item.content}\n\n"
            "二、可以展开的问题\n"
            "- 这个想法想解决什么科研问题？\n"
            "- 目前已有证据、数据或现象是什么？\n"
            "- 还缺少哪些实验、文献或对照？\n\n"
            "三、今日推进\n"
            "- 已完成：\n"
            "- 新发现：\n"
            "- 遇到的问题：\n\n"
            "四、下一步计划\n"
            "- 优先验证：\n"
            "- 需要补充的数据/材料：\n"
            "- 可发布到社区讨论的问题："
        )
        self.update_inspiration(
            user_id,
            inspiration_id,
            InspirationUpdateRequest(status="used"),
        )
        return InspirationDraftResponse(
            title=title,
            summary=summary,
            content=content,
            category_id=category_id,
            tag_ids=tag_ids,
        )

    def list_daily_templates(self) -> List[DailyTemplate]:
        return [
            DailyTemplate(
                id="experiment",
                title="实验记录",
                description="适合记录实验目的、材料方法、过程、结果和下一步计划。",
                blocks=["实验目的", "材料与方法", "关键过程", "结果观察", "问题与下一步"],
            ),
            DailyTemplate(
                id="literature",
                title="文献阅读",
                description="适合拆解论文问题、方法、数据、结论和可复用启发。",
                blocks=["研究问题", "核心方法", "数据与实验", "主要结论", "我的启发"],
            ),
            DailyTemplate(
                id="summary",
                title="科研总结",
                description="适合整理阶段进展、风险、复盘和后续安排。",
                blocks=["本周进展", "关键发现", "风险阻塞", "资源需求", "下周计划"],
            ),
        ]

    def list_daily_posts(
        self,
        status_filter: str = "published",
        category_id: Optional[str] = None,
        tag_id: Optional[str] = None,
        limit: int = 20,
        offset: int = 0,
        author_id: Optional[int] = None,
    ) -> tuple[List[DailyPost], int, bool]:
        limit = max(1, min(limit, 50))
        offset = max(0, offset)
        where = []
        params: list[object] = []
        if status_filter != "all":
            where.append("daily_posts.status = ?")
            params.append(status_filter)
        if category_id:
            where.append("daily_posts.category_id = ?")
            params.append(category_id)
        if author_id is not None:
            where.append("daily_posts.author_id = ?")
            params.append(author_id)
        if tag_id:
            where.append(
                """
                EXISTS (
                    SELECT 1 FROM daily_post_tags
                    WHERE daily_post_tags.post_id = daily_posts.id
                    AND daily_post_tags.tag_id = ?
                )
                """
            )
            params.append(tag_id)
        where_sql = "WHERE " + " AND ".join(where) if where else ""
        rows = self.conn.execute(
            f"""
            SELECT daily_posts.*, users.nickname AS author_name, topic_categories.name AS category_name
            FROM daily_posts
            JOIN users ON users.id = daily_posts.author_id
            JOIN topic_categories ON topic_categories.id = daily_posts.category_id
            {where_sql}
            ORDER BY COALESCE(daily_posts.published_at, daily_posts.updated_at) DESC
            LIMIT ? OFFSET ?
            """,
            (*params, limit + 1, offset),
        ).fetchall()
        has_more = len(rows) > limit
        page_rows = rows[:limit]
        return [self._daily_post_from_row(row) for row in page_rows], offset + len(page_rows), has_more

    def get_daily_post(self, post_id: str, include_draft: bool = False, user_id: Optional[int] = None) -> DailyPost:
        row = self.conn.execute(
            """
            SELECT daily_posts.*, users.nickname AS author_name, topic_categories.name AS category_name
            FROM daily_posts
            JOIN users ON users.id = daily_posts.author_id
            JOIN topic_categories ON topic_categories.id = daily_posts.category_id
            WHERE daily_posts.id = ?
            """,
            (post_id,),
        ).fetchone()
        if row is None:
            raise ValueError("Daily post not found")
        if row["status"] != "published" and not include_draft and row["author_id"] != user_id:
            raise ValueError("Daily post not found")
        return self._daily_post_from_row(row)

    def create_daily_post(self, user_id: int, payload: DailyPostCreateRequest) -> DailyPost:
        self._validate_category_and_tags(payload.category_id, payload.tag_ids)
        title = payload.title.strip()
        summary = payload.summary.strip()
        content = payload.content.strip()
        status_text = self._normalize_post_status(payload.status)
        if not title:
            raise ValueError("Title is required")
        if not content:
            raise ValueError("Content is required")
        created_at = now_text()
        post_id = f"daily-{secrets.token_hex(8)}"
        published_at = created_at if status_text == "published" else None
        cover_url = payload.cover_url or self._default_cover_for_category(payload.category_id)
        self.conn.execute(
            """
            INSERT INTO daily_posts (
                id, author_id, title, summary, content, cover_url, image_urls,
                category_id, status, created_at, updated_at, published_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                post_id,
                user_id,
                title,
                summary,
                content,
                cover_url,
                json.dumps(payload.image_urls, ensure_ascii=False),
                payload.category_id,
                status_text,
                created_at,
                created_at,
                published_at,
            ),
        )
        self._replace_post_tags(post_id, payload.tag_ids)
        self._sync_user_post(user_id, post_id, title, summary, status_text, created_at)
        self.conn.commit()
        return self.get_daily_post(post_id, include_draft=True, user_id=user_id)

    def update_daily_post(self, user_id: int, post_id: str, payload: DailyPostUpdateRequest) -> DailyPost:
        existing = self.get_daily_post(post_id, include_draft=True, user_id=user_id)
        if existing.author_id != user_id:
            raise ValueError("Only the author can edit this daily post")
        category_id = payload.category_id if payload.category_id is not None else existing.category_id
        tag_ids = payload.tag_ids if payload.tag_ids is not None else existing.tag_ids
        self._validate_category_and_tags(category_id, tag_ids)
        fields = payload.model_dump(exclude_none=True)
        assignments = []
        values: list[object] = []
        for field in ["title", "summary", "content", "cover_url", "category_id"]:
            if field in fields:
                value = str(fields[field]).strip() if fields[field] is not None else ""
                if field in ["title", "content"] and not value:
                    raise ValueError(f"{field} is required")
                assignments.append(f"{field} = ?")
                values.append(value)
        if "image_urls" in fields:
            assignments.append("image_urls = ?")
            values.append(json.dumps(fields["image_urls"], ensure_ascii=False))
        if "status" in fields:
            status_text = self._normalize_post_status(str(fields["status"]))
            assignments.append("status = ?")
            values.append(status_text)
            if status_text == "published" and existing.published_at is None:
                assignments.append("published_at = ?")
                values.append(now_text())
        assignments.append("updated_at = ?")
        values.append(now_text())
        values.append(post_id)
        if assignments:
            self.conn.execute(
                f"UPDATE daily_posts SET {', '.join(assignments)} WHERE id = ?",
                values,
            )
        if payload.tag_ids is not None:
            self._replace_post_tags(post_id, payload.tag_ids)
        refreshed = self.get_daily_post(post_id, include_draft=True, user_id=user_id)
        self._sync_user_post(user_id, refreshed.id, refreshed.title, refreshed.summary, refreshed.status, refreshed.updated_at)
        self.conn.commit()
        return refreshed

    def publish_daily_post(self, user_id: int, post_id: str) -> DailyPost:
        return self.update_daily_post(user_id, post_id, DailyPostUpdateRequest(status="published"))

    def delete_daily_post(self, user_id: int, post_id: str) -> None:
        existing = self.get_daily_post(post_id, include_draft=True, user_id=user_id)
        if existing.author_id != user_id:
            raise ValueError("Only the author can delete this daily post")
        self.conn.execute("DELETE FROM daily_posts WHERE id = ?", (post_id,))
        self.conn.execute("DELETE FROM user_posts WHERE user_id = ? AND id = ?", (user_id, self._stored_item_id(user_id, "posts", post_id)))
        self.conn.commit()

    def list_papers(
        self,
        category_id: Optional[str] = None,
        tag_id: Optional[str] = None,
        limit: int = 20,
        offset: int = 0,
    ) -> tuple[List[PaperItem], int, bool]:
        limit = max(1, min(limit, 50))
        offset = max(0, offset)
        where = []
        params: list[object] = []
        if category_id:
            where.append("papers.category_id = ?")
            params.append(category_id)
        if tag_id:
            where.append(
                """
                EXISTS (
                    SELECT 1 FROM paper_tags
                    WHERE paper_tags.paper_id = papers.id
                    AND paper_tags.tag_id = ?
                )
                """
            )
            params.append(tag_id)
        where_sql = "WHERE " + " AND ".join(where) if where else ""
        rows = self.conn.execute(
            f"""
            SELECT papers.*, topic_categories.name AS category_name
            FROM papers
            JOIN topic_categories ON topic_categories.id = papers.category_id
            {where_sql}
            ORDER BY papers.published_at DESC, papers.created_at DESC
            LIMIT ? OFFSET ?
            """,
            (*params, limit + 1, offset),
        ).fetchall()
        has_more = len(rows) > limit
        page_rows = rows[:limit]
        return [self._paper_from_row(row) for row in page_rows], offset + len(page_rows), has_more

    def get_paper(self, paper_id: str) -> PaperItem:
        row = self.conn.execute(
            """
            SELECT papers.*, topic_categories.name AS category_name
            FROM papers
            JOIN topic_categories ON topic_categories.id = papers.category_id
            WHERE papers.id = ?
            """,
            (paper_id,),
        ).fetchone()
        if row is None:
            raise ValueError("Paper not found")
        return self._paper_from_row(row)

    def create_paper(self, payload: PaperCreateRequest) -> PaperItem:
        self._validate_category_and_tags(payload.category_id, payload.tag_ids)
        title = payload.title.strip()
        abstract = payload.abstract.strip()
        if not title:
            raise ValueError("Title is required")
        if not payload.pdf_url.strip():
            raise ValueError("PDF url is required")
        created_at = now_text()
        paper_id = f"paper-{secrets.token_hex(8)}"
        self.conn.execute(
            """
            INSERT INTO papers (
                id, title, abstract, authors, category_id, source_url, pdf_url,
                local_pdf_path, doi, published_at, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                paper_id,
                title,
                abstract,
                json.dumps(payload.authors, ensure_ascii=False),
                payload.category_id,
                payload.source_url,
                payload.pdf_url,
                payload.local_pdf_path,
                payload.doi,
                payload.published_at,
                created_at,
                created_at,
            ),
        )
        self._replace_paper_tags(paper_id, payload.tag_ids)
        self.conn.commit()
        return self.get_paper(paper_id)

    def get_reading_progress(self, user_id: int, paper_id: str) -> ReadingProgress:
        self.get_paper(paper_id)
        row = self.conn.execute(
            "SELECT * FROM reading_progress WHERE user_id = ? AND paper_id = ?",
            (user_id, paper_id),
        ).fetchone()
        if row is None:
            return ReadingProgress(
                paper_id=paper_id,
                current_page=1,
                progress=0,
                updated_at=now_text(),
            )
        return ReadingProgress(
            paper_id=row["paper_id"],
            current_page=int(row["current_page"]),
            progress=float(row["progress"]),
            updated_at=row["updated_at"],
        )

    def update_reading_progress(self, user_id: int, paper_id: str, payload: ReadingProgressRequest) -> ReadingProgress:
        self.get_paper(paper_id)
        current_page = max(1, payload.current_page)
        progress = max(0, min(float(payload.progress), 1))
        updated_at = now_text()
        self.conn.execute(
            """
            INSERT INTO reading_progress (user_id, paper_id, current_page, progress, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(user_id, paper_id) DO UPDATE SET
                current_page = excluded.current_page,
                progress = excluded.progress,
                updated_at = excluded.updated_at
            """,
            (user_id, paper_id, current_page, progress, updated_at),
        )
        self.conn.commit()
        return self.get_reading_progress(user_id, paper_id)

    def list_topic_categories(self) -> List[TopicCategory]:
        rows = self.conn.execute(
            """
            SELECT topic_categories.*,
                   COUNT(CASE WHEN daily_posts.status = 'published' THEN daily_posts.id END) AS post_count
            FROM topic_categories
            LEFT JOIN daily_posts ON daily_posts.category_id = topic_categories.id
            GROUP BY topic_categories.id
            ORDER BY topic_categories.created_at ASC
            """
        ).fetchall()
        return [
            TopicCategory(
                id=row["id"],
                name=row["name"],
                description=row["description"],
                post_count=int(row["post_count"]),
            )
            for row in rows
        ]

    def create_topic_category(self, payload: TopicCategoryRequest) -> TopicCategory:
        category_id = self._slug_or_generated(payload.id, payload.name, "cat")
        name = payload.name.strip()
        if not name:
            raise ValueError("Category name is required")
        created_at = now_text()
        self.conn.execute(
            """
            INSERT INTO topic_categories (id, name, description, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                description = excluded.description,
                updated_at = excluded.updated_at
            """,
            (category_id, name, payload.description or "", created_at, created_at),
        )
        self.conn.commit()
        return next(item for item in self.list_topic_categories() if item.id == category_id)

    def update_topic_category(self, category_id: str, payload: TopicCategoryRequest) -> TopicCategory:
        if self.conn.execute("SELECT id FROM topic_categories WHERE id = ?", (category_id,)).fetchone() is None:
            raise ValueError("Category not found")
        name = payload.name.strip()
        if not name:
            raise ValueError("Category name is required")
        self.conn.execute(
            """
            UPDATE topic_categories
            SET name = ?, description = ?, updated_at = ?
            WHERE id = ?
            """,
            (name, payload.description or "", now_text(), category_id),
        )
        self.conn.commit()
        return next(item for item in self.list_topic_categories() if item.id == category_id)

    def delete_topic_category(self, category_id: str) -> None:
        post_count = self.conn.execute(
            "SELECT COUNT(*) FROM daily_posts WHERE category_id = ?",
            (category_id,),
        ).fetchone()[0]
        tag_count = self.conn.execute(
            "SELECT COUNT(*) FROM research_tags WHERE category_id = ?",
            (category_id,),
        ).fetchone()[0]
        if post_count > 0 or tag_count > 0:
            raise ValueError("Category still has tags or posts")
        self.conn.execute("DELETE FROM topic_categories WHERE id = ?", (category_id,))
        self.conn.commit()

    def list_topic_tags(self, category_id: Optional[str] = None) -> List[TopicTag]:
        params: list[object] = []
        where_sql = ""
        if category_id:
            where_sql = "WHERE research_tags.category_id = ?"
            params.append(category_id)
        rows = self.conn.execute(
            f"""
            SELECT research_tags.*, topic_categories.name AS category_name,
                   COUNT(CASE WHEN daily_posts.status = 'published' THEN daily_posts.id END) AS post_count
            FROM research_tags
            JOIN topic_categories ON topic_categories.id = research_tags.category_id
            LEFT JOIN daily_post_tags ON daily_post_tags.tag_id = research_tags.id
            LEFT JOIN daily_posts ON daily_posts.id = daily_post_tags.post_id
            {where_sql}
            GROUP BY research_tags.id
            ORDER BY post_count DESC, research_tags.created_at ASC
            """,
            params,
        ).fetchall()
        return [
            TopicTag(
                id=row["id"],
                name=row["name"],
                category_id=row["category_id"],
                category_name=row["category_name"],
                description=row["description"],
                post_count=int(row["post_count"]),
            )
            for row in rows
        ]

    def create_topic_tag(self, payload: TopicTagRequest) -> TopicTag:
        if self.conn.execute("SELECT id FROM topic_categories WHERE id = ?", (payload.category_id,)).fetchone() is None:
            raise ValueError("Category not found")
        tag_id = self._slug_or_generated(payload.id, payload.name, "tag")
        name = payload.name.strip()
        if not name:
            raise ValueError("Tag name is required")
        created_at = now_text()
        self.conn.execute(
            """
            INSERT INTO research_tags (id, name, category_id, description, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                category_id = excluded.category_id,
                description = excluded.description,
                updated_at = excluded.updated_at
            """,
            (tag_id, name, payload.category_id, payload.description or "", created_at, created_at),
        )
        self.conn.commit()
        return next(item for item in self.list_topic_tags() if item.id == tag_id)

    def update_topic_tag(self, tag_id: str, payload: TopicTagRequest) -> TopicTag:
        if self.conn.execute("SELECT id FROM research_tags WHERE id = ?", (tag_id,)).fetchone() is None:
            raise ValueError("Tag not found")
        if self.conn.execute("SELECT id FROM topic_categories WHERE id = ?", (payload.category_id,)).fetchone() is None:
            raise ValueError("Category not found")
        name = payload.name.strip()
        if not name:
            raise ValueError("Tag name is required")
        self.conn.execute(
            """
            UPDATE research_tags
            SET name = ?, category_id = ?, description = ?, updated_at = ?
            WHERE id = ?
            """,
            (name, payload.category_id, payload.description or "", now_text(), tag_id),
        )
        self.conn.commit()
        return next(item for item in self.list_topic_tags() if item.id == tag_id)

    def delete_topic_tag(self, tag_id: str) -> None:
        if self.conn.execute("SELECT id FROM research_tags WHERE id = ?", (tag_id,)).fetchone() is None:
            raise ValueError("Tag not found")
        self.conn.execute("DELETE FROM research_tags WHERE id = ?", (tag_id,))
        self.conn.commit()

    def _daily_post_from_row(self, row: sqlite3.Row) -> DailyPost:
        tag_rows = self.conn.execute(
            """
            SELECT research_tags.id, research_tags.name
            FROM daily_post_tags
            JOIN research_tags ON research_tags.id = daily_post_tags.tag_id
            WHERE daily_post_tags.post_id = ?
            ORDER BY research_tags.name ASC
            """,
            (row["id"],),
        ).fetchall()
        return DailyPost(
            id=row["id"],
            author_id=int(row["author_id"]),
            author_name=row["author_name"],
            title=row["title"],
            summary=row["summary"],
            content=row["content"],
            cover_url=row["cover_url"],
            image_urls=self._json_list(row["image_urls"]),
            category_id=row["category_id"],
            category_name=row["category_name"],
            tags=[tag["name"] for tag in tag_rows],
            tag_ids=[tag["id"] for tag in tag_rows],
            status=row["status"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
            published_at=row["published_at"],
        )

    def _paper_from_row(self, row: sqlite3.Row) -> PaperItem:
        tag_rows = self.conn.execute(
            """
            SELECT research_tags.id, research_tags.name
            FROM paper_tags
            JOIN research_tags ON research_tags.id = paper_tags.tag_id
            WHERE paper_tags.paper_id = ?
            ORDER BY research_tags.name ASC
            """,
            (row["id"],),
        ).fetchall()
        return PaperItem(
            id=row["id"],
            title=row["title"],
            abstract=row["abstract"],
            authors=self._json_list(row["authors"]),
            category_id=row["category_id"],
            category_name=row["category_name"],
            tags=[tag["name"] for tag in tag_rows],
            tag_ids=[tag["id"] for tag in tag_rows],
            source_url=row["source_url"],
            pdf_url=row["pdf_url"],
            local_pdf_path=row["local_pdf_path"],
            doi=row["doi"],
            published_at=row["published_at"],
            created_at=row["created_at"],
        )

    def _inspiration_from_row(self, row: sqlite3.Row) -> InspirationItem:
        return InspirationItem(
            id=row["id"],
            content=row["content"],
            scene=row["scene"],
            source=row["source"],
            status=row["status"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )

    def _agent_session_from_row(self, row: sqlite3.Row) -> AgentSession:
        return AgentSession(
            id=row["id"],
            user_id=int(row["user_id"]),
            title=row["title"],
            input=row["input"],
            source_type=row["source_type"],
            source_id=row["source_id"],
            status=row["status"],
            current_round=int(row["current_round"]),
            memory_version=int(row["memory_version"]),
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )

    def _agent_message_from_row(self, row: sqlite3.Row) -> AgentMessage:
        return AgentMessage(
            id=int(row["id"]),
            session_id=row["session_id"],
            agent_key=row["agent_key"],
            agent_name=row["agent_name"],
            role=row["role"],
            content=row["content"],
            status=row["status"],
            round=int(row["round"]),
            context_version_started=int(row["context_version_started"]),
            created_at=row["created_at"],
            started_at=row["started_at"],
            completed_at=row["completed_at"],
        )

    def _json_list(self, raw: str) -> List[str]:
        try:
            value = json.loads(raw)
        except json.JSONDecodeError:
            return []
        if not isinstance(value, list):
            return []
        return [str(item) for item in value]

    def _normalize_inspiration_scene(self, scene: str) -> str:
        value = scene.strip().lower()
        if value in ["idea", "experiment", "paper", "meeting", "question"]:
            return value
        return "idea"

    def _normalize_inspiration_status(self, status_text: str) -> str:
        value = status_text.strip().lower()
        if value in ["active", "used", "archived"]:
            return value
        raise ValueError("Unsupported inspiration status")

    def _inspiration_scene_title(self, scene: str) -> str:
        title_map = {
            "idea": "科研灵感",
            "experiment": "实验想法",
            "paper": "文献启发",
            "meeting": "组会记录",
            "question": "待验证问题",
        }
        return title_map.get(scene, "科研灵感")

    def _inspiration_summary(self, content: str) -> str:
        text = re.sub(r"\s+", " ", content).strip()
        if len(text) <= 68:
            return text
        return f"{text[:68]}..."

    def _category_for_inspiration(self, content: str) -> str:
        text = content.lower()
        if any(keyword in text for keyword in ["单细胞", "免疫", "基因", "蛋白", "细胞", "生物", "组学"]):
            return "bio"
        if any(keyword in text for keyword in ["材料", "钙钛矿", "催化", "电池", "光伏", "合金"]):
            return "materials"
        if any(keyword in text for keyword in ["临床", "医学", "患者", "诊断", "药物", "疾病"]):
            return "medicine"
        return "ai"

    def _tag_ids_for_inspiration(self, content: str, category_id: str) -> List[str]:
        text = content.lower()
        candidates = []
        if any(keyword in text for keyword in ["agent", "智能体", "工具调用", "自动化"]):
            candidates.append("ai-agent")
        if any(keyword in text for keyword in ["llm", "大模型", "论文", "rag", "transformer"]):
            candidates.append("llm-paper")
        if any(keyword in text for keyword in ["单细胞", "细胞"]):
            candidates.append("single-cell")
        if any(keyword in text for keyword in ["免疫", "炎症"]):
            candidates.append("immunology")
        if any(keyword in text for keyword in ["钙钛矿", "材料", "光伏"]):
            candidates.append("perovskite")
        if any(keyword in text for keyword in ["临床", "诊断", "医学"]):
            candidates.append("clinical-ai")
        rows = self.conn.execute(
            "SELECT id FROM research_tags WHERE category_id = ?",
            (category_id,),
        ).fetchall()
        available = {row["id"] for row in rows}
        matched = [tag_id for tag_id in candidates if tag_id in available]
        if matched:
            return list(dict.fromkeys(matched))[:3]
        fallback = self.conn.execute(
            "SELECT id FROM research_tags WHERE category_id = ? ORDER BY created_at ASC LIMIT 1",
            (category_id,),
        ).fetchone()
        return [fallback["id"]] if fallback is not None else []

    def _validate_category_and_tags(self, category_id: str, tag_ids: List[str]) -> None:
        if self.conn.execute("SELECT id FROM topic_categories WHERE id = ?", (category_id,)).fetchone() is None:
            raise ValueError("Category not found")
        if not tag_ids:
            return
        placeholders = ",".join("?" for _ in tag_ids)
        rows = self.conn.execute(
            f"SELECT id FROM research_tags WHERE id IN ({placeholders})",
            tag_ids,
        ).fetchall()
        found = {row["id"] for row in rows}
        missing = [tag_id for tag_id in tag_ids if tag_id not in found]
        if missing:
            raise ValueError(f"Tags not found: {', '.join(missing)}")

    def _replace_post_tags(self, post_id: str, tag_ids: List[str]) -> None:
        self.conn.execute("DELETE FROM daily_post_tags WHERE post_id = ?", (post_id,))
        for tag_id in dict.fromkeys(tag_ids):
            self.conn.execute(
                "INSERT OR IGNORE INTO daily_post_tags (post_id, tag_id) VALUES (?, ?)",
                (post_id, tag_id),
            )

    def _replace_paper_tags(self, paper_id: str, tag_ids: List[str]) -> None:
        self.conn.execute("DELETE FROM paper_tags WHERE paper_id = ?", (paper_id,))
        for tag_id in dict.fromkeys(tag_ids):
            self.conn.execute(
                "INSERT OR IGNORE INTO paper_tags (paper_id, tag_id) VALUES (?, ?)",
                (paper_id, tag_id),
            )

    def _sync_user_post(self, user_id: int, post_id: str, title: str, summary: str, status_text: str, created_at: str) -> None:
        status_label = "已发布" if status_text == "published" else "草稿"
        self.conn.execute(
            """
            INSERT OR REPLACE INTO user_posts
            (id, user_id, title, summary, created_at, status)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (self._stored_item_id(user_id, "posts", post_id), user_id, title, summary, created_at, status_label),
        )

    def _normalize_post_status(self, status_text: str) -> str:
        status_text = status_text.strip().lower()
        if status_text in ["published", "draft"]:
            return status_text
        raise ValueError("Status must be draft or published")

    def _slug_or_generated(self, raw_id: Optional[str], name: str, prefix: str) -> str:
        seed = raw_id or name
        slug = re.sub(r"[^a-zA-Z0-9_-]+", "-", seed.strip().lower()).strip("-")
        if slug:
            return slug[:48]
        return f"{prefix}-{secrets.token_hex(4)}"

    def _default_cover_for_category(self, category_id: str) -> str:
        cover_map = {
            "ai": "https://images.unsplash.com/photo-1677442136019-21780ecad995?auto=format&fit=crop&w=900&q=80",
            "bio": "https://images.unsplash.com/photo-1576086213369-97a306d36557?auto=format&fit=crop&w=900&q=80",
            "materials": "https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?auto=format&fit=crop&w=900&q=80",
            "medicine": "https://images.unsplash.com/photo-1581093458791-9d09f8d088f4?auto=format&fit=crop&w=900&q=80",
        }
        return cover_map.get(category_id, cover_map["ai"])

    def _seed_research_daily_data(self) -> None:
        category_count = self.conn.execute("SELECT COUNT(*) FROM topic_categories").fetchone()[0]
        if category_count == 0:
            for category in [
                TopicCategoryRequest(id="ai", name="人工智能", description="AI for Science、智能体、机器学习与科研自动化"),
                TopicCategoryRequest(id="bio", name="生命科学", description="组学、细胞、免疫、神经与生物医学发现"),
                TopicCategoryRequest(id="materials", name="材料科学", description="能源材料、结构材料、催化与表征"),
                TopicCategoryRequest(id="medicine", name="医学转化", description="临床研究、药物研发、诊断与公共健康"),
            ]:
                self.create_topic_category(category)
        tag_count = self.conn.execute("SELECT COUNT(*) FROM research_tags").fetchone()[0]
        if tag_count == 0:
            for tag in [
                TopicTagRequest(id="ai-agent", name="AI Agent", category_id="ai", description="科研智能体、工具调用与自动化流程"),
                TopicTagRequest(id="llm-paper", name="大模型论文", category_id="ai", description="大模型方法、评测和应用阅读"),
                TopicTagRequest(id="single-cell", name="单细胞", category_id="bio", description="单细胞组学图谱与机制发现"),
                TopicTagRequest(id="immunology", name="免疫学", category_id="bio", description="免疫细胞状态、炎症和疾病机制"),
                TopicTagRequest(id="perovskite", name="钙钛矿", category_id="materials", description="光伏、稳定性和器件工艺"),
                TopicTagRequest(id="clinical-ai", name="临床AI", category_id="medicine", description="临床辅助诊断与医学大模型"),
            ]:
                self.create_topic_tag(tag)
        post_count = self.conn.execute("SELECT COUNT(*) FROM daily_posts").fetchone()[0]
        if post_count >= 20:
            return
        existing_titles = {
            row["title"]
            for row in self.conn.execute("SELECT title FROM daily_posts").fetchall()
        }
        user_row = self.conn.execute("SELECT id FROM users ORDER BY id ASC LIMIT 1").fetchone()
        if user_row is None:
            return
        user_id = int(user_row["id"])
        samples = [
            DailyPostCreateRequest(
                title="多模态科研智能体复现记录",
                summary="把论文检索、实验脚本和结果复盘串成自动化流程，记录第一轮复现实验的收获。",
                content="今天完成了多模态科研智能体的最小复现。核心变化是把检索、代码执行和结果摘要拆成三个可观察节点，方便定位失败原因。下一步会加入更严格的基准任务和错误归因表。",
                cover_url="https://images.unsplash.com/photo-1677442136019-21780ecad995?auto=format&fit=crop&w=900&q=80",
                image_urls=[
                    "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=900&q=80"
                ],
                category_id="ai",
                tag_ids=["ai-agent", "llm-paper"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="单细胞免疫图谱文献阅读",
                summary="整理炎症消退过程中的瞬时免疫状态，标注可复用的数据处理与可视化方法。",
                content="这篇工作最值得复用的是跨组织整合策略。作者没有只停留在聚类命名，而是把状态转移、标志基因和功能验证连成证据链。",
                cover_url="https://images.unsplash.com/photo-1576086213369-97a306d36557?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="bio",
                tag_ids=["single-cell", "immunology"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="钙钛矿稳定性实验小结",
                summary="记录退火温度、封装条件和湿热测试对器件寿命的影响，准备下一轮对照实验。",
                content="本轮实验显示封装条件比单纯调配方更影响早期衰减。下一步需要把湿度、温度和光照强度拆开做三因素设计。",
                cover_url="https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="materials",
                tag_ids=["perovskite"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="RAG 文献问答流程搭建",
                summary="把论文 PDF 切分、向量检索和回答溯源串起来，形成可复用的文献问答管线。",
                content="今天重点验证了 chunk 大小和召回数量对回答质量的影响。下一步会把 DOI、页码和原文句子一起写入引用卡片。",
                cover_url="https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="ai",
                tag_ids=["llm-paper", "ai-agent"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="大模型评测误差分析",
                summary="对科研问答任务中的错误类型做归因，区分检索失败、推理跳步和格式解析错误。",
                content="本轮错误主要集中在长表格和跨段落证据合并。后续计划加入结构化证据缓存，降低重复检索成本。",
                cover_url="https://images.unsplash.com/photo-1551288049-bebda4e38f71?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="ai",
                tag_ids=["llm-paper"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="AI Agent 工具调用实验",
                summary="记录智能体在论文检索、代码运行和结果总结三个工具间切换的稳定性表现。",
                content="工具调用链条中最容易失败的是参数生成和异常恢复。今天给每个工具加了输入校验和失败重试提示。",
                cover_url="https://images.unsplash.com/photo-1677756119517-756a188d2d94?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="ai",
                tag_ids=["ai-agent"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="Transformer 经典论文复盘",
                summary="从注意力机制、位置编码和并行训练三个角度复盘 Transformer 的核心贡献。",
                content="复盘后最重要的启发是结构简化带来的工程扩展性。后续会把这部分整理成教学图解。",
                cover_url="https://images.unsplash.com/photo-1620712943543-bcc4688e7485?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="ai",
                tag_ids=["llm-paper"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="单细胞聚类参数对比",
                summary="比较不同分辨率参数对细胞群划分的影响，检查标志基因是否稳定。",
                content="高分辨率能发现更细状态，但也带来噪声簇。今天先固定 QC 阈值，再逐步调整聚类参数。",
                cover_url="https://images.unsplash.com/photo-1581093458791-9d09f8d088f4?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="bio",
                tag_ids=["single-cell"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="免疫细胞状态标注记录",
                summary="根据标志基因和通路活性为免疫细胞状态命名，整理可复用标注规则。",
                content="今天把 T 细胞耗竭、活化和增殖状态分开标注。后续会加入参考图谱做自动映射校验。",
                cover_url="https://images.unsplash.com/photo-1579154204601-01588f351e67?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="bio",
                tag_ids=["immunology", "single-cell"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="空间转录组阅读笔记",
                summary="整理空间表达热点、细胞互作和组织结构之间的证据链。",
                content="空间数据最关键的是把组织位置和表达模式同时解释。今天先完成邻域富集分析的流程梳理。",
                cover_url="https://images.unsplash.com/photo-1559757175-0eb30cd8c063?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="bio",
                tag_ids=["single-cell"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="蛋白结构预测工具体验",
                summary="试用结构预测结果可视化流程，记录置信度、结构域和突变位点映射。",
                content="今天重点看了 pLDDT 和结构域边界。后续会把突变位点和文献证据联动展示。",
                cover_url="https://images.unsplash.com/photo-1530026405186-ed1f139313f8?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="bio",
                tag_ids=["immunology"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="钙钛矿薄膜退火条件记录",
                summary="比较不同退火温度和时间对薄膜均匀性、缺陷和初始效率的影响。",
                content="本轮结果显示 100 摄氏度附近的工艺窗口更稳定，但湿度敏感性仍需要进一步控制。",
                cover_url="https://images.unsplash.com/photo-1617791160505-6f00504e3519?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="materials",
                tag_ids=["perovskite"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="材料表征数据整理",
                summary="把 XRD、SEM 和吸收谱数据统一归档，建立材料实验记录模板。",
                content="今天完成了命名规则和图谱导出格式统一。后续会把异常峰位自动标注接入日报模板。",
                cover_url="https://images.unsplash.com/photo-1582719471384-894fbb16e074?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="materials",
                tag_ids=["perovskite"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="催化剂活性数据复核",
                summary="复核不同批次催化剂的活性和稳定性曲线，定位批间差异来源。",
                content="批间差异可能来自前驱体纯度和干燥条件。下一步会增加空白对照和重复实验。",
                cover_url="https://images.unsplash.com/photo-1567427017947-545c5f8d16ad?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="materials",
                tag_ids=["perovskite"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="临床 AI 影像读片笔记",
                summary="整理医学影像模型在敏感性、特异性和可解释性上的评估指标。",
                content="今天重点对比了 ROC、PR 曲线和医生一致性评估。后续会加入病例级错误分析。",
                cover_url="https://images.unsplash.com/photo-1583912267550-d44c03f6df43?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="medicine",
                tag_ids=["clinical-ai"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="电子病历结构化抽取",
                summary="记录诊断、用药和检验指标抽取规则，准备构建临床研究队列。",
                content="目前规则抽取对缩写和否定表达较敏感。下一步会加入医学词典和人工校验界面。",
                cover_url="https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="medicine",
                tag_ids=["clinical-ai"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="药物重定位文献整理",
                summary="汇总网络药理学和大模型辅助筛选在药物重定位中的常见流程。",
                content="今天把候选药物筛选、靶点验证和临床证据分层整理成表格，方便后续写综述。",
                cover_url="https://images.unsplash.com/photo-1587854692152-cbe660dbde88?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="medicine",
                tag_ids=["clinical-ai"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="科研日报写作模板优化",
                summary="根据实验记录、文献阅读和阶段总结三种场景优化日报模板字段。",
                content="模板需要兼顾快速填写和结构完整。今天新增了风险阻塞和下一步计划两个固定字段。",
                cover_url="https://images.unsplash.com/photo-1456324504439-367cee3b3c32?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="ai",
                tag_ids=["ai-agent"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="论文 PDF 阅读进度设计",
                summary="设计 PDF 阅读模块的页码、进度、收藏和笔记入口，连接文献库与日报创作。",
                content="阅读进度不应存 PDF 本体，只需保存 paper_id、当前页和进度比例。这样数据库更轻，迁移也简单。",
                cover_url="https://images.unsplash.com/photo-1481627834876-b7833e8f5570?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="ai",
                tag_ids=["llm-paper"],
                status="published",
            ),
            DailyPostCreateRequest(
                title="科研知识库索引方案",
                summary="规划论文元数据、PDF 地址、标签关系和阅读进度表，避免把大文件直接塞进数据库。",
                content="数据库只做索引，PDF 放在文件目录或对象存储。这样列表查询快，也方便后续做全文检索。",
                cover_url="https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=900&q=80",
                image_urls=[],
                category_id="ai",
                tag_ids=["ai-agent", "llm-paper"],
                status="published",
            ),
        ]
        for sample in samples:
            if post_count >= 20:
                break
            if sample.title in existing_titles:
                continue
            self.create_daily_post(user_id, sample)
            existing_titles.add(sample.title)
            post_count += 1

    def _is_placeholder_text(self, value: str) -> bool:
        text = value.strip()
        return len(text) >= 3 and re.fullmatch(r"\?+", text) is not None

    def _cleanup_placeholder_daily_posts(self) -> None:
        rows = self.conn.execute(
            """
            SELECT id, title, summary
            FROM daily_posts
            """
        ).fetchall()
        placeholder_ids = [
            row["id"]
            for row in rows
            if self._is_placeholder_text(row["title"]) and self._is_placeholder_text(row["summary"])
        ]
        if not placeholder_ids:
            return
        self.conn.executemany(
            "DELETE FROM daily_posts WHERE id = ?",
            [(post_id,) for post_id in placeholder_ids],
        )
        self.conn.commit()

    def _cleanup_placeholder_papers(self) -> None:
        rows = self.conn.execute(
            """
            SELECT id, title, abstract
            FROM papers
            """
        ).fetchall()
        placeholder_ids = [
            row["id"]
            for row in rows
            if self._is_placeholder_text(row["title"]) and self._is_placeholder_text(row["abstract"])
        ]
        if not placeholder_ids:
            return
        self.conn.executemany(
            "DELETE FROM papers WHERE id = ?",
            [(paper_id,) for paper_id in placeholder_ids],
        )
        self.conn.commit()

    def _seed_paper_library(self) -> None:
        paper_count = self.conn.execute("SELECT COUNT(*) FROM papers").fetchone()[0]
        if paper_count >= 20:
            return
        existing_titles = {
            row["title"]
            for row in self.conn.execute("SELECT title FROM papers").fetchall()
        }
        samples = [
            PaperCreateRequest(
                title="Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks",
                abstract="A foundational paper on combining parametric language models with non-parametric retrieval, useful for building reliable research assistants.",
                authors=["Patrick Lewis", "Ethan Perez", "Aleksandra Piktus"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/2005.11401",
                pdf_url="https://arxiv.org/pdf/2005.11401",
                doi=None,
                published_at="2020-05-22",
            ),
            PaperCreateRequest(
                title="ReAct: Synergizing Reasoning and Acting in Language Models",
                abstract="Introduces a prompting framework where language models interleave reasoning traces and actions, a core reference for AI agent workflows.",
                authors=["Shunyu Yao", "Jeffrey Zhao", "Dian Yu"],
                category_id="ai",
                tag_ids=["ai-agent", "llm-paper"],
                source_url="https://arxiv.org/abs/2210.03629",
                pdf_url="https://arxiv.org/pdf/2210.03629",
                doi=None,
                published_at="2022-10-06",
            ),
            PaperCreateRequest(
                title="Attention Is All You Need",
                abstract="The Transformer paper that introduced attention-only sequence modeling and became a foundation for modern large language models.",
                authors=["Ashish Vaswani", "Noam Shazeer", "Niki Parmar"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/1706.03762",
                pdf_url="https://arxiv.org/pdf/1706.03762",
                doi=None,
                published_at="2017-06-12",
            ),
            PaperCreateRequest(
                title="BERT: Pre-training of Deep Bidirectional Transformers for Language Understanding",
                abstract="Introduces bidirectional Transformer pre-training for language understanding tasks.",
                authors=["Jacob Devlin", "Ming-Wei Chang", "Kenton Lee"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/1810.04805",
                pdf_url="https://arxiv.org/pdf/1810.04805",
                doi=None,
                published_at="2018-10-11",
            ),
            PaperCreateRequest(
                title="Language Models are Few-Shot Learners",
                abstract="Presents GPT-3 and demonstrates strong few-shot learning behavior at scale.",
                authors=["Tom B. Brown", "Benjamin Mann", "Nick Ryder"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/2005.14165",
                pdf_url="https://arxiv.org/pdf/2005.14165",
                doi=None,
                published_at="2020-05-28",
            ),
            PaperCreateRequest(
                title="Learning Transferable Visual Models From Natural Language Supervision",
                abstract="Introduces CLIP, aligning images and text through large-scale contrastive learning.",
                authors=["Alec Radford", "Jong Wook Kim", "Chris Hallacy"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/2103.00020",
                pdf_url="https://arxiv.org/pdf/2103.00020",
                doi=None,
                published_at="2021-02-26",
            ),
            PaperCreateRequest(
                title="Chain-of-Thought Prompting Elicits Reasoning in Large Language Models",
                abstract="Shows that chain-of-thought examples improve multi-step reasoning in large language models.",
                authors=["Jason Wei", "Xuezhi Wang", "Dale Schuurmans"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/2201.11903",
                pdf_url="https://arxiv.org/pdf/2201.11903",
                doi=None,
                published_at="2022-01-28",
            ),
            PaperCreateRequest(
                title="Toolformer: Language Models Can Teach Themselves to Use Tools",
                abstract="A method for teaching language models to call external tools through self-supervised data generation.",
                authors=["Timo Schick", "Jane Dwivedi-Yu", "Roberto Dessì"],
                category_id="ai",
                tag_ids=["ai-agent", "llm-paper"],
                source_url="https://arxiv.org/abs/2302.04761",
                pdf_url="https://arxiv.org/pdf/2302.04761",
                doi=None,
                published_at="2023-02-09",
            ),
            PaperCreateRequest(
                title="Tree of Thoughts: Deliberate Problem Solving with Large Language Models",
                abstract="Extends chain-of-thought into a search process over intermediate reasoning states.",
                authors=["Shunyu Yao", "Dian Yu", "Jeffrey Zhao"],
                category_id="ai",
                tag_ids=["ai-agent", "llm-paper"],
                source_url="https://arxiv.org/abs/2305.10601",
                pdf_url="https://arxiv.org/pdf/2305.10601",
                doi=None,
                published_at="2023-05-17",
            ),
            PaperCreateRequest(
                title="Segment Anything",
                abstract="Presents the Segment Anything Model and a large-scale segmentation dataset.",
                authors=["Alexander Kirillov", "Eric Mintun", "Nikhila Ravi"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/2304.02643",
                pdf_url="https://arxiv.org/pdf/2304.02643",
                doi=None,
                published_at="2023-04-05",
            ),
            PaperCreateRequest(
                title="Generative Adversarial Nets",
                abstract="Introduces GANs, a foundational generative modeling framework.",
                authors=["Ian Goodfellow", "Jean Pouget-Abadie", "Mehdi Mirza"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/1406.2661",
                pdf_url="https://arxiv.org/pdf/1406.2661",
                doi=None,
                published_at="2014-06-10",
            ),
            PaperCreateRequest(
                title="Auto-Encoding Variational Bayes",
                abstract="Introduces variational autoencoders and the reparameterization trick.",
                authors=["Diederik P. Kingma", "Max Welling"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/1312.6114",
                pdf_url="https://arxiv.org/pdf/1312.6114",
                doi=None,
                published_at="2013-12-20",
            ),
            PaperCreateRequest(
                title="Adam: A Method for Stochastic Optimization",
                abstract="Presents the Adam optimizer widely used in deep learning training.",
                authors=["Diederik P. Kingma", "Jimmy Ba"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/1412.6980",
                pdf_url="https://arxiv.org/pdf/1412.6980",
                doi=None,
                published_at="2014-12-22",
            ),
            PaperCreateRequest(
                title="Deep Residual Learning for Image Recognition",
                abstract="Introduces ResNet and residual connections for very deep neural networks.",
                authors=["Kaiming He", "Xiangyu Zhang", "Shaoqing Ren"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/1512.03385",
                pdf_url="https://arxiv.org/pdf/1512.03385",
                doi=None,
                published_at="2015-12-10",
            ),
            PaperCreateRequest(
                title="Faster R-CNN: Towards Real-Time Object Detection with Region Proposal Networks",
                abstract="A classic object detection framework using region proposal networks.",
                authors=["Shaoqing Ren", "Kaiming He", "Ross Girshick"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/1506.01497",
                pdf_url="https://arxiv.org/pdf/1506.01497",
                doi=None,
                published_at="2015-06-04",
            ),
            PaperCreateRequest(
                title="Neural Ordinary Differential Equations",
                abstract="Introduces continuous-depth neural networks parameterized by ordinary differential equations.",
                authors=["Ricky T. Q. Chen", "Yulia Rubanova", "Jesse Bettencourt"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/1806.07366",
                pdf_url="https://arxiv.org/pdf/1806.07366",
                doi=None,
                published_at="2018-06-19",
            ),
            PaperCreateRequest(
                title="Exploring the Limits of Transfer Learning with a Unified Text-to-Text Transformer",
                abstract="Introduces T5 and frames many NLP tasks as text-to-text problems.",
                authors=["Colin Raffel", "Noam Shazeer", "Adam Roberts"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/1910.10683",
                pdf_url="https://arxiv.org/pdf/1910.10683",
                doi=None,
                published_at="2019-10-23",
            ),
            PaperCreateRequest(
                title="EfficientNet: Rethinking Model Scaling for Convolutional Neural Networks",
                abstract="Studies compound scaling of model depth, width, and resolution.",
                authors=["Mingxing Tan", "Quoc V. Le"],
                category_id="ai",
                tag_ids=["llm-paper"],
                source_url="https://arxiv.org/abs/1905.11946",
                pdf_url="https://arxiv.org/pdf/1905.11946",
                doi=None,
                published_at="2019-05-28",
            ),
            PaperCreateRequest(
                title="Highly accurate protein structure prediction with AlphaFold",
                abstract="A landmark Nature paper describing AlphaFold's high-accuracy protein structure prediction.",
                authors=["John Jumper", "Richard Evans", "Alexander Pritzel"],
                category_id="bio",
                tag_ids=["single-cell"],
                source_url="https://www.nature.com/articles/s41586-021-03819-2",
                pdf_url="https://www.nature.com/articles/s41586-021-03819-2.pdf",
                doi="10.1038/s41586-021-03819-2",
                published_at="2021-07-15",
            ),
            PaperCreateRequest(
                title="Scalable and accurate deep learning with electronic health records",
                abstract="A representative clinical AI paper using deep learning over electronic health records.",
                authors=["Alvin Rajkomar", "Eyal Oren", "Kai Chen"],
                category_id="medicine",
                tag_ids=["clinical-ai"],
                source_url="https://www.nature.com/articles/s41746-018-0029-1",
                pdf_url="https://www.nature.com/articles/s41746-018-0029-1.pdf",
                doi="10.1038/s41746-018-0029-1",
                published_at="2018-05-08",
            ),
            PaperCreateRequest(
                title="Best practices for single-cell analysis across modalities",
                abstract="A review-style reference for single-cell analysis workflows across data modalities.",
                authors=["Single-cell analysis community"],
                category_id="bio",
                tag_ids=["single-cell"],
                source_url="https://www.nature.com/articles/s41576-023-00586-w",
                pdf_url="https://www.nature.com/articles/s41576-023-00586-w.pdf",
                doi="10.1038/s41576-023-00586-w",
                published_at="2023-04-01",
            ),
            PaperCreateRequest(
                title="Perovskite photovoltaics: stability and scalability",
                abstract="A representative materials science paper about stability and scaling challenges in perovskite photovoltaics.",
                authors=["Materials research community"],
                category_id="materials",
                tag_ids=["perovskite"],
                source_url="https://www.nature.com/articles/s41560-020-00739-5",
                pdf_url="https://www.nature.com/articles/s41560-020-00739-5.pdf",
                doi="10.1038/s41560-020-00739-5",
                published_at="2020-12-01",
            ),
        ]
        for sample in samples:
            if paper_count >= 20:
                break
            if sample.title in existing_titles:
                continue
            try:
                self.create_paper(sample)
                existing_titles.add(sample.title)
                paper_count += 1
            except ValueError:
                continue

    def get_interaction_summary(self, news_id: str) -> InteractionSummary:
        like_count = self._count_interaction_items("user_likes", "likes", news_id)
        collection_count = self._count_interaction_items("user_collections", "collections", news_id)
        comment_count = int(
            self.conn.execute("SELECT COUNT(*) FROM comments WHERE news_id = ?", (news_id,)).fetchone()[0]
        )
        return InteractionSummary(
            like_count=like_count,
            collection_count=collection_count,
            comment_count=comment_count,
        )

    def list_comments(self, news_id: str, page: int, size: int, sort: str) -> CommentListResponse:
        page = max(page, 1)
        size = min(max(size, 1), 50)
        offset = (page - 1) * size
        order_by = "comments.like_count DESC, comments.created_at DESC" if sort == "hot" else "comments.created_at DESC"
        rows = self.conn.execute(
            f"""
            SELECT
                comments.*,
                users.nickname AS nickname,
                parent_users.nickname AS reply_to_nickname
            FROM comments
            JOIN users ON users.id = comments.user_id
            LEFT JOIN comments AS parent_comments ON parent_comments.id = comments.parent_id
            LEFT JOIN users AS parent_users ON parent_users.id = parent_comments.user_id
            WHERE comments.news_id = ?
            ORDER BY {order_by}
            LIMIT ? OFFSET ?
            """,
            (news_id, size, offset),
        ).fetchall()
        total = int(self.conn.execute("SELECT COUNT(*) FROM comments WHERE news_id = ?", (news_id,)).fetchone()[0])
        return CommentListResponse(
            items=[self._comment_from_row(row) for row in rows],
            total=total,
            page=page,
            size=size,
        )

    def add_comment(self, news_id: str, user_id: int, payload: CommentCreateRequest) -> CommentItem:
        content = payload.content.strip()
        if not content:
            raise ValueError("Comment content is required")
        if len(content) > 200:
            raise ValueError("Comment content must be at most 200 characters")
        parent_user_id: Optional[int] = None
        if payload.parent_id is not None:
            parent = self.conn.execute(
                "SELECT id, user_id FROM comments WHERE id = ? AND news_id = ?",
                (payload.parent_id, news_id),
            ).fetchone()
            if parent is None:
                raise ValueError("Parent comment not found")
            parent_user_id = int(parent["user_id"])
        created_at = now_text()
        cursor = self.conn.execute(
            """
            INSERT INTO comments (news_id, user_id, parent_id, content, like_count, created_at)
            VALUES (?, ?, ?, ?, 0, ?)
            """,
            (news_id, user_id, payload.parent_id, content, created_at),
        )
        comment_id = int(cursor.lastrowid)
        self.conn.commit()

        notice_title = "评论已发布" if payload.parent_id is None else "回复已发布"
        self._add_notification(
            user_id=user_id,
            notice_type="comment",
            title=notice_title,
            content=content[:80],
            related_item_id=news_id,
        )
        if parent_user_id is not None and parent_user_id != user_id:
            replier = self.get_user(user_id)
            self._add_notification(
                user_id=parent_user_id,
                notice_type="comment",
                title="收到一条评论回复",
                content=f"{replier.nickname} 回复了你：{content[:60]}",
                related_item_id=news_id,
            )
        row = self.conn.execute(
            """
            SELECT
                comments.*,
                users.nickname AS nickname,
                parent_users.nickname AS reply_to_nickname
            FROM comments
            JOIN users ON users.id = comments.user_id
            LEFT JOIN comments AS parent_comments ON parent_comments.id = comments.parent_id
            LEFT JOIN users AS parent_users ON parent_users.id = parent_comments.user_id
            WHERE comments.id = ?
            """,
            (comment_id,),
        ).fetchone()
        return self._comment_from_row(row)

    def like_comment(self, comment_id: int, user_id: int) -> CommentItem:
        row = self.conn.execute(
            "SELECT id, news_id, user_id, content FROM comments WHERE id = ?",
            (comment_id,),
        ).fetchone()
        if row is None:
            raise ValueError("Comment not found")

        created_at = now_text()
        cursor = self.conn.execute(
            """
            INSERT OR IGNORE INTO comment_likes (comment_id, user_id, created_at)
            VALUES (?, ?, ?)
            """,
            (comment_id, user_id, created_at),
        )
        if cursor.rowcount > 0:
            self.conn.execute(
                "UPDATE comments SET like_count = like_count + 1 WHERE id = ?",
                (comment_id,),
            )
            owner_id = int(row["user_id"])
            if owner_id != user_id:
                liker = self.get_user(user_id)
                self._add_notification(
                    user_id=owner_id,
                    notice_type="like",
                    title="评论收到点赞",
                    content=f"{liker.nickname} 点赞了你的评论：{row['content'][:60]}",
                    related_item_id=row["news_id"],
                )
        self.conn.commit()
        return self.get_comment(comment_id)

    def unlike_comment(self, comment_id: int, user_id: int) -> CommentItem:
        row = self.conn.execute("SELECT id FROM comments WHERE id = ?", (comment_id,)).fetchone()
        if row is None:
            raise ValueError("Comment not found")

        cursor = self.conn.execute(
            "DELETE FROM comment_likes WHERE comment_id = ? AND user_id = ?",
            (comment_id, user_id),
        )
        if cursor.rowcount > 0:
            self.conn.execute(
                """
                UPDATE comments
                SET like_count = CASE WHEN like_count > 0 THEN like_count - 1 ELSE 0 END
                WHERE id = ?
                """,
                (comment_id,),
            )
        self.conn.commit()
        return self.get_comment(comment_id)

    def get_comment(self, comment_id: int) -> CommentItem:
        row = self.conn.execute(
            """
            SELECT
                comments.*,
                users.nickname AS nickname,
                parent_users.nickname AS reply_to_nickname
            FROM comments
            JOIN users ON users.id = comments.user_id
            LEFT JOIN comments AS parent_comments ON parent_comments.id = comments.parent_id
            LEFT JOIN users AS parent_users ON parent_users.id = parent_comments.user_id
            WHERE comments.id = ?
            """,
            (comment_id,),
        ).fetchone()
        if row is None:
            raise ValueError("Comment not found")
        return self._comment_from_row(row)

    def delete_comment(self, comment_id: int, user_id: int) -> None:
        row = self.conn.execute("SELECT user_id FROM comments WHERE id = ?", (comment_id,)).fetchone()
        if row is None:
            raise ValueError("Comment not found")
        if int(row["user_id"]) != user_id:
            raise ValueError("You can only delete your own comments")
        self.conn.execute("DELETE FROM comments WHERE id = ?", (comment_id,))
        self.conn.commit()

    def get_research_stats(self, user_id: int, range_name: str) -> ResearchStatsResponse:
        labels = self._stats_labels(range_name)
        points: list[ResearchStatsPoint] = []
        rows = self.conn.execute(
            """
            SELECT title, summary, created_at FROM user_posts WHERE user_id = ?
            UNION ALL
            SELECT title, summary, created_at FROM user_browsing_history WHERE user_id = ?
            """,
            (user_id, user_id),
        ).fetchall()
        label_set = {label: {"daily": 0, "experiment": 0, "literature": 0} for label in labels}
        for row in rows:
            label = row["created_at"][:10]
            if range_name == "week":
                label = label[-5:]
            elif range_name == "month":
                label = label[-5:]
            if label not in label_set:
                continue
            merged = f"{row['title']} {row['summary']}"
            label_set[label]["daily"] += 1
            if "实验" in merged:
                label_set[label]["experiment"] += 1
            if "文献" in merged or "论文" in merged:
                label_set[label]["literature"] += 1
        for label in labels:
            values = label_set[label]
            points.append(
                ResearchStatsPoint(
                    label=label,
                    daily_count=values["daily"],
                    experiment_count=values["experiment"],
                    literature_count=values["literature"],
                )
            )
        return ResearchStatsResponse(
            range=range_name,
            total_daily=sum(point.daily_count for point in points),
            total_experiment=sum(point.experiment_count for point in points),
            total_literature=sum(point.literature_count for point in points),
            points=points,
        )

    def list_notifications(self, user_id: int) -> NotificationListResponse:
        rows = self.conn.execute(
            """
            SELECT * FROM notifications
            WHERE user_id = ?
            ORDER BY is_read ASC, created_at DESC
            LIMIT 100
            """,
            (user_id,),
        ).fetchall()
        unread = int(
            self.conn.execute(
                "SELECT COUNT(*) FROM notifications WHERE user_id = ? AND is_read = 0",
                (user_id,),
            ).fetchone()[0]
        )
        return NotificationListResponse(
            items=[self._notification_from_row(row) for row in rows],
            unread_count=unread,
        )

    def mark_notification_read(self, user_id: int, notice_id: int) -> None:
        self.conn.execute(
            "UPDATE notifications SET is_read = 1 WHERE user_id = ? AND id = ?",
            (user_id, notice_id),
        )
        self.conn.commit()

    def mark_all_notifications_read(self, user_id: int) -> None:
        self.conn.execute("UPDATE notifications SET is_read = 1 WHERE user_id = ?", (user_id,))
        self.conn.commit()

    def clear_notifications(self, user_id: int) -> None:
        self.conn.execute("DELETE FROM notifications WHERE user_id = ?", (user_id,))
        self.conn.commit()

    def _seed_user_workspace(self, user_id: int) -> None:
        samples = {
            "user_posts": [
                (
                    "post-001",
                    "实验记录：多模态推理评测复现",
                    "记录数据清洗、基线模型和第一轮误差分析。",
                    "2026-06-01T09:30:00+00:00",
                    "已发布",
                ),
                (
                    "post-002",
                    "文献阅读：单细胞免疫图谱",
                    "整理核心方法、数据来源和可复用的分析流程。",
                    "2026-05-30T14:20:00+00:00",
                    "草稿",
                ),
            ],
            "user_collections": [
                (
                    "collect-001",
                    "基础模型提升多模态科学推理能力",
                    "工具增强推理显著提升科学问答准确率。",
                    "2026-06-02T11:12:00+00:00",
                    "已收藏",
                ),
                (
                    "collect-002",
                    "高熵钙钛矿用于稳定太阳能转换",
                    "高熵钙钛矿提升热稳定性和使用寿命。",
                    "2026-06-01T18:05:00+00:00",
                    "已收藏",
                ),
            ],
            "user_likes": [
                (
                    "like-001",
                    "单细胞图谱揭示动态免疫细胞状态",
                    "跨组织单细胞图谱揭示炎症恢复中的瞬时状态。",
                    "2026-06-02T20:15:00+00:00",
                    "已点赞",
                ),
                (
                    "like-002",
                    "实验记录：多模态推理评测复现",
                    "记录数据清洗、基线模型和第一轮误差分析。",
                    "2026-06-01T12:42:00+00:00",
                    "已点赞",
                ),
            ],
            "user_browsing_history": [
                (
                    "history-001",
                    "基础模型提升多模态科学推理能力",
                    "工具增强推理显著提升科学问答准确率。",
                    "2026-06-03T08:00:00+00:00",
                    "已浏览",
                ),
                (
                    "history-002",
                    "单细胞图谱揭示动态免疫细胞状态",
                    "跨组织单细胞图谱揭示炎症恢复中的瞬时状态。",
                    "2026-06-02T08:10:00+00:00",
                    "已浏览",
                ),
                (
                    "history-003",
                    "高熵钙钛矿用于稳定太阳能转换",
                    "高熵钙钛矿提升热稳定性和使用寿命。",
                    "2026-06-01T08:25:00+00:00",
                    "已浏览",
                ),
            ],
        }
        inspirations = [
            (
                "inspiration-001",
                "RAG 文献问答如果把 DOI、页码和原文句子一起存下来，组会汇报时更容易说明证据来源。",
                "idea",
                "阅读 PDF 时想到",
                "active",
                "2026-06-03T09:12:00+00:00",
            ),
            (
                "inspiration-002",
                "钙钛矿稳定性实验要把湿度、温度、光照强度拆成三个变量，先做小规模正交对照。",
                "experiment",
                "实验讨论",
                "active",
                "2026-06-02T16:30:00+00:00",
            ),
            (
                "inspiration-003",
                "单细胞状态标注可以增加一个“证据等级”：标志基因、通路活性、参考图谱三者都支持才算高可信。",
                "paper",
                "文献阅读",
                "used",
                "2026-06-01T20:05:00+00:00",
            ),
            (
                "inspiration-004",
                "今天想把科研日报和论文阅读串起来：先记录论文标题、DOI、PDF 链接、核心方法、实验结果和局限，再自动生成一版可直接发到社区的日报。下一步准备补充引用页码、复现要点和组会提问三个固定栏位。",
                "paper",
                "科研日报模板优化",
                "active",
                "2026-06-04T09:40:00+00:00",
            ),
        ]
        for table, rows in samples.items():
            for row in rows:
                item_id = f"u{user_id}-{row[0]}"
                self.conn.execute(
                    f"""
                    INSERT OR IGNORE INTO {table}
                    (id, user_id, title, summary, created_at, status)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (item_id, user_id, row[1], row[2], row[3], row[4]),
                )
        for item in inspirations:
            inspiration_id = f"u{user_id}-{item[0]}"
            self.conn.execute(
                """
                INSERT OR IGNORE INTO user_inspirations
                (id, user_id, content, scene, source, status, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (inspiration_id, user_id, item[1], item[2], item[3], item[4], item[5], item[5]),
            )
        self.conn.commit()

    def _count_table(self, table: str, user_id: int) -> int:
        return int(self.conn.execute(f"SELECT COUNT(*) FROM {table} WHERE user_id = ?", (user_id,)).fetchone()[0])

    def _count_item_suffix(self, table: str, table_key: str, item_id: str) -> int:
        suffix = f"%-{table_key}-{item_id.strip()}"
        return int(self.conn.execute(f"SELECT COUNT(*) FROM {table} WHERE id LIKE ?", (suffix,)).fetchone()[0])

    def _count_interaction_items(self, table: str, table_key: str, news_id: str) -> int:
        title = self._news_title(news_id)
        suffix = f"%-{table_key}-{news_id.strip()}"
        if title:
            return int(
                self.conn.execute(
                    f"SELECT COUNT(*) FROM {table} WHERE id LIKE ? OR title = ?",
                    (suffix, title),
                ).fetchone()[0]
            )
        return self._count_item_suffix(table, table_key, news_id)

    def _table_for_key(self, table_key: str) -> str:
        table_map = {
            "posts": "user_posts",
            "collections": "user_collections",
            "likes": "user_likes",
            "follows": "user_follows",
            "history": "user_browsing_history",
        }
        if table_key not in table_map:
            raise ValueError("Unsupported personal item type")
        return table_map[table_key]

    def _stored_item_id(self, user_id: int, table_key: str, item_id: str) -> str:
        return f"u{user_id}-{table_key}-{item_id.strip()}"

    def _continuous_days(self, user_id: int) -> int:
        rows = self.conn.execute(
            """
            SELECT created_at FROM user_posts WHERE user_id = ?
            UNION ALL
            SELECT created_at FROM user_browsing_history WHERE user_id = ?
            """,
            (user_id, user_id),
        ).fetchall()
        active_dates = {row["created_at"][:10] for row in rows}
        current = date.today()
        days = 0
        while current.isoformat() in active_dates:
            days += 1
            current = current - timedelta(days=1)
        return days

    def _stats_labels(self, range_name: str) -> list[str]:
        today = date.today()
        if range_name == "day":
            return [today.isoformat()]
        days = 30 if range_name == "month" else 7
        labels = []
        for index in range(days - 1, -1, -1):
            labels.append((today - timedelta(days=index)).isoformat()[-5:])
        return labels

    def _news_title(self, news_id: str) -> str:
        for item in MOCK_NEWS:
            if item.id == news_id:
                return item.title
        return ""

    def _comment_from_row(self, row: sqlite3.Row) -> CommentItem:
        return CommentItem(
            id=int(row["id"]),
            news_id=row["news_id"],
            user_id=int(row["user_id"]),
            nickname=row["nickname"],
            content=row["content"],
            parent_id=row["parent_id"],
            reply_to_nickname=row["reply_to_nickname"],
            like_count=int(row["like_count"]),
            created_at=row["created_at"],
        )

    def _notification_from_row(self, row: sqlite3.Row) -> NotificationItem:
        return NotificationItem(
            id=int(row["id"]),
            type=row["type"],
            title=row["title"],
            content=row["content"],
            related_item_id=row["related_item_id"],
            is_read=bool(row["is_read"]),
            created_at=row["created_at"],
        )

    def _add_notification(
        self,
        user_id: int,
        notice_type: str,
        title: str,
        content: str,
        related_item_id: Optional[str] = None,
    ) -> None:
        if not self._notification_enabled(user_id, notice_type):
            return
        self.conn.execute(
            """
            INSERT INTO notifications (user_id, type, title, content, related_item_id, is_read, created_at)
            VALUES (?, ?, ?, ?, ?, 0, ?)
            """,
            (user_id, notice_type, title, content, related_item_id, now_text()),
        )
        self.conn.commit()

    def _notification_enabled(self, user_id: int, notice_type: str) -> bool:
        row = self.conn.execute("SELECT * FROM user_settings WHERE user_id = ?", (user_id,)).fetchone()
        if row is None:
            return True
        if notice_type in ("like", "collection", "follow"):
            return bool(row["like_notice"])
        if notice_type == "comment":
            return bool(row["comment_notice"])
        return bool(row["system_notice"])

    def _profile_from_row(self, row: sqlite3.Row) -> UserProfile:
        return UserProfile(
            id=int(row["id"]),
            username=row["username"],
            nickname=row["nickname"],
            avatar_url=row["avatar_url"],
            email=row["email"],
            bio=row["bio"],
            institution=row["institution"],
            research_field=row["research_field"],
            created_at=row["created_at"],
        )


store = AppStore()
