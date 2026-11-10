---

editor_options: 
  markdown: 
    wrap: 72
---

# AI Developer Log: Team B (Manōʻike, Gabby, Tim, Yang An)

> Draft written during the first AI session (Oct 20). Each teammate should add the prompts they use themselves and their own manual checks.

# Yang An

## Tools and disclosure

- **Tool:** Claude (Anthropic), used through the Claude app as a coding agent that could run R in a sandbox. Configured model: `claude-opus-5-5`.
- **Used for:** inventorying the 20 workbooks, writing the importers, cleaning script, `check_effort()`, tests, the Quarto report and the first draft of this log.
- **Data-stewardship note:** in this first session the raw workbooks, which include student, teacher and contact names, were uploaded to the AI tool before we noticed the guardrail "do not upload teacher identifiers to an external AI system". From now on we only share de-identified outputs (`data/clean/`) or column headers with AI tools.

## Selected prompts

| \# | Prompt (summary) | What the AI produced |
|------------------------|------------------------|------------------------|
| 1 | Uploaded the assignment PDF + data zip | Inventory of the 4 file layouts, duplicate sources, site-name variants, which question fits the data |
| 2 | "选 B" (pick Question B), build the effort pipeline | Importers, build script, `check_effort()`, tests, report |

## Verification and the AI's mistakes

We checked the AI's code against the raw workbooks and against an independent source, the compiled trip sheet (*OPIHI Data – Reformated*, "Actual Quadrats sampled").

| \# | What went wrong in the AI's first version | How it was caught | Fix |
|------------------|------------------|------------------|------------------|
| 1 | **Unlabelled block merged into another trip.** In the 2020 file a block whose Date cell reads "???????" sits right after the Wawaloli trip. The importer only started a new block at a "Date" label, so it gave Wawaloli **36** quadrats. | Cross-check: compiled sheet says 20. Then counted the headers by hand in the raw sheet (transect-1…5 = 9+10+4+5+7 = 35 + 1 stray label). | Blocks now also start at any "Organisms" label. Orphan blocks are logged as excluded. Wawaloli now has 15 raw quadrats; the orphan has exactly 20, so this is an **open question for OPIHI**, not something to guess. |
| 2 | **Trips without quadrat data silently dropped.** Blocks with metadata plus a TOTALS summary but no quadrat columns returned `NULL` (227 trips instead of 231). | Trip count per file did not match a simple count of "Date" labels. | Those trips are kept with `effort_status = no_quadrat_data`. For question B they are real effort with missing data. |
| 3 | **2019 site names assumed to be present.** The first version gave 69 surveys a blank site. | `flag_missing_site` fired 69 times. Inspection showed the 2019 cells are blank or literally say "Location". Lat/long and school are intact. | Documented recovery rule: compiled sheet (same date + school) → nearest known site within 1 km. 64 + 5 recovered, 0 left missing. The method is stored in `site_recovery`. |
| 4 | **Duplicate key too loose.** In the 2025–26 sheets the position is written in "Quadrat location (m)", not "Position \# on Transect", so position was NA and different quadrats looked identical. Rows were wrongly removed as duplicates. | The duplicate log listed removals inside files that should not contain copies (BIOL 499, RAW Mauliola). | Read the right position column and add a full taxon-count fingerprint (`taxa_signature`) to the key. |
| 5 | **Near-duplicates missed.** 43 rows of *Copy of OPIHI 2024 datasheet* survived deduplication. | Compared them with the original: all 43 match on date/site/person/transect/position and differ only in renamed taxon columns (e.g. "Haminoea cymbalum" vs "Haminoea cymbalum - green snail"). | Rule: a "Copy of" row whose quadrat position exists in the original is the same quadrat. Logged as `dup_type = same quadrat in 'Copy of' file`. |

**Result of the cross-check after fixes:** 225 trips appear in both sources; 219 agree exactly. The rest are listed in the report (section 3).

## Reflection

### Yang An

I selected Question B for our team and produced the first working version of the full pipeline, using Claude (Anthropic) as a coding agent. I inventoried the 20 OPIHI workbooks and their four different layouts, then directed the AI to write the importers, the cleaning script that builds the de-identified survey-effort table and quadrat master (with exclusion and duplicate logs and a data dictionary), the reusable `check_effort()` function with its tests, and the two draft figures in the Quarto report. AI was most helpful with the tedious parsing of inconsistent spreadsheet layouts, but its first version was wrong in five ways that only surfaced through verification: it merged an unlabelled 2020 data block into the Wawaloli trip, silently dropped trips that had metadata but no quadrat data, assumed the 2019 site names were present when most were blank, used a duplicate key so loose that distinct quadrats were deleted, and missed near-duplicate rows in the "Copy of" 2024 file. These errors were caught by cross-checking quadrat counts derived from the raw sheets against the independent compiled trip sheet (219 of 225 trips now agree exactly) and by going back to the raw sheet for every mismatch. I personally recounted the quadrats for two surveys (2005-05-01 Kalaeloa and 2007-05-15 Hilo Yacht Club) directly in the raw Excel files, and both matched the clean table. I also made a data-stewardship mistake: I uploaded raw workbooks containing student and teacher names to the AI before noticing the guardrail, and since then we share only de-identified outputs. I would trust AI-generated code for boilerplate and plotting once tests pass, but not for data-cleaning logic whose errors produce plausible-looking numbers, unless its output has been checked against an independent source and a small hand-checked example.

# Mano'ike Delude

## Tools and Disclosure

- **Tool:** Gemini (Google) Configured model: `3.8 Flash`.
- **Used for:** Answer quick questions about code syntax, and to build the base for the ggplotly widget.
- **Data-stewardship note:** data was already sanitized before this step, one Le'ahi visit was excluded from the map because I wasn't able to figure out the merging conflict

## Selected Prompts

### Gemini

| \# | Prompt (summary) | What the AI produced |
|------------------------|------------------------|------------------------|
| 1 | Specific instructions on libraries, and which columns to use with sub-functions of those libraries to build an interactive map. | A close to finished interactive map, only needed minor visual edits to make ready |

## Verification and the AI's Mistakes

Verification was visual (did the data frame accurately get transposed into an image), and the code is similar to ones I've written in the past.\
Gemini left in, and even labeled Latitude and Longitute in the original iteration, which is less of a mistake and more a limitation of my prompting.

## Reflection

### Manōʻike

I was very cautious about uploading unsanitized sheets into an LLM, so we individually tried breaking down the correct phrasing we’d need to accurately describe the .excel files. There are many, many, technical terms that describe excel workbook mechanics that were much more in-depth than I could completely grasp during our sprint. Luckily, Yang got that through.\
Working backwards from the end, I focused on getting a mockup of a figure, since I knew we would sort by site and year. Using our basic cleaning methods I calculated our “mean effort scores” and did some simple joining. Having more experience with this aspect of the project made it so I could get the interactive map mostly done in one prompt to Gemini (see attached pdf). Afterwards, my questions went into a fresh google tab to look up syntax for the different parts of ggplot/sf/plotly to remove all the axis labels and grid marks, since I normally would miss some and have to google anyway.\
My main takeaway is that Yang’s use of Claude made much more complex code that did a better job of handling the sheets. Gemini is good for short r queries, but you have to have more background knowledge on what you’re asking to prompt it to do what you need.\

# Gabby

*(same four points)*

# Tim

## Tools and disclosure

- **Tool:** Gemini `3.6 Flash`, a large language model built by Google.
- **Used for:** Refactoring `01_build_master.R`, running verifications on functions and `01_build_master.R`, and generating AI summaries of prompts/interactions
- **Data-stewardship note:** In verification process, all forms of identification were already hidde 
  
## Selected prompts

This first table is a summary of some prompts I used in attempting to generalize the `01_build_master.R` so that it did not include references to specific raw data. 

| \# | Prompt (summary) | Issue / Error | Root Cause | Fix Applied |
|------------------------|------------------------|------------------------|------------------------|------------------------|
| 1 | Refactor and generalize `01_build_master.R` for unknown/messy Excel workbooks. | Error in group_by(): Column file_name is not found. Column sheet_name is not found. | standardize_generic_columns() regex patterns renamed or stripped tracking metadata attached by read_single_sheet(). | Updated column standardization to freeze and protect tracking attributes (file_name, sheet_name, raw_row_id, header_row_found). |
| 2 | User Prompt: "add it to the entire code please" | Error in mutate(): Can't transform a data frame with duplicate names. | Blank or duplicated raw Excel headers created non-unique column names that broke dplyr::mutate(). | Added make.names(..., unique = TRUE) on raw read-ins and applied janitor::make_clean_names() on merged header vectors. |
| 3 | User Prompt: "it gave me 0 for all the outputs though" | Pipeline finished without crashing, but returned 0 rows across surveys, quad_master, and log files. | Strict numeric date serial ranges dropped text date strings; rigid regex missed dirty headers; file path mismatch (AI Data Sprint). | Integrated lubridate::parse_date_time(), relaxed header regex rules, and updated search path to here("AI Data Sprint") with local fallback. |
| 4 | User Prompt: "theres still no sheet_name object" | Error in summarise(): object 'sheet_name' not found. | If sub-sheets returned empty or missing attributes, bind_rows() dropped sheet_name from master_combined_data. | Added safe fallback initialization checks right after bind_rows() to ensure metadata columns exist before group_by() and summarise(). |

This second table is a summary of some prompts I used attempting to clean the data from scratch again.

| \# | Prompt (summary) | Issue / Error | Fix Applied |
|------------------------|------------------------|------------------------|------------------------|
| 1 | Headers aren't always at row 1 (metadata sits above table). | Standard read_excel() reads row 1 as headers, causing offset/misaligned columns when metadata rows sit above the data table. | Integrated find_true_header_row() to scan preview rows dynamically for keyword density and find the true data table starting row. |
| 2 | Top headers span multiple rows or miss sub-columns (e.g., organism names split across rows). | Default header extraction only reads the first header line, missing nested column names and partial top headers split across multiple rows. | Created collapse_all_top_headers() & detect_header_row_span() to dynamically collapse and concatenate all multi-row header text into single, unified column names. | 
| 3 | Pipeline Output Returned 0 Rows Across All Datasets. | Strict numeric serial date parsing filters dropped text-formatted dates (e.g., "5/12/24", "2024-05-12"), causing filter(!is.na(date)) to wipe all records. | Integrated lubridate::parse_date_time() to parse raw text date strings alongside numeric Excel serial dates, preventing 0-row drops. | 
| 4 | Directory & File Extraction Failure (0 workbooks found). | Local folder directory mismatch (AI Data Sprint vs. relative pathing) caused list.files() to return character(0). | Updated ingestion path resolution to explicitly target here("AI Data Sprint") with a recursive fallback to local working directories. | 

## Verification and the AI's mistakes

| \# | Topic | Input | Key Findings | Result |
|------------------------|------------------------|------------------------|------------------------|------------------------|
| 1 | check_effort() Unit Tests | Shared # Tests for check_effort() script using testthat with 8 mock survey scenarios (ok, half, nodata, excel_qt, future, dup1/dup2). Asked what the code does. | Explained that the script is a unit test suite verifying that sampling effort metrics are calculated correctly and data entry anomalies are properly flagged. | Concept Explained: Confirmed code validates data quality rules before building master files.
| 2 | Test Logic Breakdown | Asked what specific results the test suite gives you. | Itemized the expected metrics and flag triggers across all 8 mock survey scenarios (e.g., detecting Excel auto-formatting dates like 45576 or year 2099). | Results Detailed: Outlined expected behavior for both complete/incomplete trips and bad inputs.
| 3 | Console Output Interpretation | Shared console output showing Test passed with 3 successes 😸 (and up to 10 successes per block). Asked what it meant and if 3 successes was good. | Confirmed "3 successes" is great. Explained that each assertion (expect_equal, expect_true) equals 1 success, and simply shortens long code blocks in R console outputs. | 19/19 Assertions Passed: 0 failures or errors across all 5 test blocks.
| 4 | Feature Summary Tables | Requested a detailed summary table, followed by a smaller, simplified version. | Created structured tables detailing the exact scenario, target flags, and verified behavior for each test case. | Tables Provided: Delivered both a comprehensive breakdown and a 5-row summary table. |
| 5 | Crosscheck Audit Chunk | Shared cc R Markdown snippet comparing n_quadrats_raw vs n_quadrats_compiled. Asked if it compares manual Excel counts to master builder code counts. | Clarified that the code acts as an auditor comparing two human data sources against each other (raw annual workbook rows vs the compiled summary sheet Totals_NO_Excl). | Clarification Provided: Defined difference == 0 (exact match) vs difference != 0 (missing/excluded raw rows). |

## Reflection

### Tim

Before I began using AI to write code to clean the 20 OPIHI workbooks, I looked through each excel sheet manually to get a better understanding of what their contents were, how they were formatted, and how they could be combined into one master data sheet. Our group had decided that each of us were going to play around with different strategies to develop a master code and in doing so, I found myself wanting to make manual changes to the workbooks themselves because it would have been easier, albeit more time consuming. I generally struggled with how to formulate accurate enough inputs into AI to standardize the formatting of all the excel sheets. One particular issue that arose was trying to get AI to scan through each excel sheet and identify which rows contained the appropriate column headers. The code generated would always run smoothly but when I cross referenced with the raw data sheets, they never matched. After achieving a working master code that Yang was able to generate more effectively than myself, I verified all the functions for cleaning, importing, and calculating effort. I also verified the use of the master build R script by deleting and re-downloading all the raw datafiles and running them through again. After verification and testing, I manually edited the final quarto document as well as re-organized the Github repository which required restructuring the file paths. Once completed, I took our master build code and used AI to see if it could reproduce a similar but more generic and simplified structure while still maintaining 100% parity. AI came in very handy for this assignment and I would trust its ability to develop general pathways for cleaning and creating summary tables but not as much for more data specific adjustments across large scales. The AI generated code often still resulted in repeated errors and sometimes created new errors. Overall, this was a difficult task and I wouldn’t necessarily want to trust AI for cleaning sensitive data, especially when it is employing coding structure and functions I’ve never seen before. In many cases, the AI would struggle with more complex debugging despite always finding some part of the code to change every time I input the error in Gemini. 

