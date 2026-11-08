# =============================================================================
# 00_setup.R
# Packages, folders and analysis parameters.
#
# Every other script starts with  source("R/00_setup.R")
# Open the project file (external-causes-brazil.Rproj) before running anything,
# so that all paths below are relative to the project folder.
# =============================================================================

# ---- 1. Packages -------------------------------------------------------------
# Packages that are not installed yet are installed automatically (once).
packages <- c("dplyr", "tidyr", "readr", "stringr", "openxlsx",
              "ggplot2", "DemoDecomp", "future.apply")
missing_packages <- packages[!packages %in% rownames(installed.packages())]
if (length(missing_packages) > 0) {
  cat("Installing missing packages:", paste(missing_packages, collapse = ", "), "\n")
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(openxlsx)    # reads the IBGE life tables (.xlsx)
  library(ggplot2)     # figures
  library(DemoDecomp)  # horiuchi() decomposition (Riffe, 2018)
})

# ---- 2. Folders --------------------------------------------------------------
folder_raw       <- "data/raw"        # original files (you download them; see data/raw/README.md)
folder_processed <- "data/processed"  # created by the scripts
folder_tables    <- "output/tables"
folder_figures   <- "output/figures"

dir.create(folder_processed, showWarnings = FALSE, recursive = TRUE)
dir.create(folder_tables,    showWarnings = FALSE, recursive = TRUE)
dir.create(folder_figures,   showWarnings = FALSE, recursive = TRUE)

# ---- 3. Input files ----------------------------------------------------------
# Deaths from the Mortality Information System (SIM), one row per
# year x state x sex x age group x underlying cause (ICD-10), with a count N.
file_sim  <- file.path(folder_raw, "SIM_UF_1996-2023.csv")

# IBGE life tables by state and sex (2024 revision of the population projections)
file_ibge <- file.path(folder_raw, "projecoes_2024_tab5_tabuas_mortalidade.xlsx")

# ---- 4. Analysis parameters --------------------------------------------------
years <- 2010:2023

# Periods of the decomposition (start year, end year)
periods <- list(
  c(2010, 2015),
  c(2015, 2019),
  c(2019, 2021),   # pandemic shock
  c(2021, 2023)    # recovery
)

# Number of steps in the Horiuchi et al. (2008) line-integral decomposition
n_horiuchi <- 50

# 19 age groups: 0, 1-4, 5-9, ..., 80-84, 85+ (open age group)
ages <- c("0", "1-4", paste0(seq(5, 80, 5), "-", seq(9, 84, 5)), "85+")

# Width of each age group in years (NA = open age group)
age_width <- c(1, 4, rep(5, 16), NA)

# Causes of death used in the decomposition (see R/functions.R for ICD-10 codes)
causes <- c("homicide", "suicide", "transport", "other_external",
            "covid19", "influenza_pneumonia",
            "cardiovascular", "diabetes", "copd", "lung_cancer",
            "avoidable", "other")

# The three external causes analysed in the article
selected_external <- c("homicide", "suicide", "transport")

# ---- 5. Our own functions ----------------------------------------------------
source("R/functions.R")
