-- ============================================================================
-- Materialized Tables + Refresh Task
-- Pre-aggregates ACCOUNT_USAGE data for fast dashboard response.
-- Pair-programmed by SE Community + Cortex Code
-- ============================================================================

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_AI_COST_CONTROLS;

-- ---------------------------------------------------------------------------
-- Table 1: Unified AI usage (row-level detail, last 90 days)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS MAT_AI_USAGE_UNIFIED (
    service_type    VARCHAR,
    user_id         NUMBER,
    user_name       VARCHAR,
    credits         NUMBER(38,12),
    tokens          NUMBER,
    usage_time      TIMESTAMP_LTZ,
    request_id      VARCHAR,
    role_name       VARCHAR,
    user_tags       VARIANT,
    entity_name     VARCHAR,
    interaction_interface VARCHAR
);

-- ---------------------------------------------------------------------------
-- Table 2: Daily spend aggregates
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS MAT_AI_SPEND_DAILY (
    usage_date      DATE,
    service_type    VARCHAR,
    total_credits   NUMBER(38,12),
    total_tokens    NUMBER,
    unique_users    NUMBER
);

-- ---------------------------------------------------------------------------
-- Table 3: Per-user spend summary (rolling 30d)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS MAT_AI_SPEND_BY_USER (
    user_id         NUMBER,
    user_name       VARCHAR,
    service_type    VARCHAR,
    total_credits   NUMBER(38,12),
    total_tokens    NUMBER,
    request_count   NUMBER,
    user_tags       VARIANT,
    last_seen       TIMESTAMP_LTZ
);

-- ---------------------------------------------------------------------------
-- Table 4: Agent attribution
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS MAT_AGENT_ATTRIBUTION (
    agent_name              VARCHAR,
    agent_database_name     VARCHAR,
    agent_schema_name       VARCHAR,
    cost_center_tag         VARCHAR,
    total_credits           NUMBER(38,12),
    total_tokens            NUMBER,
    request_count           NUMBER,
    interaction_interface   VARCHAR,
    sql_query_credits       NUMBER(38,12)
);

-- ---------------------------------------------------------------------------
-- Table 5: Quota status snapshot
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS MAT_QUOTA_STATUS (
    snapshot_time       TIMESTAMP_LTZ,
    quota_name          VARCHAR,
    quota_database      VARCHAR,
    quota_schema        VARCHAR,
    per_user_limit      NUMBER(38,12),
    daily_limit         NUMBER(38,12),
    block_enforcement   BOOLEAN,
    users_in_scope      NUMBER,
    users_blocked       NUMBER
);

-- ---------------------------------------------------------------------------
-- Refresh Procedure
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SP_REFRESH_COST_MATERIALIZATION()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
    -- 1. Unified usage (last 90 days)
    CREATE OR REPLACE TEMPORARY TABLE tmp_unified AS
    WITH ai_functions AS (
        SELECT
            'AI_FUNCTION' AS service_type,
            f.USER_ID,
            u.NAME AS user_name,
            f.CREDITS,
            NULL AS tokens,
            f.START_TIME AS usage_time,
            f.QUERY_ID AS request_id,
            f.ROLE_NAMES[0]::VARCHAR AS role_name,
            NULL AS user_tags,
            f.FUNCTION_NAME || ' (' || COALESCE(f.MODEL_NAME, 'default') || ')' AS entity_name,
            NULL AS interaction_interface
        FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY f
        LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON f.USER_ID = u.USER_ID
        WHERE f.START_TIME >= DATEADD('day', -90, CURRENT_TIMESTAMP())
    ),
    agents AS (
        SELECT
            'CORTEX_AGENT' AS service_type,
            a.USER_ID,
            a.USER_NAME,
            a.TOKEN_CREDITS AS credits,
            a.TOKENS,
            a.START_TIME AS usage_time,
            a.REQUEST_ID,
            a.METADATA:role_name::VARCHAR AS role_name,
            a.USER_TAGS,
            a.AGENT_NAME AS entity_name,
            a.METADATA:interaction_interface::VARCHAR AS interaction_interface
        FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY a
        WHERE a.START_TIME >= DATEADD('day', -90, CURRENT_TIMESTAMP())
    ),
    cowork AS (
        SELECT
            'SNOWFLAKE_COWORK' AS service_type,
            c.USER_ID,
            c.USER_NAME,
            c.TOKEN_CREDITS AS credits,
            c.TOKENS,
            c.START_TIME AS usage_time,
            c.REQUEST_ID,
            c.METADATA:role_name::VARCHAR AS role_name,
            c.USER_TAGS,
            c.SNOWFLAKE_COWORK_NAME AS entity_name,
            NULL AS interaction_interface
        FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COWORK_USAGE_HISTORY c
        WHERE c.START_TIME >= DATEADD('day', -90, CURRENT_TIMESTAMP())
    ),
    coco AS (
        SELECT
            'CORTEX_CODE' AS service_type,
            cc.USER_ID,
            NULL AS user_name,
            cc.TOKEN_CREDITS AS credits,
            cc.TOKENS,
            cc.USAGE_TIME AS usage_time,
            cc.REQUEST_ID,
            cc.METADATA:role_name::VARCHAR AS role_name,
            cc.USER_TAGS,
            'CoCo' AS entity_name,
            NULL AS interaction_interface
        FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COCO_USAGE_HISTORY cc
        WHERE cc.USAGE_TIME >= DATEADD('day', -90, CURRENT_TIMESTAMP())
    )
    SELECT * FROM ai_functions
    UNION ALL SELECT * FROM agents
    UNION ALL SELECT * FROM cowork
    UNION ALL SELECT * FROM coco;

    INSERT OVERWRITE INTO MAT_AI_USAGE_UNIFIED
    SELECT * FROM tmp_unified;

    -- 2. Daily spend
    INSERT OVERWRITE INTO MAT_AI_SPEND_DAILY
    SELECT
        usage_time::DATE AS usage_date,
        service_type,
        SUM(credits) AS total_credits,
        SUM(tokens) AS total_tokens,
        COUNT(DISTINCT user_id) AS unique_users
    FROM MAT_AI_USAGE_UNIFIED
    GROUP BY 1, 2;

    -- 3. Per-user spend (30d)
    INSERT OVERWRITE INTO MAT_AI_SPEND_BY_USER
    SELECT
        user_id,
        user_name,
        service_type,
        SUM(credits) AS total_credits,
        SUM(tokens) AS total_tokens,
        COUNT(*) AS request_count,
        ANY_VALUE(user_tags) AS user_tags,
        MAX(usage_time) AS last_seen
    FROM MAT_AI_USAGE_UNIFIED
    WHERE usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
    GROUP BY user_id, user_name, service_type;

    -- 4. Agent attribution (30d)
    INSERT OVERWRITE INTO MAT_AGENT_ATTRIBUTION
    SELECT
        AGENT_NAME,
        AGENT_DATABASE_NAME,
        AGENT_SCHEMA_NAME,
        -- Extract cost-center from AGENT_TAGS array
        (SELECT t.VALUE:tag_value::VARCHAR
         FROM LATERAL FLATTEN(input => a.AGENT_TAGS) t
         WHERE LOWER(t.VALUE:tag_name::VARCHAR) = 'cost-center'
         LIMIT 1) AS cost_center_tag,
        SUM(TOKEN_CREDITS) AS total_credits,
        SUM(TOKENS) AS total_tokens,
        COUNT(*) AS request_count,
        METADATA:interaction_interface::VARCHAR AS interaction_interface,
        SUM(METADATA:sql_query_credits::NUMBER(38,12)) AS sql_query_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY a
    WHERE START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
    GROUP BY AGENT_NAME, AGENT_DATABASE_NAME, AGENT_SCHEMA_NAME,
             cost_center_tag, interaction_interface;

    -- 5. Quota status snapshot (best-effort; quotas may not exist)
    -- Note: This requires listing quotas which uses SHOW commands.
    -- For the materialization, we simply truncate and rely on the app
    -- to call quota methods directly when needed.
    -- Placeholder: quota status is queried live by the app.

    RETURN 'Materialization complete: ' || CURRENT_TIMESTAMP()::VARCHAR;
END;
$$;

-- ---------------------------------------------------------------------------
-- Scheduled Task (ships SUSPENDED for safety)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TASK TASK_REFRESH_COST_MATERIALIZATION
    WAREHOUSE = SFE_CORTEX_AI_COST_CONTROLS_WH
    SCHEDULE = '15 MINUTE'
    COMMENT = 'Refreshes materialized cost tables every 15 minutes'
AS
    CALL SP_REFRESH_COST_MATERIALIZATION();

-- To activate: ALTER TASK TASK_REFRESH_COST_MATERIALIZATION RESUME;

-- Run once immediately to populate tables
CALL SP_REFRESH_COST_MATERIALIZATION();
