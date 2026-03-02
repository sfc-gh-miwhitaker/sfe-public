/*******************************************************************************
 * DEMO PROJECT: Cortex Cost Calculator - Data Quality Tests
 *
 * AUTHOR: SE Community
 * CREATED: 2026-01-05
 * See deploy_all.sql for expiration (30 days)
 *
 * PURPOSE:
 *   Comprehensive data quality validation for Cortex usage data.
 *   Identifies data anomalies, missing data, and quality issues.
 *
 * TEST CATEGORIES:
 *   1. Completeness - Missing dates, gaps in data
 *   2. Accuracy - Calculation errors, inconsistencies
 *   3. Validity - Value ranges, data types
 *   4. Consistency - Cross-view data matching
 *
 * VERSION: 1.0
 * LAST UPDATED: 2026-02-18
 ******************************************************************************/

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE;

-- ===========================================================================
-- DATA QUALITY REPORT
-- ===========================================================================

-- === DATA QUALITY REPORT ===

-- ===========================================================================
-- 1. COMPLETENESS CHECKS
-- ===========================================================================

-- ---
-- === COMPLETENESS CHECKS ===

-- Check 1: Date gaps in daily summary
WITH date_series AS (
    SELECT DATEADD('day', SEQ4(), DATEADD('day', -30, CURRENT_DATE())) AS expected_date
    FROM TABLE(GENERATOR(ROWCOUNT => 31))
),
actual_dates AS (
    SELECT DISTINCT usage_date FROM V_CORTEX_DAILY_SUMMARY
    WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
)
SELECT
    'Missing Dates' AS check_name,
    COUNT(*) AS missing_count,
    LISTAGG(expected_date::VARCHAR, ', ') AS missing_dates
FROM date_series d
LEFT JOIN actual_dates a ON d.expected_date = a.usage_date
WHERE a.usage_date IS NULL;

-- Check 2: Services with no recent data
SELECT
    'Services with No Recent Data' AS check_name,
    service_type,
    MAX(usage_date) AS last_data_date,
    DATEDIFF('day', MAX(usage_date), CURRENT_DATE()) AS days_since_last_data
FROM V_CORTEX_DAILY_SUMMARY
GROUP BY service_type
HAVING days_since_last_data > 7
ORDER BY days_since_last_data DESC;

-- Check 3: NULL value counts by column
SELECT
    'NULL Values by Column' AS check_name,
    SUM(CASE WHEN service_type IS NULL THEN 1 ELSE 0 END) AS null_service_type,
    SUM(CASE WHEN total_credits IS NULL THEN 1 ELSE 0 END) AS null_total_credits,
    SUM(CASE WHEN daily_unique_users IS NULL THEN 1 ELSE 0 END) AS null_daily_users,
    SUM(CASE WHEN total_operations IS NULL THEN 1 ELSE 0 END) AS null_operations
FROM V_CORTEX_DAILY_SUMMARY;

-- ===========================================================================
-- 2. ACCURACY CHECKS
-- ===========================================================================

-- ---
-- === ACCURACY CHECKS ===

-- Check 4: Calculation accuracy - credits_per_user
SELECT
    'Incorrect credits_per_user Calculations' AS check_name,
    COUNT(*) AS error_count,
    SUM(total_credits) AS total_credits_affected
FROM V_CORTEX_DAILY_SUMMARY
WHERE daily_unique_users > 0
  AND ABS(credits_per_user - (total_credits / daily_unique_users)) > 0.01;

-- Check 5: Credits sum consistency across views
WITH summary_totals AS (
    SELECT SUM(total_credits) AS summary_credits
    FROM V_CORTEX_DAILY_SUMMARY
    WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
),
export_totals AS (
    SELECT SUM(total_credits) AS export_credits
    FROM V_CORTEX_COST_EXPORT
    WHERE date >= DATEADD('day', -30, CURRENT_DATE())
)
SELECT
    'Credits Sum Consistency' AS check_name,
    s.summary_credits,
    e.export_credits,
    ABS(s.summary_credits - e.export_credits) AS difference,
    CASE
        WHEN ABS(s.summary_credits - e.export_credits) < 0.01 THEN 'PASS'
        ELSE 'FAIL - Views out of sync'
    END AS status
FROM summary_totals s, export_totals e;

-- ===========================================================================
-- 3. VALIDITY CHECKS
-- ===========================================================================

-- ---
-- === VALIDITY CHECKS ===

-- Check 6: Value ranges
SELECT
    'Value Range Validation' AS check_name,
    SUM(CASE WHEN total_credits < 0 THEN 1 ELSE 0 END) AS negative_credits,
    SUM(CASE WHEN total_credits > 10000 THEN 1 ELSE 0 END) AS extremely_high_credits,
    SUM(CASE WHEN daily_unique_users < 0 THEN 1 ELSE 0 END) AS negative_users,
    SUM(CASE WHEN daily_unique_users > 10000 THEN 1 ELSE 0 END) AS extremely_high_users,
    SUM(CASE WHEN total_operations < 0 THEN 1 ELSE 0 END) AS negative_operations
FROM V_CORTEX_DAILY_SUMMARY;

-- Check 7: Date validity
SELECT
    'Date Validity' AS check_name,
    SUM(CASE WHEN usage_date > CURRENT_DATE() THEN 1 ELSE 0 END) AS future_dates,
    SUM(CASE WHEN usage_date < '2020-01-01' THEN 1 ELSE 0 END) AS dates_too_old,
    MIN(usage_date) AS earliest_date,
    MAX(usage_date) AS latest_date
FROM V_CORTEX_DAILY_SUMMARY;

-- Check 8: Service type validity
SELECT
    'Unknown Service Types' AS check_name,
    service_type,
    COUNT(*) AS occurrence_count
FROM V_CORTEX_DAILY_SUMMARY
WHERE service_type NOT IN (
    'Cortex Analyst',
    'Cortex Search',
    'Cortex Search Serving',
    'Cortex Functions',
    'Document AI',
    'Cortex Fine-tuning'
)
GROUP BY service_type;

-- ===========================================================================
-- 4. CONSISTENCY CHECKS
-- ===========================================================================

-- ---
-- === CONSISTENCY CHECKS ===

-- Check 9: Duplicate detection
SELECT
    'Duplicate Date-Service Records' AS check_name,
    usage_date,
    service_type,
    COUNT(*) AS duplicate_count
FROM V_CORTEX_DAILY_SUMMARY
GROUP BY usage_date, service_type
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- ===========================================================================
-- DATA QUALITY SCORE
-- ===========================================================================

-- ---
-- === DATA QUALITY SCORE ===

WITH quality_metrics AS (
    SELECT
        -- Completeness score (0-100)
        CASE
            WHEN (SELECT COUNT(DISTINCT usage_date) FROM V_CORTEX_DAILY_SUMMARY WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())) >= 25
            THEN 100
            ELSE (SELECT COUNT(DISTINCT usage_date) * 100.0 / 30 FROM V_CORTEX_DAILY_SUMMARY WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE()))
        END AS completeness_score,

        -- Accuracy score (0-100)
        100 - (
            SELECT COUNT(*) * 10 FROM V_CORTEX_DAILY_SUMMARY
            WHERE daily_unique_users > 0
              AND ABS(credits_per_user - (total_credits / daily_unique_users)) > 0.01
        ) AS accuracy_score,

        -- Validity score (0-100)
        100 - (
            SELECT (
                SUM(CASE WHEN total_credits < 0 THEN 1 ELSE 0 END) +
                SUM(CASE WHEN daily_unique_users < 0 THEN 1 ELSE 0 END)
            ) * 5
            FROM V_CORTEX_DAILY_SUMMARY
        ) AS validity_score,

        -- Consistency score (0-100)
        CASE
            WHEN (SELECT COUNT(*) FROM (
                SELECT date, service_type, COUNT(*) AS cnt
                FROM V_CORTEX_DAILY_SUMMARY
                GROUP BY date, service_type
                HAVING cnt > 1
            )) = 0
            THEN 100
            ELSE 50
        END AS consistency_score
)
SELECT
    completeness_score,
    accuracy_score,
    validity_score,
    consistency_score,
    ROUND((completeness_score + accuracy_score + validity_score + consistency_score) / 4, 2) AS overall_quality_score,
    CASE
        WHEN ((completeness_score + accuracy_score + validity_score + consistency_score) / 4) >= 90 THEN 'EXCELLENT'
        WHEN ((completeness_score + accuracy_score + validity_score + consistency_score) / 4) >= 75 THEN 'GOOD'
        WHEN ((completeness_score + accuracy_score + validity_score + consistency_score) / 4) >= 60 THEN 'FAIR'
        ELSE 'POOR'
    END AS quality_rating
FROM quality_metrics;

-- ===========================================================================
-- RECOMMENDATIONS
-- ===========================================================================

-- ---
-- === RECOMMENDATIONS ===

WITH issues AS (
    SELECT COUNT(*) AS missing_dates FROM (
        WITH date_series AS (
            SELECT DATEADD('day', SEQ4(), DATEADD('day', -30, CURRENT_DATE())) AS expected_date
            FROM TABLE(GENERATOR(ROWCOUNT => 31))
        ),
        actual_dates AS (
            SELECT DISTINCT usage_date FROM V_CORTEX_DAILY_SUMMARY WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
        )
        SELECT d.expected_date FROM date_series d
        LEFT JOIN actual_dates a ON d.expected_date = a.usage_date
        WHERE a.usage_date IS NULL
    ),
    (SELECT COUNT(*) AS calc_errors FROM V_CORTEX_DAILY_SUMMARY
     WHERE daily_unique_users > 0 AND ABS(credits_per_user - (total_credits / daily_unique_users)) > 0.01) AS errors,
    (SELECT COUNT(*) AS negative_values FROM V_CORTEX_DAILY_SUMMARY WHERE total_credits < 0) AS negatives
)
SELECT
    CASE
        WHEN missing_dates > 5 THEN 'Investigate missing dates - possible data pipeline issue'
        WHEN calc_errors > 0 THEN 'Fix calculation errors in views'
        WHEN negative_values > 0 THEN 'Investigate negative credit values'
        ELSE 'No critical issues detected'
    END AS recommendation
FROM issues;

/*******************************************************************************
 * END OF DATA QUALITY REPORT
 ******************************************************************************/
