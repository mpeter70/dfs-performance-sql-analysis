# Data Dictionary — DFS Performance Analysis

Documents the `contest_history` table in the `DFS_Performance` SQL Server database, how each reported metric is calculated, and which query produces it.

> **Before publishing:** lines marked **CONFIRM** are inferred from the queries and result exports, not from the table itself. Run the schema query at the bottom of this file and correct them.

## 1. Source

| Item | Value |
|---|---|
| Source system | DraftKings contest history export (CSV) |
| Loaded into | SQL Server, database `DFS_Performance`, table `contest_history` |
| Grain | One row per contest entry |
| Row count | 28,491 |
| Date range | 2015-09-13 to 2021-02-24 (Eastern time) |
| Sports | 13 distinct values in `Sport` |

## 2. Fields

| Field | Type (observed) | Origin | Definition | Notes |
|---|---|---|---|---|
| `entry_id` | INT | Added on load — **CONFIRM** | Unique row identifier for one contest entry | Used only in Query 5 |
| `Entry` | VARCHAR | DraftKings export | Contest name as DraftKings displays it, e.g. `NFL $300K Wildcat [$50K to 1st, 3 Entry Max]` | Parsed with `LIKE` in Query 7 to derive contest type |
| `Sport` | VARCHAR | DraftKings export | Sport or league of the contest (NFL, MLB, NBA, NHL, CS:GO, …) | Rows with NULL `Sport` are excluded in Query 2 |
| `Contest_Date_EST` | DATETIME | DraftKings export | Contest start date and time, Eastern | Truncated to date in Query 10, month in Query 6, year in Query 9 |
| `Entry_Fee` | DECIMAL | DraftKings export | Amount paid to enter, USD | 125 rows have `Entry_Fee = 0` (free contests); Query 3 excludes them |
| `Place_Clean` | INT | Cleaned from export column `Place` — **CONFIRM** cleaning step | Finish position (1 = first place) | **CONFIRM** what was removed (text, blanks) to make it numeric |
| `Contest_Entries_Clean` | INT | Cleaned from export column `Contest_Entries` — **CONFIRM** | Total entries in the contest (field size) | Same cleaning question as `Place_Clean` |
| `total_winnings` | DECIMAL | Calculated column | Total payout for the entry, USD | **CONFIRM** formula — e.g. cash winnings + ticket winnings from the export |
| `profit` | DECIMAL | Calculated column | `total_winnings − Entry_Fee` | Verified against Query 5: $50,000 − $333 = $49,667 |
| `roi_pct` | DECIMAL | Calculated column | `profit / Entry_Fee × 100` for that single entry | Verified against Query 5: 49,667 / 333 × 100 = 14,915.02. **CONFIRM** value when `Entry_Fee = 0` |

## 3. Metric definitions

The project reports two ROI calculations and two hit-rate measures. Conclusions use **portfolio ROI**; the per-entry average is shown only for comparison.

| Metric | Formula | Used in | All-contest value |
|---|---|---|---|
| **ROI (portfolio)** | `SUM(total_winnings) / SUM(Entry_Fee) − 1`, × 100 | Queries 2, 3, 4, 6, 7, 9, 10 (`portfolio_roi_pct` in 3, 4, 7) | **62.74%** — the headline figure |
| **Average ROI per entry** | `AVG(roi_pct)` | Query 1; `avg_entry_roi_pct` in Queries 3, 4, 7 | **42.69%** (Query 1) — weights a $1 entry the same as a $333 entry; comparison only |
| **Profit rate** | entries with `profit > 0` ÷ all entries | Queries 1, 2 (column `win_rate_pct`); README "Profit Rate" | **35.80%** (10,199 entries) |
| **Placement rate** | entries not in Query 8's "Did Not Cash" bucket ÷ all entries | Query 8; README "Placement Rate" | **47.75%** — counts any top-100 finish even if it paid less than the fee |
| **First-place rate** | entries with `Place_Clean = 1` ÷ all entries | Query 8 | **7.68%** (2,187 entries), including head-to-head wins |

## 4. Source-to-report map

| Query | Output | Fields read | Filters | Metrics |
|---|---|---|---|---|
| 1 Overall summary | 1 row | all money fields, `Sport`, `Contest_Date_EST` | none | totals, average ROI per entry, profit rate |
| 2 By sport | 13 rows | `Sport`, money fields | `Sport IS NOT NULL` | portfolio ROI, profit rate |
| 3 By entry-fee tier | 4 rows | `Entry_Fee`, `total_winnings`, `profit`, `roi_pct` | `Entry_Fee > 0` | portfolio ROI; per-entry average, min/max for comparison |
| 4 By field size | 5 rows | `Contest_Entries_Clean`, money fields, `roi_pct` | `Contest_Entries_Clean IS NOT NULL` | portfolio ROI; per-entry average for comparison |
| 5 Top 20 wins | 20 rows | all fields | `total_winnings > 0` | none (row listing) |
| 6 Monthly trend | 64 rows | `Contest_Date_EST`, money fields | `Contest_Date_EST IS NOT NULL` | portfolio ROI by month |
| 7 Contest types | top 15 | `Sport`, `Entry`, `Contest_Entries_Clean`, money fields, `roi_pct` | `Entry IS NOT NULL`, groups with 10+ entries | portfolio ROI by sport × contest type (rules in section 5) |
| 8 Finish distribution | 6 rows | `Place_Clean`, `profit`, `total_winnings` | none | share of entries, total profit by finish bucket |
| 9 Year over year | 7 rows | `Contest_Date_EST`, money fields | `Contest_Date_EST IS NOT NULL` | portfolio ROI by year |
| 10 Cumulative profit | 100 rows | `Contest_Date_EST`, money fields | most recent 100 contest days only | running profit and running portfolio ROI |

## 5. Contest-type rules (Query 7)

Rules run top to bottom; the first match wins.

| Order | Rule | Type | Entries | Share |
|---|---|---|---|---|
| 1 | `Contest_Entries_Clean = 2` | Head-to-Head | 3,273 | 11.49% |
| 2 | name contains `Double Up` | Double Up | 1,642 | 5.76% |
| 3 | name contains `50/50` or `50-50` | 50/50 | 1,823 | 6.40% |
| 4 | name contains `Triple Up`, `Quintuple Up` or `Multiplier` | Multiplier | 1,395 | 4.90% |
| 5 | `Contest_Entries_Clean < 20` | Small League (3-19) | 402 | 1.41% |
| 6 | name contains `to 1st`, `Entry Max`, `Max Entry`, `Single Entry`, `GPP` or `Million`, or `Contest_Entries_Clean >= 100` | Tournament (GPP) | 19,876 | 69.76% |
| 7 | none of the above | Other | 80 | 0.28% |

The first version matched names only and left about 90% of entries as "Other": DraftKings writes `50-50` with a hyphen, calls multipliers "Triple Up", and gives tournaments brand names (Wildcat, Splash, Big Jam) rather than "GPP". Bracketed tags are matched without the brackets because `[ ]` is a wildcard character in SQL Server `LIKE`.

## 6. Known gaps

- **First-place rate includes head-to-head contests.** 3,273 entries are 2-player contests, where first place is far more common than in large tournaments, so 7.68% should not be compared with large-field win rates without separating them.
- **Query 10 shows only the last 100 contest days**, not the full history, because of `TOP 100 … ORDER BY contest_date DESC`.
- **Resolved:** tier, field-size and contest-type ROI previously used the per-entry average while the headline used portfolio ROI; the README's "Win Rate" (47.75%) and Query 1's `win_rate_pct` (35.80%) used different definitions under one name; Query 7 left about 90% of entries as "Other". All three are fixed in the current queries and README.

## Schema check

Run this in SSMS and update section 2 with the real types and nullability:

```sql
SELECT COLUMN_NAME, DATA_TYPE, NUMERIC_PRECISION, NUMERIC_SCALE, IS_NULLABLE
FROM DFS_Performance.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'contest_history'
ORDER BY ORDINAL_POSITION;
```
