from __future__ import annotations

from collections import defaultdict
from datetime import date
from pathlib import Path

import markdown as mdlib
from jinja2 import Template

from research_daily.config import ReportConfig
from research_daily.models import PaperRecord, ProjectRecord


def _group_papers(papers: list[PaperRecord]) -> dict[str, list[PaperRecord]]:
    grouped: dict[str, list[PaperRecord]] = defaultdict(list)
    for paper in papers:
        grouped[paper.section].append(paper)
    return dict(sorted(grouped.items(), key=lambda x: x[0]))


def render_markdown(
    papers: list[PaperRecord],
    projects: list[ProjectRecord],
    report_date: date,
    report_cfg: ReportConfig,
) -> str:
    grouped = _group_papers(papers)
    lines = [
        f"# {report_cfg.title}",
        "",
        f"日期：{report_date.isoformat()}",
        "",
        f"今日新增论文：{len(papers)}篇",
        "",
        "## 论文速览",
    ]
    if not papers:
        lines.append("")
        lines.append("今日未匹配到关键词论文。")
    for section, items in grouped.items():
        lines.extend(["", f"## {section}"])
        for paper in items:
            lines.extend(
                [
                    "",
                    f"### {paper.title}",
                    f"- 作者：{', '.join(paper.authors) if paper.authors else 'N/A'}",
                    f"- 发布时间：{paper.publish_time.date().isoformat()}",
                    f"- 来源：{paper.source} / {paper.category}",
                    f"- 关键词：{', '.join(paper.matched_keywords) if paper.matched_keywords else 'N/A'}",
                    f"- 链接：{paper.url}",
                    "",
                    "摘要：",
                    paper.abstract or "N/A",
                ]
            )

    lines.extend(["", "## Github 热门项目"])
    if not projects:
        lines.extend(["", "今日未抓取到热门项目。"])
    for project in projects:
        lines.extend(
            [
                "",
                f"### {project.name}",
                f"- Star：{project.stars}",
                f"- 语言：{project.language}",
                f"- 链接：{project.url}",
                "",
                project.description or "N/A",
            ]
        )
    return "\n".join(lines)


def save_markdown(markdown_text: str, report_date: date, output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    md_path = output_dir / f"daily_{report_date.strftime('%Y_%m_%d')}.md"
    md_path.write_text(markdown_text, encoding="utf-8")
    return md_path


def markdown_to_html(markdown_text: str) -> str:
    return mdlib.markdown(markdown_text, extensions=["tables", "fenced_code"])


def render_html(html_body: str, report_cfg: ReportConfig, report_date: date, template_path: Path) -> str:
    template = Template(template_path.read_text(encoding="utf-8"))
    return template.render(title=report_cfg.title, date=report_date.isoformat(), content=html_body)


def save_html(html: str, report_date: date, output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    html_path = output_dir / f"daily_{report_date.strftime('%Y_%m_%d')}.html"
    html_path.write_text(html, encoding="utf-8")
    return html_path

