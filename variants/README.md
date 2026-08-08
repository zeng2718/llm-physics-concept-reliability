# Isomorphic variants — selection and review records

This directory contains test-secure records for the selection and predeployment review of the 25 author-constructed isomorphic variants (V-001–V-025). It supports the near-transfer analysis reported in manuscript Sections 2.2, 3.2, and 4.1 without distributing item text, figures, option meanings, or answer keys.

## Files

| Path | Content |
|---|---|
| `mapping_id_level.csv` | ID-level mapping between each variant and its source item, with inventory and representation type. |
| `selection/sampling_frame.csv` | Test-secure 87-item sampling frame containing only the fields used by the selection procedure. |
| `selection/select_isomorphic_variants.py` | Reproducible stratified selection with fixed inventory × representation-type quotas and seed `20260615`; within-stratum ordering spans the source- or answer-recall tiers observed in the initial Kimi runs. Main-item accuracy and response consistency are not inputs. |
| `selection/selected_items.csv` | The resulting 25 selected source items. |
| `review/variant_validity_criteria_G1_G5.md` | The five prespecified validity gates (construct identity; unique and semantically equivalent answer; one-to-one distractor mapping; no new confounds; self-contained with equivalent difficulty) and surface-perturbation rules. |
| `review/two_reviewer_review_protocol.md` | Two-reviewer verification procedure (independent blind solve, G1–G5 review, correction, re-check, and approval). |
| `review/two_reviewer_approval_outcomes.csv` | Final pass/approval outcomes for all 25 variants; answer letters and free-text internal notes are excluded. |
| `review/option_permutation_protocol_summary.md` | Test-secure summary of the constrained option-permutation protocol (21/25 answer-letter changes and 4 registered natural-order exemptions). |
| `review/option_permutation_outcomes.csv` | Per-variant changed/retained flag needed for the reported sensitivity analysis; actual letters, option meanings, mappings, and stimulus transformations are excluded. |

## Materials not redistributed

The repository does not include FCI, BEMA, or TCE item text, options, figures, or answer keys; full isomorphic-variant text or figures; per-option semantic mappings; source or variant answer letters; or stimulus-transform details that could reveal a keyed response. Access to third-party instruments is governed by the respective rights holders and test-security conditions.

The final variant figures were drawn manually in Microsoft PowerPoint. No variant-figure generation script was used or is included in the public package.
