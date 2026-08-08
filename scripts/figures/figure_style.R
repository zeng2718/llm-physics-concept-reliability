suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})

# Shared visual contract for manuscript Figures 2--5.
figure_font <- "Arial"

model_order <- c(
  "Kimi K2.6",
  "GPT-5.5",
  "Gemini 3.1 Pro Preview",
  "Claude Opus 4.6"
)
model_labels <- c(
  "Kimi K2.6" = "Kimi K2.6",
  "GPT-5.5" = "GPT-5.5",
  "Gemini 3.1 Pro Preview" = "Gemini 3.1 Pro",
  "Claude Opus 4.6" = "Claude Opus 4.6"
)

inventory_order <- c("FCI", "BEMA", "TCE")
inventory_labels <- c(FCI = "FCI", BEMA = "BEMA", TCE = "TCE")
# Short aliases retained inside plotting code; values are the public inventory
# names, not the historical internal F/EM/T codes.
domain_order <- inventory_order
domain_labels <- inventory_labels

script_file <- function() {
  arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(arg) != 1L) {
    stop("Run this script with Rscript so release-relative paths can be resolved.")
  }
  path <- sub("^--file=", "", arg)
  normalizePath(gsub("~\\+~", " ", path), mustWork = TRUE)
}

figure_script_dir <- dirname(script_file())
release_root <- normalizePath(file.path(figure_script_dir, "..", ".."), mustWork = TRUE)
public_data_dir <- file.path(release_root, "data")
figure_source_dir <- file.path(figure_script_dir, "source_data")
figure_output_dir <- file.path(figure_script_dir, "reproduced_figures")
dir.create(figure_source_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_output_dir, recursive = TRUE, showWarnings = FALSE)

pal <- c(
  ink = "#263238",
  ink_mid = "#58656B",
  grid = "#D9E0E3",
  paper = "#FFFFFF",
  neutral_1 = "#F3F5F6",
  neutral_2 = "#D9E0E3",
  neutral_3 = "#AAB7BD",
  blue_1 = "#DCEAF3",
  blue_2 = "#A9C9DD",
  blue_3 = "#5D91B3",
  blue_4 = "#2F688C",
  teal_1 = "#DCEEEB",
  teal_2 = "#8FC5BC",
  teal_3 = "#398C83",
  violet_1 = "#E9E5F1",
  violet_2 = "#B7A8D0",
  violet_3 = "#7664A1",
  gold_1 = "#F4E8C7",
  gold_2 = "#D8B86A",
  rust_1 = "#F1DCD5",
  rust_2 = "#CC806B",
  rust_3 = "#9E4F3D",
  dnf = "#4E5B61"
)

model_cols <- c(
  "Kimi K2.6" = "#2F688C",
  "GPT-5.5" = "#398C83",
  "Gemini 3.1 Pro Preview" = "#7664A1",
  "Claude Opus 4.6" = "#B07A32"
)

outcome_cols <- c(
  correct = pal[["blue_3"]],
  wrong = pal[["rust_2"]],
  DNF = pal[["dnf"]],
  unresolved = pal[["neutral_3"]]
)

transition_cols <- c(
  "C→C" = pal[["blue_2"]],
  "W→C" = pal[["teal_3"]],
  "C→W" = pal[["rust_2"]],
  "W→W" = pal[["rust_1"]],
  "Unresolved" = pal[["neutral_3"]]
)

theme_nature_v4 <- function(base_size = 7, base_family = figure_font) {
  theme_classic(base_size = base_size, base_family = base_family) +
    theme(
      text = element_text(colour = pal[["ink"]]),
      axis.line = element_line(linewidth = 0.35, colour = pal[["ink"]]),
      axis.ticks = element_line(linewidth = 0.35, colour = pal[["ink"]]),
      axis.ticks.length = grid::unit(1.5, "pt"),
      axis.title = element_text(size = base_size),
      axis.text = element_text(size = base_size - 0.3, colour = pal[["ink"]]),
      legend.title = element_text(size = base_size - 0.2, face = "bold"),
      legend.text = element_text(size = base_size - 0.5),
      legend.key.height = grid::unit(8, "pt"),
      legend.key.width = grid::unit(10, "pt"),
      legend.spacing.x = grid::unit(3, "pt"),
      strip.background = element_blank(),
      strip.text = element_text(size = base_size, face = "bold"),
      plot.title = element_text(size = base_size + 0.6, face = "bold", hjust = 0),
      plot.subtitle = element_text(size = base_size - 0.1, colour = pal[["ink_mid"]]),
      plot.caption = element_text(size = base_size - 0.8, colour = pal[["ink_mid"]], hjust = 0),
      plot.tag = element_text(size = base_size + 1, face = "bold"),
      plot.tag.position = c(0, 1),
      panel.grid = element_blank(),
      panel.spacing = grid::unit(4, "pt"),
      plot.margin = margin(5, 5, 5, 5, unit = "pt"),
      legend.background = element_blank(),
      legend.box.background = element_blank()
    )
}

theme_set(theme_nature_v4())

fmt_pct <- function(x, digits = 1) {
  paste0(formatC(100 * x, digits = digits, format = "f"), "%")
}

save_pub_r <- function(plot, filename, width_mm = 183, height_mm = 120,
                       png_dpi = 300, tiff_dpi = 600) {
  w <- width_mm / 25.4
  h <- height_mm / 25.4

  svglite::svglite(
    paste0(filename, ".svg"),
    width = w,
    height = h,
    bg = "white",
    system_fonts = list(sans = figure_font)
  )
  print(plot)
  grDevices::dev.off()

  grDevices::cairo_pdf(
    paste0(filename, ".pdf"),
    width = w,
    height = h,
    family = figure_font,
    bg = "white",
    onefile = TRUE
  )
  print(plot)
  grDevices::dev.off()

  ragg::agg_png(
    paste0(filename, ".png"),
    width = w,
    height = h,
    units = "in",
    res = png_dpi,
    background = "white",
    scaling = 1
  )
  print(plot)
  grDevices::dev.off()

  ragg::agg_tiff(
    paste0(filename, ".tiff"),
    width = w,
    height = h,
    units = "in",
    res = tiff_dpi,
    background = "white",
    compression = "lzw",
    scaling = 1
  )
  print(plot)
  grDevices::dev.off()
}

read_public_data <- function(filename) {
  read.csv(
    file.path(public_data_dir, filename),
    check.names = FALSE,
    stringsAsFactors = FALSE,
    na.strings = c("", "NA")
  )
}

write_source_csv <- function(x, path) {
  write.csv(x, path, row.names = FALSE, na = "")
}
