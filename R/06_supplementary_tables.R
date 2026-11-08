# =============================================================================
# 06_supplementary_tables.R
# Supplementary tables by state:
#   Supplementary Table 2 : e0 and e-dagger by state and sex in 2010, 2015,
#                           2019, 2021 and 2023 (each year with its own ax)
#   State results         : contributions by cause, by age group, and levels,
#                           as CSV files (all numbers behind Figures 1-4)
#
# Input : data/processed/life_tables.csv, contributions.csv, levels.csv
# Output: output/tables/Supplementary_Table_2.xlsx
#         output/tables/states_contribution_by_cause.csv
#         output/tables/states_external_by_age.csv
#         output/tables/states_external_by_fine_age.csv
# =============================================================================
source("R/00_setup.R")

life_tables   <- read_csv(file.path(folder_processed, "life_tables.csv"),   show_col_types = FALSE)
contributions <- read_csv(file.path(folder_processed, "contributions.csv"), show_col_types = FALSE)


# ---- 1. Supplementary Table 2: levels of e0 and e-dagger ---------------------
table_years <- c(2010, 2015, 2019, 2021, 2023)

# e0 and e-dagger from one life table
compute_levels <- function(mx, ax) {
  lt <- life_table(mx, ax = fix_ax(ax))
  tibble(e0 = lt$ex[1], edagger = sum(lt$dx * lt$ex))
}

levels_by_year <- life_tables |>
  filter(year %in% table_years) |>
  arrange(region, sex, year, factor(age, levels = ages)) |>
  group_by(region, sex, year) |>
  reframe(compute_levels(mx, ax))

# One row per state x sex, one column per year
supp_table2 <- levels_by_year |>
  mutate(across(c(e0, edagger), ~ round(.x, 2))) |>
  pivot_wider(names_from = year, values_from = c(e0, edagger)) |>
  mutate(sex = factor(sex, levels = c("Male", "Female"))) |>
  arrange(sex, region != "Brasil", region)

# States where e0 fell AND e-dagger rose between 2019 and 2023
worse_in_both <- supp_table2 |>
  filter(region != "Brasil",
         e0_2023 < e0_2019, edagger_2023 > edagger_2019) |>
  select(sex, region, e0_2019, e0_2023, edagger_2019, edagger_2023)
cat("\nStates with lower e0 and higher e-dagger in 2023 than in 2019:\n")
print(worse_in_both, n = Inf)

wb <- createWorkbook()
addWorksheet(wb, "Supplementary_Table_2"); writeData(wb, "Supplementary_Table_2", supp_table2)
saveWorkbook(wb, file.path(folder_tables, "Supplementary_Table_2.xlsx"), overwrite = TRUE)


# ---- 2. Contribution by cause, by state (sum over ages) ----------------------
by_cause <- contributions |>
  group_by(region, sex, period, indicator, cause) |>
  summarise(contribution = sum(contribution), .groups = "drop")

selected <- by_cause |>
  filter(cause %in% selected_external) |>
  group_by(region, sex, period, indicator) |>
  summarise(contribution = sum(contribution), .groups = "drop") |>
  mutate(cause = "selected_external")

total <- by_cause |>
  group_by(region, sex, period, indicator) |>
  summarise(contribution = sum(contribution), .groups = "drop") |>
  mutate(cause = "total")

states_by_cause <- bind_rows(by_cause, selected, total) |>
  mutate(contribution = round(contribution, 4)) |>
  pivot_wider(names_from = indicator, values_from = contribution) |>
  arrange(region, sex, period, cause)

write_csv(states_by_cause, file.path(folder_tables, "states_contribution_by_cause.csv"))


# ---- 3. External causes by age group, by state -------------------------------
external_by_age <- function(breaks) {
  contributions |>
    filter(cause %in% selected_external) |>
    mutate(age_group = broad_age_group(age, breaks = breaks)) |>
    group_by(region, sex, period, indicator, cause, age_group) |>
    summarise(contribution = round(sum(contribution), 4), .groups = "drop") |>
    mutate(age_group = factor(age_group, levels = unique(broad_age_group(ages, breaks)))) |>
    arrange(age_group) |>
    pivot_wider(names_from = age_group, values_from = contribution) |>
    arrange(region, sex, period, indicator, cause)
}

write_csv(external_by_age(c(0, 14, 44, 64, 79)),
          file.path(folder_tables, "states_external_by_age.csv"))
write_csv(external_by_age(c(0, 14, 24, 34, 44, 64, 79)),
          file.path(folder_tables, "states_external_by_fine_age.csv"))

cat("\nSaved: Supplementary_Table_2.xlsx and three CSV files in output/tables/\n")
