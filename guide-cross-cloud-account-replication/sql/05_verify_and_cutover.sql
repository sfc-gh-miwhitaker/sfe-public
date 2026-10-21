/*
 * Cross-cloud account replication: verify, then (optionally) cut over to Azure
 * Pair-programmed by SE Community + Cortex Code
 *
 * Sections A and B are read-only. Section C makes Azure the primary: run it only
 * in a planned change window, in the AZURE account, as ACCOUNTADMIN.
 */

USE ROLE ACCOUNTADMIN;

-- A. Replication health (Azure account) ---------------------------------------
SHOW FAILOVER GROUPS;   -- is_primary = false here; next_scheduled_refresh populated

SELECT phase_name, start_time, end_time
  FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_HISTORY('ACCOUNT_FG'))
 ORDER BY start_time DESC
 LIMIT 5;

-- Snapshot time of the last refresh; use it in section B on the AWS side.
SELECT PARSE_JSON(details):primarySnapshotTimestamp::TIMESTAMP_LTZ AS primary_snapshot_ts
  FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_PROGRESS('ACCOUNT_FG'))
 WHERE phase_name = 'PRIMARY_UPLOADING_METADATA';

-- Replication spend (credits and bytes), last 30 days. Billed here, in the target.
-- ACCOUNT_USAGE has latency; recent refreshes can take a few hours to appear.
SELECT replication_group_name, SUM(credits_used) AS credits, SUM(bytes_transferred) AS bytes
  FROM SNOWFLAKE.ACCOUNT_USAGE.REPLICATION_GROUP_USAGE_HISTORY
 WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
 GROUP BY replication_group_name;

-- B. Optional spot check of one table (Snowflake already verifies file hashes and
--    row/byte counts on every refresh; this is for auditors). Run in both accounts,
--    adding AT(TIMESTAMP => '<primary_snapshot_ts>'::TIMESTAMP_LTZ) on the AWS side.
-- SELECT HASH_AGG(*) FROM <db>.<schema>.<table>;

-- C. Cut over: Azure becomes primary (Azure account) ---------------------------
-- 1. Stop scheduled refreshes, and wait for any running refresh to finish.
-- ALTER FAILOVER GROUP ACCOUNT_FG SUSPEND;
-- 2. Confirm nothing is still running (expect zero rows).
-- SELECT phase_name, start_time, job_uuid
--   FROM TABLE(INFORMATION_SCHEMA.REPLICATION_GROUP_REFRESH_HISTORY('ACCOUNT_FG'))
--  WHERE phase_name NOT IN ('COMPLETED', 'CANCELED');
-- 3. Promote data and the client URL together.
-- ALTER FAILOVER GROUP ACCOUNT_FG PRIMARY;
-- ALTER CONNECTION PRIMARY_CONN PRIMARY;
-- 4. AWS is now the secondary. Resume refreshes there to keep it as your fallback.
--    (Run in the AWS account.)
-- ALTER FAILOVER GROUP ACCOUNT_FG RESUME;
-- 5. Confirm clients land in Azure: connect through the connection URL and run
-- SELECT CURRENT_REGION();
