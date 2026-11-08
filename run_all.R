# =============================================================================
# run_all.R
# Runs the whole analysis and creates all tables and figures in output/.
# Open external-causes-brazil.Rproj in RStudio and run this file.
#
# Two ways to run:
#
#   start_from_raw <- FALSE  (default)
#     Uses the processed data deposited with the article (data/processed/).
#     Nothing to download. Reproduces exactly the published results.
#
#   start_from_raw <- TRUE
#     Rebuilds the processed data from the raw SIM and IBGE files.
#     You must first put the raw files in data/raw/ (see data/raw/README.md).
#     The SIM is revised over time, so results may differ slightly.
# =============================================================================

start_from_raw <- FALSE

if (start_from_raw) {
  source("R/01_prepare_data.R")         # reads SIM and IBGE raw files   (~ 2 min)
}
source("R/02_build_input.R")            # cause shares                   (~ 1 min)
source("R/03_decompose.R")              # decompositions                 (~ 15 min)
source("R/04_table1.R")                 # Table 1
source("R/05_figures.R")                # Figures 1-4, Suppl. Figures 3-6
source("R/06_supplementary_tables.R")   # Suppl. Table 2 and state tables
source("R/07_uncertainty.R")            # Monte Carlo intervals          (~ 4 min)
source("R/08_supplementary_figures_1_2.R") # Suppl. Figures 1-2 (e0 and e-dagger, Brazil, 2010-2023)
source("R/09_supplementary_table_3.R")  # Suppl. Table 3 in the layout of the article

# Package versions used in this run (useful when reporting problems)
writeLines(capture.output(sessionInfo()), "output/sessionInfo.txt")
