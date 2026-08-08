# De-identified response-level data

This directory contains the formal, adjudicated response-level coding data used for the manuscript, together with paired pre-adjudication coder labels. Item text, figures, option text, actual answer letters, answer keys, and model rationales are not distributed because they could reproduce protected concept-inventory content or disclose keyed responses.

## Files

| File | Content | Data rows |
|---|---|---:|
| `main_runs.csv` | 87 main items × 4 models × 5 independent runs | 1,740 |
| `variant_runs.csv` | 25 isomorphic variants × 4 models × 5 independent runs | 500 |
| `prompted_self_review_runs.csv` | 13 inconsistent model–item series × 5 prompted self-review probe runs | 65 |
| `intercoder_labels.csv` | Paired pre-adjudication labels for the 2,305-response formal corpus | 2,305 |
| `model_configurations.csv` | Model routes, API identifiers, reasoning settings, sampling, output limits, and collection dates reported in Supplementary Table S1 | 4 |
| `student_misconception_comparison.csv` | Test-secure series-level classifications for the 13 primary and 6 sensitivity model–student error comparisons | 19 |
| `source_or_answer_recall_presence.csv` | Presence-only audit outcome for main items and isomorphic variants in each model | 8 |

The formal corpus contains 2,305 responses, matching manuscript Section 2.1. The response-level files support the reported main-item performance, run-to-run reliability, original–variant transfer, spatial-representation failure, prompted self-review, and confidence-calibration analyses. The 19-row comparison file supports the series-level counts in manuscript Section 3.5 and Figure 5. Figure and table source-data files generated from these inputs are provided under `../scripts/figures/source_data/` and `../scripts/analysis/source_data/`.

## Response-level column dictionary

| Column | Meaning |
|---|---|
| `Model` | Exact model name used in the manuscript: `Kimi K2.6`, `GPT-5.5`, `Gemini 3.1 Pro Preview`, or `Claude Opus 4.6` |
| `Data Stage` | `main item`, `isomorphic variant`, or `prompted self-review probe` |
| `Item ID` | Test-secure inventory/item identifier (`FCI-##`, `BEMA-##`, `TCE-##`) or neutral variant identifier (`V-###`) |
| `Original Item ID` | Source inventory item for an isomorphic variant; blank otherwise |
| `Inventory` | `FCI`, `BEMA`, or `TCE` |
| `Run` | Independent run index, 1–5 |
| `Response Class` | Pseudonymized, item-specific class for the selected final-answer option; identical classes mean the same option was selected for that item, including across the main and prompted self-review files, but `class_1`, `class_2`, and so forth do not correspond to source option positions and cannot be compared across items |
| `Completion Status` | `completed` or `DNF` (did not finish) |
| `Reasoning Source` | `visible output`, `provider auxiliary`, or `unavailable`; this retains the source flag described in manuscript Section 2.4 without distributing the reasoning text |
| `Has Figure` | `true` if the administered item included one or more figures; otherwise `false` |
| `Number of Figures` | Number of figures attached to that item |
| `Confidence Raw` | Model-stated confidence before scale normalization |
| `Confidence Normalized` | Confidence on a 0–1 scale; requested 0–10 values were divided by 10, while values clearly reported on a 0–100 scale were divided by 100 |
| `AC`, `RC`, `Rep`, `Rep-LM` | Track 1: answer correctness, reasoning correctness, representation correctness, and supported-conclusion/option-label mismatch |
| `AD`, `CB`, `SRF`, `SRF-sub` | Track 2: assumption deficit, contradiction blindness, spatial-representation failure, and SRF subtype |
| `CI`, `AT`, `CQ`, `EVAL`, `ML` | Track 3 fields for prompted self-review probe responses; blank for the other stages |

Allowed code values and operational definitions are provided in `../codebook/`. Blank cells mean that a field was not applicable to that data stage or coding condition.

## Test-security transformation

Actual final-answer letters were replaced with item-specific response classes. The private class-to-letter mappings are not distributed. Class numbers are arbitrary within each item: they are not option numbers or letter positions. This preserves the ability to reproduce run-to-run consistency, distinct-answer counts, and prompted self-review target selection without disclosing answer positions. Correctness remains available through adjudicated `AC`, and letter–meaning mismatch through `Rep-LM`.

Full model rationales and raw provider responses are excluded because they can reproduce protected question content. Ten exploratory variant follow-up records and all archived or sensitivity-only collection branches are outside the 2,305-response formal corpus and are not included.

## Comparison with documented student misconceptions

`student_misconception_comparison.csv` uses the manuscript term `comparison` throughout. It contains only the fields needed to reproduce the primary and sensitivity contingency counts: model and item identifiers, correct/incorrect/DNF run counts, majority outcome, the two-level error-pattern grouping used in Figure 5, answer-level overlap, mechanism-level overlap, and supporting literature.

It does not contain answer keys, actual response letters, option-level mappings, detailed item-specific reasoning summaries, or internal evidence grades. `primary_majority_incorrect` contains the 13 majority-incorrect model–item series. `sensitivity_correct_majority` contains the 6 correct-majority series with at least one adjudicated incorrect completed response; these tiers must not be pooled or treated as independent run-level observations.

## Source- or answer-recall presence

`source_or_answer_recall_presence.csv` records only whether at least one source- or answer-recall cue was observed in provider-exposed reasoning fields for each model and data stage. It supports the presence statement in manuscript Section 3.2. It does not provide excerpts or frequencies, and it must not be used for between-model prevalence comparisons because access to provider-exposed reasoning fields differed across providers.

## Inter-coder labels

`intercoder_labels.csv` contains only formal-corpus paired labels, with coders identified generically as Coder 1 and Coder 2. It excludes internal packet filenames, supplemental flags, adjudication discussions, and derived audit columns. Cohen's κ is calculated from these pre-adjudication labels; adjudicated labels in the three response-level files are used for the manuscript analyses.
