# =============================================================================
# 03_decompose.R
# Decomposes the change in life expectancy at birth, e(0), and in lifespan
# inequality (life disparity, e-dagger) between two years by age and cause,
# using the line-integral method of Horiuchi, Wilmoth & Pletcher (2008),
# as implemented in DemoDecomp::horiuchi().
#
# Runs for Brazil and the 27 states, males and females, and all `periods`.
# This is the slow step (it can take about an hour).
#
# Input : data/processed/life_tables.csv
#         data/processed/cause_shares.csv
# Output: data/processed/contributions.csv  (region x sex x period x indicator x age x cause)
#         data/processed/levels.csv         (e0 and e-dagger at start and end of each period)
# =============================================================================
source("R/00_setup.R")

life_tables  <- read_csv(file.path(folder_processed, "life_tables.csv"),  show_col_types = FALSE)
cause_shares <- read_csv(file.path(folder_processed, "cause_shares.csv"), show_col_types = FALSE)


# -----------------------------------------------------------------------------
# cause_rates(): matrix of cause-specific death rates m(x, c) for one
# region, sex and year. Rows = 19 ages, columns = causes.
#   m(x, c) = m(x) from IBGE  x  share of cause c at age x from SIM
# -----------------------------------------------------------------------------
cause_rates <- function(reg, sx, yr) {
  lt <- life_tables |>
    filter(region == reg, sex == sx, year == yr) |>
    arrange(factor(age, levels = ages))

  shares <- cause_shares |>
    filter(region == reg, sex == sx, year == yr) |>
    select(age, cause, share) |>
    pivot_wider(names_from = cause, values_from = share) |>
    arrange(factor(age, levels = ages))

  share_matrix <- as.matrix(shares[, causes])

  # age groups without deaths in the SIM: whole rate goes to "other"
  no_deaths <- rowSums(share_matrix) == 0
  share_matrix[no_deaths, ]        <- 0
  share_matrix[no_deaths, "other"] <- 1

  list(rates = share_matrix * lt$mx,   # each row multiplied by m(x)
       ax    = fix_ax(lt$ax))
}


# ---- Loop over region x sex x period -----------------------------------------
regions <- intersect(unique(life_tables$region), unique(cause_shares$region))
cat("Regions:", length(regions), "(expected 28: 27 states + Brasil)\n")

all_contributions <- list()
all_levels        <- list()
start_time <- Sys.time()

for (reg in regions) {
  cat("Decomposing:", reg, "\n")

  for (sx in c("Male", "Female")) {
    for (p in periods) {
      year1 <- p[1]
      year2 <- p[2]
      period_label <- paste0(year1, "-", year2)

      m1 <- cause_rates(reg, sx, year1)
      m2 <- cause_rates(reg, sx, year2)

      # NOTE: the ax of the FIRST year is used for both years, so that only
      # the death rates change between the two life tables. Because of this,
      # the end-of-period level below can differ slightly (usually in the
      # 2nd decimal) from the value computed with that year's own ax.
      ax <- m1$ax

      for (indicator in c("e0", "edagger")) {
        if (indicator == "e0") f <- e0_from_rates else f <- edagger_from_rates

        value1 <- f(as.vector(m1$rates), ax = ax)
        value2 <- f(as.vector(m2$rates), ax = ax)

        contrib <- horiuchi(func  = f,
                            pars1 = as.vector(m1$rates),
                            pars2 = as.vector(m2$rates),
                            N     = n_horiuchi,
                            ax    = ax)

        # horiuchi() returns one number per age x cause, in the same order as
        # as.vector(): all ages of the 1st cause, then all ages of the 2nd, ...
        all_contributions[[length(all_contributions) + 1]] <- tibble(
          region = reg, sex = sx, period = period_label,
          period_length = year2 - year1, indicator = indicator,
          age   = rep(ages,   times = length(causes)),
          cause = rep(causes, each  = length(ages)),
          contribution = contrib
        )

        all_levels[[length(all_levels) + 1]] <- tibble(
          region = reg, sex = sx, period = period_label, indicator = indicator,
          year1 = year1, value1 = value1, year2 = year2, value2 = value2,
          change = value2 - value1,
          sum_contributions = sum(contrib),
          residual = sum(contrib) - (value2 - value1)
        )
      }
    }
  }
}

cat("Time:", round(difftime(Sys.time(), start_time, units = "mins"), 1), "minutes\n")

contributions <- bind_rows(all_contributions)
levels_df     <- bind_rows(all_levels)

# ---- Check: the contributions must add up to the observed change -------------
cat("\nLargest |sum of contributions - observed change| (should be close to 0):\n")
print(levels_df |> group_by(indicator) |> summarise(max_residual = max(abs(residual))))

# ---- Save --------------------------------------------------------------------
write_csv(contributions, file.path(folder_processed, "contributions.csv"))
write_csv(levels_df,     file.path(folder_processed, "levels.csv"))
cat("\nSaved: data/processed/contributions.csv and levels.csv\n")
