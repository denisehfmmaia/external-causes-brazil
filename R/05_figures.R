# =============================================================================
# 05_figures.R
# Figures of the article (all by state):
#   Figure 1  / Suppl. Figure 3 : contributions of causes to the change in e0
#                                 (males / females)
#   Figure 2  / Suppl. Figure 4 : same for lifespan inequality (e-dagger)
#   Figure 3, Figure 4, Suppl. Figure 5 : contribution of homicide, transport
#                                 accidents and suicide to the change in
#                                 e-dagger, by age group (males)
#   Suppl. Figure 6 : homicide, with ages 15-44 split into 15-24, 25-34, 35-44
#
# Input : data/processed/contributions.csv
# Output: output/figures/*.png and *.pdf
# =============================================================================
source("R/00_setup.R")

contributions <- read_csv(file.path(folder_processed, "contributions.csv"), show_col_types = FALSE)

# States only (Brazil is in Table 1)
states <- contributions |> filter(region != "Brasil")

# Periods in chronological order (for the panels)
period_labels <- sapply(periods, function(p) paste0(p[1], "-", p[2]))
states <- states |> mutate(period = factor(period, levels = period_labels))


# ---- Names and colours of the causes -----------------------------------------
cause_labels <- c(
  homicide = "Homicides", transport = "Transport accidents", suicide = "Suicide",
  other_external = "Other external causes",
  influenza_pneumonia = "Influenza and pneumonia", covid19 = "COVID-19",
  cardiovascular = "Cardiovascular diseases", diabetes = "Diabetes",
  copd = "COPD", lung_cancer = "Lung cancer",
  avoidable = "Avoidable medical-care-related causes", other = "Other causes"
)
cause_colours <- c(
  "Homicides" = "#FB9A99", "Transport accidents" = "#FDBF6F", "Suicide" = "#CCEBC5",
  "Other external causes" = "#B15928", "Influenza and pneumonia" = "#B2DF8A",
  "COVID-19" = "#1F78B4", "Cardiovascular diseases" = "#CAB2D6", "Diabetes" = "#FFFF99",
  "COPD" = "#FCCDE5", "Lung cancer" = "#8DA0CB",
  "Avoidable medical-care-related causes" = "#A6CEE3", "Other causes" = "#D9D9D9"
)

# Common look of all figures
my_theme <- theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(),
        legend.position  = "bottom",
        strip.text       = element_text(face = "bold", hjust = 0, size = 11),
        plot.caption     = element_text(hjust = 0, face = "italic", size = 8))

# Saves each figure as PNG (300 dpi) and PDF
save_figure <- function(plot, name, width = 11, height = 12) {
  ggsave(file.path(folder_figures, paste0(name, ".png")), plot,
         width = width, height = height, dpi = 300, bg = "white")
  ggsave(file.path(folder_figures, paste0(name, ".pdf")), plot,
         width = width, height = height, bg = "white")
}


# =============================================================================
# PART 1 — Figures 1, 2 and Suppl. Figures 3, 4: all causes, by state
# =============================================================================
plot_causes_by_state <- function(ind, sx) {

  data_plot <- states |>
    filter(indicator == ind, sex == sx) |>
    group_by(region, period, cause) |>
    summarise(value = sum(contribution), .groups = "drop") |>
    mutate(cause_label = factor(cause_labels[cause], levels = names(cause_colours)))

  # States ordered by the contribution of the 3 external causes in the 1st period
  state_order <- data_plot |>
    filter(period == period_labels[1], cause %in% selected_external) |>
    group_by(region) |>
    summarise(order = sum(value)) |>
    arrange(order) |>
    pull(region)
  data_plot <- data_plot |> mutate(region = factor(region, levels = state_order))

  # Total change (black dots)
  totals <- data_plot |>
    group_by(region, period) |>
    summarise(value = sum(value), .groups = "drop")

  x_title <- ifelse(ind == "e0",
                    "Contribution to change in life expectancy at birth (years)",
                    "Contribution to change in lifespan inequality (years)")

  ggplot(data_plot, aes(x = value, y = region)) +
    geom_col(aes(fill = cause_label), width = 0.8) +
    geom_vline(xintercept = 0, linewidth = 0.3) +
    geom_point(data = totals, size = 1.6, colour = "grey15") +
    facet_wrap(~ period, ncol = 2) +
    scale_fill_manual(values = cause_colours, drop = FALSE, name = NULL) +
    guides(fill = guide_legend(nrow = 3)) +
    labs(x = x_title, y = NULL, caption = "Dots show the total change.") +
    my_theme
}

save_figure(plot_causes_by_state("e0",      "Male"),   "Figure_1")
save_figure(plot_causes_by_state("edagger", "Male"),   "Figure_2")
save_figure(plot_causes_by_state("e0",      "Female"), "Supplementary_Figure_3")
save_figure(plot_causes_by_state("edagger", "Female"), "Supplementary_Figure_4")


# =============================================================================
# PART 2 — Figures 3, 4 and Suppl. Figure 5: external causes by age (males)
# =============================================================================
age_colours <- c("0" = "#1B9E77", "1-14" = "#D95F02", "15-44" = "#7570B3",
                 "45-64" = "#E7298A", "65-79" = "#66A61E", "80+" = "#E6AB02")

by_age <- states |>
  filter(indicator == "edagger", sex == "Male", cause %in% selected_external) |>
  mutate(age_group = broad_age_group(age)) |>
  group_by(region, period, cause, age_group) |>
  summarise(value = sum(contribution), .groups = "drop")

# Same x-axis limits for the three causes, so that they can be compared.
# Stacked bars: the limit is the largest sum of positive (or negative) parts.
bar_ends <- by_age |>
  group_by(region, period, cause) |>
  summarise(positive = sum(value[value > 0]),
            negative = sum(value[value < 0]), .groups = "drop")
x_limit <- ceiling(max(abs(c(bar_ends$positive, bar_ends$negative))) * 10) / 10

plot_by_age <- function(data_plot, colours, caption) {
  # States ordered by the total contribution in the 1st period
  state_order <- data_plot |>
    filter(period == period_labels[1]) |>
    group_by(region) |>
    summarise(order = sum(value)) |>
    arrange(order) |>
    pull(region)

  data_plot <- data_plot |>
    mutate(region    = factor(region, levels = state_order),
           age_group = factor(age_group, levels = names(colours)))

  ggplot(data_plot, aes(x = value, y = region, fill = age_group)) +
    geom_col(width = 0.8) +
    geom_vline(xintercept = 0, linewidth = 0.3) +
    facet_wrap(~ period, ncol = 4) +
    scale_x_continuous(limits = c(-x_limit, x_limit)) +
    scale_fill_manual(values = colours, name = "Age group", drop = FALSE) +
    labs(x = "Contribution to change in lifespan inequality (years)", y = NULL,
         caption = caption) +
    my_theme
}

caption_age <- "The x-axis scale is the same for all causes and periods."
save_figure(plot_by_age(filter(by_age, cause == "homicide"),  age_colours, caption_age),
            "Figure_3", width = 14, height = 7)
save_figure(plot_by_age(filter(by_age, cause == "transport"), age_colours, caption_age),
            "Figure_4", width = 14, height = 7)
save_figure(plot_by_age(filter(by_age, cause == "suicide"),   age_colours, caption_age),
            "Supplementary_Figure_5", width = 14, height = 7)


# =============================================================================
# PART 3 — Suppl. Figure 6: homicide with finer age groups (males)
# =============================================================================
fine_colours <- c("0" = "#1B9E77", "1-14" = "#D95F02",
                  "15-24" = "#3F007D", "25-34" = "#7570B3", "35-44" = "#BCBDDC",
                  "45-64" = "#E7298A", "65-79" = "#66A61E", "80+" = "#E6AB02")

homicide_fine <- states |>
  filter(indicator == "edagger", sex == "Male", cause == "homicide") |>
  mutate(age_group = broad_age_group(age, breaks = c(0, 14, 24, 34, 44, 64, 79))) |>
  group_by(region, period, cause, age_group) |>
  summarise(value = sum(contribution), .groups = "drop")

# Check: 15-24 + 25-34 + 35-44 must equal 15-44 in Figure 3
check <- homicide_fine |>
  filter(age_group %in% c("15-24", "25-34", "35-44")) |>
  group_by(region, period) |>
  summarise(fine = sum(value), .groups = "drop") |>
  left_join(by_age |> filter(cause == "homicide", age_group == "15-44"),
            by = c("region", "period"))
stopifnot(max(abs(check$fine - check$value)) < 1e-8)

save_figure(plot_by_age(homicide_fine, fine_colours,
                        "The x-axis scale is the same as in Figure 3."),
            "Supplementary_Figure_6", width = 14, height = 7)

cat("\nSaved: figures in output/figures/\n")
