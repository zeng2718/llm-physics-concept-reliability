#!/usr/bin/env Rscript

# Figure 5. Comparison between model errors and documented student misconceptions.
# Equal-sized primary and sensitivity contingency panels; R-only output.

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- gsub("~\\+~", " ", sub("^--file=", "", script_arg))
script_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
source(file.path(script_dir, "figure_style.R"))

out_dir <- figure_output_dir
comparison <- read_public_data("student_misconception_comparison.csv")
primary <- comparison[
  comparison$comparison_tier == "primary_majority_incorrect",
  ,
  drop = FALSE
]
sensitivity <- comparison[
  comparison$comparison_tier == "sensitivity_correct_majority",
  ,
  drop = FALSE
]

answer_levels <- c("Yes", "Partial", "No")
mechanism_levels <- c("Indeterminate", "No", "Partial", "Full")
pattern_levels <- c("Representation-driven", "Other / boundary")

answer_map <- c(
  yes = "Yes",
  partial = "Partial",
  no = "No"
)
mechanism_map <- c(
  indeterminate = "Indeterminate",
  no = "No",
  partial = "Partial",
  full = "Full"
)

publication_item_label <- function(item_id) {
  inventory <- sub("-.*$", "", item_id)
  item_number <- as.integer(sub("^.*-", "", item_id))
  sprintf("%s Q%d", inventory, item_number)
}

prepare_comparison <- function(x) {
  x$Answer <- factor(
    unname(answer_map[x$answer_level_overlap]),
    levels = answer_levels
  )
  x$Mechanism <- factor(
    unname(mechanism_map[x$mechanism_level_overlap]),
    levels = mechanism_levels
  )
  x$Pattern <- factor(
    ifelse(x$error_pattern == "representation-driven", "Representation-driven", "Other / boundary"),
    levels = pattern_levels
  )
  x$Item_label <- publication_item_label(x$item_id)
  x
}

primary <- prepare_comparison(primary)
sensitivity <- prepare_comparison(sensitivity)

make_contingency <- function(x) {
  tab <- as.data.frame(
    xtabs(
      ~ Answer + Mechanism + Pattern,
      data = x,
      drop.unused.levels = FALSE
    ),
    responseName = "Series_n",
    stringsAsFactors = FALSE
  )
  tab$Answer <- factor(tab$Answer, levels = answer_levels)
  tab$Mechanism <- factor(tab$Mechanism, levels = mechanism_levels)
  tab$Pattern <- factor(tab$Pattern, levels = pattern_levels)
  tab
}

primary_grid <- make_contingency(primary)
sensitivity_grid <- make_contingency(sensitivity)

collapse_cells <- function(grid) {
  out <- aggregate(
    Series_n ~ Answer + Mechanism,
    data = grid,
    FUN = sum,
    drop = FALSE
  )
  out$Answer <- factor(out$Answer, levels = answer_levels)
  out$Mechanism <- factor(out$Mechanism, levels = mechanism_levels)
  out
}

primary_cells <- collapse_cells(primary_grid)
sensitivity_cells <- collapse_cells(sensitivity_grid)

cell_n <- function(grid, answer, mechanism, pattern = NULL) {
  keep <- as.character(grid$Answer) == answer &
    as.character(grid$Mechanism) == mechanism
  if (!is.null(pattern)) {
    keep <- keep & as.character(grid$Pattern) == pattern
  }
  sum(grid$Series_n[keep])
}

# ---------- Locked data checks ----------

stopifnot(
  nrow(primary) == 13L,
  sum(primary$answer_level_overlap == "yes") == 11L,
  sum(primary$answer_level_overlap == "partial") == 1L,
  sum(primary$answer_level_overlap == "no") == 1L,
  sum(primary$mechanism_level_overlap == "no") == 9L,
  sum(primary$mechanism_level_overlap == "partial") == 2L,
  sum(primary$mechanism_level_overlap == "indeterminate") == 2L,
  sum(primary$mechanism_level_overlap == "full") == 0L,
  sum(primary$Pattern == "Representation-driven") == 9L,
  cell_n(primary_grid, "Yes", "No") == 7L,
  cell_n(primary_grid, "Yes", "Partial") == 2L,
  cell_n(primary_grid, "Yes", "Indeterminate") == 2L,
  cell_n(primary_grid, "Partial", "No") == 1L,
  cell_n(primary_grid, "No", "No") == 1L,
  all(
    primary_grid$Series_n[
      as.character(primary_grid$Mechanism) == "No" &
        as.character(primary_grid$Pattern) == "Other / boundary"
    ] == 0L
  )
)

stopifnot(
  nrow(sensitivity) == 6L,
  sum(sensitivity$incorrect_run_count) == 9L,
  sum(sensitivity$answer_level_overlap == "yes") == 6L,
  sum(sensitivity$mechanism_level_overlap == "no") == 3L,
  sum(sensitivity$mechanism_level_overlap == "partial") == 3L,
  sum(sensitivity$mechanism_level_overlap == "full") == 0L,
  sum(sensitivity$Pattern == "Representation-driven") == 3L,
  cell_n(sensitivity_grid, "Yes", "No") == 3L,
  cell_n(sensitivity_grid, "Yes", "Partial") == 3L
)

# ---------- Draw ----------

panel_frame_theme <- theme(
  plot.background = element_rect(
    fill = pal[["paper"]],
    colour = "#111111",
    linewidth = 0.45
  ),
  plot.tag = element_text(
    family = figure_font,
    face = "bold",
    size = 7.6,
    colour = "#111111"
  ),
  plot.tag.position = c(0.020, 0.985)
)

make_panel <- function(
    cells,
    panel_title,
    panel_tag,
    bubble_fill) {
  ggplot(
    cells,
    aes(x = Answer, y = Mechanism)
  ) +
    geom_hline(
      yintercept = 1.5,
      linewidth = 0.40,
      linetype = "22",
      colour = "#AEB9BE"
    ) +
    geom_point(
      data = cells[cells$Series_n > 0, , drop = FALSE],
      aes(size = Series_n),
      shape = 21,
      colour = pal[["ink"]],
      stroke = 0.34,
      fill = bubble_fill,
      alpha = 0.94
    ) +
    geom_text(
      data = cells[cells$Series_n > 0, , drop = FALSE],
      aes(label = Series_n),
      family = figure_font,
      fontface = "bold",
      size = 2.45,
      colour = "#FFFFFF",
      show.legend = FALSE
    ) +
    scale_size_area(
      max_size = 10.8,
      limits = c(0, 7),
      guide = "none"
    ) +
    scale_x_discrete(
      limits = answer_levels,
      drop = FALSE,
      expand = expansion(add = 0.30)
    ) +
    scale_y_discrete(
      limits = mechanism_levels,
      drop = FALSE,
      expand = expansion(add = 0.30)
    ) +
    labs(
      tag = panel_tag,
      title = panel_title,
      x = "Answer-level overlap",
      y = "Mechanism-level overlap"
    ) +
    theme_nature_v4(base_size = 6.8) +
    theme(
      panel.background = element_blank(),
      panel.grid.major = element_line(
        colour = "#E7EBED",
        linewidth = 0.32
      ),
      panel.grid.minor = element_blank(),
      axis.line = element_blank(),
      axis.ticks = element_blank(),
      axis.text.x = element_text(
        size = 6.0,
        margin = margin(t = 4)
      ),
      axis.text.y = element_text(
        size = 6.0,
        margin = margin(r = 4)
      ),
      axis.title.x = element_text(
        size = 6.3,
        margin = margin(t = 5)
      ),
      axis.title.y = element_text(
        size = 6.3,
        margin = margin(r = 6)
      ),
      plot.title = element_text(
        family = figure_font,
        face = "bold",
        size = 6.7,
        hjust = 0.5,
        margin = margin(b = 4)
      ),
      legend.position = "none",
      plot.margin = margin(8, 7, 5, 7, unit = "pt")
    ) +
    panel_frame_theme
}

p_a <- make_panel(
  primary_cells,
  "Primary analysis (n = 13)",
  "(a)",
  pal[["blue_4"]]
)

p_b <- make_panel(
  sensitivity_cells,
  "Sensitivity analysis (n = 6)",
  "(b)",
  pal[["blue_4"]]
)

panel_row <- p_a | plot_spacer() | p_b
panel_row <- panel_row + plot_layout(widths = c(1, 0.035, 1))

figure5_f5r3 <- panel_row

save_pub_r(
  figure5_f5r3,
  file.path(out_dir, "Figure5_student_misconception_comparison"),
  width_mm = 183,
  height_mm = 70,
  png_dpi = 300,
  tiff_dpi = 600
)

message(
  "Exported Figure 5 to ",
  normalizePath(out_dir, winslash = "/", mustWork = TRUE)
)
