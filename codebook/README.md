# Coding framework (codebook)

> Source: Supplementary Materials, Sections S3 and S4 of the manuscript "Reliability Boundaries of Reasoning Large Language Models in Physics Education: Evidence from Concept Inventories".
> This directory contains the prespecified three-track coding framework used to evaluate the formal corpus, the coding and adjudication procedure, and pre-adjudication inter-coder reliability statistics.

## Files

| File                                                           | Content                                                                                                                                   |
| -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `table_S3_correctness_reasoning_representation_codes.csv`      | Table S3. Correctness (AC), reasoning (RC), and representation (Rep) codes applied to the formal corpus                                   |
| `table_S4_failure_mode_codes.csv`                              | Table S4. Failure-mode codes applied to all formal responses (e.g., assumption deficit, spatial-representation failure)                   |
| `table_S5_probe_monitoring_attribution_codes.csv`              | Table S5. Prompted self-review probe monitoring and attribution codes (contradiction identification and related labels)                   |
| `table_S6_probe_correction_evaluation_metacognitive_codes.csv` | Table S6. Prompted self-review probe correction, evaluation, and derived output-based metacognitive level                                 |
| `table_S2_intercoder_agreement.csv`                            | Table S2. Pre-adjudication inter-coder agreement for the formal coding corpus (observed/expected agreement and Cohen's κ per code family) |

## Coding procedure

Codes were assigned by the meaning supported by the response rather than by the final answer letter alone. The stated answer letter and the conclusion supported by the reasoning were retained as separate audit fields; Rep-LM captured a mismatch between them.

Two coders independently coded the 2,305-response formal corpus before adjudication. Disagreements were resolved only after the independent labels had been locked. The adjudicated label was used for analysis, whereas `table_S2_intercoder_agreement.csv` reports agreement computed from the pre-adjudication coder labels.

Both coders were experienced physics teachers, and all coding judgments were made manually. Before coding, a large language model was used to convert the response records into HTML pages with point-and-click controls for coder-selected rubric labels; it did not assign codes. After jointly aligning their interpretation of the prespecified coding rubrics, the coders coded independently. Disagreements were resolved through discussion to produce a final adjudicated code.

## Track structure

- **Track 1** — answer correctness (AC), reasoning correctness (RC), representation correctness (Rep), and supported-conclusion/option-label mismatch (Rep-LM) for formal responses (Table S3).
- **Track 2** — assumption deficit (AD), contradiction blindness (CB), and spatial-representation failure (SRF) for formal responses (Table S4). CB was retained as an audit field rather than a primary outcome because the inventories did not contain deliberately contradictory stems.
- **Track 3** — contradiction identification (CI), attribution type (AT), evaluation of prior reasoning (EVAL), correction quality (CQ), and the derived output-based metacognitive level (ML) for prompted self-review probe responses (Tables S5–S6).

The comparison with documented student misconceptions is a separate mechanism-level comparison reported in manuscript Sections 2.5 and 3.5; it is not one of the three coding tracks.

## Agreement notes

- CB κ was not estimable because both coders assigned CB-4 to every response.
- The conditional SRF-subtype κ reflects strong category imbalance despite 87.1% observed agreement.
- ML was derived from CI, EVAL, and CQ and was not independently coded.
