from __future__ import annotations

import json
import sqlite3
from datetime import datetime
from pathlib import Path

from research_daily.models import PaperRecord, ProjectRecord


class DailyDatabase:
    def __init__(self, db_path: str) -> None:
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(self.db_path)
        self.conn.execute("PRAGMA journal_mode=WAL;")
        self._create_tables()

    def _create_tables(self) -> None:
        self.conn.execute(
            """
            CREATE TABLE IF NOT EXISTS papers (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                authors TEXT NOT NULL,
                abstract TEXT NOT NULL,
                url TEXT NOT NULL,
                source TEXT NOT NULL,
                publish_time TEXT NOT NULL,
                category TEXT NOT NULL,
                matched_keywords TEXT NOT NULL,
                section TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        )
        self.conn.execute(
            """
            CREATE TABLE IF NOT EXISTS projects (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                url TEXT NOT NULL,
                description TEXT NOT NULL,
                language TEXT NOT NULL,
                stars INTEGER NOT NULL,
                source TEXT NOT NULL,
                publish_time TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        )
        self.conn.execute(
            """
            CREATE TABLE IF NOT EXISTS run_logs (
                run_date TEXT PRIMARY KEY,
                papers_total INTEGER NOT NULL,
                papers_filtered INTEGER NOT NULL,
                projects_total INTEGER NOT NULL,
                markdown_path TEXT NOT NULL,
                html_path TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            """
        )
        self.conn.commit()

    def upsert_papers(self, papers: list[PaperRecord]) -> int:
        now = datetime.now().isoformat()
        rows = [
            (
                p.id,
                p.title,
                json.dumps(p.authors, ensure_ascii=False),
                p.abstract,
                p.url,
                p.source,
                p.publish_time.isoformat(),
                p.category,
                json.dumps(p.matched_keywords, ensure_ascii=False),
                p.section,
                now,
            )
            for p in papers
        ]
        self.conn.executemany(
            """
            INSERT INTO papers (
                id, title, authors, abstract, url, source, publish_time,
                category, matched_keywords, section, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title=excluded.title,
                authors=excluded.authors,
                abstract=excluded.abstract,
                url=excluded.url,
                source=excluded.source,
                publish_time=excluded.publish_time,
                category=excluded.category,
                matched_keywords=excluded.matched_keywords,
                section=excluded.section,
                updated_at=excluded.updated_at;
            """,
            rows,
        )
        self.conn.commit()
        return len(rows)

    def upsert_projects(self, projects: list[ProjectRecord]) -> int:
        now = datetime.now().isoformat()
        rows = [
            (
                p.id,
                p.name,
                p.url,
                p.description,
                p.language,
                p.stars,
                p.source,
                p.publish_time.isoformat(),
                now,
            )
            for p in projects
        ]
        self.conn.executemany(
            """
            INSERT INTO projects (
                id, name, url, description, language, stars, source, publish_time, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name=excluded.name,
                url=excluded.url,
                description=excluded.description,
                language=excluded.language,
                stars=excluded.stars,
                source=excluded.source,
                publish_time=excluded.publish_time,
                updated_at=excluded.updated_at;
            """,
            rows,
        )
        self.conn.commit()
        return len(rows)

    def insert_run_log(
        self,
        run_date: str,
        papers_total: int,
        papers_filtered: int,
        projects_total: int,
        markdown_path: str,
        html_path: str,
    ) -> None:
        self.conn.execute(
            """
            INSERT INTO run_logs (
                run_date, papers_total, papers_filtered, projects_total,
                markdown_path, html_path, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(run_date) DO UPDATE SET
                papers_total=excluded.papers_total,
                papers_filtered=excluded.papers_filtered,
                projects_total=excluded.projects_total,
                markdown_path=excluded.markdown_path,
                html_path=excluded.html_path,
                created_at=excluded.created_at;
            """,
            (
                run_date,
                papers_total,
                papers_filtered,
                projects_total,
                markdown_path,
                html_path,
                datetime.now().isoformat(),
            ),
        )
        self.conn.commit()

    def close(self) -> None:
        self.conn.close()

