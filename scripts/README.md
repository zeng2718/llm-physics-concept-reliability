# Formal collection and analysis scripts

This directory contains the public, test-secure portions of the pipeline used for the 2,305-response formal corpus. Protected item content, answer keys, full model outputs, API credentials, and exploratory or sensitivity-only branches are intentionally excluded.

## `collection/`

| File | Role |
|---|---|
| `run_batch.py` | Loads items, assembles multimodal requests, performs five independent sessions per model–item condition, parses the final answer and confidence, records DNF outcomes, and supports resumable JSONL output. It implements main-item runs, isomorphic-variant runs, and the formal prompted self-review probe. |
| `config.py` | Two verbatim system prompts, the four formal model routes and reasoning settings, protected-input paths, and default run parameters. Main items and isomorphic variants use the same prompt. Historical output-limit exceptions are recorded in `../data/model_configurations.csv`. |
| `items.py` | Loads single-item Markdown records and associated figures from locally supplied protected directories. |
| `parse.py` | Parses the final answer choice and model-stated confidence from visible model output. |
| `adapters.py` | OpenAI-compatible multimodal request adapter plus an offline mock adapter. No tools, web access, or retrieval are attached to requests. |
| `requirements.txt` | Python client dependencies for the formal routes. |
| `.env.example` | Empty credential and protected-input path template. |

The public package does not include the restricted item files needed to repeat data collection. Authorized users can point the script to local copies with `PHYS_QB_ITEM_DIR` and `PHYS_QB_VARIANT_DIR`.

Example commands, run from `scripts/collection/`:

```bash
python run_batch.py --model kimi --domains F,EM,T --runs 5
python run_batch.py --model kimi --run-type variant --runs 5
python run_batch.py --model kimi --run-type prompted_self_review --runs 5
```

For `prompted_self_review`, the script identifies model–item series with at least two distinct valid final answer choices across the five prior main-item runs. Every probe response is collected in a new session; the five prior answers and reasoning records are presented in the same deterministic randomized order used in the study.

## `analysis/`

| File | Role |
|---|---|
| `compute_intercoder_reliability.py` | Reads `data/intercoder_labels.csv` and reproduces the 14 pre-adjudication agreement rows reported in Supplementary Table S2. |
| `reproduce_manuscript_tables.R` | Reads the de-identified formal data and test-secure variant records, reproduces manuscript Tables 1 and 2, and exports the author-synthesized Table 3. |

## `figures/`

`figure2_main_item_reliability.R` through `figure5_student_misconception_comparison.R` read only the public files in `../data/`. They regenerate Figures 2–5 and their test-secure source-data tables. `figure_style.R` contains the shared visual settings. Generated PDF, PNG, SVG, and TIFF files are written to the ignored `reproduced_figures/` directory.

All analysis and plotting scripts use the de-identified adjudicated files in `../data/`, not protected answer keys or raw provider responses.
