/**************************************************************************
 Project: PatentClock (WPI submission version)
 Purpose: Figures 1-3 as SEPARATE files (Elsevier artwork rule: no
          combined multi-panel figures). Replaces the combined Figure 1
          of "figure1 (260809).do"; panel content is unchanged.
 Author:  Kyoungah Noh · 2026-09-03
 Input:   claude_outputs/patent_priority_v3_`vintage'.dta
 Output:  claude_outputs/Figure_1.pdf/.png  (gap distribution)
          claude_outputs/Figure_2.pdf/.png  (>=12/24-month shares by year)
          claude_outputs/Figure_3.pdf/.png  (source of earliest date)

 Cross-check targets (unchanged from the combined version):
   - Analysis N (application rows, QC-clean, dm>=0) = 7,825,523
   - Share with priority earlier than filing month   = 65.2%
   - dm==0 share = 35% ; dm==12 spike = 28%
   - Skipped: 687 QC-flagged, 0 negative-gap patents
**************************************************************************/

clear
cd "/Users/knoh/Desktop/i3 work"
local vintage 250319

use "claude_outputs/patent_priority_v3_`vintage'.dta", clear

////////////////////////////////////////////////////////////
* 1) Patent-level analysis frame (one row per patent)
////////////////////////////////////////////////////////////

* earliest-doc type per patent (family_order==1 row), for Figure 3
bys patent_id (family_order): gen etype = fam_doc_type[1]

keep if fam_doc_type=="application"
drop if qc_flag!=""                          // expect 687 drops

gen pdd = date(priority_date, "YMD")
gen fdd = date(fam_doc_date, "YMD")          // application filing date
gen dm  = (year(fdd)*12 + month(fdd)) - (year(pdd)*12 + month(pdd))
assert dm >= 0                               // expect no violations
gen fy  = year(fdd)

count
di as res "Analysis N = " r(N) "  (target 7,825,523)"
qui count if dm>0
di as res "Share priority < filing month = " %4.1f 100*r(N)/_N "%  (target 65.2)"

* source of the earliest date, for Figure 3
gen src = ""
replace src = "none"    if priority_date==fam_doc_date
replace src = "foreign" if src=="" & foreign_filing_date==priority_date
replace src = "PRO"     if src=="" & etype=="us-provisional-application"
replace src = "CON"     if src=="" & etype=="continuation"
replace src = "CIP"     if src=="" & etype=="continuation-in-part"
replace src = "DIV"     if src=="" & etype=="division"

tempfile analysis
save `analysis'

////////////////////////////////////////////////////////////
* 2) Figure 1: distribution of the priority-filing gap (months)
*    (journal version: no embedded title -- the caption carries it)
////////////////////////////////////////////////////////////

use `analysis', clear
gen dmb = cond(dm>60, 61, dm)                // top-code at 60+
contract dmb
egen tot = total(_freq)
gen share = 100*_freq/tot

twoway (bar share dmb, barwidth(0.85) color("42 120 214")) ///
       (pci 33.3 2.6 34.8 0.7, lcolor(gs10) lwidth(thin)) ///
       (pci 26.3 15.9 27.6 12.7, lcolor(gs10) lwidth(thin)), ///
    text(32 3.0 "same month" "35%", ///
         placement(e) size(small) color(gs5) justification(left)) ///
    text(24.5 16.3 "12-month spike: 28%" "(provisional & Paris Convention" "priority window)", ///
         placement(e) size(small) color(gs5) justification(left)) ///
    text(34 61 "65% of patents have a priority date" "earlier than their filing month", ///
         placement(w) size(small) color(gs5) justification(right)) ///
    xlabel(0 6 12 18 24 36 48 61 "60+", labsize(small)) ///
    ylabel(0(5)35, angle(0) labsize(small)) ///
    xtitle("Months between earliest priority date and application filing date", size(small)) ///
    ytitle("Share of patents (%)", size(small)) ///
    legend(off) ///
    graphregion(color(white)) plotregion(margin(small)) ///
    xsize(10) ysize(5.5) ///
    name(fig1, replace)

graph export "claude_outputs/Figure_1.pdf", replace
graph export "claude_outputs/Figure_1.png", replace width(2400)

////////////////////////////////////////////////////////////
* 3) Figure 2: share with gap >= 12 / 24 months, by filing year
*    (end at 2022: later cohorts selected on fast grants,
*     given the 2024-12-31 grant-coverage cut)
////////////////////////////////////////////////////////////

use `analysis', clear
keep if inrange(fy, 1980, 2022)
gen ge12 = 100*(dm>=12)
gen ge24 = 100*(dm>=24)
collapse (mean) ge12 ge24, by(fy)

twoway (line ge12 fy, lwidth(medthick) lcolor("42 120 214"))  ///
       (line ge24 fy, lwidth(medthick) lcolor("235 104 52")), ///
    xlabel(1980(10)2020, labsize(small)) ylabel(0(20)80, angle(0) labsize(small)) ///
    xtitle("Application filing year", size(small)) ///
    ytitle("Share of patents (%)", size(small)) ///
    legend(order(1 "gap ≥ 12 mo." 2 "gap ≥ 24 mo.") ring(0) pos(11) cols(1) size(small) region(lstyle(none))) ///
    graphregion(color(white)) ///
    xsize(7.5) ysize(5.5) ///
    name(fig2, replace)

graph export "claude_outputs/Figure_2.pdf", replace
graph export "claude_outputs/Figure_2.png", replace width(2400)

////////////////////////////////////////////////////////////
* 4) Figure 3: source of the earliest date, by filing year
////////////////////////////////////////////////////////////

use `analysis', clear
keep if inrange(fy, 1980, 2022)
gen n = 1
collapse (count) n, by(fy src)
bys fy: egen tot = total(n)
gen share = 100*n/tot
keep fy src share
reshape wide share, i(fy) j(src) string
foreach s in none foreign PRO CON CIP DIV {
    capture confirm variable share`s'
    if _rc gen share`s' = 0
    replace share`s' = 0 if missing(share`s')
}
* cumulative stack: none -> foreign -> PRO -> CON -> CIP -> DIV
gen c1 = sharenone
gen c2 = c1 + shareforeign
gen c3 = c2 + sharePRO
gen c4 = c3 + shareCON
gen c5 = c4 + shareCIP
gen c6 = c5 + shareDIV

twoway (area c6 fy, color("232 123 164")) ///
       (area c5 fy, color("237 161 0"))   ///
       (area c4 fy, color("27 175 122"))  ///
       (area c3 fy, color("235 104 52"))  ///
       (area c2 fy, color("42 120 214"))  ///
       (area c1 fy, color(gs12)),         ///
    xlabel(1980(10)2020, labsize(small)) ylabel(0(20)100, angle(0) labsize(small)) ///
    xtitle("Application filing year", size(small)) ///
    ytitle("Share of patents (%)", size(small)) ///
    legend(order(6 "No earlier claim" 5 "Foreign priority" 4 "Provisional" 3 "Continuation" 2 "Cont.-in-part" 1 "Division") ///
           size(vsmall) cols(3) pos(6) region(lstyle(none))) ///
    graphregion(color(white)) ///
    xsize(7.5) ysize(5.5) ///
    name(fig3, replace)

graph export "claude_outputs/Figure_3.pdf", replace
graph export "claude_outputs/Figure_3.png", replace width(2400)

di as res "Done: Figure_1 / Figure_2 / Figure_3 (.pdf + .png) written to claude_outputs"
