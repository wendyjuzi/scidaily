from __future__ import annotations

from datetime import datetime
from typing import Any

import requests
from bs4 import BeautifulSoup

from research_daily.models import ProjectRecord

API_ENDPOINTS = [
    "https://gta.isboyjc.com/v2/trending?since=daily",
    "https://gta.isboyjc.com/v2/trending?since=weekly",
]


def _normalize_project_id(url: str, name: str) -> str:
    if url:
        return url.rstrip("/").replace("https://github.com/", "")
    return name.lower().replace(" ", "-")


def _as_int(value: Any) -> int:
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        clean = value.replace(",", "").strip()
        if clean.isdigit():
            return int(clean)
    return 0


def _parse_api_payload(payload: Any) -> list[ProjectRecord]:
    items: list[dict[str, Any]]
    if isinstance(payload, dict):
        for key in ("data", "items", "records", "list"):
            if isinstance(payload.get(key), list):
                items = payload[key]
                break
        else:
            items = []
    elif isinstance(payload, list):
        items = payload
    else:
        items = []

    projects: list[ProjectRecord] = []
    for item in items:
        url = item.get("url") or item.get("repoLink") or item.get("href") or ""
        name = item.get("fullName") or item.get("repo") or item.get("name") or ""
        description = item.get("description") or item.get("desc") or ""
        language = item.get("language") or "Unknown"
        stars = _as_int(item.get("stars") or item.get("starCount") or item.get("star"))
        if not name:
            continue
        projects.append(
            ProjectRecord(
                id=_normalize_project_id(url, name),
                name=name,
                url=url,
                description=description.strip(),
                language=language.strip(),
                stars=stars,
                source="github-trending-api",
                publish_time=datetime.now(),
            )
        )
    return projects


def fetch_github_trending_api(timeout: int = 15) -> list[ProjectRecord]:
    for endpoint in API_ENDPOINTS:
        try:
            resp = requests.get(endpoint, timeout=timeout)
            resp.raise_for_status()
            projects = _parse_api_payload(resp.json())
            if projects:
                return projects
        except requests.RequestException:
            continue
        except ValueError:
            continue
    return []


def fetch_github_trending_html(timeout: int = 15) -> list[ProjectRecord]:
    url = "https://github.com/trending?since=daily"
    resp = requests.get(url, timeout=timeout, headers={"User-Agent": "Mozilla/5.0"})
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")
    rows = soup.select("article.Box-row")
    projects: list[ProjectRecord] = []
    for row in rows:
        title_link = row.select_one("h2 a")
        if not title_link:
            continue
        name = " ".join(title_link.get_text(" ", strip=True).split())
        name = name.replace(" / ", "/").replace(" ", "")
        href = title_link.get("href", "")
        project_url = f"https://github.com{href}" if href.startswith("/") else href
        desc_tag = row.select_one("p")
        lang_tag = row.select_one("[itemprop='programmingLanguage']")
        stars_tag = row.select_one("a[href$='/stargazers']")
        projects.append(
            ProjectRecord(
                id=_normalize_project_id(project_url, name),
                name=name,
                url=project_url,
                description=(desc_tag.get_text(" ", strip=True) if desc_tag else ""),
                language=(lang_tag.get_text(" ", strip=True) if lang_tag else "Unknown"),
                stars=_as_int(stars_tag.get_text(" ", strip=True) if stars_tag else 0),
                source="github-trending-html",
                publish_time=datetime.now(),
            )
        )
    return projects


def fetch_github_trending(top_n: int = 20) -> list[ProjectRecord]:
    projects = fetch_github_trending_api()
    if not projects:
        projects = fetch_github_trending_html()
    return projects[:top_n]

