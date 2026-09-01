/**************************************************************************
 Purpose: Apply v2 fixes DIRECTLY to the existing patent_priority.dta
          — no raw PatentsView files needed.
 Use this if you just want the corrected public-release files now.
 (The full rebuild script patent_priority_v2 (260809).do requires the
  raw TSVs, incl. g_us_rel_doc.tsv which is currently missing from
  "raw data/" — re-download from patentsview.org if you want a full
  end-to-end rerun.)

 Author: Kyoungah Noh · patched 2026-08-09
 Input:  patent_priority.dta (v1 output)
 Output: patent_priority_v2.dta, patent_priority_v2.csv
**************************************************************************/

clear
cd "/Users/knoh/Desktop/i3 work"

use patent_priority.dta, clear

* [v2] priority_year (was missing in v1)
gen priority_year = real(substr(priority_date,1,4))
order priority_year, a(priority_date)

* [v2] QC flags
gen qc_flag = ""
replace qc_flag = "invalid_priority_year" if priority_year<1836 | priority_year>2026
replace qc_flag = "pre1970_review"        if inrange(priority_year,1836,1969)
label var qc_flag "data-quality flag: invalid_priority_year / pre1970_review / empty=clean"

* [v2] missing dates as empty strings, not "."
replace foreign_filing_date = "" if foreign_filing_date=="."
replace priority_date       = "" if priority_date=="."

* Sanity checks — expected: 2,263 invalid rows / 1,014 pre1970 rows
tab qc_flag, missing
count if foreign_filing_date=="."
assert r(N)==0

save "claude_outputs/patent_priority_v2.dta", replace
* Optional: the CSV below is identical to the one already generated in
* claude_outputs/ — uncomment to regenerate from Stata as the official
* reproducible path.
* export delimited using "claude_outputs/patent_priority_v2.csv", replace
