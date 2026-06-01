from __future__ import annotations

from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.cron import CronTrigger

from research_daily.config import AppConfig
from research_daily.pipeline import run_pipeline


def run_scheduler(cfg: AppConfig, dry_run: bool = False) -> None:
    scheduler = BlockingScheduler(timezone=cfg.report.timezone)

    def _job() -> None:
        result = run_pipeline(cfg, dry_run=dry_run)
        print(
            f"[research-daily] {result.run_date} papers={result.papers_total} "
            f"filtered={result.papers_filtered} projects={result.projects_total}"
        )

    scheduler.add_job(
        _job,
        CronTrigger(hour=cfg.schedule.hour, minute=cfg.schedule.minute),
        id="research-daily-job",
        replace_existing=True,
    )
    print(
        f"[research-daily] scheduler started: every day at "
        f"{cfg.schedule.hour:02d}:{cfg.schedule.minute:02d} ({cfg.report.timezone})"
    )
    scheduler.start()

