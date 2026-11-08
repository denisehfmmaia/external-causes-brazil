# =============================================================================
# 01_prepare_data.R
# The ONLY script that reads the raw data. It creates the processed files
# deposited with the article, so it is needed only to rebuild them.
#
#   (a) SIM deaths -> counts by year, state, sex, age group and cause
#   (b) IBGE life tables -> death rates m(x) and a(x), open age group 85+
#
# Input : data/raw/SIM_UF_1996-2023.csv
#         data/raw/projecoes_2024_tab5_tabuas_mortalidade.xlsx
# Output: data/processed/deaths_by_cause.csv
#         data/processed/deaths_excluded_sex_age.csv
#         data/processed/life_tables.csv
# =============================================================================
source("R/00_setup.R")


# =============================================================================
# PART A — Deaths (SIM)
# =============================================================================

# ---- A1. Read the SIM file ---------------------------------------------------
# Expected columns: ano, causabas, faixa_etaria, sexo, uf_nome_res, N
sim <- read_delim(file_sim, delim = ";", show_col_types = FALSE,
                  locale = locale(encoding = "UTF-8"))

sim <- sim |>
  rename(year = ano, icd = causabas, age_label = faixa_etaria,
         sex = sexo, state = uf_nome_res, deaths = N) |>
  filter(year %in% years)

# ---- A2. Classify causes and age groups --------------------------------------
sim <- sim |>
  mutate(cause = classify_cause(icd, year),
         age   = age_to_group(age_label))

# Check: how each SIM age label was grouped (look at this the first time)
age_check <- sim |> distinct(age_label, age) |> arrange(age)
print(age_check, n = Inf)

# ---- A3. Deaths excluded (sex or age not informed) ---------------------------
# These deaths are left out. Because the decomposition uses the SHARE of each
# cause within each age group, this is the same as distributing them
# proportionally across causes.
sim <- sim |>
  mutate(excluded = !(sex %in% c("Homem", "Mulher")) | is.na(age))

excluded_summary <- sim |>
  group_by(year) |>
  summarise(total_deaths     = sum(deaths),
            excluded_deaths  = sum(deaths[excluded]),
            percent_excluded = round(100 * excluded_deaths / total_deaths, 3))
print(excluded_summary, n = Inf)

# ---- A4. Aggregate -----------------------------------------------------------
deaths <- sim |>
  filter(!excluded) |>
  mutate(sex = recode(sex, Homem = "Male", Mulher = "Female")) |>
  group_by(year, state, sex, age, cause) |>
  summarise(deaths = sum(deaths), .groups = "drop")


# =============================================================================
# PART B — Life tables (IBGE)
# =============================================================================

# ---- B1. Read the IBGE file --------------------------------------------------
# The spreadsheet has title lines above the table. After reading, the 4th row
# of the data frame holds the real column names (LOCAL, SEXO, ANO, IDADE, nMx...).
ibge <- read.xlsx(file_ibge)
names(ibge) <- as.character(unlist(ibge[4, ]))
ibge <- ibge[-(1:4), ]
stopifnot(all(c("LOCAL", "SEXO", "ANO", "IDADE", "nMx", "nAx", "ndx", "nLx") %in% names(ibge)))

# Numbers come as text with decimal comma
numeric_cols <- c("IDADE", "ANO", "nMx", "nqx", "lx", "ndx", "nLx", "Tx", "ex", "nAx")
ibge <- ibge |>
  mutate(across(any_of(numeric_cols), ~ as.numeric(str_replace(.x, ",", ".")))) |>
  filter(ANO %in% years) |>
  mutate(sex = case_when(str_detect(SEXO, regex("^hom", ignore_case = TRUE)) ~ "Male",
                         str_detect(SEXO, regex("^mul", ignore_case = TRUE)) ~ "Female")) |>
  filter(!is.na(sex))   # drops the "both sexes" tables

# ---- B2. Move the open age group from 90+ to 85+ -----------------------------
#   deaths and person-years of 85-89 and 90+ are added,
#   m(85+) = d(85+) / L(85+)  and  a(85+) = 1 / m(85+)
collapse_85 <- function(lt) {
  lt   <- arrange(lt, IDADE)
  old  <- lt |> filter(IDADE >= 85)
  open <- old |> slice(1)
  open$ndx <- sum(old$ndx)
  open$nLx <- sum(old$nLx)
  open$nMx <- open$ndx / open$nLx
  open$nAx <- 1 / open$nMx
  bind_rows(lt |> filter(IDADE < 85), open)
}

life_tables <- ibge |>
  group_by(LOCAL, sex, ANO) |>
  group_modify(~ collapse_85(.x)) |>
  ungroup() |>
  transmute(region = LOCAL, sex, year = as.integer(ANO),
            age = age_to_group(IDADE), mx = nMx, ax = nAx)

# Check: every region x sex x year must have the 19 age groups
n_ages <- count(life_tables, region, sex, year)
stopifnot(all(n_ages$n == length(ages)))

# ---- B3. Keep Brazil and the states, and check that names match the SIM ------
# (IBGE also has the 5 macro-regions, which are not used.)
missing_in_ibge <- setdiff(unique(deaths$state), unique(life_tables$region))
if (length(missing_in_ibge) > 0) {
  stop("State names in the SIM not found in the IBGE file: ",
       paste(missing_in_ibge, collapse = ", "))
}
life_tables <- life_tables |> filter(region %in% c("Brasil", unique(deaths$state)))
cat("\nRegions in the life tables:", length(unique(life_tables$region)),
    "(expected 28: 27 states + Brasil)\n")


# =============================================================================
# Save
# =============================================================================
write_csv(deaths,           file.path(folder_processed, "deaths_by_cause.csv"))
write_csv(excluded_summary, file.path(folder_processed, "deaths_excluded_sex_age.csv"))
write_csv(life_tables,      file.path(folder_processed, "life_tables.csv"))
cat("\nSaved: deaths_by_cause.csv, deaths_excluded_sex_age.csv and life_tables.csv",
    "in data/processed/\n")
