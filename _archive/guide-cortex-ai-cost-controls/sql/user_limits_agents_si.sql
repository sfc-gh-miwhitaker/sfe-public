-- =============================================================================
-- CORTEX AGENTS & SNOWFLAKE INTELLIGENCE — REVOKE-BASED ENFORCEMENT
-- Run as: ACCOUNTADMIN
-- Purpose: Monitor per-user Cortex Agent and SI/CoWork spend and revoke access
--          when a user exceeds their budget.
--
-- There is NO native per-user limit for Cortex Agents or Snowflake Intelligence.
-- The enforcement mechanism is role/privilege revocation:
--   - For Agents: revoke USAGE on the specific agent (per-agent granularity)
--   - For SI/CoWork: revoke the CORTEX_AGENT_USER database role (broad) or
--     revoke USAGE on the SI object (targeted)
--
-- Key advantage over AI Functions enforcement:
-- Because agents are first-class Snowflake objects, you can revoke access to
-- ONE agent without affecting access to others. Example: if a user's sales agent
-- budget is exhausted, they can still use their marketing agent.
--
-- Latency: CORTEX_AGENT_USAGE_HISTORY has ~45 minute latency.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS COST_GOVERNANCE;
CREATE SCHEMA IF NOT EXISTS COST_GOVERNANCE.ENFORCEMENT;
USE SCHEMA COST_GOVERNANCE.ENFORCEMENT;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Create a limits table (per user, per agent)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS agent_user_limits (
    user_name         VARCHAR NOT NULL,
    agent_fqn         VARCHAR NOT NULL,    -- e.g., 'MY_DB.MY_SCHEMA.SALES_AGENT'
    daily_credit_limit NUMBER(10,2) NOT NULL,
    is_revoked        BOOLEAN DEFAULT FALSE,
    revoked_at        TIMESTAMP_LTZ,
    restored_at       TIMESTAMP_LTZ,
    CONSTRAINT pk_agent_limits PRIMARY KEY (user_name, agent_fqn)
);

-- Define per-user, per-agent limits.
-- MERGE is Snowflake's upsert (Snowflake has no Postgres-style ON CONFLICT).
MERGE INTO agent_user_limits AS t
USING (
    SELECT column1 AS user_name, column2 AS agent_fqn, column3 AS daily_credit_limit
    FROM VALUES
        ('ALICE', 'MY_DB.MY_SCHEMA.SALES_AGENT', 15.00),
        ('ALICE', 'MY_DB.MY_SCHEMA.SUPPORT_AGENT', 5.00),
        ('BOB',   'MY_DB.MY_SCHEMA.SALES_AGENT', 10.00)
) AS s
    ON t.user_name = s.user_name AND t.agent_fqn = s.agent_fqn
WHEN MATCHED THEN UPDATE SET t.daily_credit_limit = s.daily_credit_limit
WHEN NOT MATCHED THEN INSERT (user_name, agent_fqn, daily_credit_limit)
    VALUES (s.user_name, s.agent_fqn, s.daily_credit_limit);

-- ─────────────────────────────────────────────────────────────────────────────
-- IMPORTANT: Agent access is ROLE-based, not user-based.
-- USAGE ON AGENT is granted TO ROLE, never TO USER. To enforce a limit on a
-- single user, that user needs a dedicated role you can revoke from without
-- affecting others. If multiple users share one role, revoking the agent blocks
-- all of them. (See guide-cowork-only-users for the per-user-role pattern.)
-- The procedure below resolves each user's DEFAULT_ROLE and acts on that role.
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2: Enforcement procedure
-- Revokes USAGE on the specific agent when the user exceeds their budget.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE enforce_agent_limits()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
DECLARE
    v_role STRING;
BEGIN
    -- Compute per-user, per-agent spend in the last 24 hours
    CREATE OR REPLACE TEMPORARY TABLE _agent_usage AS
    SELECT
        user_name,
        agent_database_name || '.' || agent_schema_name || '.' || agent_name AS agent_fqn,
        SUM(token_credits) AS credits_last_24h
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
    WHERE start_time >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
    GROUP BY user_name, agent_fqn;

    -- REVOKE: Users over limit for a specific agent.
    -- USAGE ON AGENT is revoked FROM ROLE (the user's default role), not the user.
    FOR overbudget IN (
        SELECT lim.user_name, lim.agent_fqn
        FROM agent_user_limits lim
        JOIN _agent_usage u
            ON u.user_name = lim.user_name AND u.agent_fqn = lim.agent_fqn
        WHERE u.credits_last_24h >= lim.daily_credit_limit
          AND lim.is_revoked = FALSE
    ) DO
        SELECT default_role INTO :v_role
        FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
        WHERE name = :overbudget.user_name AND deleted_on IS NULL
        ORDER BY created_on DESC
        LIMIT 1;

        IF (v_role IS NOT NULL) THEN
            EXECUTE IMMEDIATE
                'REVOKE USAGE ON AGENT ' || overbudget.agent_fqn ||
                ' FROM ROLE IDENTIFIER(''' || :v_role || ''')';
            UPDATE agent_user_limits
                SET is_revoked = TRUE, revoked_at = CURRENT_TIMESTAMP()
                WHERE user_name = :overbudget.user_name
                  AND agent_fqn = :overbudget.agent_fqn;
        END IF;
    END FOR;

    -- RESTORE: Users back under limit
    FOR underbudget IN (
        SELECT lim.user_name, lim.agent_fqn
        FROM agent_user_limits lim
        LEFT JOIN _agent_usage u
            ON u.user_name = lim.user_name AND u.agent_fqn = lim.agent_fqn
        WHERE COALESCE(u.credits_last_24h, 0) < lim.daily_credit_limit
          AND lim.is_revoked = TRUE
    ) DO
        SELECT default_role INTO :v_role
        FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
        WHERE name = :underbudget.user_name AND deleted_on IS NULL
        ORDER BY created_on DESC
        LIMIT 1;

        IF (v_role IS NOT NULL) THEN
            EXECUTE IMMEDIATE
                'GRANT USAGE ON AGENT ' || underbudget.agent_fqn ||
                ' TO ROLE IDENTIFIER(''' || :v_role || ''')';
            UPDATE agent_user_limits
                SET is_revoked = FALSE, restored_at = CURRENT_TIMESTAMP()
                WHERE user_name = :underbudget.user_name
                  AND agent_fqn = :underbudget.agent_fqn;
        END IF;
    END FOR;

    RETURN 'Agent enforcement check complete';
END;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: Schedule the task
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE TASK enforce_agent_limits_task
  WAREHOUSE = '<your_warehouse>'
  SCHEDULE = '15 MINUTE'
  COMMENT = 'Checks per-user agent spend and revokes/restores USAGE on specific agents'
AS
  CALL COST_GOVERNANCE.ENFORCEMENT.enforce_agent_limits();

ALTER TASK enforce_agent_limits_task RESUME;

-- ─────────────────────────────────────────────────────────────────────────────
-- ALTERNATIVE: Revoke ALL agent access (nuclear option)
-- Use CORTEX_AGENT_USER database role to cut off all agent access at once.
-- Only use this when you want to block ALL Cortex Agent usage for a user.
-- ─────────────────────────────────────────────────────────────────────────────

-- Block ALL agent access for a user
-- REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_AGENT_USER FROM ROLE <user_role>;

-- Restore ALL agent access
-- GRANT DATABASE ROLE SNOWFLAKE.CORTEX_AGENT_USER TO ROLE <user_role>;

-- ─────────────────────────────────────────────────────────────────────────────
-- MONITORING: Current enforcement state
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    user_name,
    agent_fqn,
    daily_credit_limit,
    is_revoked,
    revoked_at,
    restored_at
FROM COST_GOVERNANCE.ENFORCEMENT.agent_user_limits
ORDER BY is_revoked DESC, user_name, agent_fqn;
