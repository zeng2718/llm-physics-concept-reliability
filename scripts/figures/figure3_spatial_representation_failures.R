#!/usr/bin/env Rscript

# Figure 3. Model-dependent localization of spatial-representation failures.
# Final adjudicated public main-run coding; plotting and export are R-only.

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- gsub("~\\+~", " ", sub("^--file=", "", script_arg))
script_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
source(file.path(script_dir, "figure_style.R"))

out_dir <- figure_output_dir
source_dir <- figure_source_dir
main <- read_public_data("main_runs.csv")

candidate_items <- c("FCI-07", "FCI-12", "FCI-14", "FCI-21", "FCI-19", "FCI-20")
candidate_labels <- c(
  "FCI-07" = "FCI Q7",
  "FCI-12" = "FCI Q12",
  "FCI-14" = "FCI Q14",
  "FCI-21" = "FCI Q21",
  "FCI-19" = "FCI Q19",
  "FCI-20" = "FCI Q20"
)
candidate_formats <- c(
  "FCI-07" = "Trajectory alternatives",
  "FCI-12" = "Trajectory alternatives",
  "FCI-14" = "Trajectory alternatives",
  "FCI-21" = "Trajectory alternatives",
  "FCI-19" = "Tick-mark scales",
  "FCI-20" = "Tick-mark scales"
)

# ---------- Panel b: fixed 1 x 5 run micro-grid ----------

candidate <- main[main[["Item ID"]] %in% candidate_items, , drop = FALSE]
candidate$Item_index <- match(candidate[["Item ID"]], candidate_items)
candidate$Item_label <- unname(candidate_labels[candidate[["Item ID"]]])
candidate$Format <- unname(candidate_formats[candidate[["Item ID"]]])
candidate$Model_y <- unname(setNames(4:1, model_order)[candidate$Model])
candidate$Run_x <- candidate$Item_index + (candidate$Run - 3) * 0.165
candidate$Outcome <- ifelse(
  candidate$AC == "AC-1",
  "Correct",
  ifelse(candidate$AC == "AC-3", "DNF", "Wrong")
)
candidate$Outcome <- factor(
  candidate$Outcome,
  levels = c("Correct", "Wrong", "DNF")
)
candidate$SRF_outline <- ifelse(
  candidate$SRF == "SRF-2",
  "SRF-coded run",
  "No SRF"
)
candidate$SRF_outline <- factor(
  candidate$SRF_outline,
  levels = c("No SRF", "SRF-coded run")
)

candidate <- candidate[
  order(candidate$Item_index, match(candidate$Model, model_order), candidate$Run),
  ,
  drop = FALSE
]

cell_background <- expand.grid(
  Item_index = seq_along(candidate_items),
  Model = model_order,
  stringsAsFactors = FALSE
)
cell_background$Model_y <- unname(setNames(4:1, model_order)[cell_background$Model])

format_bands <- data.frame(
  xmin = c(0.55, 4.55),
  xmax = c(4.45, 6.45),
  xmid = c(2.50, 5.50),
  label = c("Trajectory alternatives", "Tick-mark scales"),
  stringsAsFactors = FALSE
)

# ---------- Panel a: SRF rate among applicable responses ----------

applicable <- main[main$SRF %in% c("SRF-1", "SRF-2"), , drop = FALSE]
failure <- applicable[applicable$SRF == "SRF-2", , drop = FALSE]

applicable_n <- table(factor(applicable$Model, levels = model_order))
subtype_n <- table(
  factor(failure$Model, levels = model_order),
  factor(failure[["SRF-sub"]], levels = c("V", "C"))
)

srf_rates <- expand.grid(
  Model = model_order,
  Subtype = c("V", "C"),
  stringsAsFactors = FALSE
)
srf_rates$Failures <- mapply(
  function(model, subtype) subtype_n[model, subtype],
  srf_rates$Model,
  srf_rates$Subtype
)
srf_rates$Applicable <- as.integer(applicable_n[srf_rates$Model])
srf_rates$Rate <- srf_rates$Failures / srf_rates$Applicable
srf_rates$Subtype_label <- ifelse(
  srf_rates$Subtype == "V",
  "Visual misreading",
  "Coordination/application"
)
srf_rates$Subtype_label <- factor(
  srf_rates$Subtype_label,
  levels = c("Visual misreading", "Coordination/application")
)
srf_rates$Model_label <- factor(
  unname(model_labels[srf_rates$Model]),
  levels = rev(unname(model_labels[model_order]))
)

srf_totals <- do.call(
  rbind,
  lapply(model_order, function(model) {
    x <- srf_rates[srf_rates$Model == model, , drop = FALSE]
    data.frame(
      Model = model,
      Model_label = unname(model_labels[model]),
      Failures = sum(x$Failures),
      Applicable = unique(x$Applicable),
      Rate = sum(x$Failures) / unique(x$Applicable),
      stringsAsFactors = FALSE
    )
  })
)
srf_totals$Model_label <- factor(
  srf_totals$Model_label,
  levels = rev(unname(model_labels[model_order]))
)
srf_totals$Label <- sprintf(
  "%d/%d (%.1f%%)",
  srf_totals$Failures,
  srf_totals$Applicable,
  100 * srf_totals$Rate
)

# ---------- Assertions and source data ----------

stopifnot(
  nrow(main) == 1740L,
  nrow(candidate) == 120L,
  all(table(
    candidate$Model,
    candidate[["Item ID"]]
  ) == 5L),
  sum(main$SRF %in% c("SRF-1", "SRF-2")) == 989L,
  sum(main$SRF == "SRF-2") == 54L,
  sum(main$SRF == "SRF-2" & main[["SRF-sub"]] == "V") == 48L,
  sum(main$SRF == "SRF-2" & main[["SRF-sub"]] == "C") == 6L,
  sum(candidate$SRF == "SRF-2") == 45L,
  sum(candidate$SRF == "SRF-2" & candidate[["SRF-sub"]] == "V") == 41L
)

candidate_source <- candidate[, c(
  "Format", "Item ID", "Item_label", "Model", "Run", "Outcome",
  "AC", "SRF", "SRF-sub", "Rep-LM"
)]
names(candidate_source) <- c(
  "Format", "Item ID", "Item Label", "Model", "Run", "Outcome",
  "AC", "SRF", "SRF Subtype", "Rep-LM"
)

srf_source <- merge(
  srf_rates,
  srf_totals[, c("Model", "Failures", "Rate")],
  by = "Model",
  suffixes = c("_subtype", "_total"),
  sort = FALSE
)
srf_source <- srf_source[
  order(
    match(srf_source$Model, model_order),
    match(srf_source$Subtype, c("V", "C"))
  ),
  ,
  drop = FALSE
]
srf_source$Model_label <- unname(model_labels[srf_source$Model])
names(srf_source) <- c(
  "Model", "SRF Subtype", "Subtype Failures", "Applicable Responses",
  "Subtype Rate", "Subtype Label", "Model Label", "Total SRF", "Total SRF Rate"
)

concentration_audit <- data.frame(
  Metric = c(
    "All SRFs",
    "Visual misreadings",
    "Coordination/application failures",
    "DNF runs",
    "Representation-label mismatches"
  ),
  Candidate_six_items = c(
    sum(candidate$SRF == "SRF-2"),
    sum(candidate$SRF == "SRF-2" & candidate[["SRF-sub"]] == "V"),
    sum(candidate$SRF == "SRF-2" & candidate[["SRF-sub"]] == "C"),
    sum(candidate$AC == "AC-3"),
    sum(candidate[["Rep-LM"]] == 1, na.rm = TRUE)
  ),
  All_main_items = c(
    sum(main$SRF == "SRF-2"),
    sum(main$SRF == "SRF-2" & main[["SRF-sub"]] == "V"),
    sum(main$SRF == "SRF-2" & main[["SRF-sub"]] == "C"),
    sum(main$AC == "AC-3"),
    sum(main[["Rep-LM"]] == 1, na.rm = TRUE)
  ),
  stringsAsFactors = FALSE
)
names(concentration_audit) <- c(
  "Metric", "Six Exploratory Items", "All Main Items"
)

write_source_csv(
  candidate_source,
  file.path(source_dir, "figure3_candidate_runs.csv")
)
write_source_csv(
  srf_source,
  file.path(source_dir, "figure3_srf_rates.csv")
)
write_source_csv(
  concentration_audit,
  file.path(source_dir, "figure3_concentration_summary.csv")
)

# ---------- Draw ----------

run_cols <- c(
  "Correct" = unname(outcome_cols[["correct"]]),
  "Wrong" = unname(outcome_cols[["wrong"]]),
  "DNF" = unname(outcome_cols[["DNF"]])
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
  plot.tag.position = c(0.018, 0.982)
)

p_candidate <- ggplot() +
  annotate(
    "rect",
    xmin = 0.55,
    xmax = 4.45,
    ymin = 4.58,
    ymax = 4.88,
    fill = pal[["blue_1"]],
    colour = NA
  ) +
  annotate(
    "rect",
    xmin = 4.55,
    xmax = 6.45,
    ymin = 4.58,
    ymax = 4.88,
    fill = pal[["violet_1"]],
    colour = NA
  ) +
  geom_text(
    data = format_bands,
    aes(x = xmid, y = 4.73, label = label),
    family = figure_font,
    fontface = "bold",
    size = 2.15,
    colour = pal[["ink"]]
  ) +
  geom_tile(
    data = cell_background,
    aes(x = Item_index, y = Model_y),
    width = 0.86,
    height = 0.62,
    fill = pal[["neutral_1"]],
    colour = pal[["grid"]],
    linewidth = 0.22
  ) +
  geom_point(
    data = candidate,
    aes(
      x = Run_x,
      y = Model_y,
      fill = Outcome,
      colour = SRF_outline
    ),
    shape = 21,
    size = 1.45,
    stroke = 0.50
  ) +
  annotate(
    "segment",
    x = 4.5,
    xend = 4.5,
    y = 0.55,
    yend = 4.88,
    colour = pal[["ink_mid"]],
    linewidth = 0.35
  ) +
  scale_x_continuous(
    breaks = seq_along(candidate_items),
    labels = unname(candidate_labels[candidate_items]),
    limits = c(0.48, 6.52),
    expand = c(0, 0)
  ) +
  scale_y_continuous(
    breaks = c(4, 3, 2, 1),
    labels = unname(model_labels[model_order]),
    limits = c(0.45, 4.96),
    expand = c(0, 0)
  ) +
  scale_fill_manual(
    values = run_cols,
    breaks = c("Correct", "Wrong", "DNF"),
    name = "Run outcome",
    drop = FALSE
  ) +
  scale_colour_manual(
    values = c(
      "No SRF" = pal[["paper"]],
      "SRF-coded run" = pal[["violet_3"]]
    ),
    breaks = "SRF-coded run",
    labels = "SRF-coded run",
    name = NULL,
    drop = FALSE
  ) +
  guides(
    fill = guide_legend(
      order = 1,
      nrow = 1,
      title.position = "left",
      title.hjust = 0,
      override.aes = list(
        shape = 21,
        colour = pal[["paper"]],
        size = 2.1,
        stroke = 0.45
      )
    ),
    colour = guide_legend(
      order = 2,
      nrow = 1,
      override.aes = list(
        shape = 21,
        fill = pal[["paper"]],
        size = 2.1,
        stroke = 0.75
      )
    )
  ) +
  coord_cartesian(clip = "off") +
  labs(
    tag = "(b)",
    x = NULL,
    y = NULL
  ) +
  theme_nature_v4(base_size = 6.8) +
  theme(
    axis.line = element_blank(),
    axis.ticks = element_blank(),
    axis.text.x = element_text(
      size = 6.0,
      face = "bold",
      margin = margin(t = 4)
    ),
    axis.text.y = element_text(
      size = 6.0,
      face = "bold",
      margin = margin(r = 4)
    ),
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.box = "horizontal",
    legend.box.just = "left",
    legend.title = element_text(size = 5.8, face = "bold"),
    legend.text = element_text(size = 5.6),
    legend.key.width = grid::unit(8, "pt"),
    legend.key.height = grid::unit(7, "pt"),
    legend.spacing.x = grid::unit(1.5, "pt"),
    legend.box.spacing = grid::unit(3, "pt"),
    plot.margin = margin(10, 7, 5, 8, unit = "pt")
  ) +
  panel_frame_theme

p_srf <- ggplot(
  srf_rates,
  aes(x = Rate, y = Model_label, fill = Subtype_label)
) +
  geom_col(
    width = 0.58,
    colour = pal[["paper"]],
    linewidth = 0.25
  ) +
  geom_text(
    data = srf_totals[srf_totals$Rate >= 0.075, , drop = FALSE],
    aes(x = Rate, y = Model_label, label = Label),
    inherit.aes = FALSE,
    hjust = 1.06,
    family = figure_font,
    size = 2.05,
    colour = pal[["paper"]]
  ) +
  geom_text(
    data = srf_totals[srf_totals$Rate < 0.075, , drop = FALSE],
    aes(x = Rate, y = Model_label, label = Label),
    inherit.aes = FALSE,
    hjust = -0.10,
    family = figure_font,
    size = 2.05,
    colour = pal[["ink"]]
  ) +
  scale_fill_manual(
    values = c(
      "Visual misreading" = pal[["violet_3"]],
      "Coordination/application" = pal[["gold_2"]]
    ),
    breaks = c("Visual misreading", "Coordination/application"),
    name = "SRF subtype",
    drop = FALSE
  ) +
  scale_x_continuous(
    limits = c(0, 0.135),
    breaks = c(0, 0.05, 0.10),
    labels = c("0", "5", "10"),
    expand = c(0, 0)
  ) +
  labs(
    tag = "(a)",
    x = "SRF rate (%)",
    y = NULL
  ) +
  theme_nature_v4(base_size = 6.8) +
  theme(
    panel.grid.major.x = element_line(
      colour = pal[["grid"]],
      linewidth = 0.25
    ),
    panel.grid.major.y = element_blank(),
    axis.line.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.text.y = element_text(
      size = 6.0,
      face = "bold",
      margin = margin(r = 4)
    ),
    axis.title.x = element_text(size = 6.2, margin = margin(t = 4)),
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.box.just = "left",
    legend.title = element_text(size = 5.8, face = "bold"),
    legend.text = element_text(size = 5.6),
    legend.key.width = grid::unit(9, "pt"),
    legend.key.height = grid::unit(7, "pt"),
    legend.spacing.x = grid::unit(1.5, "pt"),
    legend.box.spacing = grid::unit(3, "pt"),
    plot.margin = margin(10, 8, 5, 8, unit = "pt")
  ) +
  panel_frame_theme

# Equal outer frames are retained after moving the model-level overview to
# panel a and the six-item exploratory detail to panel b. The small spacer
# keeps the two black borders visually distinct.
figure3_r2 <- p_srf | plot_spacer() | p_candidate
figure3_r2 <- figure3_r2 +
  plot_layout(widths = c(1, 0.045, 1))

save_pub_r(
  figure3_r2,
  file.path(out_dir, "Figure3_spatial_representation_failures"),
  width_mm = 183,
  height_mm = 86,
  png_dpi = 300,
  tiff_dpi = 600
)

message(
  "Exported Figure 3 and source data to ",
  normalizePath(out_dir, winslash = "/", mustWork = TRUE)
)
