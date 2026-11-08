# =============================================================================
# 08_supplementary_figures_1_2.R
# Supplementary Figure 1 : life expectancy at birth (e0) by sex, Brazil, 2010-2023
# Supplementary Figure 2 : lifespan inequality (e-dagger) by sex, Brazil, 2010-2023
#
# Each year is computed from its own IBGE life table (own m(x) and a(x)),
# exactly as in Supplementary Table 2 (06_supplementary_tables.R).
# The values plotted are also saved as a CSV (quoted in the Results).
#
# Input : data/processed/life_tables.csv
# Output: output/figures/Supplementary_Figure_1.png / .pdf
#         output/figures/Supplementary_Figure_2.png / .pdf
#         output/tables/levels_brazil_by_year.csv
# =============================================================================
source("R/00_setup.R")

life_tables <- read_csv(file.path(folder_processed, "life_tables.csv"), show_col_types = FALSE)

# ---- 1. e0 and e-dagger for Brazil, every year --------------------------------
compute_levels <- function(mx, ax) {
  lt <- life_table(mx, ax = fix_ax(ax))
  tibble(e0 = lt$ex[1], edagger = sum(lt$dx * lt$ex))
}

levels_brazil <- life_tables |>
  filter(region == "Brasil") |>
  arrange(sex, year, factor(age, levels = ages)) |>
  group_by(sex, year) |>
  reframe(compute_levels(mx, ax)) |>
  mutate(sex = factor(sex, levels = c("Male", "Female")))

print(levels_brazil |> mutate(across(c(e0, edagger), ~ round(.x, 2))), n = Inf)
write_csv(levels_brazil, file.path(folder_tables, "levels_brazil_by_year.csv"))

# ---- 2. Figures ----------------------------------------------------------------
plot_series <- function(y, y_title) {
  ggplot(levels_brazil, aes(x = year, y = .data[[y]], colour = sex)) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 1.8) +
    scale_x_continuous(breaks = years) +
    scale_colour_manual(values = c(Male = "#1F78B4", Female = "#E31A1C"), name = NULL) +
    labs(x = NULL, y = y_title) +
    theme_minimal(base_size = 10) +
    theme(panel.grid.minor = element_blank(), legend.position = "bottom")
}

save_series <- function(plot, name, width = 7, height = 4) {
  ggsave(file.path(folder_figures, paste0(name, ".png")), plot,
         width = width, height = height, dpi = 300, bg = "white")
  ggsave(file.path(folder_figures, paste0(name, ".pdf")), plot,
         width = width, height = height, bg = "white")
}

save_series(plot_series("e0",      "Life expectancy at birth (years)"), "Supplementary_Figure_1")
save_series(plot_series("edagger", "Lifespan inequality, e-dagger (years)"), "Supplementary_Figure_2")

cat("\nSaved: Supplementary_Figure_1 and Supplementary_Figure_2 in output/figures/,",
    "levels_brazil_by_year.csv in output/tables/\n")
