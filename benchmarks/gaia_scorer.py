"""GAIA official-style scorer.

Port of the normalization + match rules used by the GAIA scorer
(huggingface.co/gaia-benchmark). Keep semantics faithful to comparability;
do NOT add homegrown fuzzy matching. If the grader is wrong on a specific
task, record the raw answer and flag it for manual review rather than
loosening the scorer.
"""
from __future__ import annotations

import re
import string
import unicodedata


_ARTICLES = {"a", "an", "the"}
_NUMBER_RE = re.compile(r"[-+]?\d*\.?\d+")


def _strip_accents(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")


def _normalize_text(s: str) -> str:
    s = _strip_accents(str(s)).lower()
    # Drop punctuation
    s = s.translate(str.maketrans("", "", string.punctuation))
    # Drop articles
    words = [w for w in s.split() if w not in _ARTICLES]
    return " ".join(words).strip()


def _is_numeric(s: str) -> bool:
    return bool(_NUMBER_RE.fullmatch(str(s).strip().replace(",", "")))


def _to_number(s: str) -> float:
    return float(str(s).strip().replace(",", ""))


def _numeric_match(a: str, b: str, tol: float = 1e-6) -> bool:
    try:
        return abs(_to_number(a) - _to_number(b)) <= tol
    except Exception:
        return False


def _split_list(s: str) -> list[str]:
    # GAIA list answers are comma-separated; semicolons appear occasionally
    parts = re.split(r"[;,]\s*", str(s).strip())
    return [p.strip() for p in parts if p.strip()]


def score(predicted: str, gold: str) -> tuple[bool, str]:
    """Return (is_correct, reason). Reason helps debug false-fails."""
    if predicted is None:
        return False, "predicted is None"
    if gold is None or gold == "":
        return False, "gold is empty"

    p_raw, g_raw = str(predicted).strip(), str(gold).strip()
    if not p_raw:
        return False, "predicted is empty"

    # List answers
    if "," in g_raw or ";" in g_raw:
        p_list = sorted(_normalize_text(x) for x in _split_list(p_raw))
        g_list = sorted(_normalize_text(x) for x in _split_list(g_raw))
        if p_list == g_list:
            return True, "list-match"
        return False, f"list-mismatch pred={p_list} gold={g_list}"

    # Numeric answers
    if _is_numeric(g_raw):
        if _is_numeric(p_raw) and _numeric_match(p_raw, g_raw):
            return True, "numeric-match"
        return False, f"numeric-mismatch pred={p_raw} gold={g_raw}"

    # String normalized match
    if _normalize_text(p_raw) == _normalize_text(g_raw):
        return True, "string-match"
    return False, f"string-mismatch norm_pred='{_normalize_text(p_raw)}' norm_gold='{_normalize_text(g_raw)}'"


def extract_final_answer(text: str) -> str:
    """Pull the final-answer span from the agent's raw text.

    Convention: the agent is instructed to end with 'Answer: <value>' on its
    own line. Fall back to the last non-empty line if that pattern isn't
    present.
    """
    if not text:
        return ""
    for line in reversed(text.splitlines()):
        s = line.strip()
        if not s:
            continue
        m = re.match(r"(?i)^(?:final\s+answer|answer)\s*[:\-]\s*(.+)$", s)
        if m:
            return m.group(1).strip().strip('"').strip("'")
    for line in reversed(text.splitlines()):
        s = line.strip()
        if s:
            return s
    return ""
