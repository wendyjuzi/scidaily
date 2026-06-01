from __future__ import annotations

from collections import OrderedDict

from research_daily.config import FilterConfig, SectionRule
from research_daily.models import PaperRecord


def dedupe_papers(papers: list[PaperRecord]) -> list[PaperRecord]:
    unique: "OrderedDict[str, PaperRecord]" = OrderedDict()
    for paper in papers:
        if paper.id not in unique:
            unique[paper.id] = paper
    return list(unique.values())


def _text_contains_keywords(text: str, keywords: list[str]) -> list[str]:
    lower_text = text.lower()
    return [k for k in keywords if k in lower_text]


def _pick_section(matched_keywords: list[str], rules: list[SectionRule]) -> str:
    for rule in rules:
        for keyword in matched_keywords:
            if keyword in rule.keywords:
                return rule.name
    return "General"


def _filter_simple(papers: list[PaperRecord], cfg: FilterConfig) -> list[PaperRecord]:
    selected: list[PaperRecord] = []
    for paper in papers:
        merged = f"{paper.title}\n{paper.abstract}"
        matched = _text_contains_keywords(merged, cfg.keywords)
        if matched:
            paper.matched_keywords = matched
            paper.section = _pick_section(matched, cfg.sections)
            selected.append(paper)
    return selected


def _filter_tfidf(papers: list[PaperRecord], cfg: FilterConfig) -> list[PaperRecord]:
    try:
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.metrics.pairwise import cosine_similarity
    except ImportError:
        return _filter_simple(papers, cfg)

    if not papers:
        return []
    docs = [f"{p.title}\n{p.abstract}" for p in papers]
    query = " ".join(cfg.keywords)
    vectorizer = TfidfVectorizer(stop_words="english")
    matrix = vectorizer.fit_transform(docs + [query])
    scores = cosine_similarity(matrix[:-1], matrix[-1]).ravel()
    selected: list[PaperRecord] = []
    for paper, score in zip(papers, scores):
        matched = _text_contains_keywords(f"{paper.title}\n{paper.abstract}", cfg.keywords)
        if matched and score >= cfg.tfidf_min_score:
            paper.matched_keywords = matched
            paper.section = _pick_section(matched, cfg.sections)
            selected.append(paper)
    return selected


def filter_papers(papers: list[PaperRecord], cfg: FilterConfig) -> list[PaperRecord]:
    if not cfg.keywords:
        return papers
    if cfg.mode == "tfidf":
        return _filter_tfidf(papers, cfg)
    return _filter_simple(papers, cfg)

