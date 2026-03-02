/*******************************************************************************
 * DEMO PROJECT: Cortex Cost Calculator - SQL Test Suite
 *
 * AUTHOR: SE Community
 * CREATED: 2026-01-05
 * See deploy_all.sql for expiration (30 days)
 *
 * PURPOSE:
 *   Comprehensive testing suite for all SQL views in Cortex Cost Calculator.
 *   Validates view compilation, data quality, and business logic.
 *
 * TEST CATEGORIES:
 *   1. View Compilation Tests - All views can be queried
 *   2. Data Quality Tests - NULL checks, data type validation
 *   3. Business Logic Tests - Calculations, aggregations
 *   4. Performance Tests - Query execution time
 *
 * USAGE:
 *   Run this entire script to validate deployment.
 *   All tests should return "PASS" status.
 *
 * VERSION: 1.0
 * LAST UPDATED: 2026-02-18
 ******************************************************************************/

-- ===========================================================================
-- TEST SETUP
-- ===========================================================================

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE;

-- Create temporary test results table
CREATE OR REPLACE TEMP TABLE TEST_RESULTS (
    test_number INT,
    test_category VARCHAR(100),
    test_name VARCHAR(200),
    test_status VARCHAR(10),  -- PASS, FAIL, WARN
    test_message VARCHAR(500),
    execution_time_ms NUMBER(10,2),
    tested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ===========================================================================
-- TEST CATEGORY 1: VIEW COMPILATION TESTS
-- ===========================================================================
-- Verify all views can be queried without errors

-- Test 1: V_CORTEX_ANALYST_DETAIL
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP();
    row_count INT;
BEGIN
    SELECT COUNT(*) INTO :row_count FROM V_CORTEX_ANALYST_DETAIL;
    INSERT INTO TEST_RESULTS VALUES (
        1, 'Compilation', 'V_CORTEX_ANALYST_DETAIL compiles successfully',
        'PASS', 'View accessible, returned ' || :row_count || ' rows',
        DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
    );
EXCEPTION
    WHEN OTHER THEN
        INSERT INTO TEST_RESULTS VALUES (
            1, 'Compilation', 'V_CORTEX_ANALYST_DETAIL compiles successfully',
            'FAIL', 'Error: ' || SQLERRM,
            DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
        );
END;

-- Test 2: V_CORTEX_SEARCH_DETAIL
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP();
    row_count INT;
BEGIN
    SELECT COUNT(*) INTO :row_count FROM V_CORTEX_SEARCH_DETAIL;
    INSERT INTO TEST_RESULTS VALUES (
        2, 'Compilation', 'V_CORTEX_SEARCH_DETAIL compiles successfully',
        'PASS', 'View accessible',
        DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
    );
EXCEPTION
    WHEN OTHER THEN
        INSERT INTO TEST_RESULTS VALUES (
            2, 'Compilation', 'V_CORTEX_SEARCH_DETAIL compiles successfully',
            'FAIL', 'Error: ' || SQLERRM,
            DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
        );
END;

-- Test 3: V_CORTEX_DAILY_SUMMARY
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP();
    row_count INT;
BEGIN
    SELECT COUNT(*) INTO :row_count FROM V_CORTEX_DAILY_SUMMARY;
    INSERT INTO TEST_RESULTS VALUES (
        3, 'Compilation', 'V_CORTEX_DAILY_SUMMARY compiles successfully',
        'PASS', 'View accessible',
        DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
    );
EXCEPTION
    WHEN OTHER THEN
        INSERT INTO TEST_RESULTS VALUES (
            3, 'Compilation', 'V_CORTEX_DAILY_SUMMARY compiles successfully',
            'FAIL', 'Error: ' || SQLERRM,
            DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
        );
END;

-- Test 4: V_USER_SPEND_ATTRIBUTION
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP();
    row_count INT;
BEGIN
    SELECT COUNT(*) INTO :row_count FROM V_USER_SPEND_ATTRIBUTION;
    INSERT INTO TEST_RESULTS VALUES (
        4, 'Compilation', 'V_USER_SPEND_ATTRIBUTION compiles successfully',
        'PASS', 'View accessible',
        DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
    );
EXCEPTION
    WHEN OTHER THEN
        INSERT INTO TEST_RESULTS VALUES (
            4, 'Compilation', 'V_USER_SPEND_ATTRIBUTION compiles successfully',
            'FAIL', 'Error: ' || SQLERRM,
            DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
        );
END;

-- Test 5: V_CORTEX_USAGE_HISTORY (snapshot-backed history view)
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP();
    row_count INT;
BEGIN
    SELECT COUNT(*) INTO :row_count FROM V_CORTEX_USAGE_HISTORY;
    INSERT INTO TEST_RESULTS VALUES (
        5, 'Compilation', 'V_CORTEX_USAGE_HISTORY compiles successfully',
        'PASS', 'View accessible',
        DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
    );
EXCEPTION
    WHEN OTHER THEN
        INSERT INTO TEST_RESULTS VALUES (
            5, 'Compilation', 'V_CORTEX_USAGE_HISTORY compiles successfully',
            'FAIL', 'Error: ' || SQLERRM,
            DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
        );
END;

-- Test 6: V_USAGE_FORECAST_12M (exists even if empty placeholder)
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP();
    row_count INT;
BEGIN
    SELECT COUNT(*) INTO :row_count FROM V_USAGE_FORECAST_12M;
    INSERT INTO TEST_RESULTS VALUES (
        6, 'Compilation', 'V_USAGE_FORECAST_12M compiles successfully',
        'PASS', 'View accessible',
        DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
    );
EXCEPTION
    WHEN OTHER THEN
        INSERT INTO TEST_RESULTS VALUES (
            6, 'Compilation', 'V_USAGE_FORECAST_12M compiles successfully',
            'FAIL', 'Error: ' || SQLERRM,
            DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
        );
END;

-- Test 6b: V_CORTEX_REST_API_DETAIL (REST API token tracking)
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP();
    row_count INT;
BEGIN
    SELECT COUNT(*) INTO :row_count FROM V_CORTEX_REST_API_DETAIL;
    INSERT INTO TEST_RESULTS VALUES (
        60, 'Compilation', 'V_CORTEX_REST_API_DETAIL compiles successfully',
        'PASS', 'View accessible, ' || :row_count || ' rows',
        DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
    );
EXCEPTION
    WHEN OTHER THEN
        INSERT INTO TEST_RESULTS VALUES (
            60, 'Compilation', 'V_CORTEX_REST_API_DETAIL compiles successfully',
            'FAIL', 'Error: ' || SQLERRM,
            DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()
        );
END;

-- ===========================================================================
-- TEST CATEGORY 2: DATA QUALITY TESTS
-- ===========================================================================

-- Test 7: Check for NULL service_type
INSERT INTO TEST_RESULTS
SELECT
    7 AS test_number,
    'Data Quality' AS test_category,
    'No NULL service_type in V_CORTEX_DAILY_SUMMARY' AS test_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    'Found ' || COUNT(*) || ' NULL service_type rows' AS test_message,
    0 AS execution_time_ms,
    CURRENT_TIMESTAMP() AS tested_at
FROM V_CORTEX_DAILY_SUMMARY
WHERE service_type IS NULL;

-- Test 8: Check for negative credits
INSERT INTO TEST_RESULTS
SELECT
    8 AS test_number,
    'Data Quality' AS test_category,
    'No negative credits in V_CORTEX_DAILY_SUMMARY' AS test_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    'Found ' || COUNT(*) || ' rows with negative credits' AS test_message,
    0 AS execution_time_ms,
    CURRENT_TIMESTAMP() AS tested_at
FROM V_CORTEX_DAILY_SUMMARY
WHERE total_credits < 0;

-- Test 9: Check date consistency
INSERT INTO TEST_RESULTS
SELECT
    9 AS test_number,
    'Data Quality' AS test_category,
    'Dates within valid range (90 days lookback)' AS test_name,
    CASE
        WHEN MIN(usage_date) >= DATEADD('day', -90, CURRENT_DATE())
         AND MAX(usage_date) <= CURRENT_DATE()
        THEN 'PASS'
        ELSE 'WARN'
    END AS test_status,
    'Date range: ' || MIN(usage_date)::VARCHAR || ' to ' || MAX(usage_date)::VARCHAR AS test_message,
    0 AS execution_time_ms,
    CURRENT_TIMESTAMP() AS tested_at
FROM V_CORTEX_DAILY_SUMMARY;

-- Test 10: Check for duplicate dates per service
INSERT INTO TEST_RESULTS
SELECT
    10 AS test_number,
    'Data Quality' AS test_category,
    'No duplicate date-service combinations' AS test_name,
    CASE WHEN MAX(cnt) = 1 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    'Max occurrences per date-service: ' || MAX(cnt) AS test_message,
    0 AS execution_time_ms,
    CURRENT_TIMESTAMP() AS tested_at
FROM (
    SELECT usage_date, service_type, COUNT(*) AS cnt
    FROM V_CORTEX_DAILY_SUMMARY
    GROUP BY usage_date, service_type
);

-- ===========================================================================
-- TEST CATEGORY 3: BUSINESS LOGIC TESTS
-- ===========================================================================

-- Test 11: Verify credits_per_user calculation
INSERT INTO TEST_RESULTS
SELECT
    11 AS test_number,
    'Business Logic' AS test_category,
    'credits_per_user calculated correctly' AS test_name,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_status,
    CASE
        WHEN COUNT(*) = 0 THEN 'All calculations correct'
        ELSE 'Found ' || COUNT(*) || ' rows with incorrect calculations'
    END AS test_message,
    0 AS execution_time_ms,
    CURRENT_TIMESTAMP() AS tested_at
FROM V_CORTEX_DAILY_SUMMARY
WHERE daily_unique_users > 0
  AND ABS(credits_per_user - (total_credits / daily_unique_users)) > 0.01;

-- ===========================================================================
-- TEST CATEGORY 4: PERFORMANCE TESTS
-- ===========================================================================

-- Test 12: V_CORTEX_DAILY_SUMMARY query performance
DECLARE
    test_start TIMESTAMP := CURRENT_TIMESTAMP();
    row_count INT;
    exec_time_ms NUMBER(10,2);
BEGIN
    SELECT COUNT(*) INTO :row_count FROM V_CORTEX_DAILY_SUMMARY;
    exec_time_ms := DATEDIFF('millisecond', :test_start, CURRENT_TIMESTAMP());

    INSERT INTO TEST_RESULTS VALUES (
        12, 'Performance', 'V_CORTEX_DAILY_SUMMARY query under 5 seconds',
        CASE WHEN :exec_time_ms < 5000 THEN 'PASS' ELSE 'WARN' END,
        'Query took ' || :exec_time_ms || 'ms for ' || :row_count || ' rows',
        :exec_time_ms, CURRENT_TIMESTAMP()
    );
END;

-- ===========================================================================
-- TEST RESULTS SUMMARY
-- ===========================================================================

-- Display all test results
SELECT
    '+-------------------------------------------------------------------+' AS separator
UNION ALL
SELECT '|               CORTEX COST CALCULATOR - TEST RESULTS              |'
UNION ALL
SELECT '+-------------------------------------------------------------------+'
UNION ALL
SELECT '';

SELECT
    test_number,
    test_category,
    test_name,
    test_status,
    test_message,
    execution_time_ms,
    tested_at
FROM TEST_RESULTS
ORDER BY test_number;

-- Summary statistics
SELECT '' AS separator;
-- =================== TEST SUMMARY ===================
SELECT
    test_category,
    COUNT(*) AS total_tests,
    SUM(CASE WHEN test_status = 'PASS' THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN test_status = 'FAIL' THEN 1 ELSE 0 END) AS failed,
    SUM(CASE WHEN test_status = 'WARN' THEN 1 ELSE 0 END) AS warnings,
    ROUND(AVG(execution_time_ms), 2) AS avg_exec_time_ms
FROM TEST_RESULTS
GROUP BY test_category
ORDER BY test_category;

-- Overall status
SELECT '' AS separator;
SELECT
    CASE
        WHEN SUM(CASE WHEN test_status = 'FAIL' THEN 1 ELSE 0 END) = 0 THEN
            'ALL TESTS PASSED - Deployment validated successfully'
        ELSE
            SUM(CASE WHEN test_status = 'FAIL' THEN 1 ELSE 0 END) ||
            ' TEST(S) FAILED - Review failures above'
    END AS overall_status,
    COUNT(*) AS total_tests,
    SUM(CASE WHEN test_status = 'PASS' THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN test_status = 'FAIL' THEN 1 ELSE 0 END) AS failed,
    SUM(CASE WHEN test_status = 'WARN' THEN 1 ELSE 0 END) AS warnings
FROM TEST_RESULTS;

/*******************************************************************************
 * END OF TEST SUITE
 ******************************************************************************/
