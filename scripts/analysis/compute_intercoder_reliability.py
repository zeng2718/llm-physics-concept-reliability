#!/usr/bin/env python3
"""Recompute pre-adjudication agreement and Cohen's kappa (Table S2)."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path


HERE = Path(__file__).resolve().parent
DEFAULT_INPUT = HERE.parents[1] / "data" / "intercoder_labels.csv"


def cohen_kappa(coder_1: list[str], coder_2: list[str]):
    if len(coder_1) != len(coder_2) or not coder_1:
        raise ValueError("Coder vectors must be non-empty and have equal length")
    n = len(coder_1)
    observed = sum(a == b for a, b in zip(coder_1, coder_2)) / n
    counts_1 = Counter(coder_1)
    counts_2 = Counter(coder_2)
    labels = set(counts_1) | set(counts_2)
    expected = sum((counts_1[label] / n) * (counts_2[label] / n) for label in labels)
    kappa = None if expected == 1 else (observed - expected) / (1 - expected)
    return observed, expected, kappa


def paired(rows: list[dict], code: str, predicate=lambda row: True):
    selected = [row for row in rows if predicate(row)]
    coder_1 = [row[f"Coder 1 {code}"] for row in selected]
    coder_2 = [row[f"Coder 2 {code}"] for row in selected]
    if any(not value for value in coder_1 + coder_2):
        raise ValueError(f"Blank paired label encountered for {code}")
    return coder_1, coder_2


def hierarchical_label(row: dict, coder: int):
    srf = row[f"Coder {coder} SRF"]
    subtype = row[f"Coder {coder} SRF-sub"]
    return f"SRF-2/{subtype}" if srf == "SRF-2" else srf


def subtype_eligibility_label(row: dict, coder: int):
    srf = row[f"Coder {coder} SRF"]
    return row[f"Coder {coder} SRF-sub"] if srf == "SRF-2" else "NOT-SRF-2"


def build_results(rows: list[dict]):
    specs = [
        ("AC", "Formal corpus", lambda row: True),
        ("RC", "Formal corpus", lambda row: True),
        ("Rep", "Formal corpus", lambda row: True),
        ("Rep-LM", "Formal corpus", lambda row: True),
        ("AD", "Formal corpus", lambda row: True),
        ("CB", "Formal corpus", lambda row: True),
        ("SRF", "Formal corpus", lambda row: True),
        ("CI", "Formal probe only", lambda row: row["Data Stage"] == "prompted self-review probe"),
        ("AT", "Formal probe only", lambda row: row["Data Stage"] == "prompted self-review probe"),
        ("CQ", "Formal probe only", lambda row: row["Data Stage"] == "prompted self-review probe"),
        ("EVAL", "Formal probe only", lambda row: row["Data Stage"] == "prompted self-review probe"),
        (
            "SRF-sub",
            "Both coders assigned SRF-2",
            lambda row: row["Coder 1 SRF"] == "SRF-2" and row["Coder 2 SRF"] == "SRF-2",
        ),
    ]

    output = []
    for code, scope, predicate in specs:
        coder_1, coder_2 = paired(rows, code, predicate)
        observed, expected, kappa = cohen_kappa(coder_1, coder_2)
        output.append(("SRF-subtype" if code == "SRF-sub" else code, scope, len(coder_1), observed, expected, kappa))

    coder_1 = [hierarchical_label(row, 1) for row in rows]
    coder_2 = [hierarchical_label(row, 2) for row in rows]
    observed, expected, kappa = cohen_kappa(coder_1, coder_2)
    output.append(("SRF-hierarchical", "Formal corpus", len(rows), observed, expected, kappa))

    eligible = [
        row for row in rows
        if row["Coder 1 SRF"] == "SRF-2" or row["Coder 2 SRF"] == "SRF-2"
    ]
    coder_1 = [subtype_eligibility_label(row, 1) for row in eligible]
    coder_2 = [subtype_eligibility_label(row, 2) for row in eligible]
    observed, expected, kappa = cohen_kappa(coder_1, coder_2)
    output.append(("SRF-subtype + eligibility", "Either coder assigned SRF-2", len(eligible), observed, expected, kappa))
    return output


def formatted_rows(results):
    for code, scope, n, observed, expected, kappa in results:
        yield {
            "Code": code,
            "Scope": scope,
            "n": n,
            "Observed agreement": f"{observed:.4f}",
            "Expected agreement": f"{expected:.4f}",
            "Cohen's κ": "Not estimable" if kappa is None else f"{kappa:.4f}",
        }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    with args.input.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 2305:
        raise ValueError(f"Expected 2,305 formal rows; found {len(rows)}")

    fields = ["Code", "Scope", "n", "Observed agreement", "Expected agreement", "Cohen's κ"]
    results = list(formatted_rows(build_results(rows)))
    if args.output:
        with args.output.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields)
            writer.writeheader()
            writer.writerows(results)
    else:
        writer = csv.DictWriter(__import__("sys").stdout, fieldnames=fields)
        writer.writeheader()
        writer.writerows(results)


if __name__ == "__main__":
    main()
