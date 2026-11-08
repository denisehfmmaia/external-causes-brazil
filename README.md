# External causes of death, life expectancy and lifespan inequality in Brazil, 2010–2023

R code to reproduce the results of:

> Marques DHF, Calazans JA, Aburto JM, Acosta E, Nepomuceno MR. External causes of death,
> life expectancy, and lifespan inequality in Brazil, 2010–2023.
> *Revista Panamericana de Salud Pública / Pan American Journal of Public Health*. 2026. doi: [to be added]

The code decomposes the change in **life expectancy at birth (e0)** and in **lifespan
inequality (life disparity, e†)** by age and cause of death, for Brazil and its 27 states,
by sex, using the method of Horiuchi, Wilmoth & Pletcher (2008).

---

## 1. What you need

- **R** 4.2 or later and, preferably, **RStudio**.
- An internet connection the first time you run the code: the R packages below are
  installed automatically by `R/00_setup.R` if they are missing. You can also install
  them yourself:

```r
install.packages(c("dplyr", "tidyr", "readr", "stringr", "openxlsx",
                   "ggplot2", "DemoDecomp", "future.apply"))
```

That is all. The data used in the article are included in `data/processed/`
(see [`data/processed/README.md`](data/processed/README.md)).

## 2. How to run

1. Download or clone this repository.
2. Open `external-causes-brazil.Rproj` in RStudio (this sets the working folder).
3. Run `run_all.R`.

All results are written to `output/`. The whole analysis takes about 15–30 minutes on a
laptop; most of the time is spent in `03_decompose.R`.

You can also run the scripts one at a time, in numerical order. Each script reads only
files saved by the previous ones, so you can re-run any single step.

### Starting from the raw data (optional)

By default the analysis starts from the processed data deposited with the article, which
reproduces exactly the published results. To rebuild these files from the original SIM and
IBGE data, download the two files described in [`data/raw/README.md`](data/raw/README.md),
put them in `data/raw/`, and set `start_from_raw <- TRUE` in `run_all.R`.
Because the Ministry of Health revises the SIM over time, data downloaded today may give
slightly different numbers.

## 3. What each script does

| Script | What it does | Main output |
|---|---|---|
| `R/00_setup.R` | Packages, folders and parameters (years, periods, age groups, causes). **Change the analysis here.** | — |
| `R/functions.R` | Shared functions: ICD-10 classification, age groups, life table, e0 and e†. | — |
| `R/01_prepare_data.R` | *Only needed to start from the raw data.* Classifies SIM deaths by cause and age group, and reads the IBGE life tables (open age group moved from 90+ to 85+). | `data/processed/deaths_by_cause.csv`, `life_tables.csv`, `deaths_excluded_sex_age.csv` |
| `R/02_build_input.R` | Share of each cause in the deaths of each age group. | `data/processed/cause_shares.csv` |
| `R/03_decompose.R` | Decomposition of the change in e0 and e† by age × cause. | `data/processed/contributions.csv`, `levels.csv` |
| `R/04_table1.R` | Table 1 (Brazil). | `output/tables/Table_1.xlsx` |
| `R/05_figures.R` | Figures 1–4 and Supplementary Figures 3–6. | `output/figures/` |
| `R/06_supplementary_tables.R` | Supplementary Table 2 and all state-level results as CSV. | `output/tables/` |
| `R/07_uncertainty.R` | Monte Carlo 95% intervals (1000 replicates) for the small states (Acre, Amapá, Roraima, Tocantins). | `output/tables/uncertainty_small_states.csv` |
| `R/08_supplementary_figures_1_2.R` | Supplementary Figures 1 and 2: e0 and e† by sex, Brazil, 2010–2023 (each year with its own a(x), as in Supplementary Table 2). | `output/figures/`, `output/tables/levels_brazil_by_year.csv` |
| `R/09_supplementary_table_3.R` | Supplementary Table 3 in the layout of the article ("estimate (lower to upper)"). | `output/tables/Supplementary_Table_3.xlsx` |

## 4. Methods in brief

- **Cause-specific rates.** For each state, sex and year, the all-cause death rate of each age
  group, m(x), comes from the IBGE life table. It is split by cause using the share of each cause
  among the SIM deaths of that age group: m(x, c) = m(x) × D(x, c) / D(x).
  Deaths with unknown sex or age are left out, which is equivalent to distributing them
  proportionally. Age groups with no registered death have their whole rate assigned to
  "other causes".
- **Brazil** uses the IBGE life table for Brazil and the sum of the deaths of the 27 states.
- **Age groups:** 0, 1–4, 5–9, …, 80–84, 85+.
- **Lifespan inequality** is measured by life disparity, e† = Σ d(x) · e(x) (Vaupel et al., 2011).
- **Decomposition:** `DemoDecomp::horiuchi()` with 50 steps. The a(x) values of the first year of
  each period are used in both life tables, so that only the death rates change.
  The sum of the contributions reproduces the observed change (the script prints the residual).
- **Causes of death** (ICD-10 codes in `R/functions.R`, function `classify_cause()`):
  homicide (X85–Y09; legal interventions Y35–Y36 are *not* included), suicide (X60–X84),
  transport accidents (V01–V99), other external causes (rest of chapter XX),
  COVID-19, influenza and pneumonia (J09–J18), cardiovascular diseases, diabetes, COPD,
  lung cancer, avoidable medical-care-related causes, and other causes.

## 5. Folder structure

```
.
├── run_all.R                    runs everything
├── external-causes-brazil.Rproj
├── R/                           analysis scripts
├── data/
│   ├── raw/                     optional: original SIM and IBGE files (not in the repository)
│   └── processed/               data used in the article (included)
└── output/
    ├── tables/
    └── figures/
```

## 6. License and citation

Code released under the MIT License (see `LICENSE`). The processed data derive from public
sources (Ministry of Health/SIM and IBGE). If you use the code or the data, please cite the
article above and the archived version of this repository: doi: [Zenodo DOI to be added].

## 7. Contact

Denise Helena França Marques — Fundação João Pinheiro, Belo Horizonte, Brazil — denise.maia@fjp.mg.gov.br

## References

- Horiuchi S, Wilmoth JR, Pletcher SD. A decomposition method based on a model of continuous change. *Demography*. 2008;45(4):785–801.
- Riffe T. DemoDecomp: Demographic decomposition methods. R package, 2018.
- Vaupel JW, Zhang Z, van Raalte AA. Life expectancy and disparity: an international comparison of life table data. *BMJ Open*. 2011;1:e000128.
