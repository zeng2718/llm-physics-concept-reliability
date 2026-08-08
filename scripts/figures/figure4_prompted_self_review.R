#!/usr/bin/env Rscript

# Figure 4. Prompted self-review detects disagreement without reliable repair.
# Final adjudicated public main and prompted-self-review coding; R-only output.

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- gsub("~\\+~", " ", sub("^--file=", "", script_arg))
script_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
source(file.path(script_dir, "figure_style.R"))

out_dir <- figure_output_dir
source_dir <- figure_source_dir
probe <- read_public_data("prompted_self_review_runs.csv")
main <- read_public_data("main_runs.csv")

stopifnot(
  nrow(probe) == 65L,
  length(unique(paste(
    probe$Model,
    probe[["Item ID"]],
    sep = "::"
  ))) == 13L
)

targets <- unique(probe[, c("Model", "Item ID"), drop = FALSE])
target_key <- paste(targets$Model, targets[["Item ID"]], sep = "::")
main_key <- paste(main$Model, main[["Item ID"]], sep = "::")
main_target <- main[main_key %in% target_key, , drop = FALSE]

stopifnot(nrow(main_target) == 65L)

outcome_from_ac <- function(x) {
  out <- rep(NA_character_, length(x))
  out[x == "AC-1"] <- "Correct"
  out[x == "AC-2"] <- "Incorrect"
  out[x == "AC-3"] <- "DNF"
  out
}

majority_outcome <- function(x) {
  n_correct <- sum(x == "AC-1", na.rm = TRUE)
  n_wrong <- sum(x == "AC-2", na.rm = TRUE)
  if (n_correct > n_wrong) return("C")
  if (n_wrong > n_correct) return("W")
  "U"
}

publication_item_label <- function(item_id) {
  inventory <- sub("-.*$", "", item_id)
  item_number <- as.integer(sub("^.*-", "", item_id))
  sprintf("%s Q%d", inventory, item_number)
}

series_keys <- sort(unique(paste(
  probe$Model,
  probe[["Item ID"]],
  sep = "::"
)))

series_summary <- do.call(
  rbind,
  lapply(series_keys, function(key) {
    bits <- strsplit(key, "::", fixed = TRUE)[[1]]
    m <- main_target[
      main_target$Model == bits[1] &
        main_target[["Item ID"]] == bits[2],
      ,
      drop = FALSE
    ]
    p <- probe[
      probe$Model == bits[1] &
        probe[["Item ID"]] == bits[2],
      ,
      drop = FALSE
    ]
    main_majority <- majority_outcome(m$AC)
    review_majority <- majority_outcome(p$AC)
    item_domain <- sub("-.*$", "", bits[2])
    data.frame(
      Model = bits[1],
      Item = bits[2],
      Item_label = publication_item_label(bits[2]),
      Domain_rank = match(item_domain, domain_order),
      Item_number = as.integer(sub("^.*-", "", bits[2])),
      main_majority = main_majority,
      review_majority = review_majority,
      transition = paste0(main_majority, "\u2192", review_majority),
      main_correct = sum(m$AC == "AC-1"),
      review_correct = sum(p$AC == "AC-1"),
      stringsAsFactors = FALSE
    )
  })
)

series_summary$Model_rank <- match(series_summary$Model, model_order)
series_summary <- series_summary[
  order(
    series_summary$Model_rank,
    series_summary$Domain_rank,
    series_summary$Item_number
  ),
  ,
  drop = FALSE
]
rownames(series_summary) <- NULL

# Compact, still-visible gaps separate the unequal model blocks.
group_gap <- 0.20
cursor_y <- nrow(series_summary) + (length(model_order) - 1) * group_gap
series_summary$y <- NA_real_

for (model in model_order) {
  idx <- which(series_summary$Model == model)
  series_summary$y[idx] <- cursor_y - (seq_along(idx) - 1)
  cursor_y <- min(series_summary$y[idx]) - 1 - group_gap
}

model_display <- c(
  "Kimi K2.6" = "Kimi K2.6",
  "GPT-5.5" = "GPT-5.5",
  "Gemini 3.1 Pro Preview" = "Gemini 3.1\nPro",
  "Claude Opus 4.6" = "Claude\nOpus 4.6"
)

model_bands <- do.call(
  rbind,
  lapply(model_order, function(model) {
    x <- series_summary[series_summary$Model == model, , drop = FALSE]
    data.frame(
      Model = model,
      Model_label = unname(model_display[model]),
      ymin = min(x$y) - 0.43,
      ymax = max(x$y) + 0.43,
      ymid = mean(range(x$y)),
      Series_n = nrow(x),
      stringsAsFactors = FALSE
    )
  })
)

make_run_rows <- function(x, stage_name, x_offset) {
  x <- x[order(x$Model, x[["Item ID"]], x$Run), , drop = FALSE]
  data.frame(
    Model = x$Model,
    Item = x[["Item ID"]],
    Stage = stage_name,
    Run = x$Run,
    x = x$Run + x_offset,
    Outcome = outcome_from_ac(x$AC),
    stringsAsFactors = FALSE
  )
}

run_rows <- rbind(
  make_run_rows(main_target, "Main", 0),
  make_run_rows(probe, "Probe", 6)
)
run_rows <- merge(
  run_rows,
  series_summary[, c(
    "Model", "Item", "Item_label", "y",
    "main_majority", "review_majority", "transition"
  )],
  by = c("Model", "Item"),
  all.x = TRUE,
  sort = FALSE
)
run_rows$Outcome <- factor(
  run_rows$Outcome,
  levels = c("Correct", "Incorrect", "DNF")
)
series_summary$transition <- factor(
  series_summary$transition,
  levels = c("C\u2192C", "W\u2192C", "C\u2192W", "W\u2192W")
)

transition_counts <- table(series_summary$transition)
expected_transitions <- c(
  "C\u2192C" = 5,
  "W\u2192C" = 2,
  "C\u2192W" = 2,
  "W\u2192W" = 4
)

stopifnot(
  nrow(run_rows) == 130L,
  all(table(
    run_rows$Model,
    run_rows$Item,
    run_rows$Stage
  )[table(
    run_rows$Model,
    run_rows$Item,
    run_rows$Stage
  ) > 0] == 5L),
  sum(run_rows$Outcome == "DNF") == 0L,
  all(as.integer(
    transition_counts[names(expected_transitions)]
  ) == expected_transitions),
  sum(main_target$AC == "AC-1") == 32L,
  sum(probe$AC == "AC-1") == 38L,
  sum(series_summary$main_majority == "C") == 7L,
  sum(series_summary$review_majority == "C") == 7L,
  identical(
    as.integer(model_bands$Series_n),
    c(4L, 2L, 1L, 6L)
  )
)

# ---------- Panel b: response-level review-process measures ----------

metric_rows <- data.frame(
  Metric = c(
    "Recognized disagreement",
    "Evaluated prior reasoning",
    "Substantive regulation (ML-3)",
    "Error persistence (CQ-3)",
    "SRF among incorrect probes"
  ),
  Numerator = c(
    sum(probe$CI %in% c("CI-1", "CI-2")),
    sum(probe$EVAL == "EVAL-1"),
    sum(probe$ML == "ML-3"),
    sum(probe$CQ == "CQ-3"),
    sum(probe$AC == "AC-2" & probe$SRF == "SRF-2")
  ),
  Denominator = c(
    65,
    65,
    65,
    65,
    sum(probe$AC == "AC-2")
  ),
  Measure_type = c(
    "Monitoring / evaluation",
    "Monitoring / evaluation",
    "Monitoring / evaluation",
    "Failure-related",
    "Failure-related"
  ),
  stringsAsFactors = FALSE
)
metric_rows$Proportion <- metric_rows$Numerator / metric_rows$Denominator
metric_rows$Label <- sprintf(
  "%d/%d",
  metric_rows$Numerator,
  metric_rows$Denominator
)
metric_rows$Metric <- factor(
  metric_rows$Metric,
  levels = rev(metric_rows$Metric)
)
metric_rows$Measure_type <- factor(
  metric_rows$Measure_type,
  levels = c("Monitoring / evaluation", "Failure-related")
)

stopifnot(
  all(metric_rows$Numerator == c(49L, 41L, 22L, 32L, 23L)),
  all(metric_rows$Denominator == c(65L, 65L, 65L, 65L, 27L))
)

# ---------- Source data ----------

source_runs <- run_rows[, c(
  "Model", "Item", "Item_label", "Stage", "Run", "Outcome",
  "main_majority", "review_majority", "transition"
)]
source_runs <- source_runs[
  order(
    match(source_runs$Model, model_order),
    match(source_runs$Item, series_summary$Item),
    match(source_runs$Stage, c("Main", "Probe")),
    source_runs$Run
  ),
  ,
  drop = FALSE
]

source_runs$Stage <- ifelse(
  source_runs$Stage == "Main",
  "main item",
  "prompted self-review probe"
)
source_runs <- data.frame(
  Model = source_runs$Model,
  `Item ID` = source_runs$Item,
  `Item Label` = source_runs$Item_label,
  `Data Stage` = source_runs$Stage,
  Run = source_runs$Run,
  Outcome = source_runs$Outcome,
  `Main Majority` = source_runs$main_majority,
  `Prompted Self-Review Majority` = source_runs$review_majority,
  `Majority Transition` = source_runs$transition,
  check.names = FALSE
)

source_transitions <- series_summary[, c(
  "Model", "Item", "Item_label", "main_correct", "review_correct",
  "main_majority", "review_majority", "transition"
)]
names(source_transitions) <- c(
  "Model", "Item ID", "Item Label", "Main Correct Runs",
  "Prompted Self-Review Correct Runs", "Main Majority",
  "Prompted Self-Review Majority", "Majority Transition"
)

source_measures <- data.frame(
  Metric = as.character(metric_rows$Metric),
  Numerator = metric_rows$Numerator,
  Denominator = metric_rows$Denominator,
  `Measure Type` = as.character(metric_rows$Measure_type),
  Proportion = metric_rows$Proportion,
  Label = metric_rows$Label,
  check.names = FALSE
)

write_source_csv(
  source_runs,
  file.path(source_dir, "figure4_main_and_prompted_self_review_runs.csv")
)
write_source_csv(
  source_transitions,
  file.path(source_dir, "figure4_series_transitions.csv")
)
write_source_csv(
  source_measures,
  file.path(source_dir, "figure4_prompted_self_review_measures.csv")
)

# ---------- Draw ----------

# Plotting-only coordinates reduce vertical dispersion in panel b while
# preserving the original ordering, labels, values and source-data table.
metric_plot <- metric_rows
metric_plot$Metric_label <- as.character(metric_plot$Metric)
metric_plot$Metric_y <- rev(seq_len(nrow(metric_plot)))

run_cols <- c(
  "Correct" = unname(outcome_cols[["correct"]]),
  "Incorrect" = unname(outcome_cols[["wrong"]])
)
transition_cols <- c(
  "C\u2192C" = pal[["blue_4"]],
  "W\u2192C" = pal[["teal_3"]],
  "C\u2192W" = pal[["rust_2"]],
  "W\u2192W" = pal[["rust_3"]]
)
measure_cols <- c(
  "Monitoring / evaluation" = pal[["blue_4"]],
  "Failure-related" = pal[["rust_2"]]
)

panel_frame_theme <- theme(
  plot.background = element_rect(
    fill = pal[["paper"]],
    colour = "#111111",
    linewidth = 0.45
  ),
  plot.tag = element_text(
    family = figure_font,
    face = "bold",
    size = 8.2,
    colour = "#111111"
  ),
  plot.tag.position = c(0.018, 0.988)
)

header_y <- max(series_summary$y) + 0.86
legend_y_outcome <- min(series_summary$y) - 1.20
legend_y_transition <- min(series_summary$y) - 2.18
y_limits <- c(min(series_summary$y) - 2.68, header_y + 0.42)

outcome_legend <- data.frame(
  x = c(0.45, 3.15),
  y = legend_y_outcome,
  Outcome = factor(
    c("Correct", "Incorrect"),
    levels = c("Correct", "Incorrect", "DNF")
  ),
  Label = c("Correct", "Incorrect"),
  stringsAsFactors = FALSE
)

transition_legend <- data.frame(
  x = c(1.25, 4.10, 6.95, 9.80),
  y = legend_y_transition,
  transition = factor(
    c("C\u2192C", "W\u2192C", "C\u2192W", "W\u2192W"),
    levels = c("C\u2192C", "W\u2192C", "C\u2192W", "W\u2192W")
  ),
  Label = c("C\u2192C", "W\u2192C", "C\u2192W", "W\u2192W"),
  stringsAsFactors = FALSE
)

p_a <- ggplot() +
  geom_rect(
    data = model_bands,
    aes(
      xmin = -5.0,
      xmax = 13.45,
      ymin = ymin,
      ymax = ymax
    ),
    fill = "#FAFBFC",
    colour = pal[["grid"]],
    linewidth = 0.34
  ) +
  geom_rect(
    data = model_bands,
    aes(
      xmin = -5.0,
      xmax = -2.25,
      ymin = ymin,
      ymax = ymax
    ),
    fill = pal[["blue_1"]],
    colour = pal[["grid"]],
    linewidth = 0.34
  ) +
  geom_text(
    data = model_bands,
    aes(x = -3.63, y = ymid, label = Model_label),
    family = figure_font,
    fontface = "bold",
    lineheight = 0.92,
    size = 2.15,
    colour = pal[["ink"]]
  ) +
  geom_text(
    data = series_summary,
    aes(x = 0.20, y = y, label = Item_label),
    hjust = 1,
    family = figure_font,
    size = 2.08,
    colour = pal[["ink"]]
  ) +
  geom_tile(
    data = run_rows,
    aes(x = x, y = y, fill = Outcome),
    width = 0.78,
    height = 0.68,
    colour = pal[["paper"]],
    linewidth = 0.30,
    show.legend = FALSE
  ) +
  geom_text(
    data = series_summary,
    aes(
      x = 12.55,
      y = y,
      label = transition,
      colour = transition
    ),
    family = figure_font,
    fontface = "bold",
    size = 2.35,
    show.legend = FALSE
  ) +
  annotate(
    "segment",
    x = 0.52,
    xend = 0.52,
    y = min(series_summary$y) - 0.43,
    yend = max(series_summary$y) + 0.43,
    colour = pal[["grid"]],
    linewidth = 0.34
  ) +
  annotate(
    "segment",
    x = 6,
    xend = 6,
    y = min(series_summary$y) - 0.43,
    yend = max(series_summary$y) + 0.43,
    colour = pal[["ink_mid"]],
    linewidth = 0.35
  ) +
  annotate(
    "segment",
    x = 11.65,
    xend = 11.65,
    y = min(series_summary$y) - 0.43,
    yend = max(series_summary$y) + 0.43,
    colour = pal[["ink_mid"]],
    linewidth = 0.35
  ) +
  annotate(
    "text",
    x = c(3, 9, 12.55),
    y = header_y,
    label = c("Main runs 1\u20135", "Probe runs 1\u20135", "Majority"),
    family = figure_font,
    fontface = "bold",
    size = 2.15,
    colour = pal[["ink_mid"]]
  ) +
  annotate(
    "text",
    x = -3.45,
    y = legend_y_outcome,
    label = "Run outcome",
    hjust = 0,
    family = figure_font,
    fontface = "bold",
    size = 2.05,
    colour = pal[["ink"]]
  ) +
  geom_tile(
    data = outcome_legend,
    aes(x = x, y = y, fill = Outcome),
    width = 0.45,
    height = 0.45,
    colour = pal[["paper"]],
    linewidth = 0.25,
    show.legend = FALSE
  ) +
  geom_text(
    data = outcome_legend,
    aes(x = x + 0.42, y = y, label = Label),
    hjust = 0,
    family = figure_font,
    size = 1.92,
    colour = pal[["ink"]]
  ) +
  annotate(
    "text",
    x = -3.45,
    y = legend_y_transition,
    label = "Majority transition",
    hjust = 0,
    family = figure_font,
    fontface = "bold",
    size = 2.05,
    colour = pal[["ink"]]
  ) +
  geom_text(
    data = transition_legend,
    aes(x = x, y = y, colour = transition),
    label = "\u2192",
    family = figure_font,
    fontface = "bold",
    size = 2.85,
    show.legend = FALSE
  ) +
  geom_text(
    data = transition_legend,
    aes(x = x + 0.46, y = y, label = Label),
    hjust = 0,
    family = figure_font,
    size = 1.92,
    colour = pal[["ink"]]
  ) +
  scale_fill_manual(
    values = run_cols,
    breaks = c("Correct", "Incorrect"),
    name = "Run outcome",
    drop = FALSE,
    guide = "none"
  ) +
  scale_colour_manual(
    values = transition_cols,
    breaks = c("C\u2192C", "W\u2192C", "C\u2192W", "W\u2192W"),
    name = "Majority transition",
    drop = FALSE,
    guide = "none"
  ) +
  scale_x_continuous(
    limits = c(-5.08, 13.55),
    expand = c(0, 0)
  ) +
  scale_y_continuous(
    limits = y_limits,
    expand = c(0, 0)
  ) +
  coord_cartesian(clip = "off") +
  labs(
    tag = "(a)",
    x = NULL,
    y = NULL
  ) +
  theme_nature_v4(base_size = 6.8) +
  theme(
    panel.background = element_blank(),
    panel.grid = element_blank(),
    axis.line = element_blank(),
    axis.ticks = element_blank(),
    axis.text = element_blank(),
    legend.position = "none",
    plot.margin = margin(7, 7, 4, 8, unit = "pt")
  ) +
  panel_frame_theme

p_b <- ggplot(
  metric_plot,
  aes(x = Proportion, y = Metric_y)
) +
  geom_segment(
    aes(x = 0, xend = Proportion, yend = Metric_y),
    linewidth = 1.35,
    colour = pal[["neutral_2"]],
    lineend = "round"
  ) +
  geom_point(
    aes(colour = Measure_type),
    size = 2.9
  ) +
  geom_text(
    aes(label = Label),
    hjust = -0.20,
    family = figure_font,
    fontface = "bold",
    size = 2.15,
    colour = pal[["ink"]]
  ) +
  scale_colour_manual(
    values = measure_cols,
    breaks = c("Monitoring / evaluation", "Failure-related"),
    name = "Measure",
    drop = FALSE
  ) +
  scale_x_continuous(
    limits = c(0, 1.12),
    breaks = c(0, 0.5, 1),
    labels = c("0", "50", "100"),
    expand = c(0, 0)
  ) +
  scale_y_continuous(
    limits = c(0, 6),
    breaks = metric_plot$Metric_y,
    labels = metric_plot$Metric_label,
    expand = c(0, 0)
  ) +
  labs(
    tag = "(b)",
    x = "Responses (%)",
    y = NULL
  ) +
  theme_nature_v4(base_size = 6.8) +
  theme(
    panel.grid.major.x = element_line(
      linewidth = 0.28,
      colour = pal[["grid"]]
    ),
    panel.grid.major.y = element_blank(),
    axis.line.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.text.y = element_text(
      size = 5.8,
      lineheight = 0.92,
      margin = margin(r = 4)
    ),
    axis.title.x = element_text(size = 6.2, margin = margin(t = 4)),
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.box.just = "left",
    legend.title = element_text(size = 5.7, face = "bold"),
    legend.text = element_text(size = 5.5),
    legend.key.width = grid::unit(9, "pt"),
    legend.key.height = grid::unit(7, "pt"),
    legend.spacing.x = grid::unit(1.5, "pt"),
    legend.box.spacing = grid::unit(1.5, "pt"),
    plot.margin = margin(7, 8, 4, 8, unit = "pt")
  ) +
  panel_frame_theme

# A retains the run-level evidence and therefore receives more width. Freeing
# its bottom alignment allows the matrix and its two custom legend rows to use
# the space otherwise reserved for panel b's axis and external legend.
figure4_f4r2 <- free(p_a, side = "b") | plot_spacer() | p_b
figure4_f4r2 <- figure4_f4r2 +
  plot_layout(widths = c(1.55, 0.05, 1))

save_pub_r(
  figure4_f4r2,
  file.path(out_dir, "Figure4_prompted_self_review"),
  width_mm = 183,
  height_mm = 99,
  png_dpi = 300,
  tiff_dpi = 600
)

message(
  "Exported Figure 4 and source data to ",
  normalizePath(out_dir, winslash = "/", mustWork = TRUE)
)
