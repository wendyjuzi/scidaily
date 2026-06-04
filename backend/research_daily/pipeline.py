from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from research_daily.config import AppConfig
from research_daily.crawler.arxiv import fetch_arxiv
from research_daily.crawler.github import fetch_github_trending
from research_daily.crawler.rss import fetch_feed
from research_daily.database import DailyDatabase
from research_daily.filtering import dedupe_papers, filter_papers
from research_daily.push import send_email, send_telegram, send_wecom
from research_daily.reporting import render_html, render_markdown, save_html, save_markdown


@dataclass(slots=True)
class RunResult:
    run_date: str
    papers_total: int
    papers_filtered: int
    projects_total: int
    markdown_path: str
    html_path: str


def _fetch_extra_feeds(urls: list[str], max_items_per_feed: int) -> list:
    items = []
    for url in urls:
        items.extend(
            fetch_feed(
                url=url,
                source="rss",
                category="external",
                max_items=max_items_per_feed,
            )
        )
    return items


def run_pipeline(cfg: AppConfig, dry_run: bool = True) -> RunResult:
    today = datetime.now().date()
    all_papers = fetch_arxiv(cfg.source.arxiv_categories, cfg.source.max_items_per_feed)
    all_papers.extend(_fetch_extra_feeds(cfg.source.extra_rss, cfg.source.max_items_per_feed))
    deduped = dedupe_papers(all_papers)
    filtered = filter_papers(deduped, cfg.filtering)
    projects = fetch_github_trending(cfg.source.github_top_n)

    output_root = Path(cfg.report.output_dir) / today.isoformat()
    template_path = Path(cfg.report.template_path)

    markdown_text = render_markdown(filtered, projects, today, cfg.report)
    md_path = save_markdown(markdown_text, today, output_root)
    html = render_html(cfg.report, today, template_path, filtered, projects)
    html_path = save_html(html, today, output_root)

    db = DailyDatabase(cfg.database_path)
    try:
        db.upsert_papers(filtered)
        db.upsert_projects(projects)
        db.insert_run_log(
            run_date=today.isoformat(),
            papers_total=len(deduped),
            papers_filtered=len(filtered),
            projects_total=len(projects),
            markdown_path=str(md_path),
            html_path=str(html_path),
        )
    finally:
        db.close()

    if not dry_run:
        subject = f"{cfg.report.title} {today.isoformat()}"
        send_email(cfg.push, subject=subject, html_body=html)
        summary_text = (
            f"{subject}\n"
            f"论文抓取: {len(deduped)}\n"
            f"关键词命中: {len(filtered)}\n"
            f"Github项目: {len(projects)}"
        )
        send_wecom(cfg.push, summary_text)
        send_telegram(cfg.push, summary_text)

    return RunResult(
        run_date=today.isoformat(),
        papers_total=len(deduped),
        papers_filtered=len(filtered),
        projects_total=len(projects),
        markdown_path=str(md_path),
        html_path=str(html_path),
    )

