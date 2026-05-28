"""LLM summary placeholder for SciDaily."""


def summarize_abstract(abstract: str) -> str:
    # TODO: call OpenAI/Kimi/DeepSeek API and return <=100 Chinese chars.
    return abstract[:60]


def main() -> None:
    sample = "This is a sample abstract for summarization."
    print(summarize_abstract(sample))


if __name__ == "__main__":
    main()
