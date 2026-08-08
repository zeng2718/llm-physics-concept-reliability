"""Parse reasoning, final answer choice, and confidence from visible output."""
from __future__ import annotations
import re

# Tolerate Markdown bold markers and parenthesized option labels.
_ANSWER_RE = re.compile(r"(?im)^\s*\**\s*ANSWER:\s*\(?\s*([A-Za-z])\s*\)?")
# Preserve 0–100 responses for the prespecified normalization step.
_CONF_RE = re.compile(r"(?im)^\s*\**\s*CONFIDENCE:\s*(\d{1,3})\b")


def parse_response(text: str) -> dict:
    """Return parsed fields, taking the last answer and confidence markers."""
    text = text or ""
    ans = list(_ANSWER_RE.finditer(text))
    conf = list(_CONF_RE.finditer(text))

    stated_letter = ans[-1].group(1).lower() if ans else None
    confidence = int(conf[-1].group(1)) if conf else None
    cut = ans[-1].start() if ans else len(text)
    reasoning = text[:cut].strip()

    notes = []
    if stated_letter is None:
        notes.append("no ANSWER line")
    if confidence is None:
        notes.append("no CONFIDENCE line")
    if not reasoning:
        notes.append("empty reasoning")
    if confidence is not None and not (0 <= confidence <= 10):
        notes.append(f"confidence out of 0-10 ({confidence}); normalize /100 at analysis")
    return {
        "reasoning": reasoning,
        "stated_letter": stated_letter,
        "confidence": confidence,
        "parse_ok": stated_letter is not None and confidence is not None,
        "notes": "; ".join(notes),
    }
