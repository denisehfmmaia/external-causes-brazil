# =============================================================================
# 04_table1.R
# Table 1: contribution of cause groups to the change in life expectancy (LE)
# and lifespan inequality (LI), Brazil, by sex and period.
# Each cell shows: total contribution in the period (contribution per year).
#
# Input : data/processed/contributions.csv, data/processed/levels.csv
# Output: output/tables/Table_1.xlsx
# =============================================================================
source("R/00_setup.R")

contributions <- read_csv(file.path(folder_processed, "contributions.csv"), show_col_types = FALSE)
levels_df     <- read_csv(file.path(folder_processed, "levels.csv"),        show_col_types = FALSE)

# ---- 1. From the 12 causes to the groups shown in Table 1 --------------------
cause_to_group <- c(
  homicide            = "Homicide",
  suicide             = "Suicide",
  transport           = "Transport accidents",
  other_external      = "Other external causes",
  covid19             = "Influenza, pneumonia and COVID-19",
  influenza_pneumonia = "Influenza, pneumonia and COVID-19",
  cardiovascular      = "Chronic NCDs",
  diabetes            = "Chronic NCDs",
  copd                = "Chronic NCDs",
  lung_cancer         = "Chronic NCDs",
  avoidable           = "Avoidable medical-care-related causes",
  other               = "Other causes"
)

row_order <- c("Homicide", "Suicide", "Transport accidents",
               "Selected external causes", "Other external causes",
               "Influenza, pneumonia and COVID-19", "Chronic NCDs",
               "Avoidable medical-care-related causes", "Other causes",
               "Total change")

by_group <- contributions |>
  filter(region == "Brasil") |>
  mutate(group = cause_to_group[cause]) |>
  group_by(sex, indicator, period, period_length, group) |>
  summarise(total = sum(contribution), .groups = "drop")

# "Selected external causes" = homicide + suicide + transport accidents
selected <- by_group |>
  filter(group %in% c("Homicide", "Suicide", "Transport accidents")) |>
  group_by(sex, indicator, period, period_length) |>
  summarise(total = sum(total), .groups = "drop") |>
  mutate(group = "Selected external causes")

# "Total change" = sum of all causes
total <- by_group |>
  group_by(sex, indicator, period, period_length) |>
  summarise(total = sum(total), .groups = "drop") |>
  mutate(group = "Total change")

table1 <- bind_rows(by_group, selected, total) |>
  mutate(per_year  = total / period_length,
         indicator = recode(indicator, e0 = "LE", edagger = "LI"),
         cell      = sprintf("%.2f (%.2f)", total, per_year),
         cell      = str_replace_all(cell, "-0\\.00", "0.00"))   # avoid "-0.00"

# ---- 2. Wide format: one column per period x indicator -----------------------
table1_wide <- table1 |>
  mutate(group = factor(group, levels = row_order),
         sex   = factor(sex,   levels = c("Male", "Female"))) |>
  arrange(period, indicator) |>
  select(sex, group, period, indicator, cell) |>
  pivot_wider(names_from = c(period, indicator), values_from = cell, names_sep = " ") |>
  arrange(sex, group)

print(table1_wide, n = Inf, width = Inf)

# ---- 3. Levels of e0 and e-dagger for Brazil (to quote in the text) ----------
levels_brazil <- levels_df |>
  filter(region == "Brasil") |>
  select(sex, indicator, period, year1, value1, year2, value2, change) |>
  mutate(across(c(value1, value2, change), ~ round(.x, 2)))

print(levels_brazil, n = Inf)

# ---- 4. Save -----------------------------------------------------------------
wb <- createWorkbook()
addWorksheet(wb, "Table_1");        writeData(wb, "Table_1", table1_wide)
addWorksheet(wb, "Table_1_long");   writeData(wb, "Table_1_long", table1)
addWorksheet(wb, "Levels_Brazil");  writeData(wb, "Levels_Brazil", levels_brazil)
saveWorkbook(wb, file.path(folder_tables, "Table_1.xlsx"), overwrite = TRUE)
cat("\nSaved: output/tables/Table_1.xlsx\n")
