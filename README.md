# OPIHI Sampling Effort & Data Quality (Question B)

OCN 682 / MBIO 612, Fall 2026: AI-Assisted Community Data Sprint
Team B: Manōʻike, Gabby, Tim, Yang An

**Published report:** https://ocn-682-uh.github.io/GroupB_AI_Data_Sprint/opihi_effort_report.html

**Question.** How does sampling effort (survey dates, transects, quadrats) differ among
OPIHI sites and years, which site-years are most complete, and how much coverage is left
as stricter quality filters are applied?

## Repository layout

```
opihi_effort_report.qmd     Quarto report (renders the whole workflow)
scripts/01_build_master.R   raw workbooks -> clean master files + logs
R/import_wide.R             importer for the 2004-2020 column-block workbooks
R/import_long.R             importer for the 2024-2026 row-per-quadrat workbooks
R/clean_helpers.R           site-name normalising, de-identification, unit parsing
R/check_effort.R            reusable function check_effort() + summarise_site_year()
tests/test_check_effort.R   tests for check_effort() on hand-made cases
data/raw/                   original workbooks (NOT in git; see data/raw/README.md)
data/lookup/site_lookup.csv site-name lookup (English/Hawaiian/spelling variants)
data/clean/                 outputs: survey effort table, quadrat master, logs
data/data_dictionary.csv    description of every output column
figures/                    the two report figures (PNG)
AI_developer_log.md         group AI Developer Log
```

## How to reproduce

1. R ≥ 4.3 with: `readxl dplyr tidyr stringr stringi purrr readr ggplot2 forcats knitr kableExtra testthat`
   ```r
   install.packages(c("readxl","tidyverse","stringi","knitr","kableExtra","testthat"))
   ```
2. Copy the 20 original OPIHI `.xlsx` files into `data/raw/` without changing them.
3. Open the project folder in RStudio (or `cd` into it in a terminal) and run:
   ```bash
   Rscript tests/test_check_effort.R      # function tests
   quarto render opihi_effort_report.qmd  # rebuilds data/clean/ and the report
   ```
   All paths are relative to the project root.

## Outputs

| File | Unit | Rows |
|---|---|---|
| `data/clean/opihi_surveys_effort.csv` | one survey (date × site × group) | 275 |
| `data/clean/opihi_quadrats_master.csv` | one quadrat | 7,180 |
| `data/clean/exclusions_log.csv` | each excluded record + reason | 136 |
| `data/clean/duplicates_log.csv` | each removed duplicate + the copy kept | 430 |
| `data/clean/crosscheck_compiled.csv` | raw vs compiled quadrat counts | 225 |

## Using `check_effort()` on new data

```r
source("R/check_effort.R")
new <- readr::read_csv("my_new_surveys.csv")   # needs the columns listed in R/check_effort.R
checked <- check_effort(new, min_completeness = 0.8)
dplyr::count(checked, effort_status)
```

## Data stewardship

* Raw workbooks and the name key (`data/private/`) are git-ignored.
* Schools and data-entry people appear only as codes (`SCH###`, `TM###`). Dr. Philippoff
  receives `data/private/id_key.csv` separately.
* Nothing is deleted from the raw data. Every exclusion and duplicate is logged with its reason.

## Open questions for OPIHI

See section 7 of the report: Wawaloli 2020 quadrat block, Māmala Bay vs Mauliola,
Sandy Beach West, Keiki Bay vs Keiki Ponds, a 2025-03-29 site conflict, and missing
dates/sites in the 2023 and 2025 class worksheets.
