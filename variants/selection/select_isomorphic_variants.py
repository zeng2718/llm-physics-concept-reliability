#!/usr/bin/env python3
"""Reproduce the stratified selection of 25 isomorphic-variant source items.

Selection balances inventory and representation type and spans the source- or
answer-recall tiers observed in the initial Kimi runs. Main-item accuracy and
response consistency are not inputs.
"""

from __future__ import annotations

import argparse
import csv
import random
from collections import defaultdict
from pathlib import Path


HERE = Path(__file__).resolve().parent
SEED = 20260615
QUOTAS = {
    ("FCI", "text"): 3,
    ("FCI", "fig_decor"): 4,
    ("FCI", "fig_spatial"): 2,
    ("BEMA", "text"): 1,
    ("BEMA", "fig_decor"): 6,
    ("BEMA", "fig_spatial"): 1,
    ("TCE", "text"): 8,
}
TIER_ORDER = {"NONE": 0, "GENRE": 1, "EPISODIC": 2, "SRC": 3, "MEM_ANS": 4}
OUTPUT_FIELDS = [
    "source_item_id",
    "inventory",
    "representation_type",
    "initial_kimi_recall_tier",
]


def spread_pick(items: list[dict], count: int) -> list[dict]:
    """Pick approximately equidistant records across an already ordered pool."""
    if count >= len(items):
        return items
    indices = [
        round(i * (len(items) - 1) / (count - 1)) if count > 1 else 0
        for i in range(count)
    ]
    used: set[int] = set()
    selected = []
    for index in indices:
        while index in used and index < len(items) - 1:
            index += 1
        used.add(index)
        selected.append(items[index])
    return selected


def select(frame: list[dict]) -> list[dict]:
    rng = random.Random(SEED)
    strata: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for row in frame:
        strata[(row["inventory"], row["representation_type"])].append(row)

    selected = []
    for stratum, count in QUOTAS.items():
        pool = list(strata[stratum])
        if len(pool) < count:
            raise ValueError(f"Stratum {stratum} contains {len(pool)} records; {count} required")
        rng.shuffle(pool)
        pool.sort(key=lambda row: TIER_ORDER[row["initial_kimi_recall_tier"]])
        selected.extend(spread_pick(pool, count))

    selected.sort(key=lambda row: (row["inventory"], row["source_item_id"]))
    if len(selected) != 25:
        raise ValueError(f"Expected 25 selected items; found {len(selected)}")
    return selected


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--frame", type=Path, default=HERE / "sampling_frame.csv")
    parser.add_argument("--output", type=Path, default=HERE / "selected_items.csv")
    args = parser.parse_args()

    with args.frame.open(encoding="utf-8-sig", newline="") as handle:
        frame = list(csv.DictReader(handle))
    if len(frame) != 87:
        raise ValueError(f"Expected an 87-item sampling frame; found {len(frame)}")

    selected = select(frame)
    with args.output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS)
        writer.writeheader()
        writer.writerows({field: row[field] for field in OUTPUT_FIELDS} for row in selected)

    print(f"Selected {len(selected)} items with seed {SEED}: {args.output}")


if __name__ == "__main__":
    main()
