# Raw data

**Optional.** These files are needed only to rebuild the processed data from scratch
(`start_from_raw <- TRUE` in `run_all.R`). They are public but are not distributed with the code.

## 1. Deaths — Mortality Information System (SIM), Ministry of Health

**File name expected by the code:** `SIM_UF_1996-2023.csv`

Semicolon-separated (`;`), UTF-8. Deaths registered in the SIM, 1996–2023, aggregated by year,
state of residence, state of occurrence, sex, age group and underlying cause. One row per
combination of the columns below:

| Column | Content | Example |
|---|---|---|
| `ano` | year of death | `2019` |
| `uf_codigo_res`, `uf_nome_res` | state of residence (IBGE code and full name) | `31`, `Minas Gerais` |
| `uf_codigo_ocor`, `uf_nome_ocor` | state of occurrence (not used) | `31`, `Minas Gerais` |
| `sexo` | `Homem`, `Mulher`, `Ignorado` or empty | `Homem` |
| `faixa_etaria` | lower bound of the age group: `0`, `1`, `5`, `10`, …, `80`, `85` (85 or more); empty = unknown | `20` |
| `causabas` | underlying cause of death, ICD-10, as in the SIM (without the dot) | `X954` |
| `N` | number of deaths | `12` |

Only `ano`, `uf_nome_res`, `sexo`, `faixa_etaria`, `causabas` and `N` are used. Deaths with sex
`Ignorado`/empty or unknown age are excluded (see `data/processed/deaths_excluded_sex_age.csv`).

Source: SIM microdata, Ministry of Health (DATASUS), available at
<https://opendatasus.saude.gov.br/dataset/sim>. The file was built by aggregating the individual
death records by the columns above.

<!-- TODO (Denise): add the download date of the SIM microdata. -->

## 2. Life tables — IBGE, population projections (2024 revision)

**File name expected by the code:** `projecoes_2024_tab5_tabuas_mortalidade.xlsx`

Life tables by state, sex and single year (2000–2070), with open age group 90+.

Source: IBGE, *Projeções da população do Brasil e das Unidades da Federação*, revisão 2024,
<https://www.ibge.gov.br/estatisticas/sociais/populacao/9109-projecao-da-populacao.html>.

<!-- TODO (Denise): add the download date of the IBGE file. -->
