/*
    Cortex Code Access Control — Observability Queries
    ==================================================
    All queries use SNOWFLAKE.ACCOUNT_USAGE views (up to 1-hour latency, 365-day retention).
    Replace date ranges as needed.

    Pair-programmed by SE Community + Cortex Code
*/

--------------------------------------------------------------------------------
-- Query 1: Who is using Cortex Code today?
--------------------------------------------------------------------------------
SELECT
    u.name                    AS user_name,
    u.login_name              AS login_name,
    u.email                   AS email,
    COUNT(h.request_id)       AS total_requests,
    SUM(h.token_credits)      AS total_credits,
    MIN(h.usage_time)         AS first_seen,
    MAX(h.usage_time)         AS last_seen
FROM (
    SELECT user_id, request_id, token_credits, usage_time
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT user_id, request_id, token_credits, usage_time
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
    UNION ALL
    SELECT user_id, request_id, token_credits, usage_time
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
) h
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u
  ON h.user_id = u.user_id
WHERE h.usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND u.deleted_on IS NULL
GROUP BY u.name, u.login_name, u.email
ORDER BY total_credits DESC;


--------------------------------------------------------------------------------
-- Query 2: Which surface is most popular?
--------------------------------------------------------------------------------
SELECT
    'CLI'        AS surface,
    COUNT(request_id) AS requests,
    SUM(token_credits) AS credits
  FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
  WHERE usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
UNION ALL
SELECT
    'Desktop'    AS surface,
    COUNT(request_id) AS requests,
    SUM(token_credits) AS credits
  FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
  WHERE usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
UNION ALL
SELECT
    'Snowsight'  AS surface,
    COUNT(request_id) AS requests,
    SUM(token_credits) AS credits
  FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
  WHERE usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
ORDER BY credits DESC;


--------------------------------------------------------------------------------
-- Query 3: What models are being consumed?
--------------------------------------------------------------------------------
SELECT
    f.key                       AS model_name,
    COUNT(h.request_id)         AS request_count,
    SUM(f.value:input::NUMBER +
        f.value:output::NUMBER +
        COALESCE(f.value:cache_read_input::NUMBER, 0) +
        COALESCE(f.value:cache_write_input::NUMBER, 0)
    )                           AS total_tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.tokens_granular) f
WHERE h.usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY f.key
ORDER BY total_tokens DESC;
-- Repeat with DESKTOP and SNOWSIGHT views for full coverage,
-- or UNION ALL the three before flattening.


--------------------------------------------------------------------------------
-- Query 4: Monthly credits per user
--------------------------------------------------------------------------------
SELECT
    u.name                      AS user_name,
    DATE_TRUNC('month', h.usage_time) AS month,
    SUM(h.token_credits)        AS credits
FROM (
    SELECT user_id, usage_time, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT user_id, usage_time, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
    UNION ALL
    SELECT user_id, usage_time, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
) h
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u
  ON h.user_id = u.user_id
WHERE h.usage_time >= DATEADD('month', -3, CURRENT_TIMESTAMP())
  AND u.deleted_on IS NULL
GROUP BY u.name, month
ORDER BY month DESC, credits DESC;


--------------------------------------------------------------------------------
-- Query 5: Peak usage hours (hour-of-day distribution)
--------------------------------------------------------------------------------
SELECT
    EXTRACT(HOUR FROM CONVERT_TIMEZONE('UTC', usage_time)) AS hour_utc,
    COUNT(request_id)    AS requests,
    SUM(token_credits)   AS credits
FROM (
    SELECT usage_time, request_id, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT usage_time, request_id, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
    UNION ALL
    SELECT usage_time, request_id, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
) h
WHERE usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY hour_utc
ORDER BY hour_utc;


--------------------------------------------------------------------------------
-- Query 6: Top 10 heaviest users (last 30 days)
--------------------------------------------------------------------------------
SELECT
    u.name                  AS user_name,
    COUNT(h.request_id)     AS total_requests,
    SUM(h.token_credits)    AS total_credits,
    SUM(h.tokens)           AS total_tokens
FROM (
    SELECT user_id, request_id, token_credits, tokens
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT user_id, request_id, token_credits, tokens
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
    UNION ALL
    SELECT user_id, request_id, token_credits, tokens
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
) h
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u
  ON h.user_id = u.user_id
WHERE h.usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND u.deleted_on IS NULL
GROUP BY u.name
ORDER BY total_credits DESC
LIMIT 10;


--------------------------------------------------------------------------------
-- Query 7: What roles are people using CoCo with?
--------------------------------------------------------------------------------
SELECT
    h.metadata:role_name::VARCHAR   AS role_name,
    COUNT(h.request_id)             AS requests,
    COUNT(DISTINCT h.user_id)       AS distinct_users,
    SUM(h.token_credits)            AS credits
FROM (
    SELECT user_id, request_id, token_credits, metadata
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT user_id, request_id, token_credits, metadata
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
    UNION ALL
    SELECT user_id, request_id, token_credits, metadata
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
) h
WHERE h.usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY role_name
ORDER BY credits DESC;


--------------------------------------------------------------------------------
-- Query 8: Users with access who have NEVER used CoCo
--------------------------------------------------------------------------------
WITH coco_users AS (
    SELECT DISTINCT user_id
    FROM (
        SELECT user_id FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
        UNION
        SELECT user_id FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
        UNION
        SELECT user_id FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
    )
)
SELECT
    u.name          AS user_name,
    u.login_name    AS login_name,
    u.email         AS email,
    u.created_on    AS user_created
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS u
LEFT JOIN coco_users c
  ON u.user_id = c.user_id
WHERE c.user_id IS NULL
  AND u.deleted_on IS NULL
  AND COALESCE(u.disabled, 'false')::VARCHAR != 'true'
ORDER BY u.created_on DESC;


--------------------------------------------------------------------------------
-- Query 9: Daily credit trend (last 30 days)
--------------------------------------------------------------------------------
SELECT
    DATE_TRUNC('day', usage_time)::DATE AS day,
    COUNT(request_id)                   AS requests,
    SUM(token_credits)                  AS credits
FROM (
    SELECT usage_time, request_id, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT usage_time, request_id, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
    UNION ALL
    SELECT usage_time, request_id, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
) h
WHERE usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY day
ORDER BY day;


--------------------------------------------------------------------------------
-- Query 10: New users in the last 7 days (adoption tracking)
--------------------------------------------------------------------------------
WITH first_use AS (
    SELECT
        user_id,
        MIN(usage_time) AS first_usage
    FROM (
        SELECT user_id, usage_time FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
        UNION ALL
        SELECT user_id, usage_time FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
        UNION ALL
        SELECT user_id, usage_time FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
    )
    GROUP BY user_id
)
SELECT
    u.name          AS user_name,
    u.email         AS email,
    f.first_usage   AS first_used_at
FROM first_use f
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u
  ON f.user_id = u.user_id
WHERE f.first_usage >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND u.deleted_on IS NULL
ORDER BY f.first_usage DESC;


--------------------------------------------------------------------------------
-- Query 11: Inference region distribution (regional vs global routing)
--------------------------------------------------------------------------------
SELECT
    COALESCE(metadata:inference_region::VARCHAR, 'unknown') AS inference_region,
    COUNT(request_id)    AS requests,
    SUM(token_credits)   AS credits
FROM (
    SELECT metadata, request_id, token_credits, usage_time
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT metadata, request_id, token_credits, usage_time
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
    UNION ALL
    SELECT metadata, request_id, token_credits, usage_time
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
) h
WHERE usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY inference_region
ORDER BY credits DESC;
