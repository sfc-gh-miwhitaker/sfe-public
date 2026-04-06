/*==============================================================================
  WORKSHEET: Understand Your Cortex Code Spend

  Purpose:    Ad-hoc analysis of Cortex Code AI credit consumption.
  Requires:   IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE (or ACCOUNTADMIN)
  Latency:    ~1-2 hours from event to ACCOUNT_USAGE
  Run in:     Snowsight — paste entire worksheet or run sections individually
==============================================================================*/

/* ── STEP 0: Confirm you have access ────────────────────────────────────────
   Expected: your username. If this errors, check IMPORTED PRIVILEGES.       */

SELECT CURRENT_USER(), CURRENT_ROLE();


/* ── STEP 1: Sanity check — is data flowing? ───────────────────────────────
   Expected: row count > 0 and most_recent_event within last few hours.
   If count = 0: your team may not be using the CLI surface. Try the
   Snowsight view in STEP 1b.                                                */

SELECT 'CLI' AS surface,
       COUNT(*) AS total_requests,
       MIN(USAGE_TIME) AS earliest_event,
       MAX(USAGE_TIME) AS most_recent_event
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY

UNION ALL

SELECT 'Snowsight',
       COUNT(*),
       MIN(USAGE_TIME),
       MAX(USAGE_TIME)
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY;


/* ── STEP 2: Daily credit spend — last 30 days ─────────────────────────────
   Expected: one row per day, descending.
   Look for: weekday vs weekend patterns (high weekend = background/agentic
   usage, not interactive). Spikes mid-week often indicate a new heavy user.  */

SELECT DATE_TRUNC('day', USAGE_TIME)::DATE AS usage_date,
       ROUND(SUM(CREDITS_USED), 4) AS credits_used,
       COUNT(*) AS requests,
       COUNT(DISTINCT USER_NAME) AS active_users
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
WHERE USAGE_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP)
GROUP BY 1
ORDER BY 1 DESC;


/* ── STEP 3: This month's spend vs. last month ─────────────────────────────
   Expected: two rows. Compare month-over-month trend.                        */

SELECT DATE_TRUNC('month', USAGE_TIME)::DATE AS month,
       ROUND(SUM(CREDITS_USED), 4) AS credits_used,
       ROUND(SUM(CREDITS_USED) * 2.00, 2) AS est_cost_usd,
       COUNT(*) AS total_requests,
       COUNT(DISTINCT USER_NAME) AS unique_users
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
WHERE USAGE_TIME >= DATEADD('month', -2, DATE_TRUNC('month', CURRENT_DATE))
GROUP BY 1
ORDER BY 1 DESC;


/* ── STEP 4: Top 20 spenders this month ───────────────────────────────────
   Expected: users ranked by total AI credits.
   Decision point: if top 3 users = >60% of spend, consider user-level
   model steering (see reduce-costs.md) before account-wide limits.          */

SELECT USER_NAME,
       ROUND(SUM(CREDITS_USED), 4) AS total_credits,
       ROUND(SUM(CREDITS_USED) * 2.00, 2) AS est_cost_usd,
       COUNT(*) AS total_requests,
       ROUND(AVG(CREDITS_USED), 6) AS avg_credits_per_request
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
WHERE USAGE_TIME >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;


/* ── STEP 5: Model breakdown — which models are being used? ───────────────
   Expected: one row per model with input/output/cache sub-totals.
   Look for: high output_credits with low cache_hit_pct (inefficient reuse),
   or claude-opus being used for tasks that haiku could handle.              */

SELECT f.key AS model,
       ROUND(SUM(f.value:input::FLOAT), 4) AS input_credits,
       ROUND(SUM(f.value:output::FLOAT), 4) AS output_credits,
       ROUND(SUM(NVL(f.value:cache_read_input::FLOAT, 0)), 4) AS cache_hit_credits,
       ROUND(
           SUM(NVL(f.value:cache_read_input::FLOAT, 0)) /
           NULLIF(SUM(f.value:input::FLOAT) + SUM(NVL(f.value:cache_read_input::FLOAT, 0)), 0)
           * 100, 1
       ) AS cache_hit_pct,
       COUNT(DISTINCT h.USER_NAME) AS unique_users
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.CREDITS_GRANULAR) f
WHERE h.USAGE_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP)
GROUP BY 1
ORDER BY 2 + 3 DESC;


/* ── STEP 6: Top user × model combinations ─────────────────────────────────
   Expected: user+model pairs ranked by AI credit use.
   Use this to identify who to talk to about model steering.                 */

SELECT h.USER_NAME,
       f.key AS model,
       ROUND(SUM(f.value:input::FLOAT + f.value:output::FLOAT), 4) AS ai_credits,
       COUNT(*) AS requests
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.CREDITS_GRANULAR) f
WHERE h.USAGE_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP)
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 20;


/* ── STEP 7: Projected end-of-month spend (linear extrapolation) ───────────
   Expected: a single projected number based on daily run rate.
   Decision point: if projected > your comfort level, go to set-a-limit.md  */

WITH daily AS (
    SELECT DATE_TRUNC('day', USAGE_TIME)::DATE AS d,
           SUM(CREDITS_USED) AS daily_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    WHERE USAGE_TIME >= DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY 1
)
SELECT ROUND(SUM(daily_credits), 2) AS credits_so_far,
       ROUND(SUM(daily_credits) / NULLIF(COUNT(d), 0), 4) AS avg_daily_credits,
       DAY(LAST_DAY(CURRENT_DATE)) AS days_in_month,
       ROUND(
           SUM(daily_credits) / NULLIF(COUNT(d), 0) * DAY(LAST_DAY(CURRENT_DATE)),
           2
       ) AS projected_month_credits,
       ROUND(
           SUM(daily_credits) / NULLIF(COUNT(d), 0) * DAY(LAST_DAY(CURRENT_DATE)) * 2.00,
           2
       ) AS projected_month_cost_usd
FROM daily;
