# =============================================================================
# 09_supplementary_table_3.R
# Supplementary Table 3 in the layout of the article: contributions of the
# selected external causes with 95% uncertainty intervals, by state, period,
# cause, sex and indicator. Cells read "estimate (lower to upper)".
#
# Input : output/tables/uncertainty_small_states.csv  (from 07_uncertainty.R)
# Output: output/tables/Supplementary_Table_3.xlsx
#         output/tables/Supplementary_Table_3.csv
# =============================================================================
source("R/00_setup.R")

uncertainty <- read_csv(file.path(folder_tables, "uncertainty_small_states.csv"),
                        show_col_types = FALSE)

cause_labels <- c(selected_external = "Selected external causes", homicide = "Homicide",
                  transport = "Transport accidents", suicide = "Suicide")
period_labels <- sapply(periods, function(p) paste0(p[1], "-", p[2]))

# "estimate (lower to upper)" with 2 decimals and a typographic minus sign
cell <- function(est, lo, hi) {
  x <- sprintf("%.2f (%.2f to %.2f)", est, lo, hi)
  x <- str_replace_all(x, "-0\\.00", "0.00")        # avoid "-0.00"
  str_replace_all(x, "-", "−")
}

supp_table3 <- uncertainty |>
  filter(age_group == "total") |>
  mutate(cell   = cell(estimate, lower_95, upper_95),
         column = paste(ifelse(sex == "Male", "Males", "Females"),
                        ifelse(indicator == "e0", "LE", "LI")),
         Causes = factor(cause_labels[cause], levels = cause_labels),
         Periods = factor(period, levels = period_labels)) |>
  select(State = region, Periods, Causes, column, cell) |>
  pivot_wider(names_from = column, values_from = cell) |>
  arrange(State, Periods, Causes) |>
  select(State, Periods, Causes, `Males LE`, `Males LI`, `Females LE`, `Females LI`)

print(supp_table3, n = Inf, width = Inf)

write_csv(supp_table3, file.path(folder_tables, "Supplementary_Table_3.csv"))
wb <- createWorkbook()
addWorksheet(wb, "Supplementary_Table_3")
writeData(wb, "Supplementary_Table_3", supp_table3)
saveWorkbook(wb, file.path(folder_tables, "Supplementary_Table_3.xlsx"), overwrite = TRUE)
cat("\nSaved: output/tables/Supplementary_Table_3.xlsx and .csv\n")
