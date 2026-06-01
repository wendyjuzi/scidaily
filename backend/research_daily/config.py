from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml


@dataclass(slots=True)
class SectionRule:
    name: str
    keywords: list[str]


@dataclass(slots=True)
class SourceConfig:
    arxiv_categories: list[str] = field(default_factory=lambda: ["cs.AI", "cs.CL", "cs.LG"])
    extra_rss: list[str] = field(default_factory=list)
    max_items_per_feed: int = 80
    github_top_n: int = 20


@dataclass(slots=True)
class FilterConfig:
    keywords: list[str] = field(default_factory=list)
    mode: str = "simple"
    tfidf_min_score: float = 0.07
    sections: list[SectionRule] = field(default_factory=list)


@dataclass(slots=True)
class ReportConfig:
    timezone: str = "Asia/Shanghai"
    title: str = "AI科研日报"
    output_dir: str = "outputs"
    template_path: str = "templates/daily_report.html.j2"


@dataclass(slots=True)
class ScheduleConfig:
    hour: int = 8
    minute: int = 0


@dataclass(slots=True)
class EmailConfig:
    enabled: bool = False
    host: str = "smtp.qq.com"
    port: int = 465
    username: str = ""
    password: str = ""
    sender: str = ""
    receivers: list[str] = field(default_factory=list)
    use_ssl: bool = True


@dataclass(slots=True)
class WecomConfig:
    enabled: bool = False
    webhook: str = ""


@dataclass(slots=True)
class TelegramConfig:
    enabled: bool = False
    bot_token: str = ""
    chat_id: str = ""


@dataclass(slots=True)
class PushConfig:
    email: EmailConfig = field(default_factory=EmailConfig)
    wecom: WecomConfig = field(default_factory=WecomConfig)
    telegram: TelegramConfig = field(default_factory=TelegramConfig)


@dataclass(slots=True)
class AppConfig:
    database_path: str = "data/research_daily.db"
    source: SourceConfig = field(default_factory=SourceConfig)
    filtering: FilterConfig = field(default_factory=FilterConfig)
    report: ReportConfig = field(default_factory=ReportConfig)
    schedule: ScheduleConfig = field(default_factory=ScheduleConfig)
    push: PushConfig = field(default_factory=PushConfig)


def _section_rules(raw: list[dict[str, Any]]) -> list[SectionRule]:
    return [
        SectionRule(name=item["name"], keywords=[k.lower() for k in item.get("keywords", [])])
        for item in raw
    ]


def _load_email(raw: dict[str, Any]) -> EmailConfig:
    return EmailConfig(
        enabled=bool(raw.get("enabled", False)),
        host=raw.get("host", "smtp.qq.com"),
        port=int(raw.get("port", 465)),
        username=raw.get("username", ""),
        password=raw.get("password", ""),
        sender=raw.get("sender", ""),
        receivers=list(raw.get("receivers", [])),
        use_ssl=bool(raw.get("use_ssl", True)),
    )


def load_config(path: str | Path) -> AppConfig:
    config_path = Path(path)
    if not config_path.is_absolute():
        candidates = [
            Path.cwd() / config_path,
            Path(__file__).resolve().parents[1] / config_path,
        ]
        for candidate in candidates:
            if candidate.exists():
                config_path = candidate
                break
    with config_path.open("r", encoding="utf-8") as f:
        raw = yaml.safe_load(f) or {}
    base_dir = config_path.parent

    source_raw = raw.get("source", {})
    filtering_raw = raw.get("filter", {})
    report_raw = raw.get("report", {})
    schedule_raw = raw.get("schedule", {})
    push_raw = raw.get("push", {})

    cfg = AppConfig(
        database_path=raw.get("database_path", "data/research_daily.db"),
        source=SourceConfig(
            arxiv_categories=list(source_raw.get("arxiv_categories", ["cs.AI", "cs.CL", "cs.LG"])),
            extra_rss=list(source_raw.get("extra_rss", [])),
            max_items_per_feed=int(source_raw.get("max_items_per_feed", 80)),
            github_top_n=int(source_raw.get("github_top_n", 20)),
        ),
        filtering=FilterConfig(
            keywords=[k.lower() for k in filtering_raw.get("keywords", [])],
            mode=str(filtering_raw.get("mode", "simple")).lower(),
            tfidf_min_score=float(filtering_raw.get("tfidf_min_score", 0.07)),
            sections=_section_rules(filtering_raw.get("sections", [])),
        ),
        report=ReportConfig(
            timezone=report_raw.get("timezone", "Asia/Shanghai"),
            title=report_raw.get("title", "AI科研日报"),
            output_dir=report_raw.get("output_dir", "outputs"),
            template_path=report_raw.get("template_path", "templates/daily_report.html.j2"),
        ),
        schedule=ScheduleConfig(
            hour=int(schedule_raw.get("hour", 8)),
            minute=int(schedule_raw.get("minute", 0)),
        ),
        push=PushConfig(
            email=_load_email(push_raw.get("email", {})),
            wecom=WecomConfig(
                enabled=bool(push_raw.get("wecom", {}).get("enabled", False)),
                webhook=push_raw.get("wecom", {}).get("webhook", ""),
            ),
            telegram=TelegramConfig(
                enabled=bool(push_raw.get("telegram", {}).get("enabled", False)),
                bot_token=push_raw.get("telegram", {}).get("bot_token", ""),
                chat_id=push_raw.get("telegram", {}).get("chat_id", ""),
            ),
        ),
    )
    cfg.database_path = str(_resolve_path(base_dir, cfg.database_path))
    cfg.report.output_dir = str(_resolve_path(base_dir, cfg.report.output_dir))
    cfg.report.template_path = str(_resolve_path(base_dir, cfg.report.template_path))
    _apply_env_overrides(cfg)
    return cfg


def _apply_env_overrides(cfg: AppConfig) -> None:
    cfg.push.email.password = os.getenv("RESEARCH_DAILY_SMTP_PASSWORD", cfg.push.email.password)
    cfg.push.wecom.webhook = os.getenv("RESEARCH_DAILY_WECOM_WEBHOOK", cfg.push.wecom.webhook)
    cfg.push.telegram.bot_token = os.getenv(
        "RESEARCH_DAILY_TELEGRAM_TOKEN", cfg.push.telegram.bot_token
    )
    cfg.push.telegram.chat_id = os.getenv("RESEARCH_DAILY_TELEGRAM_CHAT_ID", cfg.push.telegram.chat_id)


def _resolve_path(base_dir: Path, value: str) -> Path:
    p = Path(value)
    if p.is_absolute():
        return p
    return (base_dir / p).resolve()
