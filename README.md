# PatentClock

**A standardized earliest-priority-date dataset for U.S. utility patents, 1980–2024.**

Kyoungah Noh (Toss Insight) · Developed under the NBER Innovation Information Initiative (I3) Open Data Fellowship (2025)
Data: [Zenodo DOI TBD] · Paper: [TBD] · Contact: knoh@toss.im

## What this is

Patent application filing dates are routinely used as proxies for the timing of invention, but they record an administrative milestone, not the start of inventive activity. PatentClock resolves each granted U.S. utility patent's domestic continuation chain (provisional, continuation, continuation-in-part, division) together with its foreign priority claims into a single standardized **earliest priority date**.

Headline facts from the data: 65% of U.S. utility patents (filing years 1980–2024) have an earliest priority date before their filing month; the gap clusters at the 12-month statutory priority window; and the share of patents with a gap of one year or more grew from 27% (1980 filings) to 67% (2022 filings).

## Files

| File | Description |
|---|---|
| `patent_priority_v3_250319.csv` / `.dta` | Main dataset: 13,530,767 rows, 7,826,210 utility patents. One row per chain document per patent |
| `patent_priority_v3 (260809).do` | Full construction code (Stata). Rebuilds the dataset end-to-end from PatentsView bulk zips |
| `figure1 (260809).do` | Replication code for Figure 1 |
| `validation_auto_compared.csv` | 300-patent stratified validation sample with front-page adjudications |
| `validation_spotcheck_30.csv` | 30-patent spot-check of auto-matched cases |
| `pre1970_review_classified.csv` | Classification of all pre-1970 priority dates (incl. the Lemelson submarine family) |

## Source data and vintage

Built from four USPTO PatentsView bulk tables — `g_patent`, `g_application`, `g_us_rel_doc`, `g_foreign_priority` — downloaded as a synchronized batch on **2025-03-19** (grant coverage through **2024-12-31**; the release's `g_patent` and `g_us_rel_doc` share an identical maximum patent id, confirming a synchronized cut). PatentsView bulk data are distributed via the [USPTO Open Data Portal](https://data.uspto.gov) following the platform's 2026 migration.

**Vintage warning:** all four input tables must come from one synchronized release. Mixing releases silently strips family links from recently granted patents and shifts their priority dates later (we measured 40,145 affected patents when mixing a Q1-2025 `g_patent` with a 2024-year-end `g_us_rel_doc`). The build script enforces this by re-extracting every input from a single dated batch; to rebuild on a newer release, change the `vintage` and `rawdir` locals at the top of the .do file.

## Variables

| Variable | Description |
|---|---|
| `priority_year`, `priority_date` | Earliest priority claim: min{earliest foreign filing, earliest provisional, earliest non-provisional in chain} |
| `patent_id` | USPTO patent number |
| `fam_doc_number`, `fam_doc_type`, `fam_doc_date` | This row's chain document: application (self), us-provisional-application, continuation, continuation-in-part, or division |
| `patent_date` | Grant date |
| `foreign_country_filed`, `foreign_filing_date` | Earliest foreign priority claim, if any (empty if none) |
| `family_size`, `family_order` | Documents in the domestic chain; this document's rank by filing date |
| `patent_type`, `patent_title`, `wipo_kind`, `num_claims` | Bibliographic fields |
| `qc_flag` | Empty (clean, 99.98%), `invalid_priority_year` (260 patents; raw date corruptions, e.g. `0110-08-04` for 2010-08-04), `pre1970_review` (427 patents; 88% provably raw errors via the 12-month legality rule, 6 confirmed genuine pre-GATT chains incl. Jerome Lemelson's 1954 family) |
| `foreign_gap_months`, `foreign_window` | Legal-window diagnostics for the foreign claim: `within_12mo` / `grace_13_14` / `gap_15_24` / `pct_25_31` (PCT national-phase window) / `over_31` / `foreign_after_us`. Values are preserved, never recomputed — filter to your own tolerance |

## Validation summary

A stratified 300-patent sample (100 singletons / 100 chains / 100 foreign-priority) was checked against Google Patents and every discrepancy manually adjudicated against the printed patent front page: **94.0% agreement**; all 18 disagreements are source coverage gaps (parent/provisional links absent from `g_us_rel_doc`, concentrated in pre-2000 filings: 36% of pre-2000 singletons vs 0% of 2000+ singletons), all biasing the priority date **late, never early**; zero construction-logic errors. A 30-patent spot-check of auto-matched cases confirmed all 30. QC-flag populations are identical across three PatentsView release vintages.

## Known limitations

1. **CIP claims:** claims added in a continuation-in-part may not be entitled to the parent's date; the dataset dates the chain, not individual claims.
2. **No chain-inherited foreign priority:** foreign/PCT priority is recorded as claimed by the patent itself; a foreign priority reachable only through a parent application is not inherited (family-level sources such as Google Patents may therefore report earlier dates).
3. **Pre-2000 chain undercapture:** `g_us_rel_doc` misses some pre-2001-era parent links (see Validation), so some early singletons are actually chain members. Bias is conservative (dates too late).
4. **Coverage-edge truncation:** with grant coverage ending 2024-12-31, late filing cohorts are observed only if granted quickly; end filing-year analyses two years before the cut.

## Rebuilding

Requires Stata 16+ and the four PatentsView zips in `raw data/PatentsView (YYMMDD)/`. Then:

```stata
do "patent_priority_v3 (260809).do"   // set `vintage' and `rawdir' at the top
do "figure1 (260809).do"              // Figure 1
```

Expected checks are printed inline (row counts, qc_flag and foreign_window tabs, Figure 1 cross-check targets).

## Citation

> Noh, Kyoungah (2026). "PatentClock: A Standardized Earliest-Priority-Date Dataset for U.S. Utility Patents." [Journal TBD]. Data: Zenodo, [DOI TBD].

License: data CC-BY-4.0, code MIT. Please also credit USPTO PatentsView as the underlying source.
