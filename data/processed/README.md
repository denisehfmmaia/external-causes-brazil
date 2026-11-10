# Processed data deposited with the article

These three files are the exact data used in the article. They were created by
`R/01_prepare_data.R` from the raw files described in `data/raw/README.md`.
With them, the whole analysis can be reproduced without downloading anything:
just run `run_all.R` (it starts from these files by default).

The SIM database is revised by the Ministry of Health over time, so the raw data
downloaded today may give slightly different numbers. Use these files to obtain
exactly the published results.

## deaths_by_cause.csv

Registered deaths by year, state of residence, sex, age group and cause.
Deaths with unknown sex or age are not included.

| Column | Content |
|---|---|
| `year` | year of death (2010–2023) |
| `state` | state of residence |
| `sex` | `Male` or `Female` |
| `age` | age group: `0`, `1-4`, `5-9`, …, `80-84`, `85+` |
| `cause` | cause group (ICD-10 codes in `R/functions.R`, function `classify_cause()`) |
| `deaths` | number of deaths |

## life_tables.csv

Death rates and a(x) from the IBGE life tables (2024 revision), with the open
age group moved from 90+ to 85+.

| Column | Content |
|---|---|
| `region` | `Brasil` or one of the 27 states |
| `sex` | `Male` or `Female` |
| `year` | 2010–2023 |
| `age` | age group: `0`, `1-4`, `5-9`, …, `80-84`, `85+` |
| `mx` | all-cause death rate |
| `ax` | average years lived in the age group by those who die in it |

## deaths_excluded_sex_age.csv

Number and percentage of SIM deaths left out each year because sex or age was
not informed (reported in the Methods).

| Column | Content |
|---|---|
| `year` | year of death |
| `total_deaths` | all registered deaths |
| `excluded_deaths` | deaths with unknown sex or age |
| `percent_excluded` | `excluded_deaths / total_deaths × 100` |

## Sources and download dates

- SIM (Ministry of Health/DATASUS) microdata.
- IBGE life tables, population projections (2024 revision).

<!-- TODO (Denise): add the download dates of the SIM and IBGE files. -->

See `data/raw/README.md` for the description of the raw files.
