from __future__ import annotations

import hashlib
import hmac
import secrets
import sqlite3
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import List, Optional

from app.schemas import (
    CommentCreateRequest,
    CommentItem,
    CommentListResponse,
    InteractionSummary,
    MessageSettings,
    NotificationItem,
    NotificationListResponse,
    PersonalItem,
    PersonalItemActionRequest,
    PersonalStats,
    PrivacySettings,
    RegisterRequest,
    ResearchStatsPoint,
    ResearchStatsResponse,
    SettingsResponse,
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
        self._create_tables()
        self._seed_demo_data()

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

            CREATE TABLE IF NOT EXISTS user_browsing_history (
                id TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                summary TEXT NOT NULL,
                created_at TEXT NOT NULL,
                status TEXT NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
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
            post_count=post_count,
            collection_count=collection_count,
            like_count=like_count,
            history_count=history_count,
            continuous_days=self._continuous_days(user_id),
        )

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
                notice_type="system",
                title="收藏已同步",
                content=f"《{title}》已加入你的收藏列表。",
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

    def get_interaction_summary(self, news_id: str) -> InteractionSummary:
        like_count = self._count_item_suffix("user_likes", "likes", news_id)
        collection_count = self._count_item_suffix("user_collections", "collections", news_id)
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
        if payload.parent_id is not None:
            parent = self.conn.execute(
                "SELECT id, user_id FROM comments WHERE id = ? AND news_id = ?",
                (payload.parent_id, news_id),
            ).fetchone()
            if parent is None:
                raise ValueError("Parent comment not found")
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
        row = self.conn.execute(
            """
            SELECT comments.*, users.nickname AS nickname, NULL AS reply_to_nickname
            FROM comments
            JOIN users ON users.id = comments.user_id
            WHERE comments.id = ?
            """,
            (comment_id,),
        ).fetchone()
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
        self._ensure_system_notice(user_id)
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
        self.conn.commit()

    def _count_table(self, table: str, user_id: int) -> int:
        return int(self.conn.execute(f"SELECT COUNT(*) FROM {table} WHERE user_id = ?", (user_id,)).fetchone()[0])

    def _count_item_suffix(self, table: str, table_key: str, item_id: str) -> int:
        suffix = f"%-{table_key}-{item_id.strip()}"
        return int(self.conn.execute(f"SELECT COUNT(*) FROM {table} WHERE id LIKE ?", (suffix,)).fetchone()[0])

    def _table_for_key(self, table_key: str) -> str:
        table_map = {
            "posts": "user_posts",
            "collections": "user_collections",
            "likes": "user_likes",
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
        self.conn.execute(
            """
            INSERT INTO notifications (user_id, type, title, content, related_item_id, is_read, created_at)
            VALUES (?, ?, ?, ?, ?, 0, ?)
            """,
            (user_id, notice_type, title, content, related_item_id, now_text()),
        )
        self.conn.commit()

    def _ensure_system_notice(self, user_id: int) -> None:
        existing = self.conn.execute(
            "SELECT id FROM notifications WHERE user_id = ? AND type = 'system' AND related_item_id = 'welcome'",
            (user_id,),
        ).fetchone()
        if existing:
            return
        self._add_notification(
            user_id=user_id,
            notice_type="system",
            title="欢迎使用科研日报社区",
            content="C 分工模块已接入评论、科研统计看板和消息通知。",
            related_item_id="welcome",
        )

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
