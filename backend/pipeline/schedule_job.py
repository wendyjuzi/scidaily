"""Scheduler entrypoint for lightweight research daily."""

from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))

from research_daily.config import load_config
from research_daily.scheduler import run_scheduler


def run_daily_pipeline() -> None:
    cfg = load_config("config/research_daily.example.yaml")
    run_scheduler(cfg, dry_run=False)


if __name__ == "__main__":
    run_daily_pipeline()
