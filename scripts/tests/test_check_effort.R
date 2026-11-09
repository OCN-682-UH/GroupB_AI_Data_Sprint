# Tests for check_effort() ---------------------------------------------------
# Run from the project root:  Rscript tests/test_check_effort.R
# Each case is a small hand-made survey whose correct answer we know.

suppressPackageStartupMessages({
  library(dplyr); library(testthat)
  source("R/check_effort.R")
})

toy <- tibble::tribble(
  ~survey_id, ~date,                ~site_std,  ~team_id, ~n_transects_recorded, ~quad_per_transect_recorded, ~n_quadrats_observed, ~start_time, ~stop_time,
  "ok",       as.Date("2019-05-01"), "Mauliola", "A",      4,                     10,                          40,                   "09:00",     "10:30",
  "half",     as.Date("2019-05-02"), "Mauliola", "A",      4,                     10,                          20,                   "09:00",     "10:30",
  "nodata",   as.Date("2019-05-03"), "Lēʻahi",   "B",      4,                     10,                          NA,                   "09:00",     "10:30",
  "nometa",   as.Date("2019-05-04"), "Lēʻahi",   "B",      NA,                    10,                          30,                   "09:00",     "10:30",
  "excel_qt", as.Date("2024-02-10"), "ʻEwa Beach","C",     4,                     45576,                       40,                   "09:00",     "10:30",
  "future",   as.Date("2099-01-01"), "ʻEwa Beach","C",     4,                     10,                          40,                   "00:00",     "01:00",
  "dup1",     as.Date("2018-03-01"), "Kalaeloa", "D",      2,                     10,                          20,                   "09:00",     "10:00",
  "dup2",     as.Date("2018-03-01"), "Kalaeloa", "D",      2,                     10,                          20,                   "09:00",     "10:00"
)

res <- check_effort(toy)
get <- function(id, col) res[[col]][res$survey_id == id]

test_that("completeness is observed / (transects x quadrats per transect)", {
  expect_equal(get("ok", "planned_quadrats"), 40)
  expect_equal(get("ok", "completeness"), 1)
  expect_equal(get("half", "completeness"), 0.5)
})

test_that("each rule fires on the case built for it, and only there", {
  expect_equal(get("ok", "effort_status"), "complete")
  expect_equal(get("ok", "n_flags"), 0)
  expect_equal(get("half", "effort_status"), "incomplete")
  expect_equal(get("nodata", "effort_status"), "no_quadrat_data")
  expect_true(get("nometa", "flag_missing_effort_meta"))
  expect_true(get("excel_qt", "flag_implausible_qpt"))     # Excel turned "10-12" into a date
  expect_true(get("future", "flag_date_out_of_range"))
  expect_true(get("future", "flag_placeholder_time"))
  expect_true(all(res$flag_duplicate_survey[res$survey_id %in% c("dup1", "dup2")]))
  expect_false(get("ok", "flag_duplicate_survey"))
})

test_that("thresholds are adjustable", {
  loose <- check_effort(toy, min_completeness = 0.4)
  expect_equal(loose$effort_status[loose$survey_id == "half"], "complete")
})

test_that("bad input fails loudly", {
  expect_error(check_effort(select(toy, -date)), "missing column")
  expect_error(check_effort(mutate(toy, date = as.character(date))), "class Date")
})

test_that("site-year summary counts complete surveys", {
  sy <- summarise_site_year(res)
  m19 <- sy[sy$site_std == "Mauliola" & sy$year == 2019, ]
  expect_equal(m19$n_surveys, 2)
  expect_equal(m19$n_complete, 1)
  expect_equal(m19$coverage_tier, "1 complete survey")
})
