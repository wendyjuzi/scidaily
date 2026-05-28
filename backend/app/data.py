from app.schemas import NewsItem

MOCK_NEWS: list[NewsItem] = [
    NewsItem(
        id="20260528-001",
        title="Foundation Models Improve Multi-Modal Scientific Reasoning",
        abstract=(
            "We propose a benchmark for multi-modal scientific reasoning and present "
            "a model that improves accuracy by combining symbolic tool use with "
            "vision-language reasoning."
        ),
        ai_summary=(
            "Tool-augmented multi-modal reasoning significantly improves "
            "accuracy on science benchmarks."
        ),
        authors=["A. Chen", "B. Kumar", "L. Wang"],
        published_date="2026-05-28",
        category="Computer Science",
        doi="10.1000/mock.2026.001",
        source_url="https://example.org/paper/20260528-001",
    ),
    NewsItem(
        id="20260528-002",
        title="Single-Cell Atlas Reveals Dynamic Immune Cell States",
        abstract=(
            "This study constructs a cross-tissue single-cell atlas and identifies "
            "transient immune states associated with inflammation resolution."
        ),
        ai_summary=(
            "A single-cell atlas reveals transient immune states during "
            "inflammation resolution."
        ),
        authors=["Y. Li", "M. Patel"],
        published_date="2026-05-28",
        category="Biology",
        doi="10.1000/mock.2026.002",
        source_url="https://example.org/paper/20260528-002",
    ),
    NewsItem(
        id="20260528-003",
        title="High-Entropy Perovskites for Stable Solar Conversion",
        abstract=(
            "We design high-entropy perovskite compositions that suppress phase "
            "segregation and extend operational lifetime under thermal stress."
        ),
        ai_summary=(
            "High-entropy perovskites suppress phase segregation and improve "
            "thermal stability."
        ),
        authors=["R. Singh", "J. Zhao", "E. Rossi"],
        published_date="2026-05-28",
        category="Materials",
        doi="10.1000/mock.2026.003",
        source_url="https://example.org/paper/20260528-003",
    ),
]
