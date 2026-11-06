# check_effort.R ------------------------------------------------------------
# Reusable sampling-effort checker for OPIHI surveys.
#
# check_effort(surveys, ...)
#   INPUT  a data frame with one row per survey (field trip) and columns
#            survey_id, date, site_std,
#            n_transects_recorded, quad_per_transect_recorded,
#            n_quadrats_observed, start_time, stop_time
#          (start/stop as "HH:MM" text; NA allowed everywhere except survey_id)
#   OUTPUT the same rows plus
#            planned_quadrats  = n_transects_recorded * quad_per_transect_recorded
#            completeness      = n_quadrats_observed / planned_quadrats
#            one logical flag_* column per rule (TRUE = problem)
#            n_flags           number of problems
#            effort_status     "complete" | "incomplete" | "no_quadrat_data" |
#                              "metadata_problem"
#
# Rules (all thresholds are arguments so OPIHI can change them):
#   flag_missing_date / flag_missing_site   key fields empty
#   flag_date_out_of_range                  outside [first_year, today]
#   flag_placeholder_time                   start 00:00 & stop 01:00 (2004-08 filler)
#   flag_missing_effort_meta                transects or quadrats/transect not recorded
#   flag_implausible_qpt                    quadrats/transect outside [min_qpt, max_qpt]
#   flag_no_quadrat_data                    trip recorded, but no quadrat rows
#   flag_low_completeness                   completeness < min_completeness
#   flag_over_planned                       more quadrats observed than planned
#   flag_duplicate_survey                   same date + site appears twice for
#                                           the same team (key = dup_key columns)
#
# Example:
#   checked <- check_effort(surveys, min_completeness = 0.8)
#   dplyr::count(checked, effort_status)

check_effort <- function(surveys,
                         min_completeness = 0.8,
                         min_qpt = 2, max_qpt = 30,
                         first_year = 2000,
                         dup_key = c("date", "site_std", "team_id")) {
  required <- c("survey_id", "date", "site_std", "n_transects_recorded",
                "quad_per_transect_recorded", "n_quadrats_observed",
                "start_time", "stop_time")
  missing_cols <- setdiff(required, names(surveys))
  if (length(missing_cols) > 0) {
    stop("check_effort(): missing column(s): ", paste(missing_cols, collapse = ", "),
         call. = FALSE)
  }
  if (!inherits(surveys$date, "Date")) {
    stop("check_effort(): `date` must be of class Date", call. = FALSE)
  }
  dup_key <- intersect(dup_key, names(surveys))

  out <- surveys |>
    mutate(
      planned_quadrats = n_transects_recorded * quad_per_transect_recorded,
      completeness     = n_quadrats_observed / planned_quadrats,
      flag_missing_date      = is.na(date),
      flag_missing_site      = is.na(site_std) | site_std == "",
      flag_date_out_of_range = !is.na(date) &
        (date < as.Date(paste0(first_year, "-01-01")) | date > Sys.Date()),
      flag_placeholder_time  = coalesce(start_time == "00:00" & stop_time == "01:00", FALSE),
      flag_missing_effort_meta = is.na(n_transects_recorded) | is.na(quad_per_transect_recorded),
      flag_implausible_qpt   = !is.na(quad_per_transect_recorded) &
        (quad_per_transect_recorded < min_qpt | quad_per_transect_recorded > max_qpt),
      flag_no_quadrat_data   = is.na(n_quadrats_observed) | n_quadrats_observed == 0,
      flag_low_completeness  = !is.na(completeness) & completeness < min_completeness,
      flag_over_planned      = !is.na(completeness) & completeness > 1
    ) |>
    group_by(across(all_of(dup_key))) |>
    mutate(flag_duplicate_survey = n() > 1 & !is.na(date)) |>
    ungroup()

  flag_cols <- grep("^flag_", names(out), value = TRUE)
  out$n_flags <- rowSums(out[flag_cols])
  out |>
    mutate(effort_status = case_when(
      flag_no_quadrat_data                                   ~ "no_quadrat_data",
      flag_missing_date | flag_missing_site |
        flag_date_out_of_range | flag_missing_effort_meta |
        flag_implausible_qpt                                 ~ "metadata_problem",
      flag_low_completeness                                  ~ "incomplete",
      TRUE                                                   ~ "complete"
    ))
}

# summarise_site_year(): roll checked surveys up to site x year coverage.
summarise_site_year <- function(checked) {
  checked |>
    filter(!is.na(date)) |>
    mutate(year = as.integer(format(date, "%Y"))) |>
    group_by(site_std, year) |>
    summarise(
      n_surveys          = n(),
      n_complete         = sum(effort_status == "complete"),
      quadrats_observed  = sum(n_quadrats_observed, na.rm = TRUE),
      median_completeness = median(completeness, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(coverage_tier = case_when(
      n_complete >= 2 ~ "2+ complete surveys",
      n_complete == 1 ~ "1 complete survey",
      TRUE            ~ "no complete survey"
    ))
}
