# Raw data

**Optional.** These files are needed only to rebuild the processed data from scratch
(`start_from_raw <- TRUE` in `run_all.R`). They are public but are not distributed with the code.

## 1. Deaths — Mortality Information System (SIM), Ministry of Health

**File name expected by the code:** `SIM_UF_1996-2023.csv`

Semicolon-separated (`;`), UTF-8, one row per combination of the columns below:

| Column | Content | Example |
|---|---|---|
| `ano` | year of death | `2019` |
| `causabas` | underlying cause of death, ICD-10 (as in the SIM, without the dot) | `X954` |
| `faixa_etaria` | age group label | `Menor 1 ano`, `1 a 4 anos`, `85 a 89 anos`, `90 anos e mais` |
| `sexo` | `Homem`, `Mulher` (other values are treated as unknown) | `Homem` |
| `uf_nome_res` | state of residence, full name as in the IBGE tables | `Minas Gerais` |
| `N` | number of deaths | `12` |

Source: SIM microdata, available at <https://opendatasus.saude.gov.br/dataset/sim>.

<!-- TODO (Denise): describe here how this file was built from the microdata
     (download date, filters, tool used) or add the script that builds it. -->

## 2. Life tables — IBGE, population projections (2024 revision)

**File name expected by the code:** `projecoes_2024_tab5_tabuas_mortalidade.xlsx`

Life tables by state, sex and single year (2000–2070), with open age group 90+.

Source: IBGE, *Projeções da população do Brasil e das Unidades da Federação*, revisão 2024,
<https://www.ibge.gov.br/estatisticas/sociais/populacao/9109-projecao-da-populacao.html>.

<!-- TODO (Denise): add the download date and the exact link of the file. -->
