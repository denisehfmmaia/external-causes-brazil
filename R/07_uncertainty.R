# =============================================================================
# 07_uncertainty.R
# 95% uncertainty intervals for the contributions of homicide, transport
# accidents and suicide in the small states (Acre, Amapá, Roraima, Tocantins).
#
# Method (Monte Carlo):
#   1. In each replicate, the deaths D(x, c) of each year are drawn from a
#      Poisson distribution with mean equal to the observed number.
#   2. The cause shares are recomputed and applied to the IBGE rates m(x),
#      exactly as in 03_decompose.R:  m*(x, c) = m(x) * D*(x, c) / D*(x)
#   3. The decomposition is repeated.
#   The 95% interval is given by the 2.5th and 97.5th percentiles of the
#   replicates. The IBGE life table is treated as fixed.
#
# To make it faster, all causes other than the three external causes are
# merged into one group ("rest"). This does NOT change the contributions of
# the three external causes, because e0 and e-dagger depend only on the total
# rate at each age (the script checks this against 03_decompose.R).
# The decomposition itself uses decompose_both() (R/functions.R), which gives
# the same numbers as DemoDecomp::horiuchi() for e0 and e-dagger together,
# about 14 times faster. 1000 replicates take about 4 minutes (200 take 1-2).
#
# Input : data/processed/deaths_by_cause.csv, life_tables.csv, contributions.csv
# Output: output/tables/uncertainty_small_states.csv
# =============================================================================
source("R/00_setup.R")
library(future.apply)   # runs the replicates in parallel

# ---- Parameters --------------------------------------------------------------
n_replicates   <- 1000  # Monte Carlo replicates (about 4 minutes; 200 take 1-2)
states_uncert  <- c("Acre", "Amap\u00e1", "Roraima", "Tocantins")   # "Amap\u00e1" = Amapá, written this way so it works on any computer
groups_uncert  <- c(selected_external, "rest")
set.seed(20261026)

deaths      <- read_csv(file.path(folder_processed, "deaths_by_cause.csv"), show_col_types = FALSE)
life_tables <- read_csv(file.path(folder_processed, "life_tables.csv"),     show_col_types = FALSE)


# ---- Helper functions --------------------------------------------------------

# Matrix of deaths: rows = 19 ages, columns = homicide, suicide, transport, rest
death_matrix <- function(st, sx, yr) {
  deaths |>
    filter(state == st, sex == sx, year == yr) |>
    mutate(group = ifelse(cause %in% selected_external, cause, "rest")) |>
    group_by(age, group) |>
    summarise(deaths = sum(deaths), .groups = "drop") |>
    complete(age = ages, group = groups_uncert, fill = list(deaths = 0)) |>
    pivot_wider(names_from = group, values_from = deaths) |>
    arrange(factor(age, levels = ages)) |>
    select(all_of(groups_uncert)) |>
    as.matrix()
}

# IBGE rates m(x) and ax for one state, sex and year
ibge_rates <- function(st, sx, yr) {
  lt <- life_tables |>
    filter(region == st, sex == sx, year == yr) |>
    arrange(factor(age, levels = ages))
  list(mx = lt$mx, ax = fix_ax(lt$ax))
}

# From deaths to cause-specific rates (same rule as 03_decompose.R)
deaths_to_rates <- function(D, mx) {
  no_deaths <- rowSums(D) == 0
  D[no_deaths, ]       <- 0
  D[no_deaths, "rest"] <- 1
  (D / rowSums(D)) * mx
}

# Decomposes e0 and e-dagger at once and returns the contributions we want to
# keep: each external cause (total over ages), their sum, and each cause by
# age group. Names are "indicator|cause|age_group".
decompose_external <- function(rates1, rates2, ax) {
  both      <- decompose_both(rates1, rates2, N = n_horiuchi, ax = ax)
  age_group <- broad_age_group(ages)

  keep <- function(contrib, indicator) {
    dimnames(contrib) <- list(ages, groups_uncert)
    contrib <- contrib[, selected_external]
    by_age  <- rowsum(contrib, age_group)   # sums the rows of each age group

    c(setNames(colSums(contrib), paste0(indicator, "|", selected_external, "|total")),
      setNames(sum(contrib),     paste0(indicator, "|selected_external|total")),
      setNames(as.vector(by_age),
               paste0(indicator, "|", rep(colnames(by_age), each = nrow(by_age)), "|", rownames(by_age))))
  }
  c(keep(both$e0, "e0"), keep(both$edagger, "edagger"))
}

# Point estimate + Monte Carlo interval for one state, sex and period
run_one <- function(st, sx, p) {
  year1 <- p[1]; year2 <- p[2]
  D1 <- death_matrix(st, sx, year1); D2 <- death_matrix(st, sx, year2)
  r1 <- ibge_rates(st, sx, year1);   r2 <- ibge_rates(st, sx, year2)

  point <- decompose_external(deaths_to_rates(D1, r1$mx), deaths_to_rates(D2, r2$mx), r1$ax)

  # Poisson draw with the same shape (and names) as the observed matrix
  draw <- function(D) matrix(rpois(length(D), D), nrow = nrow(D), dimnames = dimnames(D))

  replicates <- replicate(n_replicates,
    decompose_external(deaths_to_rates(draw(D1), r1$mx),
                       deaths_to_rates(draw(D2), r2$mx), r1$ax))

  tibble(region = st, sex = sx, period = paste0(year1, "-", year2),
         measure = names(point),
         estimate = point,
         lower_95 = apply(replicates, 1, quantile, 0.025),
         upper_95 = apply(replicates, 1, quantile, 0.975),
         share_same_sign = rowMeans(sign(replicates) == sign(point)))
}


# ---- Run ---------------------------------------------------------------------
combinations <- expand_grid(state = states_uncert, sex = c("Male", "Female"),
                            p = seq_along(periods))
cat("Combinations:", nrow(combinations), "x", n_replicates, "replicates (e0 and e-dagger together)\n")

# Uses all processor cores but one. To run without parallel: plan(sequential)
plan(multisession, workers = max(1, parallelly::availableCores() - 1))
start_time <- Sys.time()

results <- future_lapply(seq_len(nrow(combinations)), function(i) {
  run_one(combinations$state[i], combinations$sex[i], periods[[combinations$p[i]]])
}, future.seed = TRUE)

plan(sequential)
cat("Time:", round(difftime(Sys.time(), start_time, units = "mins"), 1), "minutes\n")

uncertainty <- bind_rows(results) |>
  separate(measure, into = c("indicator", "cause", "age_group"), sep = "\\|") |>
  mutate(across(c(estimate, lower_95, upper_95), ~ round(.x, 4)),
         excludes_zero = lower_95 > 0 | upper_95 < 0)


# ---- Check: point estimates must match 03_decompose.R ------------------------
contributions <- read_csv(file.path(folder_processed, "contributions.csv"), show_col_types = FALSE)

reference <- contributions |>
  filter(region %in% states_uncert, cause %in% selected_external) |>
  group_by(region, sex, period, indicator, cause) |>
  summarise(reference = sum(contribution), .groups = "drop")

check <- uncertainty |>
  filter(age_group == "total", cause %in% selected_external) |>
  left_join(reference, by = c("region", "sex", "period", "indicator", "cause"))

cat("Largest difference from 03_decompose.R:",
    signif(max(abs(check$estimate - check$reference)), 3), "\n")
stopifnot(max(abs(check$estimate - check$reference)) < 1e-3)

write_csv(uncertainty, file.path(folder_tables, "uncertainty_small_states.csv"))
cat("\nSaved: output/tables/uncertainty_small_states.csv\n")
