"""Quick entrypoint: run one dry report generation."""

from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))

from research_daily.config import load_config
from research_daily.pipeline import run_pipeline


def main() -> None:
    cfg = load_config("config/research_daily.example.yaml")
    result = run_pipeline(cfg, dry_run=True)
    print(
        f"[research-daily] {result.run_date} papers={result.papers_total} "
        f"filtered={result.papers_filtered} projects={result.projects_total}"
    )


if __name__ == "__main__":
    main()
