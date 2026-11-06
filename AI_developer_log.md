# AI Developer Log: Team B (Manōʻike, Gabby, Tim, Yang An)

> Draft written during the first AI session (Oct 20). Each teammate should add the
> prompts they use themselves and their own manual checks.

## Tools and disclosure

* **Tool:** Claude (Anthropic), used through the Claude app as a coding agent that could run R
  in a sandbox. Configured model: `claude-opus-5-5`.
* **Used for:** inventorying the 20 workbooks, writing the importers, cleaning script,
  `check_effort()`, tests, the Quarto report and the first draft of this log.
* **Data-stewardship note:** in this first session the raw workbooks, which include student,
  teacher and contact names, were uploaded to the AI tool before we noticed the guardrail
  "do not upload teacher identifiers to an external AI system". From now on we only share
  de-identified outputs (`data/clean/`) or column headers with AI tools.

## Selected prompts

| # | Prompt (summary) | What the AI produced |
|---|---|---|
| 1 | Uploaded the assignment PDF + data zip | Inventory of the 4 file layouts, duplicate sources, site-name variants, which question fits the data |
| 2 | "选 B" (pick Question B), build the effort pipeline | Importers, build script, `check_effort()`, tests, report |
| 3 | *(teammates: add yours)* | |

## Verification and the AI's mistakes

We checked the AI's code against the raw workbooks and against an independent
source, the compiled trip sheet (*OPIHI Data – Reformated*, "Actual Quadrats sampled").

| # | What went wrong in the AI's first version | How it was caught | Fix |
|---|---|---|---|
| 1 | **Unlabelled block merged into another trip.** In the 2020 file a block whose Date cell reads "???????" sits right after the Wawaloli trip. The importer only started a new block at a "Date" label, so it gave Wawaloli **36** quadrats. | Cross-check: compiled sheet says 20. Then counted the headers by hand in the raw sheet (transect-1…5 = 9+10+4+5+7 = 35 + 1 stray label). | Blocks now also start at any "Organisms" label. Orphan blocks are logged as excluded. Wawaloli now has 15 raw quadrats; the orphan has exactly 20, so this is an **open question for OPIHI**, not something to guess. |
| 2 | **Trips without quadrat data silently dropped.** Blocks with metadata plus a TOTALS summary but no quadrat columns returned `NULL` (227 trips instead of 231). | Trip count per file did not match a simple count of "Date" labels. | Those trips are kept with `effort_status = no_quadrat_data`. For question B they are real effort with missing data. |
| 3 | **2019 site names assumed to be present.** The first version gave 69 surveys a blank site. | `flag_missing_site` fired 69 times. Inspection showed the 2019 cells are blank or literally say "Location". Lat/long and school are intact. | Documented recovery rule: compiled sheet (same date + school) → nearest known site within 1 km. 64 + 5 recovered, 0 left missing. The method is stored in `site_recovery`. |
| 4 | **Duplicate key too loose.** In the 2025–26 sheets the position is written in "Quadrat location (m)", not "Position # on Transect", so position was NA and different quadrats looked identical. Rows were wrongly removed as duplicates. | The duplicate log listed removals inside files that should not contain copies (BIOL 499, RAW Mauliola). | Read the right position column and add a full taxon-count fingerprint (`taxa_signature`) to the key. |
| 5 | **Near-duplicates missed.** 43 rows of *Copy of OPIHI 2024 datasheet* survived deduplication. | Compared them with the original: all 43 match on date/site/person/transect/position and differ only in renamed taxon columns (e.g. "Haminoea cymbalum" vs "Haminoea cymbalum - green snail"). | Rule: a "Copy of" row whose quadrat position exists in the original is the same quadrat. Logged as `dup_type = same quadrat in 'Copy of' file`. |

**Result of the cross-check after fixes:** 225 trips appear in both sources; 219 agree
exactly. The rest are listed in the report (section 3).

### Manual checks to do (assign to teammates)

- [ ] Pick 3 random surveys from `opihi_surveys_effort.csv` and recount quadrats in Excel.
- [ ] Open 5 rows of `duplicates_log.csv` and confirm the kept and removed rows are the same quadrat.
- [ ] Confirm the site lookup choices marked `check` with Dr. Philippoff.
- [ ] Run `Rscript tests/test_check_effort.R` on your own computer.

## Individual reflections

### Yang An

I selected Question B for our team and produced the first working version of the full pipeline, using Claude (Anthropic) as a coding agent. I inventoried the 20 OPIHI workbooks and their four different layouts, then directed the AI to write the importers, the cleaning script that builds the de-identified survey-effort table and quadrat master (with exclusion and duplicate logs and a data dictionary), the reusable `check_effort()` function with its tests, and the two draft figures in the Quarto report. AI was most helpful with the tedious parsing of inconsistent spreadsheet layouts, but its first version was wrong in five ways that only surfaced through verification: it merged an unlabelled 2020 data block into the Wawaloli trip, silently dropped trips that had metadata but no quadrat data, assumed the 2019 site names were present when most were blank, used a duplicate key so loose that distinct quadrats were deleted, and missed near-duplicate rows in the "Copy of" 2024 file. These errors were caught by cross-checking quadrat counts derived from the raw sheets against the independent compiled trip sheet (219 of 225 trips now agree exactly) and by going back to the raw sheet for every mismatch. I personally recounted the quadrats for two surveys (2005-05-01 Kalaeloa and 2007-05-15 Hilo Yacht Club) directly in the raw Excel files, and both matched the clean table. I also made a data-stewardship mistake: I uploaded raw workbooks containing student and teacher names to the AI before noticing the guardrail, and since then we share only de-identified outputs. I would trust AI-generated code for boilerplate and plotting once tests pass, but not for data-cleaning logic whose errors produce plausible-looking numbers, unless its output has been checked against an independent source and a small hand-checked example.

### Manōʻike

*(your contribution, how AI helped or failed, what you personally verified, when you would or would not trust AI code)*

### Gabby

*(same four points)*

### Tim

*(same four points)*
