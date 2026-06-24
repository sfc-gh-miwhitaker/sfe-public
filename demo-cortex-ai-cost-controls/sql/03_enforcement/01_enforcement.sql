/*==============================================================================
03_ENFORCEMENT — Per-user AI Function limits (SIMULATE-ONLY by default)
Cortex AI Cost Controls demo | Expires: 2026-07-24

DESIGN: This demo ships in SIMULATE-ONLY mode. The enforcement procedure LOGS
what it WOULD do (revoke AI_FUNCTIONS_USER, cancel a query) to an audit table
but does NOT alter grants or cancel queries. The scheduled task is created
SUSPENDED and never resumed by the deploy. To enforce for real, an admin sets
ENFORCEMENT_CONFIG.SIMULATE_ONLY = 'FALSE', extends the real-revoke block (see
the SKILL.md Extension Playbook), and RESUMEs the task — accepting that the task
consumes compute on its schedule and that ACCOUNT_USAGE latency (45-60 min)
makes this a safety net, not a real-time control.

GOTCHAS honored here:
  - Upserts use MERGE (Snowflake has NO "ON CONFLICT ... DO UPDATE").
  - AI_FUNCTIONS_USER is a DATABASE role: GRANT/REVOKE DATABASE ROLE ... TO ROLE.
  - Object grants go TO ROLE, never TO USER; the real path resolves each user's
    DEFAULT_ROLE and acts on that role via a quoted identifier.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS;
USE WAREHOUSE SFE_CORTEX_AI_COST_CONTROLS_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- Cost-center tag (Attribution). Apply to agents/users to populate
-- V_AGENT_ATTRIBUTION. Application examples are commented (objects vary by acct).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TAG IF NOT EXISTS COST_CENTER
  COMMENT = 'DEMO: Team/project that owns a cost (Expires: 2026-07-24)';
-- ALTER AGENT <db>.<schema>.<agent> SET TAG SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS.COST_CENTER = 'sales_team';
-- ALTER USER <name> SET TAG SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS.COST_CENTER = 'sales_team';

-- ─────────────────────────────────────────────────────────────────────────────
-- Config: simulate flag + runaway threshold. Read by procedures and the app.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ENFORCEMENT_CONFIG (
    config_key   VARCHAR     NOT NULL,
    config_value VARCHAR     NOT NULL,
    updated_at   TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'DEMO: Enforcement configuration key/value (Expires: 2026-07-24)';

MERGE INTO ENFORCEMENT_CONFIG t USING (
    SELECT 'SIMULATE_ONLY'            AS config_key, 'TRUE' AS config_value
    UNION ALL SELECT 'RUNAWAY_CREDIT_THRESHOLD', '10'
) s ON t.config_key = s.config_key
WHEN NOT MATCHED THEN INSERT (config_key, config_value) VALUES (s.config_key, s.config_value);

-- ─────────────────────────────────────────────────────────────────────────────
-- Limits table: per-user daily AI Function credit cap.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS AI_FUNCTION_USER_LIMITS (
    user_name          VARCHAR       NOT NULL,
    daily_credit_limit NUMBER(10,2)  NOT NULL,
    enabled            BOOLEAN       DEFAULT TRUE,
    updated_at         TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'DEMO: Per-user daily AI Function credit limits (Expires: 2026-07-24)';

-- Seed with the deploying user + two illustrative entries (MERGE, not ON CONFLICT).
MERGE INTO AI_FUNCTION_USER_LIMITS t USING (
    SELECT CURRENT_USER() AS user_name, 10.00 AS lim
    UNION ALL SELECT 'ALICE', 5.00
    UNION ALL SELECT 'BOB',   2.00
) s ON UPPER(t.user_name) = UPPER(s.user_name)
WHEN MATCHED THEN UPDATE SET daily_credit_limit = s.lim, updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (user_name, daily_credit_limit, enabled, updated_at)
    VALUES (s.user_name, s.lim, TRUE, CURRENT_TIMESTAMP());

-- ─────────────────────────────────────────────────────────────────────────────
-- Audit log: what the enforcement procedure decided (simulated or real).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ENFORCEMENT_AUDIT (
    event_at    TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    action      VARCHAR,
    target_user VARCHAR,
    detail      VARCHAR,
    simulated   BOOLEAN
) COMMENT = 'DEMO: Enforcement decision audit trail (Expires: 2026-07-24)';

-- ─────────────────────────────────────────────────────────────────────────────
-- V_LIMIT_STATUS — joins limits to today's observed usage. Feeds the Limits page.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW V_LIMIT_STATUS
  COMMENT = 'DEMO: Per-user limit vs observed AI Function spend today (Expires: 2026-07-24)'
AS
SELECT l.user_name,
       l.daily_credit_limit,
       l.enabled,
       COALESCE(u.credits_today, 0) AS credits_today,
       COALESCE(u.calls_today, 0)   AS calls_today,
       u.last_call_at,
       CASE
           WHEN l.enabled AND COALESCE(u.credits_today, 0) >= l.daily_credit_limit THEN 'OVER_LIMIT'
           WHEN NOT l.enabled THEN 'DISABLED'
           ELSE 'OK'
       END AS status,
       CASE
           WHEN l.enabled AND COALESCE(u.credits_today, 0) >= l.daily_credit_limit
           THEN 'WOULD REVOKE AI_FUNCTIONS_USER'
           ELSE 'none'
       END AS would_action
FROM AI_FUNCTION_USER_LIMITS l
LEFT JOIN V_AI_FUNCTION_USAGE_TODAY_BY_USER u
       ON UPPER(u.user_name) = UPPER(l.user_name);

-- ─────────────────────────────────────────────────────────────────────────────
-- SP_ENFORCE_AI_FUNCTION_LIMITS — logs over-limit users to the audit table.
-- Simulate-only: never revokes. Real path is documented and commented below.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE SP_ENFORCE_AI_FUNCTION_LIMITS()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'DEMO: Log (simulate) or revoke (real) over-limit AI Function users (Expires: 2026-07-24)'
AS
$$
DECLARE
    v_simulate STRING;
    v_count    INTEGER DEFAULT 0;
BEGIN
    SELECT config_value INTO :v_simulate FROM ENFORCEMENT_CONFIG WHERE config_key = 'SIMULATE_ONLY';

    INSERT INTO ENFORCEMENT_AUDIT (event_at, action, target_user, detail, simulated)
    SELECT CURRENT_TIMESTAMP(),
           'REVOKE_AI_FUNCTIONS_USER',
           user_name,
           'credits_today=' || credits_today || ' limit=' || daily_credit_limit,
           IFF(:v_simulate = 'FALSE', FALSE, TRUE)
    FROM V_LIMIT_STATUS
    WHERE would_action <> 'none';

    SELECT COUNT(*) INTO :v_count FROM V_LIMIT_STATUS WHERE would_action <> 'none';

    -- ── REAL ENFORCEMENT (disabled by default) ───────────────────────────────
    -- When ENFORCEMENT_CONFIG.SIMULATE_ONLY = 'FALSE', replace the block above
    -- with a cursor loop that resolves each over-limit user's DEFAULT_ROLE and
    -- revokes the database role from THAT role (grants go TO ROLE, never TO USER):
    --
    --   FOR r IN (SELECT user_name FROM V_LIMIT_STATUS WHERE would_action <> 'none') DO
    --     LET v_role STRING := (SELECT default_role FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
    --                            WHERE UPPER(name) = UPPER(r.user_name)
    --                              AND deleted_on IS NULL LIMIT 1);
    --     IF (v_role IS NOT NULL) THEN
    --       EXECUTE IMMEDIATE
    --         'REVOKE DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER FROM ROLE "' || v_role || '"';
    --     END IF;
    --   END FOR;
    -- ──────────────────────────────────────────────────────────────────────────

    RETURN :v_count || ' over-limit user(s) logged (simulate_only=' || :v_simulate || ')';
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- SP_CANCEL_RUNAWAY — cancel an in-flight query (simulate-only by default).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE SP_CANCEL_RUNAWAY(P_QUERY_ID VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'DEMO: Cancel a runaway AI Function query, simulate-aware (Expires: 2026-07-24)'
AS
$$
DECLARE
    v_simulate STRING;
    v_result   STRING;
BEGIN
    SELECT config_value INTO :v_simulate FROM ENFORCEMENT_CONFIG WHERE config_key = 'SIMULATE_ONLY';

    IF (:v_simulate = 'FALSE') THEN
        v_result := (SELECT SYSTEM$CANCEL_QUERY(:P_QUERY_ID));
        INSERT INTO ENFORCEMENT_AUDIT (event_at, action, target_user, detail, simulated)
            VALUES (CURRENT_TIMESTAMP(), 'CANCEL_QUERY', NULL,
                    'query_id=' || :P_QUERY_ID || ' result=' || :v_result, FALSE);
        RETURN 'CANCELLED: ' || :v_result;
    ELSE
        INSERT INTO ENFORCEMENT_AUDIT (event_at, action, target_user, detail, simulated)
            VALUES (CURRENT_TIMESTAMP(), 'CANCEL_QUERY', NULL,
                    'query_id=' || :P_QUERY_ID, TRUE);
        RETURN 'SIMULATED: would cancel query ' || :P_QUERY_ID
               || ' (set SIMULATE_ONLY=FALSE to enforce)';
    END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Scheduled enforcement task — created SUSPENDED. The deploy never resumes it.
-- Resume only after setting SIMULATE_ONLY appropriately and accepting the cost.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TASK TASK_ENFORCE_AI_FUNCTION_LIMITS
    WAREHOUSE = SFE_CORTEX_AI_COST_CONTROLS_WH
    SCHEDULE  = '15 MINUTE'
    COMMENT   = 'DEMO: Poll limits and enforce (SUSPENDED by default) (Expires: 2026-07-24)'
AS
    CALL SP_ENFORCE_AI_FUNCTION_LIMITS();
-- Intentionally NOT resumed. To activate: ALTER TASK TASK_ENFORCE_AI_FUNCTION_LIMITS RESUME;

SELECT 'Enforcement objects created (simulate-only, task suspended)' AS step_03_enforcement;
