"""Legacy helper: non-LLM abstract snippet generation."""


def summarize_abstract(abstract: str, max_chars: int = 120) -> str:
    """Return a deterministic short snippet without any LLM dependency."""
    text = " ".join(abstract.split())
    return text[:max_chars]


def main() -> None:
    sample = "This is a sample abstract for deterministic snippet generation."
    print(summarize_abstract(sample))


if __name__ == "__main__":
    main()
