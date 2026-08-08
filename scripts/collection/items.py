"""Load single-item Markdown records, figures, and option labels."""
from __future__ import annotations
import re
from dataclasses import dataclass, field
from pathlib import Path

from config import QB_DIR, VARIANT_DIR

_QNUM_RE = re.compile(r"\[question number\]\s*(.+)")
_OPT_LABEL_RE = re.compile(r"\(([A-Za-z])\)")
# Expand compact ranges such as "(a) through (j)".
_RANGE_RE = re.compile(r"\(([A-Za-z])\)\s*(?:through|thru|to|[-–—])\s*\(([A-Za-z])\)", re.I)


def is_plausible_option(stated_letter: str | None, options: list[str]) -> bool:
    """Return whether a stated answer is plausible for collection QC."""
    if not stated_letter:
        return False
    if options:
        return stated_letter in options
    return len(stated_letter) == 1 and "a" <= stated_letter <= "e"


def _extract_options(opts_line: str) -> list[str]:
    m = _RANGE_RE.search(opts_line)
    if m:
        lo, hi = m.group(1).lower(), m.group(2).lower()
        if ord(lo) <= ord(hi) <= ord("z"):
            return [chr(c) for c in range(ord(lo), ord(hi) + 1)]
    seen, options = set(), []
    for lab in _OPT_LABEL_RE.findall(opts_line):
        low = lab.lower()
        if low not in seen:
            seen.add(low)
            options.append(low)
    return options


@dataclass
class Item:
    item_id: str
    stem: str
    domain: str
    text: str
    figures: list[Path] = field(default_factory=list)
    options: list[str] = field(default_factory=list)

    @property
    def has_figure(self) -> bool:
        return bool(self.figures)


def _natural_key(p: Path):
    m = re.search(r"_(\d+)$", p.stem)
    return (p.parent.name, int(m.group(1)) if m else 0, p.stem)


def parse_item(md_path: Path) -> Item:
    text = md_path.read_text(encoding="utf-8")
    m = _QNUM_RE.search(text)
    item_id = m.group(1).strip() if m else md_path.stem
    stem = md_path.stem
    domain = md_path.parent.name
    figures = sorted(md_path.parent.glob(f"{stem}_fig*.png"))
    opts_line = ""
    mo = re.search(r"\[options\]\s*(.+)", text)
    if mo:
        opts_line = mo.group(1)
    options = _extract_options(opts_line)
    return Item(item_id=item_id, stem=stem, domain=domain, text=text,
                figures=figures, options=options)


def load_items(domains: list[str]) -> list[Item]:
    items: list[Item] = []
    for d in domains:
        ddir = QB_DIR / d
        if not ddir.is_dir():
            raise FileNotFoundError(f"Inventory directory not found: {ddir}")
        for md in sorted(ddir.glob(f"{d}_*.md"), key=_natural_key):
            items.append(parse_item(md))
    return items


def load_variant_items() -> list[Item]:
    """Load only neutral V-### variant records and their figures."""
    if not VARIANT_DIR.is_dir():
        raise FileNotFoundError(f"Variant directory not found: {VARIANT_DIR}")
    items: list[Item] = []
    for md in sorted(VARIANT_DIR.glob("V-*.md")):
        it = parse_item(md)
        it.domain = "V"
        items.append(it)
    if not items:
        raise FileNotFoundError(f"No V-*.md records found in {VARIANT_DIR}")
    return items
