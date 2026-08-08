#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- gsub("~\\+~", " ", sub("^--file=", "", script_arg))
script_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
source(file.path(script_dir, "figure_style.R"))

out_dir <- figure_output_dir
source_dir <- figure_source_dir
main <- read_public_data("main_runs.csv")

item_number <- function(item_id) as.integer(sub("^.*-", "", item_id))
item_position <- function(inventory, number) {
  offsets <- c(FCI = 0L, BEMA = 30L, TCE = 61L)
  as.integer(offsets[inventory]) + as.integer(number)
}
publication_item_label <- function(inventory, number) {
  sprintf("%s Q%d", inventory, as.integer(number))
}

series_groups <- split(
  main,
  interaction(main$Model, main[["Item ID"]], drop = TRUE, lex.order = TRUE)
)
series <- do.call(rbind, lapply(series_groups, function(x) {
  valid_classes <- unique(x[["Response Class"]][
    !is.na(x[["Response Class"]]) & x[["Response Class"]] != ""
  ])
  correct <- sum(x$AC == "AC-1")
  wrong <- sum(x$AC == "AC-2")
  dnf <- sum(x$AC == "AC-3")
  majority <- if (correct > wrong) {
    "Correct"
  } else if (wrong > correct) {
    "Completed wrong"
  } else {
    "Unresolved"
  }
  number <- item_number(x[["Item ID"]][1])
  data.frame(
    Model = x$Model[1],
    Model_label = unname(model_labels[x$Model[1]]),
    Item_ID = x[["Item ID"]][1],
    Publication_item_label = publication_item_label(x$Inventory[1], number),
    Domain = x$Inventory[1],
    Item_number = number,
    Item_position = item_position(x$Inventory[1], number),
    Correct_runs = correct,
    Wrong_runs = wrong,
    DNF_runs = dnf,
    Completed_runs = correct + wrong,
    Distinct_response_classes = length(valid_classes),
    Mixed_valid_answers = length(valid_classes) >= 2L,
    Departure = !(correct == 5L && dnf == 0L && length(valid_classes) == 1L),
    Majority = majority,
    stringsAsFactors = FALSE
  )
}))
rownames(series) <- NULL
series <- series[order(match(series$Model, model_order), series$Item_position), , drop = FALSE]

flagged_items <- unique(series[series$Departure, c(
  "Item_ID", "Publication_item_label", "Domain", "Item_number", "Item_position"
)])
flagged_items <- flagged_items[order(flagged_items$Item_position), , drop = FALSE]
names(flagged_items)[names(flagged_items) == "Item_ID"] <- "Item ID"
flagged_items$Zoom_position <- seq_len(nrow(flagged_items))

zoom_runs <- main[main[["Item ID"]] %in% flagged_items[["Item ID"]], , drop = FALSE]
zoom_runs$Outcome <- ifelse(
  zoom_runs$AC == "AC-1",
  "Correct",
  ifelse(zoom_runs$AC == "AC-3", "DNF", "Completed wrong")
)
zoom_runs <- zoom_runs[, c("Model", "Item ID", "Inventory", "Run", "AC", "Outcome")]
names(zoom_runs)[names(zoom_runs) == "Inventory"] <- "Domain"
zoom_runs <- merge(
  zoom_runs,
  flagged_items[, c("Item ID", "Zoom_position")],
  by = "Item ID",
  all.x = TRUE,
  sort = FALSE
)

stopifnot(nrow(series) == 348L)
stopifnot(sum(series$Correct_runs) == 1662L)
stopifnot(sum(series$Completed_runs) == 1729L)
stopifnot(sum(series$DNF_runs) == 11L)
stopifnot(sum(series$Mixed_valid_answers) == 13L)
stopifnot(sum(series$Departure) == 23L)
stopifnot(nrow(flagged_items) == 16L)
stopifnot(nrow(zoom_runs) == 320L)
stopifnot(all(table(paste(zoom_runs$Model, zoom_runs[["Item ID"]], sep = "::")) == 5L))

model_y <- setNames(4:1, model_order)
series$Model_y <- unname(model_y[series$Model])
series$Overview_status <- ifelse(
  series$Departure,
  "Any wrong, multiple final answer letters or DNF · 23/348",
  "5 correct · same final answer letter · 0 DNF · 325/348"
)
series$Overview_status <- factor(
  series$Overview_status,
  levels = c(
    "5 correct · same final answer letter · 0 DNF · 325/348",
    "Any wrong, multiple final answer letters or DNF · 23/348"
  )
)

item_lookup <- unique(series[, c(
  "Item_ID", "Domain", "Item_number", "Item_position",
  "Publication_item_label"
)])
item_lookup <- item_lookup[
  order(item_lookup$Item_position),
  ,
  drop = FALSE
]

domain_blocks <- do.call(
  rbind,
  lapply(domain_order, function(domain) {
    x <- item_lookup[item_lookup$Domain == domain, , drop = FALSE]
    data.frame(
      Domain = domain,
      Header = sprintf(
        "%s · %d items",
        unname(domain_labels[domain]),
        nrow(x)
      ),
      xmin = min(x$Item_position) - 0.45,
      xmax = max(x$Item_position) + 0.45,
      xmid = mean(range(x$Item_position)),
      stringsAsFactors = FALSE
    )
  })
)
domain_blocks$Band_fill <- unname(c(
  FCI = pal[["blue_1"]],
  BEMA = pal[["teal_1"]],
  TCE = pal[["violet_1"]]
)[domain_blocks$Domain])

zoom_cells <- merge(
  series,
  flagged_items[, c("Item ID", "Zoom_position")],
  by.x = "Item_ID",
  by.y = "Item ID",
  all = FALSE,
  sort = FALSE
)
zoom_cells <- zoom_cells[
  order(zoom_cells$Model_y, zoom_cells$Zoom_position),
  ,
  drop = FALSE
]

zoom_runs <- merge(
  zoom_runs,
  flagged_items[, c("Item ID", "Publication_item_label")],
  by = "Item ID",
  all.x = TRUE,
  sort = FALSE
)
zoom_runs$Model_y <- unname(model_y[zoom_runs$Model])
zoom_runs$Run_x <- zoom_runs$Zoom_position +
  (zoom_runs$Run - 3) * 0.135
zoom_runs$Outcome <- factor(
  zoom_runs$Outcome,
  levels = c("Correct", "Completed wrong", "DNF")
)

zoom_domain_blocks <- do.call(
  rbind,
  lapply(domain_order, function(domain) {
    x <- flagged_items[
      flagged_items$Domain == domain,
      ,
      drop = FALSE
    ]
    data.frame(
      Domain = domain,
      Label = sprintf(
        "%s · %d items",
        unname(domain_labels[domain]),
        nrow(x)
      ),
      xmin = min(x$Zoom_position) - 0.45,
      xmax = max(x$Zoom_position) + 0.45,
      xmid = mean(range(x$Zoom_position)),
      stringsAsFactors = FALSE
    )
  })
)
zoom_domain_blocks$Band_fill <- unname(c(
  FCI = pal[["blue_1"]],
  BEMA = pal[["teal_1"]],
  TCE = pal[["violet_1"]]
)[zoom_domain_blocks$Domain])

# Write only test-secure analysis fields; plotting coordinates and option labels
# are deliberately omitted from the public source-data tables.
series_source <- data.frame(
  Model = series$Model,
  `Item ID` = series$Item_ID,
  `Item Label` = series$Publication_item_label,
  Inventory = series$Domain,
  `Correct Runs` = series$Correct_runs,
  `Incorrect Runs` = series$Wrong_runs,
  `DNF Runs` = series$DNF_runs,
  `Completed Runs` = series$Completed_runs,
  `Distinct Response Classes` = series$Distinct_response_classes,
  `Inconsistent Series` = ifelse(series$Mixed_valid_answers, "yes", "no"),
  `Issue Series` = ifelse(series$Departure, "yes", "no"),
  `Majority Outcome` = series$Majority,
  check.names = FALSE
)
exception_source <- data.frame(
  Model = zoom_runs$Model,
  `Item ID` = zoom_runs[["Item ID"]],
  `Item Label` = zoom_runs$Publication_item_label,
  Inventory = zoom_runs$Domain,
  Run = zoom_runs$Run,
  AC = zoom_runs$AC,
  Outcome = zoom_runs$Outcome,
  check.names = FALSE
)
write_source_csv(series_source, file.path(source_dir, "figure2_series_summary.csv"))
write_source_csv(exception_source, file.path(source_dir, "figure2_exception_runs.csv"))

overview_cols <- c(
  "5 correct · same final answer letter · 0 DNF · 325/348" = "#EDF3F6",
  "Any wrong, multiple final answer letters or DNF · 23/348" = pal[["rust_2"]]
)

panel_border_theme <- theme(
  plot.background = element_rect(
    fill = "white",
    colour = "black",
    linewidth = 0.55
  ),
  plot.tag = element_text(
    size = 7.8,
    face = "bold",
    colour = "black",
    margin = margin(r = 2, b = 1)
  ),
  plot.tag.position = c(0.012, 0.988)
)

p_a <- ggplot(series, aes(x = Item_position, y = Model_y)) +
  geom_rect(
    data = domain_blocks,
    aes(xmin = xmin, xmax = xmax, ymin = 4.53, ymax = 4.92),
    inherit.aes = FALSE,
    fill = domain_blocks$Band_fill,
    colour = "white",
    linewidth = 0.3
  ) +
  geom_tile(
    aes(fill = Overview_status),
    width = 0.88,
    height = 0.64,
    colour = "white",
    linewidth = 0.22
  ) +
  geom_vline(
    xintercept = c(30.5, 61.5),
    colour = pal[["ink_mid"]],
    linewidth = 0.38
  ) +
  geom_text(
    data = domain_blocks,
    aes(x = xmid, y = 4.72, label = Header),
    inherit.aes = FALSE,
    family = figure_font,
    fontface = "bold",
    size = 2.25,
    colour = pal[["ink"]]
  ) +
  scale_fill_manual(
    values = overview_cols,
    breaks = names(overview_cols),
    name = NULL
  ) +
  scale_x_continuous(
    limits = c(0.5, 87.5),
    expand = c(0, 0)
  ) +
  scale_y_continuous(
    breaks = c(4, 3, 2, 1),
    labels = unname(model_labels[model_order]),
    limits = c(0.48, 4.98),
    expand = c(0, 0)
  ) +
  coord_cartesian(clip = "off") +
  labs(
    tag = "(a)",
    x = NULL,
    y = NULL
  ) +
  theme_nature_v4(base_size = 6.9) +
  theme(
    axis.line = element_blank(),
    axis.ticks = element_blank(),
    axis.text.x = element_blank(),
    axis.text.y = element_text(
      face = "bold",
      size = 6.2,
      margin = margin(r = 4)
    ),
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.justification = "left",
    legend.box.just = "left",
    legend.text = element_text(size = 5.8),
    legend.key.width = grid::unit(10, "pt"),
    legend.key.height = grid::unit(7, "pt"),
    legend.spacing.x = grid::unit(4, "pt"),
    legend.margin = margin(t = 2, b = 0),
    plot.margin = margin(12, 6, 4, 6, unit = "pt")
  ) +
  panel_border_theme

run_cols <- c(
  "Correct" = pal[["blue_3"]],
  "Completed wrong" = pal[["rust_2"]],
  "DNF" = pal[["dnf"]]
)
mixed_zoom <- zoom_cells[
  zoom_cells$Mixed_valid_answers,
  ,
  drop = FALSE
]
mixed_zoom$Mixed_label <- "≥2 distinct final answer letters"

p_b <- ggplot() +
  geom_hline(
    yintercept = c(0.5, 1.5, 2.5, 3.5, 4.5),
    colour = pal[["grid"]],
    linewidth = 0.28
  ) +
  geom_rect(
    data = zoom_domain_blocks,
    aes(xmin = xmin, xmax = xmax, ymin = 4.54, ymax = 4.94),
    fill = zoom_domain_blocks$Band_fill,
    colour = "white",
    linewidth = 0.3
  ) +
  geom_vline(
    xintercept = c(
      max(flagged_items$Zoom_position[
        flagged_items$Domain == "FCI"
      ]) + 0.5,
      max(flagged_items$Zoom_position[
        flagged_items$Domain == "BEMA"
      ]) + 0.5
    ),
    colour = pal[["ink_mid"]],
    linewidth = 0.35
  ) +
  geom_tile(
    data = zoom_cells,
    aes(x = Zoom_position, y = Model_y),
    width = 0.90,
    height = 0.70,
    fill = pal[["neutral_1"]],
    colour = "white",
    linewidth = 0.35
  ) +
  geom_point(
    data = zoom_runs,
    aes(x = Run_x, y = Model_y, fill = Outcome),
    shape = 21,
    size = 1.70,
    stroke = 0.18,
    colour = "white"
  ) +
  geom_rect(
    data = mixed_zoom,
    aes(
      xmin = Zoom_position - 0.45,
      xmax = Zoom_position + 0.45,
      ymin = Model_y - 0.35,
      ymax = Model_y + 0.35,
      colour = Mixed_label
    ),
    fill = NA,
    linewidth = 0.62
  ) +
  geom_text(
    data = zoom_domain_blocks,
    aes(x = xmid, y = 4.74, label = Label),
    family = figure_font,
    fontface = "bold",
    size = 2.25,
    colour = pal[["ink"]]
  ) +
  scale_fill_manual(
    values = run_cols,
    breaks = c("Correct", "Completed wrong", "DNF"),
    name = "Run outcome"
  ) +
  scale_colour_manual(
    values = c(
      "≥2 distinct final answer letters" = pal[["violet_3"]]
    ),
    name = NULL
  ) +
  scale_x_continuous(
    breaks = flagged_items$Zoom_position,
    labels = flagged_items$Publication_item_label,
    limits = c(0.45, nrow(flagged_items) + 0.55),
    expand = c(0, 0)
  ) +
  scale_y_continuous(
    breaks = c(4, 3, 2, 1),
    labels = unname(model_labels[model_order]),
    limits = c(0.48, 4.98),
    expand = c(0, 0)
  ) +
  guides(
    fill = guide_legend(
      order = 1,
      nrow = 1,
      title.position = "left",
      title.hjust = 0,
      override.aes = list(shape = 21, size = 2.35)
    ),
    colour = guide_legend(
      order = 2,
      override.aes = list(fill = NA, linewidth = 0.7)
    )
  ) +
  coord_cartesian(clip = "off") +
  labs(
    tag = "(b)",
    x = NULL,
    y = NULL
  ) +
  theme_nature_v4(base_size = 6.9) +
  theme(
    axis.line = element_blank(),
    axis.ticks.y = element_blank(),
    axis.ticks.x = element_line(
      linewidth = 0.3,
      colour = pal[["ink_mid"]]
    ),
    axis.text.x = element_text(
      angle = 42,
      hjust = 1,
      vjust = 1,
      size = 5.8
    ),
    axis.text.y = element_text(
      face = "bold",
      size = 6.2,
      margin = margin(r = 4)
    ),
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.box = "horizontal",
    legend.box.just = "left",
    legend.title = element_text(face = "bold", size = 5.9),
    legend.text = element_text(size = 5.6),
    legend.key.width = grid::unit(9, "pt"),
    legend.key.height = grid::unit(7, "pt"),
    legend.margin = margin(t = 2, b = 0),
    plot.margin = margin(12, 6, 4, 6, unit = "pt")
  ) +
  panel_border_theme

figure2_r2 <- wrap_plots(
  p_a,
  plot_spacer(),
  p_b,
  ncol = 1,
  heights = c(0.76, 0.045, 1.24)
)

save_pub_r(
  figure2_r2,
  file.path(out_dir, "Figure2_main_item_reliability"),
  width_mm = 183,
  height_mm = 118
)

message(
  sprintf(
    paste0(
      "Figure 2 exported: %d baseline and %d issue series; ",
      "%d flagged items; %d mixed series; %d DNF runs."
    ),
    sum(!series$Departure),
    sum(series$Departure),
    nrow(flagged_items),
    sum(series$Mixed_valid_answers),
    sum(series$DNF_runs)
  )
)
