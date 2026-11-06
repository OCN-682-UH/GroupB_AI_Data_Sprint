# clean_helpers.R -----------------------------------------------------------
# Small cleaning utilities shared by the build script.

library(stringi)

# Normalise a site label to a lookup key: lower case, no ʻokina/apostrophes,
# no macrons, single spaces. "Lēʻahi " -> "leahi", "`Ewa" -> "ewa".
site_key <- function(x) {
  x |>
    str_replace_all("[ʻ'`‘’]", "") |>
    stri_trans_general("Latin-ASCII") |>
    str_to_lower() |>
    str_squish()
}

# Join the hand-curated lookup table; any label without a match is returned
# as-is with confidence "unmatched" so it shows up in the checks.
standardise_site <- function(df, lookup_path = "data/lookup/site_lookup.csv") {
  lk <- readr::read_csv(lookup_path, show_col_types = FALSE)
  df |>
    mutate(site_key = site_key(site_raw)) |>
    left_join(lk, by = "site_key") |>
    mutate(site_confidence = coalesce(confidence, if_else(is.na(site_raw), NA_character_, "unmatched")),
           site_std = coalesce(site_std, str_squish(site_raw))) |>
    select(-confidence, -note)
}

# "1 meter", "2 m", "3m", "1/2 meter" -> metres (numeric)
parse_spacing_m <- function(x) {
  x <- str_to_lower(str_squish(x))
  frac <- str_match(x, "(\\d+)\\s*/\\s*(\\d+)")
  out <- suppressWarnings(as.numeric(str_extract(x, "[0-9.]+")))
  has_frac <- !is.na(frac[, 1])
  out[has_frac] <- as.numeric(frac[has_frac, 2]) / as.numeric(frac[has_frac, 3])
  out
}

# Replace names (schools, team leaders, data-entry people) with stable codes.
# The key linking codes to real names is written ONLY to data/private/,
# which is git-ignored and goes to Dr. Philippoff, not to GitHub.
make_id_key <- function(values, prefix) {
  v <- sort(unique(str_squish(values[!is.na(values) & str_squish(values) != ""])))
  tibble(raw_name = v, id = sprintf("%s%03d", prefix, seq_along(v)))
}

minutes_between <- function(start, stop) {
  to_min <- function(t) {
    h <- suppressWarnings(as.numeric(str_sub(t, 1, 2)))
    m <- suppressWarnings(as.numeric(str_sub(t, 4, 5)))
    h * 60 + m
  }
  d <- to_min(stop) - to_min(start)
  # stop times written on a 12-h clock ("01:10" for 13:10)
  if_else(!is.na(d) & d < 0, d + 12 * 60, d)
}
