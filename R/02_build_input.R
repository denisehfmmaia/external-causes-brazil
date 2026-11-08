# =============================================================================
# 02_build_input.R
# Share of each cause in the deaths of each age group, for each state, Brazil,
# sex and year. In 03_decompose.R these shares split the IBGE all-cause rate:
#
#   m(x, c) = m(x) * share(x, c),   share(x, c) = D(x, c) / D(x)
#
# Input : data/processed/deaths_by_cause.csv
# Output: data/processed/cause_shares.csv
# =============================================================================
source("R/00_setup.R")

deaths <- read_csv(file.path(folder_processed, "deaths_by_cause.csv"),
                   show_col_types = FALSE)

# Brazil = sum of the 27 states
deaths_brazil <- deaths |>
  group_by(year, sex, age, cause) |>
  summarise(deaths = sum(deaths), .groups = "drop") |>
  mutate(state = "Brasil")
deaths <- bind_rows(deaths, deaths_brazil)

cause_shares <- deaths |>
  # add zeros for cause/age combinations with no deaths
  complete(nesting(year, state, sex), age = ages, cause = causes,
           fill = list(deaths = 0)) |>
  group_by(year, state, sex, age) |>
  mutate(share = deaths / sum(deaths)) |>
  mutate(share = replace_na(share, 0)) |>   # 0/0 (age group without deaths) -> 0
  ungroup() |>
  select(region = state, sex, year, age, cause, share)

# Age groups with no deaths at all (all shares = 0).
# In 03_decompose.R their whole rate is attributed to "other".
empty <- cause_shares |>
  group_by(region, sex, year, age) |>
  summarise(total = sum(share), .groups = "drop") |>
  filter(total == 0)
cat("\nAge groups without any death:", nrow(empty), "\n")

write_csv(cause_shares, file.path(folder_processed, "cause_shares.csv"))
cat("\nSaved: data/processed/cause_shares.csv\n")
