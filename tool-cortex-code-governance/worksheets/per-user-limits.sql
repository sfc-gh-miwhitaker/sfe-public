/*==============================================================================
  WORKSHEET: Per-User Daily Credit Limits for Cortex Code

  Purpose:    View, set, and audit per-user daily credit limits for both
              Cortex Code surfaces (CLI and Snowsight).
  Requires:   ACCOUNTADMIN (to read/set parameters on users and account)
  Reference:  https://docs.snowflake.com/en/user-guide/cortex-code/credit-usage-limit
  Run in:     Snowsight — paste entire worksheet or run sections individually

  Parameters:
    CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER       — CLI surface
    CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER — Snowsight surface

  Values: -1 = unlimited (default), 0 = blocked, positive = rolling 24h cap
==============================================================================*/

USE ROLE ACCOUNTADMIN;


/* ── SECTION 1: View current account-level defaults ────────────────────────
   Expected: one row per parameter showing the account-wide default.
   If value = -1, no limit is enforced for that surface.                     */

SHOW PARAMETERS LIKE 'CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER' IN ACCOUNT;
SHOW PARAMETERS LIKE 'CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER' IN ACCOUNT;


/* ── SECTION 2: Set account-level daily limits ─────────────────────────────
   Applies to ALL users who don't have a per-user override.
   Uncomment and adjust the values below.                                    */

-- ALTER ACCOUNT SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
-- ALTER ACCOUNT SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;


/* ── SECTION 3: Set per-user overrides ─────────────────────────────────────
   Overrides the account default for a specific user.
   Replace <user_name> and adjust the credit value.                          */

-- ALTER USER <user_name> SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 50;
-- ALTER USER <user_name> SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 50;


/* ── SECTION 4: Remove per-user overrides (restore account default) ────── */

-- ALTER USER <user_name> UNSET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER;
-- ALTER USER <user_name> UNSET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER;


/* ── SECTION 5: Remove account-level limits (restore unlimited) ──────────  */

-- ALTER ACCOUNT UNSET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER;
-- ALTER ACCOUNT UNSET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER;


/* ── SECTION 6: List all users with per-user overrides ─────────────────────
   Iterates every user and checks for USER-level parameter overrides.
   Adapted from Snowflake docs.                                              */

EXECUTE IMMEDIATE $$
DECLARE
    current_user STRING;
    rs_users     RESULTSET;
    res          RESULTSET;
BEGIN
    CREATE OR REPLACE TEMPORARY TABLE _param_overrides (
        user_name  STRING,
        parameter  STRING,
        param_value STRING
    );

    SHOW USERS;
    rs_users := (SELECT "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));

    FOR record IN rs_users DO
        current_user := record."name";

        FOR param IN (
            SELECT column1 AS p FROM VALUES
                ('CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER'),
                ('CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER')
        ) DO
            EXECUTE IMMEDIATE
                'SHOW PARAMETERS LIKE ''' || param.p || ''' IN USER "' || :current_user || '"';

            INSERT INTO _param_overrides (user_name, parameter, param_value)
                SELECT :current_user, param.p, "value"
                FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
                WHERE "level" = 'USER';
        END FOR;
    END FOR;

    res := (SELECT * FROM _param_overrides ORDER BY user_name, parameter);
    RETURN TABLE(res);
END;
$$;


/* ── SECTION 7: Impact analysis — who would be affected by a proposed limit?
   Set @proposed_limit to your candidate value.
   Shows each user's peak daily spend (last 30 days) and whether they would
   have been blocked at the proposed limit.                                  */

SET proposed_limit = 10;  -- credits per day; adjust this

WITH daily_per_user AS (
    SELECT USER_ID,
           USAGE_TIME::DATE AS usage_date,
           SUM(TOKEN_CREDITS) AS daily_credits
    FROM (
        SELECT USER_ID, USAGE_TIME, TOKEN_CREDITS
        FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
        UNION ALL
        SELECT USER_ID, USAGE_TIME, TOKEN_CREDITS
        FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
    )
    WHERE USAGE_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP)
    GROUP BY USER_ID, USAGE_TIME::DATE
),
user_stats AS (
    SELECT USER_ID,
           COUNT(*)                                AS active_days,
           ROUND(AVG(daily_credits), 4)            AS avg_daily,
           ROUND(MAX(daily_credits), 4)            AS max_daily,
           ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY daily_credits), 4) AS p90_daily
    FROM daily_per_user
    GROUP BY USER_ID
)
SELECT u.NAME                                                    AS user_name,
       s.active_days,
       s.avg_daily,
       s.p90_daily,
       s.max_daily,
       CASE WHEN s.max_daily > $proposed_limit THEN 'YES' ELSE 'no' END AS would_hit_limit,
       ROUND(s.max_daily - $proposed_limit, 4)                  AS credits_over_limit
FROM user_stats s
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON s.USER_ID = u.USER_ID
ORDER BY s.max_daily DESC;


/* ── SECTION 8: Rolling 24h usage right now (both surfaces) ────────────────
   Shows what each user has consumed in the current rolling window.          */

SELECT u.NAME AS user_name,
       'cli' AS surface,
       ROUND(SUM(h.TOKEN_CREDITS), 4) AS rolling_24h_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY h
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON h.USER_ID = u.USER_ID
WHERE h.USAGE_TIME >= DATEADD('hour', -24, CURRENT_TIMESTAMP)
GROUP BY u.NAME

UNION ALL

SELECT u.NAME,
       'snowsight',
       ROUND(SUM(h.TOKEN_CREDITS), 4)
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY h
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON h.USER_ID = u.USER_ID
WHERE h.USAGE_TIME >= DATEADD('hour', -24, CURRENT_TIMESTAMP)
GROUP BY u.NAME

ORDER BY rolling_24h_credits DESC;
