"""Classify selection comparisons without presuming which policy is correct."""
from __future__ import annotations


ANNOTATIONS = frozenset({"intentional-divergence", "suspected-upstream-bug"})


def classify_selection(saved_id: str | None, compared_id: str | None,
                       annotation: str | None = None) -> str:
    """Return agreement or an unresolved difference unless explicitly annotated."""
    if saved_id == compared_id:
        return "agree"
    if annotation is None:
        return "unresolved"
    if annotation not in ANNOTATIONS:
        raise ValueError("unsupported divergence annotation")
    return annotation
