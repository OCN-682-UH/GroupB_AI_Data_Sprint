# import_long.R -------------------------------------------------------------
# Parse the 2024-2026 "one row per quadrat" workbooks (Quadrat PtCounts sheet)
# and their Metadata sheets.
#
# Raw quirks handled here (each is counted and reported, never silently fixed):
#   * the header row is row 1 or row 2 (a group banner sits above it)
#   * header rows are repeated inside the data ("Date", "Location", ...)
#   * template rows marked "EXAMPLE: Do not erase"
#   * names typed into the Date column (e.g. a person's name)
#   * all-zero template rows (no points recorded)

source("Scripts/Functions/import_wide.R")   # for excel_to_date(), excel_to_hhmm()

find_header_row <- function(x) {
  which(apply(x[1:min(6, nrow(x)), ], 1,
              function(r) any(str_squish(r) == "Date", na.rm = TRUE)))[1]
}

import_quadrat_sheet <- function(path, sheet = "Quadrat PtCounts") {
  file <- basename(path)
  x <- suppressMessages(read_excel(path, sheet = sheet, col_names = FALSE,
                                   col_types = "text", .name_repair = "minimal"))
  h <- find_header_row(x)
  hdr <- str_squish(as.character(unlist(x[h, ])))
  d <- x[-(1:h), , drop = FALSE]
  names(d) <- make.unique(ifelse(is.na(hdr) | hdr == "", "blank", hdr))
  d$raw_row <- seq_len(nrow(d)) + h          # row number in the Excel sheet

  # locate columns by name pattern (they differ slightly between years)
  col_of <- function(p) names(d)[str_detect(tolower(names(d)), p)][1]
  c_date <- col_of("^date$"); c_loc <- col_of("^location")
  c_who  <- col_of("data entry")
  c_tr   <- col_of("^(# t|transect #)$")
  c_pos  <- col_of("^position")
  c_qloc <- col_of("^quadrat location")   # 2025-26 sheets fill this instead
  c_tot  <- col_of("^total")

  # taxon / substrate columns sit between the position column and "Total"
  i_pos <- match(c_pos, names(d)); i_tot <- match(c_tot, names(d))
  taxon_cols <- names(d)[(i_pos + 1):(i_tot - 1)]
  taxon_cols <- taxon_cols[!str_detect(taxon_cols, "^blank")]

  counts <- d[, taxon_cols] |>
    mutate(across(everything(), ~ suppressWarnings(as.numeric(.x))))

  out <- tibble(
    source_file   = file,
    raw_row       = d$raw_row,
    date_raw      = d[[c_date]],
    date          = excel_to_date(d[[c_date]]),
    site_raw      = str_squish(d[[c_loc]]),
    team_raw      = str_squish(d[[c_who]]),
    transect      = suppressWarnings(as.integer(as.numeric(d[[c_tr]]))),
    point_m       = coalesce(suppressWarnings(as.numeric(d[[c_pos]])),
                             if (is.na(c_qloc)) NA_real_ else suppressWarnings(as.numeric(d[[c_qloc]]))),
    n_taxa_recorded = rowSums(counts > 0, na.rm = TRUE),
    total_points    = rowSums(counts, na.rm = TRUE),
    # full fingerprint of the counts, used to find exact duplicate quadrats
    taxa_signature  = apply(counts, 1, function(v) {
      k <- which(!is.na(v) & v > 0)
      paste(paste0(taxon_cols[k], "=", v[k]), collapse = "|")
    }),
    is_example      = apply(d, 1, function(r) any(str_detect(r, regex("example", ignore_case = TRUE)), na.rm = TRUE))
  ) |>
    filter(!is.na(date_raw) | !is.na(site_raw))   # fully blank rows are not records

  out |>
    mutate(row_status = case_when(
      str_squish(date_raw) == "Date"           ~ "repeated_header",
      is_example                                ~ "example_template",
      is.na(date)                               ~ "unparseable_date",
      total_points == 0                         ~ "no_points_recorded",
      TRUE                                      ~ "ok"
    )) |>
    select(-is_example)
}

import_metadata_sheet <- function(path) {
  file <- basename(path)
  if (!"Metadata" %in% excel_sheets(path)) return(NULL)
  x <- suppressMessages(read_excel(path, sheet = "Metadata", col_names = FALSE,
                                   col_types = "text", .name_repair = "minimal"))
  h <- find_header_row(x)
  hdr <- str_squish(as.character(unlist(x[h, ])))
  d <- x[-(1:h), , drop = FALSE]
  names(d) <- make.unique(ifelse(is.na(hdr) | hdr == "", "blank", hdr))
  d <- d[rowSums(!is.na(d)) > 0, ]
  num <- function(v) suppressWarnings(as.numeric(str_extract(v, "[0-9.]+")))
  col <- function(name) if (name %in% names(d)) d[[name]] else rep(NA_character_, nrow(d))

  tibble(
    source_file  = file,
    date         = excel_to_date(col("Date")),
    site_raw     = str_squish(col("Location")),
    team_raw     = str_squish(col("Team Leader")),
    n_people     = num(col("# in field group")),
    n_transects_recorded = num(col("# T lines")),
    transect_length_m    = num(col("Longest T (m)")),
    point_spacing_raw    = col("Dist between T pts"),
    quad_per_transect_raw = col("# Quad/T"),
    quad_per_transect_recorded = num(col("# Quad/T")),
    start_time   = excel_to_hhmm(col("Start time")),
    stop_time    = excel_to_hhmm(col("End time"))
  ) |>
    # "# Quad/T" values like "10-12" were auto-converted by Excel into dates
    # (serial numbers ~45000+). Those are not counts: set NA, keep the raw value.
    mutate(quad_per_transect_recorded = if_else(quad_per_transect_recorded > 100,
                                                NA_real_, quad_per_transect_recorded))
}

LONG_FILES <- c(
  "OPIHI 2024 datasheet .xlsx",
  "Copy of OPIHI 2024 datasheet .xlsx",
  "OPIHI BIOL 499 2025 LT data.xlsx",
  "OPIHI 2026 Longitudinal Monitoring Data.xlsx",
  "RAW Mauliola OPIHI Data 2026.xlsx"
)

import_all_long <- function(raw_dir) {
  paths <- file.path(raw_dir, LONG_FILES)
  list(quadrats = map_dfr(paths, import_quadrat_sheet),
       metadata = map_dfr(paths, import_metadata_sheet))
}
