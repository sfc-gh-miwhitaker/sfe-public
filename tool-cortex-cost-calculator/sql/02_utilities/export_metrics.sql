/*******************************************************************************
 * DEMO PROJECT: Cortex Cost Calculator - Metrics Export Utility
 *
 * PURPOSE:
 *   Extract Cortex usage data for cost analysis in Streamlit calculator.
 *   Designed for Solution Engineer two-account workflow.
 *
 * WORKFLOW:
 *   Customer Account -> Run export -> Download CSV -> Your Account -> Upload to calculator
 *
 * PREREQUISITES:
 *   - Monitoring views deployed (sql/01_deployment/deploy_cortex_monitoring.sql)
 *   - IMPORTED PRIVILEGES on SNOWFLAKE database
 *   - At least 7-14 days of Cortex usage for meaningful analysis
 *
 * USAGE:
 *   1. Run query in CUSTOMER'S Snowflake account
 *   2. Click "Download" -> Save as CSV
 *   3. Upload CSV to YOUR Streamlit calculator
 *   4. Calculator generates credit projections
 *   5. Export summary for sales/pricing team
 *
 * VERSION: 3.3 (Updated Feb 2026)
 * LAST UPDATED: 2025-12-02
 ******************************************************************************/

-- ===========================================================================
-- OPTION 1: REAL-TIME DATA EXPORT (Recommended for Most Cases)
-- ===========================================================================
-- Source: V_CORTEX_COST_EXPORT (queries ACCOUNT_USAGE live)
-- Use Case: Most up-to-date data, ideal for recent Cortex adoption
-- Performance: Slightly slower than snapshot-based query
-- Data Range: Default 90 days (adjust WHERE clause as needed)
--
-- Note: ROUND() functions prevent scientific notation in CSV exports
--       This ensures consistent display between CSV and Streamlit UI

SELECT
    date,
    service_type,
    daily_unique_users,
    total_operations,
    ROUND(total_credits, 8) AS total_credits,
    ROUND(credits_per_user, 8) AS credits_per_user,
    ROUND(credits_per_operation, 12) AS credits_per_operation
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_COST_EXPORT
WHERE date >= DATEADD('day', -90, CURRENT_DATE())  -- Adjust range: -30, -60, -180 days
ORDER BY date DESC, total_credits DESC;

-- ===========================================================================
-- OPTION 2: SNAPSHOT DATA EXPORT (Faster for Large Datasets)
-- ===========================================================================
-- Source: V_CORTEX_USAGE_HISTORY (reads from CORTEX_USAGE_SNAPSHOTS table)
-- Use Case: 4-5x faster queries, ideal for long-term analysis
-- Performance: Optimized for speed (pre-aggregated snapshots)
-- Data Lag: Data captured at 3:00 AM Pacific (may be 1 day behind)
-- Bonus: Includes trend metrics (credits_7d_ago, week-over-week growth)
--
-- Uncomment to use:
/*
SELECT
    date,
    service_type,
    daily_unique_users,
    total_operations,
    ROUND(total_credits, 8) AS total_credits,
    ROUND(credits_per_user, 8) AS credits_per_user,
    ROUND(credits_per_operation, 12) AS credits_per_operation,
    ROUND(credits_7d_ago, 8) AS credits_7d_ago,
    credits_wow_growth_pct
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_USAGE_HISTORY
WHERE date >= DATEADD('day', -90, CURRENT_DATE())
ORDER BY date DESC, total_credits DESC;
*/

-- ===========================================================================
-- OPTION 3: AISQL FUNCTION-LEVEL DETAIL (For Function/Model Analysis)
-- ===========================================================================
-- Source: V_AISQL_FUNCTION_SUMMARY (aggregated function/model metrics)
-- Use Case: Detailed cost breakdown by LLM function and model
-- Granularity: Per-function per-model (e.g., COMPLETE with gemma-7b vs llama3.1-8b)
-- Analysis: Compare serverless vs warehouse usage, identify cost-per-million-tokens
--
-- Uncomment to use:
/*
SELECT
    function_name,
    model_name,
    call_count,
    ROUND(total_credits, 8) AS total_credits,
    total_tokens,
    ROUND(avg_credits_per_call, 8) AS avg_credits_per_call,
    ROUND(avg_tokens_per_call, 2) AS avg_tokens_per_call,
    ROUND(cost_per_million_tokens, 8) AS cost_per_million_tokens,
    serverless_calls,
    compute_calls,
    first_usage,
    last_usage
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_AISQL_FUNCTION_SUMMARY
ORDER BY total_credits DESC;
*/

-- ===========================================================================
-- EXPECTED OUTPUT COLUMNS
-- ===========================================================================
-- Option 1 & 2 Output:
--   date                  - Usage date (YYYY-MM-DD)
--   service_type          - Cortex Analyst, Search, Functions, Document AI, etc.
--   daily_unique_users    - Number of unique users (where available)
--   total_operations      - Requests, tokens, messages, pages processed
--   total_credits         - Actual Snowflake credits consumed
--   credits_per_user      - Average credits per user per day
--   credits_per_operation - Average credits per operation
--
-- Option 3 Output:
--   function_name         - Cortex function (COMPLETE, TRANSLATE, SUMMARIZE)
--   model_name            - LLM model (gemma-7b, llama3.1-8b, mistral-large)
--   call_count            - Number of function calls
--   total_credits         - Total credits consumed
--   cost_per_million_tokens - Cost efficiency metric

-- ===========================================================================
-- DATA QUALITY CHECKS (Optional - Run Before Export)
-- ===========================================================================

-- Check 1: Verify data exists and date range
SELECT
    COUNT(*) AS total_rows,
    MIN(date) AS earliest_date,
    MAX(date) AS latest_date,
    DATEDIFF('day', MIN(date), MAX(date)) AS days_of_history,
    COUNT(DISTINCT service_type) AS service_count
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_COST_EXPORT;
-- Expected: total_rows > 0, days_of_history >= 7, service_count between 1-7

-- Check 2: Service breakdown by credits
SELECT
    service_type,
    COUNT(DISTINCT date) AS days_with_data,
    ROUND(SUM(total_credits), 8) AS total_credits,
    ROUND(AVG(daily_unique_users), 2) AS avg_daily_users,
    ROUND(AVG(credits_per_operation), 8) AS avg_cost_per_operation
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_COST_EXPORT
GROUP BY service_type
ORDER BY total_credits DESC;

-- Check 3: Recent activity (last 7 days) - Spot-check data quality
SELECT
    date,
    service_type,
    ROUND(total_credits, 8) AS total_credits,
    total_operations
FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.V_CORTEX_COST_EXPORT
WHERE date >= DATEADD('day', -7, CURRENT_DATE())
ORDER BY date DESC, total_credits DESC;

-- ===========================================================================
-- EXPORT WORKFLOW (For Solution Engineers)
-- ===========================================================================
--
-- IN CUSTOMER'S ACCOUNT:
-- ----------------------
-- STEP 1: Run your chosen extraction query (Option 1, 2, or 3 above)
-- STEP 2: Verify data returned (if no data, see Troubleshooting below)
-- STEP 3: Click "Download" -> Select "CSV" format
-- STEP 4: Save as: customer_name_cortex_usage_YYYYMMDD.csv
--
-- IN YOUR ACCOUNT:
-- ----------------
-- STEP 5: Open YOUR Streamlit calculator (Projects -> Streamlit)
-- STEP 6: Select "Upload Customer CSV" data source
-- STEP 7: Upload the CSV file downloaded from customer
--
-- ANALYZE & EXPORT:
-- -----------------
-- STEP 8: Calculator displays:
--         - Historical usage trends
--         - Cost projections (3, 6, 12, 24 months)
--         - Per-user cost estimates
--         - Service-level breakdown
--
-- STEP 9: Export results:
--         - Download "Credit Estimate Summary" spreadsheet
--         - Share with sales/pricing team for proposal
--
-- ===========================================================================
-- TROUBLESHOOTING
-- ===========================================================================
--
-- ISSUE: "No data returned"
-- CAUSE: Customer has no Cortex usage or insufficient history
-- FIX:
--   1. Verify Cortex usage:
--      SELECT usage_date, service_type, credits_used
--      FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
--      WHERE service_type = 'AI_SERVICES'
--      ORDER BY usage_date DESC LIMIT 10;
--   2. Minimum 7-14 days of Cortex usage recommended for analysis
--
-- ISSUE: "View doesn't exist"
-- CAUSE: Monitoring views not deployed
-- FIX: Run sql/01_deployment/deploy_cortex_monitoring.sql first
--
-- ISSUE: "Permission denied"
-- CAUSE: Missing IMPORTED PRIVILEGES on SNOWFLAKE database
-- FIX: Run as ACCOUNTADMIN:
--      GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <your_role>;
--
-- ISSUE: "Wrong date range" or "Need more history"
-- CAUSE: Default 90-day range may not match your needs
-- FIX: Adjust WHERE clause in extraction query:
--      - Last 30 days: WHERE date >= DATEADD('day', -30, CURRENT_DATE())
--      - Last 180 days: WHERE date >= DATEADD('day', -180, CURRENT_DATE())
--      - All history: Remove WHERE clause entirely
--
-- ISSUE: "Scientific notation in CSV"
-- CAUSE: Excel/spreadsheet formatting issue
-- FIX: Already handled by ROUND() functions in queries. If still occurs,
--      open CSV in text editor to verify raw values are decimal format.
--
-- ===========================================================================
