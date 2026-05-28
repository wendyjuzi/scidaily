"""Scheduler placeholder for daily pipeline."""

from datetime import datetime


def run_daily_pipeline() -> None:
    now = datetime.now().isoformat()
    print(f"[{now}] run pipeline: fetch -> summarize -> store")


if __name__ == "__main__":
    run_daily_pipeline()
