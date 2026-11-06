# import_wide.R -------------------------------------------------------------
# Parse the 2004-2020 "one field trip = one column block" workbooks
# (files named "OPIHI data YYYY.xlsx").
#
# Layout of each block (found by scanning row 1 for the label "Date"):
#   rows 1-11 : label / value pairs (Date, Start Time, ..., Location, School)
#   "Organisms" row : quadrat headers, e.g. "transect-1 quadrat-3 at point 4.0"
#                     (2019 uses "T-1 Q-3 at point 4.0")
#   rows below : one row per taxon, counts per quadrat, until the first blank
#                label. A derived "TOTALS:" block further down is ignored.
# Nothing in the raw files is modified; everything is read as text first.

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(purrr)

# Excel stores dates as serial numbers when read as text ("38018" etc.)
excel_to_date <- function(x) {
  num <- suppressWarnings(as.numeric(x))
  out <- as.Date(num, origin = "1899-12-30")
  # some cells are already ISO strings
  iso <- is.na(num) & !is.na(x) & str_detect(coalesce(x, ""), "^\\d{4}-\\d{2}-\\d{2}")
  out[iso] <- as.Date(str_sub(x[iso], 1, 10))
  out
}

# Excel times come through as day fractions ("0.3194") -> "HH:MM"
excel_to_hhmm <- function(x) {
  num <- suppressWarnings(as.numeric(x))
  mins <- round((num %% 1) * 24 * 60)
  ifelse(is.na(num), NA_character_,
         sprintf("%02d:%02d", mins %/% 60, mins %% 60))
}

parse_wide_block <- function(x, start, end, file) {
  lab <- str_squish(as.character(x[[start]]))
  val <- as.character(x[[start + 1]])
  get <- function(pattern) {
    i <- which(str_detect(tolower(lab[1:15]), pattern))[1]
    if (is.na(i)) NA_character_ else val[i]
  }

  trip <- tibble(
    source_file   = file,
    source_block  = start,
    date          = excel_to_date(get("^date")),
    start_time    = excel_to_hhmm(get("^start")),
    stop_time     = excel_to_hhmm(get("^stop")),
    n_transects_recorded = suppressWarnings(as.numeric(get("number of transect"))),
    transect_length_m    = get("length of transect"),
    point_spacing_raw    = get("point spacing"),
    quad_per_transect_recorded = suppressWarnings(as.numeric(get("quadrats per"))),
    # in 2019 most blocks lost the site name (cell is blank or says "Location")
    site_raw      = na_if(str_squish(get("^location")), "Location"),
    latitude      = suppressWarnings(as.numeric(get("^latitude"))),
    longitude     = suppressWarnings(as.numeric(get("^longitude"))),
    school_raw    = get("^school")
  )

  # Some blocks have metadata + a TOTALS summary but no quadrat-level data.
  # Keep the trip (it is real sampling effort) but return no quadrats.
  org_row <- which(lab == "Organisms")[1]
  if (is.na(org_row)) return(list(trip = trip, quadrats = NULL))

  # taxon rows: from below "Organisms" until the first empty label
  after <- (org_row + 1):nrow(x)
  first_blank <- after[is.na(lab[after]) | lab[after] == ""][1]
  taxon_rows <- if (is.na(first_blank)) after else seq(org_row + 1, first_blank - 1)
  taxon_rows <- taxon_rows[taxon_rows > org_row]

  qcols <- (start + 1):end
  qhead <- as.character(unlist(x[org_row, qcols]))
  keep  <- !is.na(qhead) & str_detect(qhead, regex("(transect|t)-\\s*\\d", ignore_case = TRUE))
  qcols <- qcols[keep]; qhead <- qhead[keep]

  if (length(qcols) == 0 || length(taxon_rows) == 0) {
    return(list(trip = trip, quadrats = NULL))
  }

  counts <- x[taxon_rows, qcols, drop = FALSE] |>
    mutate(across(everything(), ~ suppressWarnings(as.numeric(.x))))
  quadrats <- tibble(
    quadrat_label = qhead,
    transect  = as.integer(str_match(qhead, regex("(?:transect|t)-\\s*(\\d+)", ignore_case = TRUE))[, 2]),
    quadrat   = as.integer(str_match(qhead, regex("(?:quadrat|q)-\\s*(\\d+)", ignore_case = TRUE))[, 2]),
    point_m   = suppressWarnings(as.numeric(str_match(qhead, "point\\s*([0-9.]+)")[, 2])),
    n_taxa_recorded = colSums(counts > 0, na.rm = TRUE),
    total_points    = colSums(counts, na.rm = TRUE),
    has_data        = colSums(!is.na(counts)) > 0
  )
  list(trip = trip, quadrats = quadrats)
}

import_wide_file <- function(path) {
  file <- basename(path)
  x <- suppressMessages(read_excel(path, sheet = 1, col_names = FALSE,
                                   col_types = "text", .name_repair = "minimal"))
  names(x) <- paste0("c", seq_along(x))
  # A block starts at a "Date" label in row 1 OR at an "Organisms" label.
  # (2020 contains a block whose Date cell reads "???????" and has no metadata;
  #  without the second rule its quadrats were merged into the previous trip.)
  date_cols <- which(str_squish(unlist(x[1, ])) == "Date")
  org_cols  <- which(apply(x[1:min(20, nrow(x)), ], 2,
                           function(col) any(str_squish(col) == "Organisms", na.rm = TRUE)))
  starts <- sort(unique(c(date_cols, org_cols)))
  ends   <- c(starts[-1] - 1, ncol(x))
  blocks <- map2(starts, ends, ~ parse_wide_block(x, .x, .y, file)) |> compact()

  trips <- map_dfr(blocks, "trip")
  quads <- map2_dfr(blocks, seq_along(blocks), function(b, k) {
    if (is.null(b$quadrats)) return(NULL)
    mutate(b$quadrats, source_file = file, source_block = b$trip$source_block)
  })
  list(trips = trips, quadrats = quads)
}

import_all_wide <- function(raw_dir) {
  files <- list.files(raw_dir, pattern = "^OPIHI data (20\\d\\d).*\\.xlsx$", full.names = TRUE)
  res <- map(files, import_wide_file)
  list(trips    = map_dfr(res, "trips"),
       quadrats = map_dfr(res, "quadrats"))
}
