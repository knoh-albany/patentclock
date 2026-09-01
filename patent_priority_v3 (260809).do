/**************************************************************************
 Project: USPTO PatentsView → Priority/Family Build
 Purpose: Build patent families & priority dates from PatentsView
 Author: Kyoungah Noh (University at Albany, SUNY)
 Contact: knoh@albany.edu
 Date: 2025-09-08  // created
 Last edit: 2026-08-09  // v3

 v3 changes (marked with [v3]):
   6) NEW: foreign-priority legal-window diagnostics.
      foreign_gap_months = months between the earliest foreign filing and
      the earliest U.S. chain document. Paris Convention allows 12 months
      (+2 restoration); the PCT national-phase route allows up to ~31
      months. Larger gaps indicate either raw-data date errors or U.S.
      chain links missing from g_us_rel_doc (concentrated in pre-2001
      filings). priority_date is PRESERVED as the face-value minimum —
      foreign_window lets users filter to their own tolerance.
      Expected counts (250319 vintage, patent level at family_order==1):
      within_12mo 2,739,247 / foreign_after_us 22,589 /
      grace_13_14 8,582 / gap_15_24 57,802 / pct_25_31 87,665 /
      over_31 131,999.
   7) Outputs renamed v2 -> v3 (schema change).

 v2 changes (marked with [v2]):
   1) FIX: `order priority_year` referenced a variable that was never
      created — v1 did not run end-to-end. priority_year is now generated.
   2) FIX: missing dates exported as "." (Stata missing string) in the
      public CSV — now exported as empty strings.
   3) NEW: qc_flag column
        - "invalid_priority_year": priority year <1836 or >2026
          (raw PatentsView date typos, e.g. "0110-08-04" for 2010-08-04;
          ~260 patents, ~0.003% of sample)
        - "pre1970_review": priority year 1836–1969 with filing year
          1980+; mix of raw-data errors and possibly genuine long
          continuation chains (submarine patents) — manual review list
          (~427 patents)
   4) NEW: export delimited block for the public-release CSV.
   5) NOTE (not changed): the monotonicity filter in Section 3 drops rows
      whose date exceeds BOTH neighbors (a spike filter). Revisit whether
      this is the intended rule before public release — see TODO below.

 Data source:
   - PatentsView (USPTO): https://patentsview.org/download/data-download-tables
   - g_patent.tsv, g_application.tsv, g_us_rel_doc.tsv, g_foreign_priority.tsv
   - Date: 2025-09-06

 Outputs: patent_priority_v3_`vintage'.dta / .csv
    - U.S. utility patents, application filing years 1980–2025

**************************************************************************/


clear
cd "/Users/knoh/Desktop/i3 work"   // [v2] was commented out (old Albany path)

* [v2] Data vintage — PatentsView bulk download date (YYMMDD).
* Update this ONCE per rebuild; all output filenames inherit it.
* NOTE: the 250319 batch is the 2024 year-end release —
*       grant coverage ends 2024-12-31 (max patent_id 12185647,
*       identical in g_patent and g_us_rel_doc → synchronized cut).
local vintage 250319
local rawdir "raw data/PatentsView (250319)"


////////////////////////////////////////////////////////////
* -1) [v2] Extract raw TSVs from the synchronized vintage folder
////////////////////////////////////////////////////////////
* ALWAYS re-extracts (replace) so stale TSVs from a previous run —
* possibly a different vintage — can never be silently reused.
* All four tables MUST come from the same download batch.

unzipfile "`rawdir'/g_patent.tsv.zip", replace
unzipfile "`rawdir'/g_application.tsv.zip", replace
unzipfile "`rawdir'/g_foreign_priority.tsv.zip", replace
unzipfile "`rawdir'/g_us_rel_doc.tsv.zip", replace


////////////////////////////////////////////////////////////
* 0) Load & clean raw data
////////////////////////////////////////////////////////////

import delimited "g_patent.tsv", clear
drop withdrawn filename
isid patent_id
tempfile pat
save `pat'   // [v2] added space after `save` (v1: "save`pat'")

import delimited "g_application.tsv", clear
drop patent_application_type series_code rule_47_flag
tempfile app
save `app'

import delimited "g_foreign_priority.tsv", clear
rename filing_date foreign_filing_date
* Keep earliest foreign filing per patent
bys patent_id: egen foreign_filing_date_min = min(cond(missing(date(foreign_filing_date,"YMD")),., date(foreign_filing_date,"YMD")))
keep patent_id foreign_filing_date_min foreign_country_filed
duplicates drop patent_id foreign_filing_date_min, force
* TODO [v2]: when two countries share the same earliest date, `force`
* keeps an arbitrary one — consider a deterministic tie-break rule
* (e.g., alphabetical) and documenting it in the README.
format foreign_filing_date_min %tdYMD
gen foreign_year = year(foreign_filing_date_min)
tempfile fprio
save `fprio'

import delimited "g_us_rel_doc.tsv", clear
* Keep only relationships that imply *family* ties (related-publication is NOT a family link)
tab related_doc_type
keep if inlist(related_doc_type, "us-provisional-application","continuation","continuation-in-part","division") // PRO, CON, CIP, DIV
drop if related_doc_published_date==""
keep patent_id related_doc_number related_doc_type related_doc_published_date
tempfile usrel
save `usrel'



////////////////////////////////////////////////////////////
* 1) Base patent panel with dates/types and filters
////////////////////////////////////////////////////////////

use `pat', clear
merge 1:m patent_id using `app', gen(_m_app) keep(master match)

tab _m_app
drop if _m_app==1 // drop patents with no application_id row
drop _m_app

* Filing/patent dates
gen filing_date_d = date(filing_date, "YMD")
format filing_date_d %tdYMD
gen filing_year = year(filing_date_d)

gen patent_date_d = date(patent_date, "YMD")
format patent_date_d %tdYMD
gen patent_year = year(patent_date_d)

keep if inrange(filing_year,1980,2025) // 1980-2025
keep if  patent_type=="utility" // Utility patents

tempfile base
save `base'


////////////////////////////////////////////////////////////
* 2) Bring in related application → patent mapping
////////////////////////////////////////////////////////////

use `usrel', clear

merge m:1 patent_id using `base', keep(using match) nogen
merge m:1 patent_id using `fprio', keep(master match) nogen

* Related_doc dates
gen related_doc_date_d = date(related_doc_published_date, "YMD")
format related_doc_date_d %tdYMD
gen related_doc_year = year(related_doc_date_d)

tempfile fam
save `fam'


////////////////////////////////////////////////////////////
* 3) Patent family per patent_id
////////////////////////////////////////////////////////////

use `fam', clear
rename related_doc_number fam_doc_number
rename related_doc_type fam_doc_type
rename related_doc_published_date fam_doc_date
rename related_doc_date_d fam_doc_date_d
rename related_doc_year fam_doc_year

* Related_doc (PRO, CON, CIP, DIV) + application_id
bys patent_id (fam_doc_date_d): gen tag = _n == _N if fam_doc_number!=""
order tag
expand 2 if tag==1
sort patent_id fam_doc_number

bys patent_id (tag): replace tag = 2 if _n == _N & tag == 1

bys patent_id: replace fam_doc_number = application_id if tag==2|tag==.
bys patent_id: replace fam_doc_type = "application" if tag==2|tag==.
bys patent_id: replace fam_doc_date = filing_date if tag==2|tag==.
bys patent_id: replace fam_doc_date_d = filing_date_d if tag==2|tag==.
bys patent_id: replace fam_doc_year = filing_year if tag==2|tag==.

* Related_doc_date monotonicity
* TODO [v2]: this drops rows whose date is strictly greater than BOTH
* neighbors (spike filter). Rows at the chain ends (_n==1 or _n==_N)
* evaluate against missing neighbors. Confirm intended behavior and
* document the rule (and # of rows dropped) in the README before release.
bys patent_id (tag fam_doc_date_d): gen bad = fam_doc_date_d > fam_doc_date_d[_n-1] & fam_doc_date_d > fam_doc_date_d[_n+1]
order bad
drop if bad==1
drop bad

* Family size
drop tag
bys patent_id (fam_doc_date_d): gen family_order = _n
order family_order

bys patent_id: gen family_size = _N
order family_size

tempfile fam_work
save `fam_work'


////////////////////////////////////////////////////////////
* 4) Compute priority_date per family
////////////////////////////////////////////////////////////

* Priority selection rule (earliest of the available; fam_doc_date_d, foreign_filing_date_min)
by patent_id: egen priority_date_d = min(fam_doc_date_d)
format priority_date_d %tdYMD

bys patent_id: replace priority_date_d = foreign_filing_date_min if (foreign_filing_date_min < priority_date_d) & foreign_filing_date_min!=.

gen priority_year = year(priority_date_d)   // [v2] FIX: was never generated in v1

* [v3] earliest U.S. chain document date (needed for foreign-window diagnostics)
bys patent_id: egen us_chain_min_d = min(fam_doc_date_d)
format us_chain_min_d %tdYMD

order family_size family_order, last
order priority_year priority_date_d

drop application_id filing_date filing_date_d filing_year patent_date_d patent_year fam_doc_date_d fam_doc_year foreign_year

order patent_type patent_title wipo_kind num_claims, last

gen priority_date = strofreal(priority_date_d, "%tdCCYY-NN-DD")
gen foreign_filing_date = strofreal(foreign_filing_date_min, "%tdCCYY-NN-DD")

order priority_date, a(priority_date_d)
order foreign_filing_date, a(foreign_filing_date_min)


////////////////////////////////////////////////////////////
* 5) [v2] QC flags
////////////////////////////////////////////////////////////

gen qc_flag = ""
replace qc_flag = "invalid_priority_year" if priority_year<1836 | priority_year>2026
replace qc_flag = "pre1970_review"        if inrange(priority_year,1836,1969)
label var qc_flag "data-quality flag: invalid_priority_year / pre1970_review / empty=clean"

* [v3] foreign-priority legal-window diagnostics (values preserved; flag only)
gen foreign_gap_months = (year(us_chain_min_d)*12 + month(us_chain_min_d)) ///
                       - (year(foreign_filing_date_min)*12 + month(foreign_filing_date_min)) ///
                       if foreign_filing_date_min!=.
gen foreign_window = ""
replace foreign_window = "foreign_after_us" if foreign_gap_months<0
replace foreign_window = "within_12mo"      if inrange(foreign_gap_months,0,12)
replace foreign_window = "grace_13_14"      if inrange(foreign_gap_months,13,14)
replace foreign_window = "gap_15_24"        if inrange(foreign_gap_months,15,24)
replace foreign_window = "pct_25_31"        if inrange(foreign_gap_months,25,31)
replace foreign_window = "over_31"          if foreign_gap_months>=32 & foreign_gap_months!=.
label var foreign_gap_months "months from earliest foreign filing to earliest U.S. chain doc"
label var foreign_window "legal-window class of the foreign priority claim (empty = no foreign priority)"
tab foreign_window if family_order==1, missing   // cross-check against header counts

drop us_chain_min_d
drop priority_date_d foreign_filing_date_min


////////////////////////////////////////////////////////////
* 6) [v2] Export — missing dates as empty strings, not "."
////////////////////////////////////////////////////////////

replace foreign_filing_date = "" if foreign_filing_date=="."
replace priority_date       = "" if priority_date=="."

save "claude_outputs/patent_priority_v3_`vintage'.dta", replace
export delimited using "claude_outputs/patent_priority_v3_`vintage'.csv", replace
�PRO
