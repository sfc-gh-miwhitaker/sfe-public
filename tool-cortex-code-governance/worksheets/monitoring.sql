/*==============================================================================
  WORKSHEET: Budget Health Monitoring

  Purpose:    Ongoing monitoring queries for budget status, at-risk spend,
              and Cortex Code usage trends. Run weekly or on-demand.
  Requires:   SNOWFLAKE.BUDGET_VIEWER (for budget queries)
              IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE (for ACCOUNT_USAGE)
==============================================================================*/

/* ── SECTION 1: All budgets — current status snapshot ─────────────────────
   Expected: one row per budget with name, limit, spent, % used, status.
   Requires: ACCOUNT_USAGE.BUDGET_DETAILS (up to 2h latency)                */

SELECT budget_name,
       spending_limit,
       ROUND(spending_limit * percent_spent / 100, 2) AS credits_spent,
       ROUND(percent_spent, 1) AS pct_spent,
       ROUND(spending_limit * percent_projected / 100, 2) AS credits_projected_eom,
       ROUND(percent_projected, 1) AS pct_projected_eom,
       CASE
           WHEN percent_spent >= 100 THEN 'OVER_LIMIT'
           WHEN percent_projected >= 100 THEN 'AT_RISK_PROJECTED'
           WHEN percent_spent >= 80 THEN 'WARNING'
           ELSE 'NORMAL'
       END AS status
FROM SNOWFLAKE.ACCOUNT_USAGE.BUDGET_DETAILS
WHERE measure_date = (SELECT MAX(measure_date) FROM SNOWFLAKE.ACCOUNT_USAGE.BUDGET_DETAILS)
ORDER BY pct_spent DESC;


/* ── SECTION 2: Budgets over limit this month ─────────────────────────────
   Expected: only rows where actual spend has crossed the limit.
   Action: investigate which warehouse drove the overage (SECTION 4).       */

SELECT budget_name, spending_limit, ROUND(percent_spent, 1) AS pct_spent
FROM SNOWFLAKE.ACCOUNT_USAGE.BUDGET_DETAILS
WHERE measure_date = (SELECT MAX(measure_date) FROM SNOWFLAKE.ACCOUNT_USAGE.BUDGET_DETAILS)
  AND percent_spent >= 100
ORDER BY percent_spent DESC;


/* ── SECTION 3: Budgets at risk — projected to exceed limit ───────────────
   Expected: budgets where EOM projection > 90% even if actual < 90%.
   Use this for proactive action before limits are crossed.                  */

SELECT budget_name,
       spending_limit,
       ROUND(percent_spent, 1) AS actual_pct,
       ROUND(percent_projected, 1) AS projected_pct_eom
FROM SNOWFLAKE.ACCOUNT_USAGE.BUDGET_DETAILS
WHERE measure_date = (SELECT MAX(measure_date) FROM SNOWFLAKE.ACCOUNT_USAGE.BUDGET_DETAILS)
  AND percent_projected >= 90
  AND percent_spent < 100
ORDER BY projected_pct_eom DESC;


/* ── SECTION 4: Spending trend for a specific budget ──────────────────────
   Change TEAM_BUDGET to the budget you want to inspect.                    */

CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!GET_SPENDING_HISTORY(
    TIME_LOWER_BOUND => DATEADD('month', -3, DATE_TRUNC('month', CURRENT_DATE)),
    TIME_UPPER_BOUND => CURRENT_TIMESTAMP
);


/* ── SECTION 5: Cortex Code daily trend — last 30 days ────────────────────
   Expected: one row per day. Useful for anomaly detection.                  */

SELECT DATE_TRUNC('day', USAGE_TIME)::DATE AS usage_date,
       ROUND(SUM(CREDITS_USED), 4) AS ai_credits_used,
       COUNT(*) AS requests,
       COUNT(DISTINCT USER_NAME) AS active_users
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
WHERE USAGE_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP)
GROUP BY 1
ORDER BY 1 DESC;


/* ── SECTION 6: Week-over-week comparison ──────────────────────────────────
   Expected: current vs prior week, with delta.                              */

WITH weekly AS (
    SELECT DATE_TRUNC('week', USAGE_TIME)::DATE AS week_start,
           SUM(CREDITS_USED) AS credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    WHERE USAGE_TIME >= DATEADD('week', -2, DATE_TRUNC('week', CURRENT_DATE))
    GROUP BY 1
)
SELECT week_start,
       ROUND(credits, 4) AS credits,
       ROUND(credits - LAG(credits) OVER (ORDER BY week_start), 4) AS wow_delta,
       ROUND(
           (credits - LAG(credits) OVER (ORDER BY week_start))
           / NULLIF(LAG(credits) OVER (ORDER BY week_start), 0) * 100, 1
       ) AS wow_pct_change
FROM weekly
ORDER BY week_start DESC;


/* ── SECTION 7: Top users this month vs. last month ───────────────────────
   Expected: side-by-side view to spot new heavy users.                     */

SELECT USER_NAME,
       ROUND(SUM(CASE WHEN USAGE_TIME >= DATE_TRUNC('month', CURRENT_DATE)
                      THEN CREDITS_USED ELSE 0 END), 4) AS this_month,
       ROUND(SUM(CASE WHEN USAGE_TIME >= DATEADD('month', -1, DATE_TRUNC('month', CURRENT_DATE))
                       AND USAGE_TIME < DATE_TRUNC('month', CURRENT_DATE)
                      THEN CREDITS_USED ELSE 0 END), 4) AS last_month
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
WHERE USAGE_TIME >= DATEADD('month', -2, DATE_TRUNC('month', CURRENT_DATE))
GROUP BY 1
HAVING this_month > 0 OR last_month > 0
ORDER BY this_month DESC
LIMIT 20;


/* ── SECTION 8: Budget event telemetry ────────────────────────────────────
   Expected: recent budget threshold events and action fire results.
   If empty: no thresholds crossed recently, or events not yet available.   */

SELECT record_attributes:budget_name::VARCHAR AS budget,
       record_attributes:threshold_percent::FLOAT AS threshold_pct,
       record_attributes:trigger_type::VARCHAR AS trigger,
       record_attributes:action_status::VARCHAR AS action_status,
       record_attributes:error_message::VARCHAR AS error_message,
       timestamp
FROM SNOWFLAKE.TELEMETRY.EVENTS
WHERE SCOPE['name'] = 'snow.cost.budget'
  AND record_type = 'SPAN_EVENT'
  AND timestamp >= DATEADD('day', -30, CURRENT_TIMESTAMP)
ORDER BY timestamp DESC
LIMIT 50;


/* ── SECTION 9: Debugging checklist ─────────────────────────────────────── */

-- a. Do I have access to query budgets?
SELECT CURRENT_ROLE(), CURRENT_USER();
SHOW GRANTS TO ROLE IDENTIFIER(CURRENT_ROLE());

-- b. Are my budgets visible?
SHOW SNOWFLAKE.CORE.BUDGET INSTANCES IN ACCOUNT;

-- c. Is ACCOUNT_USAGE available?
SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.BUDGET_DETAILS;

-- d. What roles have BUDGET_VIEWER?
SELECT GRANTEE_NAME, GRANTED_TO, CREATED_ON
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE ROLE_NAME = 'BUDGET_VIEWER'
  AND DELETED_ON IS NULL;

-- e. When was ACCOUNT_USAGE last refreshed?
SELECT MAX(CREATED_ON) AS latest_row
FROM SNOWFLAKE.ACCOUNT_USAGE.BUDGET_DETAILS;
