# Figure reproduction

The four R scripts reproduce manuscript Figures 2–5 from the public data package and regenerate the CSV files in `source_data/`. They do not read protected item text, figures, answer keys, raw model responses, or actual answer letters.

| Script | Manuscript output | Public input |
|---|---|---|
| `figure2_main_item_reliability.R` | Figure 2 | `data/main_runs.csv` |
| `figure3_spatial_representation_failures.R` | Figure 3 | `data/main_runs.csv` |
| `figure4_prompted_self_review.R` | Figure 4 | `data/main_runs.csv`, `data/prompted_self_review_runs.csv` |
| `figure5_student_misconception_comparison.R` | Figure 5 | `data/student_misconception_comparison.csv` |

For Figure 5, the script writes the 19 series-level classifications to
`source_data/figure5_series_classifications.csv` and the complete primary and
sensitivity contingency grids to `source_data/figure5_contingency_counts.csv`.

`figure_style.R` contains shared styling and export functions. Generated PDF, PNG, SVG, and TIFF files are written to `reproduced_figures/`, which is ignored by version control.

Figure 1 is a conceptual study-design diagram rather than a data-derived plot and is therefore not included in the public reproducibility package. The isomorphic-variant item figures were drawn manually in Microsoft PowerPoint; no variant-figure script exists or belongs in this directory.
