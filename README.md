# Public data and code for the manuscript

This package accompanies **“Reliability Boundaries of Reasoning Large Language Models in Physics Education: Evidence from Concept Inventories.”** It contains the smallest test-secure set of data, code, prompts, coding definitions, and variant-review records needed to reproduce the reported analyses without redistributing protected concept-inventory content or keyed responses.

## Package contents

| Directory | Contents |
|---|---|
| `data/` | De-identified formal response-level data, pre-adjudication coder labels, model configurations, the final student-misconception comparison classifications, and the presence-only recall-cue audit outcome |
| `prompts/` | The two formal prompt templates: one shared by main items and isomorphic variants, and one for the prompted self-review probe |
| `codebook/` | Supplementary Tables S2–S6 in machine-readable form and coding-field guidance |
| `variants/` | Test-secure ID-level mapping, reproducible stratified selection, G1–G5 criteria, constrained option-permutation outcomes, and sanitized two-reviewer approval outcomes |
| `scripts/collection/` | Formal collection and parsing pipeline; protected items and credentials are not included |
| `scripts/analysis/` | Reproduction of manuscript Tables 1–3 and Supplementary Table S2 |
| `scripts/figures/` | Public plotting scripts and source data for Figures 2–5 |

The formal corpus contains 2,305 responses: 1,740 main-item runs, 500 isomorphic-variant runs, and 65 prompted self-review probe runs. Ten exploratory variant follow-up records and every archived, pilot, or sensitivity-only collection branch outside the manuscript are excluded.

## Reproduce the reported tables and figures

From the package root:

```bash
Rscript scripts/analysis/reproduce_manuscript_tables.R
python scripts/analysis/compute_intercoder_reliability.py
Rscript scripts/figures/figure2_main_item_reliability.R
Rscript scripts/figures/figure3_spatial_representation_failures.R
Rscript scripts/figures/figure4_prompted_self_review.R
Rscript scripts/figures/figure5_student_misconception_comparison.R
```

The R figure scripts require `ggplot2`, `patchwork`, `svglite`, and `ragg`. The collection dependencies are listed separately in `scripts/collection/requirements.txt`.

## Test-security boundary

The package does not include FCI, BEMA, or TCE item text, figures, option text, or answer keys; full isomorphic-variant text or figures; source or variant answer letters; option-level mappings; raw provider responses; or model rationales. Public response classes are item-specific pseudonyms with no correspondence to option order.

The final isomorphic-variant figures were drawn manually in Microsoft PowerPoint. No variant-figure generation script was used, so no such script is included. The scripts under `scripts/figures/` reproduce only manuscript Figures 2–5 from de-identified analysis data.

## Licence

Software code under `scripts/` and `variants/selection/` is released under the MIT License. De-identified data, metadata, prompts, codebooks, protocols, source-data tables, and documentation are released under the Creative Commons Attribution 4.0 International License (CC BY 4.0). Protected concept-inventory materials and full isomorphic-variant items are not distributed and are not covered by these licences. See `LICENSE` for the full scope and terms.

## Terminology

Public filenames, variables, and documentation follow the manuscript terms `prompted self-review probe` and `comparison with documented student misconceptions`. The collection script retains the frozen `probe6:` hash namespace only to reproduce the original deterministic ordering of prior attempts; it is not used as a public data-stage name.
