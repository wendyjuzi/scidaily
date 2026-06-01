from __future__ import annotations

import argparse

from research_daily.config import load_config
from research_daily.pipeline import run_pipeline
from research_daily.scheduler import run_scheduler


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Research Daily lightweight pipeline")
    parser.add_argument(
        "--config",
        default="config/research_daily.example.yaml",
        help="Path to YAML config file",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    run_parser = sub.add_parser("run-once", help="Run fetch/filter/report/push once")
    run_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Do not send email/wecom/telegram push",
    )

    sched_parser = sub.add_parser("schedule", help="Run APScheduler service")
    sched_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Generate report only, skip push",
    )
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    cfg = load_config(args.config)

    if args.command == "run-once":
        result = run_pipeline(cfg, dry_run=args.dry_run)
        print(
            f"[research-daily] done {result.run_date} papers={result.papers_total} "
            f"filtered={result.papers_filtered} projects={result.projects_total}"
        )
        print(f"[research-daily] markdown={result.markdown_path}")
        print(f"[research-daily] html={result.html_path}")
        return
    if args.command == "schedule":
        run_scheduler(cfg, dry_run=args.dry_run)
        return
    parser.error("unknown command")


if __name__ == "__main__":
    main()

