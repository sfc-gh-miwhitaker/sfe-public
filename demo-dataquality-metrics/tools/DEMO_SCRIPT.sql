-- ============================================================================
-- DEMO SCRIPT: Data Quality Monitoring in Snowflake
--
-- KEY INSIGHT: You can call DMFs MANUALLY for instant results!
-- Don't wait for async background processing - call them directly.
--
-- Estimated demo time: 10 minutes (no waiting required)
-- ============================================================================

USE WAREHOUSE SFE_DATA_QUALITY_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.DATA_QUALITY;

-- ============================================================================
-- PART 1: THE PROBLEM - Raw data has quality issues
-- ============================================================================

-- "Let's look at our raw athlete performance data..."
SELECT COUNT(*) AS total_records FROM RAW_ATHLETE_PERFORMANCE;
-- Shows: 10,000 records

-- "But some of this data has problems - NULL values and out-of-range metrics..."
SELECT
  COUNT(*) AS problem_records,
  COUNT_IF(metric_value IS NULL) AS null_values,
  COUNT_IF(metric_value < 0 OR metric_value > 100) AS out_of_range
FROM RAW_ATHLETE_PERFORMANCE
WHERE metric_value IS NULL OR metric_value < 0 OR metric_value > 100;
-- Shows: ~400 bad records (NULLs + out-of-range)

-- "Here are some examples of the bad data..."
SELECT athlete_id, sport, metric_type, metric_value, data_source
FROM RAW_ATHLETE_PERFORMANCE
WHERE metric_value IS NULL OR metric_value > 100
LIMIT 5;

-- ============================================================================
-- PART 2: THE SOLUTION - Data Metric Functions
-- ============================================================================

-- "Snowflake's Data Metric Functions track quality..."
-- "We defined a DMF that checks: is metric_value between 0-100?"

-- Show the DMF definition
SELECT GET_DDL('FUNCTION', 'DMF_METRIC_VALUE_VALID_PCT(TABLE(FLOAT))');

-- "It's configured to run automatically when data changes..."
SHOW PARAMETERS LIKE 'DATA_METRIC_SCHEDULE' IN TABLE RAW_ATHLETE_PERFORMANCE;

-- ============================================================================
-- PART 2b: CALL DMFs MANUALLY - Instant Results! (THE KEY DEMO MOMENT)
-- ============================================================================

-- "But here's the cool part - we can call DMFs directly for instant results!"

-- Call our custom DMF on athlete performance data:
SELECT SNOWFLAKE_EXAMPLE.DATA_QUALITY.DMF_METRIC_VALUE_VALID_PCT(
  SELECT metric_value FROM RAW_ATHLETE_PERFORMANCE
) AS validity_percent;
-- Shows: ~96% valid (we intentionally inserted ~4% bad data)

-- Call our custom DMF on fan engagement data:
SELECT SNOWFLAKE_EXAMPLE.DATA_QUALITY.DMF_SESSION_DURATION_VALID_PCT(
  SELECT session_duration FROM RAW_FAN_ENGAGEMENT
) AS validity_percent;
-- Shows: ~97% valid

-- "And Snowflake has built-in system DMFs too..."

-- NULL_COUNT - How many NULLs in metric_value?
SELECT SNOWFLAKE.CORE.NULL_COUNT(
  SELECT metric_value FROM RAW_ATHLETE_PERFORMANCE
) AS null_count;

-- NULL_PERCENT - What percent are NULL?
SELECT SNOWFLAKE.CORE.NULL_PERCENT(
  SELECT metric_value FROM RAW_ATHLETE_PERFORMANCE
) AS null_percent;

-- DUPLICATE_COUNT - How many duplicate athlete_ids?
SELECT SNOWFLAKE.CORE.DUPLICATE_COUNT(
  SELECT athlete_id FROM RAW_ATHLETE_PERFORMANCE
) AS duplicate_count;

-- Simple COUNT for row totals (ROW_COUNT is for table associations only)
SELECT COUNT(*) AS row_count FROM RAW_ATHLETE_PERFORMANCE;

-- ============================================================================
-- PART 3: THE OUTCOME - Clean data for analytics
-- ============================================================================

-- "Our 'golden' views automatically filter out bad records..."
SELECT
  'RAW (all records)' AS dataset,
  COUNT(*) AS record_count
FROM RAW_ATHLETE_PERFORMANCE
UNION ALL
SELECT
  'CLEAN (valid only)',
  COUNT(*)
FROM V_ATHLETE_PERFORMANCE;
-- Shows: RAW has 10,000, CLEAN has ~9,600 (bad records filtered)

-- "Analysts query the clean view and never see bad data..."
SELECT sport, COUNT(*) AS athletes, ROUND(AVG(metric_value), 1) AS avg_score
FROM V_ATHLETE_PERFORMANCE
GROUP BY sport
ORDER BY avg_score DESC;

-- ============================================================================
-- PART 4: MONITORING - Multiple Options
-- ============================================================================

-- "For ongoing monitoring, you have several options..."

-- OPTION A: Native Snowsight Data Quality UI (Best for demos!)
--
-- SHOW THIS IN SNOWSIGHT:
-- 1. Go to Catalog > Database Explorer
-- 2. Navigate to: SNOWFLAKE_EXAMPLE > DATA_QUALITY > RAW_ATHLETE_PERFORMANCE
-- 3. Click the "Data Quality" tab
--
-- What you'll see:
-- - Data Profiling: Row counts, null percentages, value distributions
-- - Quality Dimensions: DMFs grouped by what they measure (after background runs)

-- OPTION B: Query async DMF results (populated by background process)
-- NOTE: This requires waiting for TRIGGER_ON_CHANGES to run.
-- The manual calls in Part 2b are faster for demos.
SELECT
  METRIC_NAME,
  VALUE,
  MEASUREMENT_TIME
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE TABLE_DATABASE = 'SNOWFLAKE_EXAMPLE'
  AND TABLE_SCHEMA = 'DATA_QUALITY'
ORDER BY MEASUREMENT_TIME DESC
LIMIT 10;

-- OPTION C: Our custom Task populates a metrics table every 5 min
SELECT * FROM V_DATA_QUALITY_METRICS ORDER BY metric_date DESC LIMIT 10;

-- OPTION D: Streamlit dashboard for custom visualization
-- (Navigate to Projects > Streamlit > DATA_QUALITY_DASHBOARD)

-- ============================================================================
-- PART 5: LIVE DEMO - Show it working in real-time
-- ============================================================================

-- "Let me add some NEW data with quality issues..."
INSERT INTO RAW_ATHLETE_PERFORMANCE
  (athlete_id, ngb_code, sport, event_date, metric_type, metric_value, data_source, load_timestamp)
VALUES
  ('A-LIVE01', 'USA', 'Swimming', CURRENT_DATE(), 'score', 85.5, 'live_demo', CURRENT_TIMESTAMP()),  -- GOOD
  ('A-LIVE02', 'GBR', 'Track', CURRENT_DATE(), 'score', NULL, 'live_demo', CURRENT_TIMESTAMP()),     -- BAD: NULL
  ('A-LIVE03', 'CAN', 'Cycling', CURRENT_DATE(), 'score', 250.0, 'live_demo', CURRENT_TIMESTAMP()),  -- BAD: >100
  ('A-LIVE04', 'AUS', 'Swimming', CURRENT_DATE(), 'score', 92.3, 'live_demo', CURRENT_TIMESTAMP()),  -- GOOD
  ('A-LIVE05', 'JPN', 'Track', CURRENT_DATE(), 'score', -10.0, 'live_demo', CURRENT_TIMESTAMP());    -- BAD: <0

-- "3 good records, 2 bad records. Let's verify..."
SELECT athlete_id, metric_value,
  CASE
    WHEN metric_value IS NULL THEN 'FAIL: NULL'
    WHEN metric_value < 0 OR metric_value > 100 THEN 'FAIL: Out of range'
    ELSE 'PASS'
  END AS quality_check
FROM RAW_ATHLETE_PERFORMANCE
WHERE athlete_id LIKE 'A-LIVE%';

-- "The stream captured these changes..."
SELECT SYSTEM$STREAM_HAS_DATA('RAW_ATHLETE_PERFORMANCE_STREAM') AS stream_has_new_data;

-- "Force the task to run now (don't wait 5 min)..."
EXECUTE TASK refresh_data_quality_metrics_task;

-- "Check the updated metrics..."
SELECT * FROM V_DATA_QUALITY_METRICS ORDER BY metric_date DESC LIMIT 5;

-- "Refresh the Streamlit dashboard to see the update!"

-- ============================================================================
-- PART 6: GOVERNANCE TAGS - Classify and protect data assets
-- ============================================================================

-- "Beyond quality, we also classify our data for governance..."

-- Show the tags we created
SHOW TAGS IN SCHEMA SNOWFLAKE_EXAMPLE.DATA_QUALITY;

-- "Every table is tagged with its business domain and quality tier..."
SELECT
  TAG_NAME,
  TAG_VALUE,
  OBJECT_NAME,
  DOMAIN
FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.RAW_ATHLETE_PERFORMANCE', 'TABLE'))
ORDER BY TAG_NAME;
-- Shows: DATA_DOMAIN = PERFORMANCE, DATA_QUALITY_TIER = RAW

-- "And columns are tagged by sensitivity level..."
SELECT
  TAG_NAME,
  TAG_VALUE,
  OBJECT_NAME,
  COLUMN_NAME
FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('DATA_QUALITY.RAW_ATHLETE_PERFORMANCE.ATHLETE_ID', 'COLUMN'));
-- Shows: DATA_SENSITIVITY = CONFIDENTIAL

-- "Here's the full governance map across all our objects..."
SELECT * FROM V_TAG_GOVERNANCE_SUMMARY ORDER BY TAG_NAME, OBJECT_NAME;

-- "The best part? CONFIDENTIAL columns are automatically masked!"
-- "We have a tag-based masking policy: any VARCHAR column tagged
--  DATA_SENSITIVITY = 'CONFIDENTIAL' is masked for non-admin roles."

-- As ACCOUNTADMIN you see the real values:
SELECT athlete_id, sport, metric_value
FROM RAW_ATHLETE_PERFORMANCE
LIMIT 5;
-- Shows: A-000000, A-000001, ... (full values visible)

-- If you switch to a non-admin role, athlete_id shows ***MASKED***
-- (Uncomment and run if you have a demo role set up)
-- USE ROLE PUBLIC;
-- SELECT athlete_id, sport, metric_value
-- FROM RAW_ATHLETE_PERFORMANCE
-- LIMIT 5;
-- USE ROLE ACCOUNTADMIN;

-- "Tag one column, protect it everywhere — no per-column policy needed."

-- ============================================================================
-- KEY TAKEAWAYS
-- ============================================================================
-- 1. Raw data has quality issues (NULLs, out-of-range values)
-- 2. DMFs can be CALLED MANUALLY for instant quality checks (Part 2b!)
-- 3. DMFs also run automatically on TRIGGER_ON_CHANGES (async, takes time)
-- 4. "Golden" views filter bad records for clean analytics
-- 5. Multiple monitoring options: Native UI, SQL queries, custom dashboards
-- 6. Governance tags classify objects by domain, sensitivity, and quality tier
-- 7. Tag-based masking policies protect CONFIDENTIAL columns automatically
-- 8. All native Snowflake - no external tools needed
