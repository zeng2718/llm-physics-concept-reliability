#!/usr/bin/env Rscript

# Reproduce manuscript Tables 1 and 2 from the public response-level data and
# write the author-synthesized Table 3 in machine-readable form.

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- gsub("~\\+~", " ", sub("^--file=", "", script_arg))
script_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
release_root <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
data_dir <- file.path(release_root, "data")
variant_dir <- file.path(release_root, "variants")
source_dir <- file.path(script_dir, "source_data")
dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)

read_public_csv <- function(path) {
  read.csv(
    path,
    check.names = FALSE,
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )
}

write_public_csv <- function(x, filename) {
  write.csv(x, file.path(source_dir, filename), row.names = FALSE, na = "")
}

model_order <- c(
  "Kimi K2.6",
  "GPT-5.5",
  "Gemini 3.1 Pro Preview",
  "Claude Opus 4.6"
)

main <- read_public_csv(file.path(data_dir, "main_runs.csv"))
variant <- read_public_csv(file.path(data_dir, "variant_runs.csv"))
mapping <- read_public_csv(file.path(variant_dir, "mapping_id_level.csv"))
permutation <- read_public_csv(
  file.path(variant_dir, "review", "option_permutation_outcomes.csv")
)

majority_state <- function(x) {
  correct <- sum(x == "AC-1", na.rm = TRUE)
  incorrect <- sum(x == "AC-2", na.rm = TRUE)
  if (correct > incorrect) return("C")
  if (incorrect > correct) return("W")
  "Unresolved"
}

summarize_series <- function(x, id_column) {
  key <- interaction(x$Model, x[[id_column]], drop = TRUE, lex.order = TRUE)
  rows <- lapply(split(x, key), function(group) {
    data.frame(
      Model = group$Model[1],
      ID = group[[id_column]][1],
      State = majority_state(group$AC),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

main_state <- summarize_series(main, "Item ID")
variant_state <- summarize_series(variant, "Item ID")
names(main_state)[2:3] <- c("source_item_id", "Main Majority Outcome")
names(variant_state)[2:3] <- c("variant_id", "Variant Majority Outcome")

pairs <- merge(mapping, permutation, by = "variant_id", all.x = TRUE, sort = FALSE)
pairs <- merge(pairs, main_state, by = "source_item_id", all.x = TRUE, sort = FALSE)
pairs <- merge(pairs, variant_state, by = c("variant_id", "Model"), all.x = TRUE, sort = FALSE)
pairs$Transition <- ifelse(
  pairs[["Main Majority Outcome"]] == "Unresolved" |
    pairs[["Variant Majority Outcome"]] == "Unresolved",
  "Unresolved",
  paste0(pairs[["Main Majority Outcome"]], "→", pairs[["Variant Majority Outcome"]])
)
pairs <- pairs[order(match(pairs$Model, model_order), pairs$variant_id), , drop = FALSE]

pair_source <- data.frame(
  Model = pairs$Model,
  `Original Item ID` = pairs$source_item_id,
  `Variant ID` = pairs$variant_id,
  `Main Majority Outcome` = pairs[["Main Majority Outcome"]],
  `Variant Majority Outcome` = pairs[["Variant Majority Outcome"]],
  Transition = pairs$Transition,
  `Retained Original Answer Letter` = pairs$retained_original_answer_letter,
  check.names = FALSE
)
write_public_csv(pair_source, "table1_variant_pair_outcomes.csv")

transition_summary <- function(x, label, calculate_p = FALSE) {
  counts <- table(factor(x$Transition, levels = c("C→C", "C→W", "W→C", "W→W", "Unresolved")))
  discordant <- unname(counts["C→W"] + counts["W→C"])
  exact_p <- if (calculate_p && discordant > 0L) {
    binom.test(unname(counts["C→W"]), discordant, p = 0.5)$p.value
  } else {
    NA_real_
  }
  data.frame(
    `Model or Analysis` = label,
    `Pair n` = nrow(x),
    `C to C` = unname(counts["C→C"]),
    `C to W` = unname(counts["C→W"]),
    `W to C` = unname(counts["W→C"]),
    `W to W` = unname(counts["W→W"]),
    Unresolved = unname(counts["Unresolved"]),
    `Exact McNemar p` = exact_p,
    check.names = FALSE
  )
}

table1 <- do.call(
  rbind,
  lapply(model_order, function(model) {
    transition_summary(pairs[pairs$Model == model, , drop = FALSE], model)
  })
)
table1 <- rbind(
  table1,
  transition_summary(pairs, "Pooled", calculate_p = TRUE),
  transition_summary(
    pairs[pairs$retained_original_answer_letter == "no", , drop = FALSE],
    "Pooled, excluding four same-letter variants",
    calculate_p = TRUE
  )
)
table1[["Exact McNemar p"]] <- ifelse(
  is.na(table1[["Exact McNemar p"]]),
  "-",
  sprintf("%.3f", as.numeric(table1[["Exact McNemar p"]]))
)

stopifnot(
  identical(as.integer(table1[5, 2:7]), c(100L, 93L, 1L, 3L, 1L, 2L)),
  identical(as.integer(table1[6, 2:7]), c(84L, 77L, 1L, 3L, 1L, 2L)),
  table1[5, "Exact McNemar p"] == "0.625",
  table1[6, "Exact McNemar p"] == "0.625"
)
write_public_csv(table1, "table1_variant_transition_summary.csv")

completed <- main[main[["Completion Status"]] == "completed", , drop = FALSE]
table2_rows <- lapply(model_order, function(model) {
  x <- completed[completed$Model == model, , drop = FALSE]
  confidence <- as.numeric(x[["Confidence Normalized"]])
  correct <- x$AC == "AC-1"
  bin <- round(confidence * 10)
  bin_groups <- split(seq_along(bin), bin)
  ece <- sum(vapply(bin_groups, function(indices) {
    length(indices) / length(bin) * abs(
      mean(confidence[indices]) - mean(correct[indices])
    )
  }, numeric(1)))
  data.frame(
    Model = model,
    `Valid n` = nrow(x),
    Accuracy = round(mean(correct), 3),
    `Mean Confidence` = round(mean(confidence), 3),
    ECE = round(ece, 3),
    check.names = FALSE
  )
})
table2 <- do.call(rbind, table2_rows)
rownames(table2) <- NULL

expected_table2 <- data.frame(
  Model = model_order,
  `Valid n` = c(424L, 435L, 435L, 435L),
  Accuracy = c(0.943, 0.989, 0.970, 0.943),
  `Mean Confidence` = c(0.995, 0.987, 0.998, 0.916),
  ECE = c(0.056, 0.009, 0.028, 0.030),
  check.names = FALSE
)
stopifnot(isTRUE(all.equal(table2, expected_table2, check.attributes = FALSE)))
write_public_csv(table2, "table2_confidence_calibration.csv")

table3 <- data.frame(
  `Evidence Dimension` = c(
    "Conceptual task performance and near transfer",
    "Figure-grounded reasoning",
    "Reliability and self-review",
    "Model-stated confidence",
    "Comparison with documented student misconceptions"
  ),
  `Empirical Capability and Boundary` = c(
    "High accuracy and stable transfer to isomorphic variants; evidence is limited to the tested transformations.",
    "Most illustrated items were solved correctly, but representation failures clustered by model and figure format.",
    "Responses were usually stable, but stable errors occurred and prompted review of inconsistent solutions did not reliably correct them.",
    "Calibration was model-specific, with high-confidence errors and inconsistent scale use.",
    "Wrong-option overlap was common, but the underlying mechanisms generally differed from documented student misconceptions."
  ),
  `Educational Implication` = c(
    "Support concept-question solving and independently verifiable answer checking.",
    "Validate the deployed model on the actual figures; test clearer redraws or parallel text where needed.",
    "Use disagreement as a warning signal; persistent cases require changed representations or external verification.",
    "Calibrate by model and use confidence to prioritize review, not as proof of correctness.",
    "Do not use model errors as proxies for student thinking without mechanism-level validation."
  ),
  check.names = FALSE
)
write_public_csv(table3, "table3_capability_boundary_matrix.csv")

message("Reproduced manuscript Tables 1–3 in ", normalizePath(source_dir, mustWork = TRUE))
