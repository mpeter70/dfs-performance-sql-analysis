USE DFS_Performance;
GO


-- ============================================
-- QUERY 1: Overall DFS Performance Summary
-- ============================================
-- Demonstrates: Aggregate functions, calculated metrics, formatting

SELECT 
    COUNT(*) as total_contests,
    COUNT(DISTINCT Sport) as sports_played,
    MIN(Contest_Date_EST) as first_contest,
    MAX(Contest_Date_EST) as last_contest,
    FORMAT(SUM(Entry_Fee), 'C', 'en-US') as total_invested,
    FORMAT(SUM(total_winnings), 'C', 'en-US') as total_won,
    FORMAT(SUM(profit), 'C', 'en-US') as net_profit,
    ROUND(AVG(roi_pct), 2) as avg_roi_pct,
    SUM(CASE WHEN profit > 0 THEN 1 ELSE 0 END) as winning_contests,
    ROUND(CAST(SUM(CASE WHEN profit > 0 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100, 2) as win_rate_pct
FROM contest_history;

-- ============================================
-- QUERY 2: ROI Analysis by Sport
-- ============================================
-- Demonstrates: GROUP BY, multiple aggregates, sorting

SELECT 
    Sport,
    COUNT(*) as contests_entered,
    FORMAT(SUM(Entry_Fee), 'C', 'en-US') as total_invested,
    FORMAT(SUM(total_winnings), 'C', 'en-US') as total_winnings,
    FORMAT(SUM(profit), 'C', 'en-US') as net_profit,
    ROUND((SUM(total_winnings) / NULLIF(SUM(Entry_Fee), 0) - 1) * 100, 2) as roi_pct,
    ROUND(CAST(SUM(CASE WHEN profit > 0 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100, 2) as win_rate_pct
FROM contest_history
WHERE Sport IS NOT NULL
GROUP BY Sport
ORDER BY SUM(profit) DESC;

-- ============================================
-- QUERY 3: Performance by Entry Fee Bracket
-- ============================================
-- Demonstrates: CASE for categorization, HAVING clause

SELECT 
    CASE 
        WHEN Entry_Fee < 5 THEN 'Low Stakes ($0-$5)'
        WHEN Entry_Fee < 20 THEN 'Mid Stakes ($5-$20)'
        WHEN Entry_Fee < 100 THEN 'High Stakes ($20-$100)'
        ELSE 'Premium ($100+)'
    END as stake_level,
    COUNT(*) as contests,
    FORMAT(SUM(profit), 'C', 'en-US') as total_profit,
    ROUND(AVG(roi_pct), 2) as avg_roi_pct,
    ROUND(MIN(roi_pct), 2) as worst_roi,
    ROUND(MAX(roi_pct), 2) as best_roi
FROM contest_history
WHERE Entry_Fee > 0
GROUP BY CASE 
    WHEN Entry_Fee < 5 THEN 'Low Stakes ($0-$5)'
    WHEN Entry_Fee < 20 THEN 'Mid Stakes ($5-$20)'
    WHEN Entry_Fee < 100 THEN 'High Stakes ($20-$100)'
    ELSE 'Premium ($100+)'
END
ORDER BY SUM(profit) DESC;

-- ============================================
-- QUERY 4: Performance by Tournament Size
-- ============================================
-- Demonstrates: Range-based categorization, calculated averages

SELECT 
    CASE 
        WHEN Contest_Entries_Clean < 10 THEN 'Head-to-Head (2-9)'
        WHEN Contest_Entries_Clean < 100 THEN 'Small Field (10-99)'
        WHEN Contest_Entries_Clean < 1000 THEN 'Medium Field (100-999)'
        WHEN Contest_Entries_Clean < 10000 THEN 'Large Field (1K-10K)'
        ELSE 'Massive Field (10K+)'
    END as field_size_category,
    COUNT(*) as contests,
    AVG(Contest_Entries_Clean) as avg_field_size,
    FORMAT(SUM(profit), 'C', 'en-US') as total_profit,
    ROUND(AVG(roi_pct), 2) as avg_roi_pct
FROM contest_history
WHERE Contest_Entries_Clean IS NOT NULL
GROUP BY CASE 
    WHEN Contest_Entries_Clean < 10 THEN 'Head-to-Head (2-9)'
    WHEN Contest_Entries_Clean < 100 THEN 'Small Field (10-99)'
    WHEN Contest_Entries_Clean < 1000 THEN 'Medium Field (100-999)'
    WHEN Contest_Entries_Clean < 10000 THEN 'Large Field (1K-10K)'
    ELSE 'Massive Field (10K+)'
END
ORDER BY avg_field_size;

-- ============================================
-- QUERY 5: Top 20 Biggest Wins
-- ============================================
-- Demonstrates: TOP N queries, multi-column output

SELECT TOP 20
    entry_id,
    Contest_Date_EST,
    Sport,
    FORMAT(Entry_Fee, 'C', 'en-US') as entry_fee,
    Place_Clean as finish_position,
    Contest_Entries_Clean as field_size,
    FORMAT(total_winnings, 'C', 'en-US') as winnings,
    FORMAT(profit, 'C', 'en-US') as profit,
    ROUND(roi_pct, 2) as roi_pct,
    Entry as contest_name
FROM contest_history
WHERE total_winnings > 0
ORDER BY total_winnings DESC;

-- ============================================
-- QUERY 6: Monthly Profit Trend
-- ============================================
-- Demonstrates: Date functions, time-series analysis

SELECT 
    FORMAT(Contest_Date_EST, 'yyyy-MM') as month,
    COUNT(*) as contests,
    FORMAT(SUM(Entry_Fee), 'C', 'en-US') as invested,
    FORMAT(SUM(total_winnings), 'C', 'en-US') as winnings,
    FORMAT(SUM(profit), 'C', 'en-US') as monthly_profit,
    ROUND((SUM(total_winnings) / NULLIF(SUM(Entry_Fee), 0) - 1) * 100, 2) as roi_pct
FROM contest_history
WHERE Contest_Date_EST IS NOT NULL
GROUP BY FORMAT(Contest_Date_EST, 'yyyy-MM')
ORDER BY FORMAT(Contest_Date_EST, 'yyyy-MM');

-- ============================================
-- QUERY 7: Top Contest Types by Profitability
-- ============================================
-- Demonstrates: LIKE pattern matching, HAVING clause filtering

SELECT TOP 15
    Sport,
    CASE 
        WHEN Entry LIKE '%Double Up%' THEN 'Double Up'
        WHEN Entry LIKE '%Head-to-Head%' THEN 'Head-to-Head'
        WHEN Entry LIKE '%GPP%' OR Entry LIKE '%Million%' THEN 'GPP/Major Tournament'
        WHEN Entry LIKE '%50/50%' THEN '50/50'
        WHEN Entry LIKE '%Multiplier%' THEN 'Multiplier'
        ELSE 'Other'
    END as contest_type,
    COUNT(*) as entries,
    FORMAT(SUM(profit), 'C', 'en-US') as total_profit,
    ROUND(AVG(roi_pct), 2) as avg_roi_pct
FROM contest_history
WHERE Entry IS NOT NULL
GROUP BY Sport, 
    CASE 
        WHEN Entry LIKE '%Double Up%' THEN 'Double Up'
        WHEN Entry LIKE '%Head-to-Head%' THEN 'Head-to-Head'
        WHEN Entry LIKE '%GPP%' OR Entry LIKE '%Million%' THEN 'GPP/Major Tournament'
        WHEN Entry LIKE '%50/50%' THEN '50/50'
        WHEN Entry LIKE '%Multiplier%' THEN 'Multiplier'
        ELSE 'Other'
    END
HAVING COUNT(*) > 10  -- Only show contest types with 10+ entries
ORDER BY SUM(profit) DESC;

-- ============================================
-- QUERY 8: Distribution of Finish Positions
-- ============================================
-- Demonstrates: Multi-tier categorization, percentage calculations

SELECT 
    CASE 
        WHEN Place_Clean = 1 THEN '1st Place'
        WHEN Place_Clean <= 3 THEN 'Top 3'
        WHEN Place_Clean <= 10 THEN 'Top 10'
        WHEN Place_Clean <= 100 THEN 'Top 100'
        WHEN profit > 0 THEN 'Cashed (Outside Top 100)'
        ELSE 'Did Not Cash'
    END as finish_category,
    COUNT(*) as contests,
    ROUND(CAST(COUNT(*) AS FLOAT) / (SELECT COUNT(*) FROM contest_history) * 100, 2) as pct_of_total,
    FORMAT(AVG(total_winnings), 'C', 'en-US') as avg_winnings,
    FORMAT(SUM(profit), 'C', 'en-US') as total_profit
FROM contest_history
GROUP BY CASE 
    WHEN Place_Clean = 1 THEN '1st Place'
    WHEN Place_Clean <= 3 THEN 'Top 3'
    WHEN Place_Clean <= 10 THEN 'Top 10'
    WHEN Place_Clean <= 100 THEN 'Top 100'
    WHEN profit > 0 THEN 'Cashed (Outside Top 100)'
    ELSE 'Did Not Cash'
END
ORDER BY SUM(profit) DESC;

-- ============================================
-- QUERY 9: Year-over-Year Performance Comparison
-- ============================================
-- Demonstrates: Date extraction, year-based grouping

SELECT 
    YEAR(Contest_Date_EST) as contest_year,
    COUNT(*) as contests,
    FORMAT(SUM(Entry_Fee), 'C', 'en-US') as total_invested,
    FORMAT(SUM(total_winnings), 'C', 'en-US') as total_winnings,
    FORMAT(SUM(profit), 'C', 'en-US') as net_profit,
    ROUND((SUM(total_winnings) / NULLIF(SUM(Entry_Fee), 0) - 1) * 100, 2) as roi_pct,
    FORMAT(AVG(Entry_Fee), 'C', 'en-US') as avg_entry_fee
FROM contest_history
WHERE Contest_Date_EST IS NOT NULL
GROUP BY YEAR(Contest_Date_EST)
ORDER BY YEAR(Contest_Date_EST);

-- ============================================
-- QUERY 10: Cumulative Profit Growth (Advanced)
-- ============================================
-- Demonstrates: Window functions, cumulative calculations, CTEs

WITH daily_results AS (
    SELECT 
        CAST(Contest_Date_EST AS DATE) as contest_date,
        SUM(Entry_Fee) as daily_invested,
        SUM(total_winnings) as daily_winnings,
        SUM(profit) as daily_profit
    FROM contest_history
    WHERE Contest_Date_EST IS NOT NULL
    GROUP BY CAST(Contest_Date_EST AS DATE)
)
SELECT TOP 100
    contest_date,
    FORMAT(daily_profit, 'C', 'en-US') as daily_profit,
    FORMAT(SUM(daily_profit) OVER (ORDER BY contest_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 'C', 'en-US') as cumulative_profit,
    FORMAT(SUM(daily_invested) OVER (ORDER BY contest_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 'C', 'en-US') as cumulative_invested,
    ROUND((SUM(daily_winnings) OVER (ORDER BY contest_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / 
           NULLIF(SUM(daily_invested) OVER (ORDER BY contest_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 0) - 1) * 100, 2) as cumulative_roi_pct
FROM daily_results
ORDER BY contest_date DESC;