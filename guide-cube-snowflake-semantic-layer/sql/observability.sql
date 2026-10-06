/*
  Cube on Snowflake — observability and cost attribution
  Pair-programmed by SE Community + Cortex Code

  Answers four operational questions about a Cube deployment:
    - Is the Cube service user authenticating the way you configured it?
    - How much warehouse compute is Cube actually consuming?
    - Which Cube queries are expensive, and are pre-aggregation rebuilds runaway?
    - Are pushed semantic views present and being queried?

  PREREQUISITE — query tagging
  Attribution depends on Cube tagging its connection. There is no environment
  variable for this; you must supply a custom driverFactory in cube.js:

      const SnowflakeDriver = require('@cubejs-backend/snowflake-driver');
      module.exports = {
        driverFactory: () => new SnowflakeDriver({ queryTag: 'cube' }),
      };

  The tag is set once per connection, so every query on that connection carries it.
  Without it, queries 3-6 return nothing and you cannot separate Cube's traffic
  from anything else in the account.

  NOTES
    - ACCOUNT_USAGE views have latency (QUERY_HISTORY up to ~45 min, WAREHOUSE_
      METERING_HISTORY up to ~3 h). For real-time checks use INFORMATION_SCHEMA.
    - Requires a role with access to SNOWFLAKE.ACCOUNT_USAGE — ACCOUNTADMIN, or a
      role granted the GOVERNANCE_VIEWER / USAGE_VIEWER database roles.
    - Every predicate is time-bound and sargable so these stay cheap on large
      accounts. Adjust the day windows rather than removing them.

  REPLACE BEFORE RUNNING
    CUBE_SVC   Your Cube service user
    CUBE_WH    Your Cube warehouse
    'cube'     Your queryTag value, if different
*/

-- =============================================================================
-- 1. Is the Cube service user authenticating as configured?
--
-- FIRST_AUTHENTICATION_FACTOR tells you which path actually ran. Verified values:
--   RSA_KEYPAIR         key pair  (CUBEJS_DB_SNOWFLAKE_AUTHENTICATOR=SNOWFLAKE_JWT)
--   OAUTH_ACCESS_TOKEN  External OAuth / OIDC workload identity  (=OAUTH)
--   PASSWORD            username + password  (=SNOWFLAKE, the default)
--
-- Seeing PASSWORD when you intended federation means the driver silently fell back.
-- INFORMATION_SCHEMA is used here deliberately — no latency.
-- =============================================================================

SELECT
      event_timestamp,
      user_name,
      first_authentication_factor,
      second_authentication_factor,
      is_success,
      error_message,
      client_ip
  FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.LOGIN_HISTORY_BY_USER(
         USER_NAME => 'CUBE_SVC',
         TIME_RANGE_START => DATEADD(day, -7, CURRENT_TIMESTAMP())))
  ORDER BY event_timestamp DESC
  LIMIT 100;

-- =============================================================================
-- 2. Failed authentication attempts, grouped by cause
--
-- The dominant failure mode is a missing scp claim: the token authenticates but
-- role authorization fails. Look for "not listed in the Access Token or was filtered".
-- =============================================================================

SELECT
      error_message,
      first_authentication_factor,
      COUNT(*)               AS attempts,
      MIN(event_timestamp)   AS first_seen,
      MAX(event_timestamp)   AS last_seen
  FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.LOGIN_HISTORY_BY_USER(
         USER_NAME => 'CUBE_SVC',
         TIME_RANGE_START => DATEADD(day, -7, CURRENT_TIMESTAMP())))
  WHERE is_success = 'NO'
  GROUP BY error_message, first_authentication_factor
  ORDER BY attempts DESC;

-- =============================================================================
-- 3. Daily credit consumption on the Cube warehouse
--
-- The baseline cost number. If this trends up without a matching increase in
-- consumer activity, suspect pre-aggregation rebuild frequency (query 6).
-- =============================================================================

SELECT
      DATE_TRUNC('day', start_time)  AS usage_day,
      warehouse_name,
      SUM(credits_used)              AS credits,
      SUM(credits_used_compute)      AS credits_compute,
      SUM(credits_used_cloud_services) AS credits_cloud_services
  FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
  WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
    AND warehouse_name = 'CUBE_WH'
  GROUP BY usage_day, warehouse_name
  ORDER BY usage_day DESC;

-- =============================================================================
-- 4. Cube's share of total account query volume
--
-- Establishes proportion. A healthy Cube deployment serves most reads from Cube
-- Store, so its Snowflake query count should be far below its consumer query count.
-- =============================================================================

SELECT
      CASE WHEN query_tag = 'cube' THEN 'cube' ELSE 'other' END AS traffic_source,
      COUNT(*)                                     AS queries,
      ROUND(SUM(total_elapsed_time) / 1000.0, 1)   AS total_seconds,
      ROUND(AVG(total_elapsed_time) / 1000.0, 2)   AS avg_seconds,
      SUM(bytes_scanned)                           AS bytes_scanned
  FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
  WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    AND warehouse_name = 'CUBE_WH'
  GROUP BY traffic_source
  ORDER BY queries DESC;

-- =============================================================================
-- 5. The 20 most expensive Cube queries
--
-- Ranked by elapsed time. Long-running scans here usually mean a metric that
-- should be pre-aggregated but isn't.
-- =============================================================================

SELECT
      query_id,
      start_time,
      ROUND(total_elapsed_time / 1000.0, 2) AS elapsed_seconds,
      bytes_scanned,
      partitions_scanned,
      partitions_total,
      rows_produced,
      execution_status,
      LEFT(query_text, 300)                 AS query_preview
  FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
  WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    AND query_tag = 'cube'
    AND total_elapsed_time IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (ORDER BY total_elapsed_time DESC) <= 20
  ORDER BY elapsed_seconds DESC;

-- =============================================================================
-- 6. Pre-aggregation build activity — the runaway-rebuild check
--
-- Batching strategy issues CREATE TABLE / CREATE TABLE AS SELECT against the
-- pre-agg schema; export bucket issues COPY INTO. Either way, a rollup rebuilding
-- far more often than its refreshKey implies is the most common source of
-- unexpected Cube spend.
--
-- QUERY_TYPE is matched explicitly rather than with LIKE 'CREATE%'. A prefix match
-- would also capture CREATE_SEMANTIC_VIEW (emitted by Cube's push integration) and
-- CREATE_VIEW (helper views), mislabeling schema pushes as pre-aggregation builds.
--
-- Compare builds against your configured refresh interval.
-- =============================================================================

SELECT
      DATE_TRUNC('day', start_time)          AS build_day,
      CASE
        WHEN query_type = 'COPY' THEN 'export_bucket'
        ELSE 'batching'
      END                                    AS build_strategy,
      COUNT(*)                               AS builds,
      ROUND(SUM(total_elapsed_time) / 1000.0, 1) AS total_build_seconds,
      SUM(rows_produced)                     AS rows_written
  FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
  WHERE start_time >= DATEADD(day, -14, CURRENT_TIMESTAMP())
    AND query_tag = 'cube'
    AND query_type IN ('CREATE_TABLE', 'CREATE_TABLE_AS_SELECT', 'COPY')
  GROUP BY build_day, build_strategy
  ORDER BY build_day DESC, builds DESC;

-- =============================================================================
-- 6b. Semantic view push activity
--
-- Separated from pre-aggregation builds because it is a schema-change event, not a
-- data-refresh event. CREATE_SEMANTIC_VIEW is a distinct QUERY_TYPE (verified).
-- =============================================================================

SELECT
      DATE_TRUNC('day', start_time) AS push_day,
      query_type,
      COUNT(*)                      AS statements,
      SUM(CASE WHEN execution_status <> 'SUCCESS' THEN 1 ELSE 0 END) AS failures
  FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
  WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
    AND query_type IN ('CREATE_SEMANTIC_VIEW', 'CREATE_VIEW')
    AND query_tag = 'cube'
  GROUP BY push_day, query_type
  ORDER BY push_day DESC, statements DESC;

-- =============================================================================
-- 7. Semantic views pushed from Cube
--
-- Cube's push integration creates native semantic views. Helper views for cubes
-- defined with a raw `sql` string are named CUBE_SV_SRC_<CUBENAME>; a large number
-- of these suggests the data model should move to sql_table where possible.
-- =============================================================================

SHOW SEMANTIC VIEWS IN ACCOUNT;

SELECT
      "database_name"  AS database_name,
      "schema_name"    AS schema_name,
      "name"           AS semantic_view_name,
      "owner"          AS owner_role,
      "created_on"     AS created_on,
      "comment"        AS view_comment
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
  ORDER BY created_on DESC;

-- Helper views created by pushes of cubes defined with a plain SQL string.
SELECT
      table_catalog,
      table_schema,
      table_name,
      created
  FROM SNOWFLAKE.ACCOUNT_USAGE.VIEWS
  WHERE deleted IS NULL
    AND table_name LIKE 'CUBE_SV_SRC_%'
  ORDER BY created DESC;

-- =============================================================================
-- 8. Are the underlying tables reachable by the Cube role?
--
-- Run a permissions sanity check before blaming Cube for "table not found".
-- Also catches the CUBEJS_DB_SNOWFLAKE_QUOTED_IDENTIFIERS_IGNORE_CASE mismatch,
-- where the object exists but Cube's identifier casing doesn't resolve it.
-- =============================================================================

SHOW GRANTS TO ROLE CUBE_ROLE;
