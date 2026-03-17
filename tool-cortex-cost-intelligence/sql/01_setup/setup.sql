USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'DEMO: Repository for example/demo projects | See deploy_all.sql for expiration';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE
    COMMENT = 'DEMO: Cortex Cost Intelligence - AI cost governance platform | See deploy_all.sql for expiration';

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CREATE TRANSIENT TABLE IF NOT EXISTS CORTEX_USAGE_CONFIG (
    setting_name    VARCHAR(100) PRIMARY KEY,
    setting_value   VARCHAR(1000) NOT NULL,
    description     VARCHAR(500),
    data_type       VARCHAR(50) DEFAULT 'STRING',
    updated_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_by      VARCHAR(100) DEFAULT CURRENT_USER()
)
COMMENT = 'DEMO: Cortex Cost Intelligence - Runtime configuration | See deploy_all.sql for expiration';

MERGE INTO CORTEX_USAGE_CONFIG AS target
USING (
    SELECT column1 AS setting_name, column2 AS setting_value, column3 AS description, column4 AS data_type
    FROM VALUES
        ('LOOKBACK_DAYS',              '90',    'Default lookback period for monitoring views (days)', 'INTEGER'),
        ('SNAPSHOT_RETENTION_DAYS',    '365',   'How long to keep historical snapshots (days)',        'INTEGER'),
        ('CREDIT_COST_USD',            '3.00',  'Default Snowflake credit cost in USD',                'DECIMAL'),
        ('ANOMALY_THRESHOLD_HIGH',     '0.50',  'WoW growth threshold for HIGH alerts (50%)',          'DECIMAL'),
        ('ANOMALY_THRESHOLD_MEDIUM',   '0.25',  'WoW growth threshold for MEDIUM alerts (25%)',        'DECIMAL'),
        ('FORECAST_HORIZON_DAYS',      '365',   'Forecast horizon in days (12 months)',                'INTEGER'),
        ('MIN_DATA_POINTS_FORECAST',   '14',    'Minimum days of data for forecasting',                'INTEGER'),
        ('ENABLE_GOVERNANCE',          'FALSE', 'Enable governance module (budgets, alerts)',           'BOOLEAN'),
        ('ENABLE_STREAMLIT',           'TRUE',  'Deploy optional Streamlit dashboard',                 'BOOLEAN'),
        ('CONFIG_VERSION',             '4.0',   'Configuration schema version',                        'STRING'),
        ('DEPLOYMENT_DATE', CURRENT_TIMESTAMP()::VARCHAR, 'Date of deployment', 'TIMESTAMP')
) AS source
ON target.setting_name = source.setting_name
WHEN MATCHED THEN UPDATE SET
    target.description = source.description,
    target.data_type   = source.data_type
WHEN NOT MATCHED THEN INSERT (setting_name, setting_value, description, data_type)
VALUES (source.setting_name, source.setting_value, source.description, source.data_type);

-- REST API is billed in USD per token (not credits) per Consumption Table 6(c).
-- This table stores per-model rates so cost_usd can be calculated from token counts.
CREATE TRANSIENT TABLE IF NOT EXISTS REST_API_PRICING (
    model_name          VARCHAR(100) PRIMARY KEY,
    input_usd_per_m     NUMBER(10,4) NOT NULL,
    output_usd_per_m    NUMBER(10,4) NOT NULL,
    effective_date       DATE DEFAULT CURRENT_DATE(),
    updated_at           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'DEMO: Cortex Cost Intelligence - REST API USD-per-token rates from Consumption Table 6(c) | See deploy_all.sql for expiration';

MERGE INTO REST_API_PRICING AS target
USING (
    SELECT column1 AS model_name, column2 AS input_usd_per_m, column3 AS output_usd_per_m
    FROM VALUES
        ('claude-3-5-sonnet',          3.00,   15.00),
        ('deepseek-r1',                1.35,    5.40),
        ('llama3.1-405b',              2.40,    2.40),
        ('llama3.1-70b',               0.72,    0.72),
        ('llama3.1-8b',                0.22,    0.22),
        ('llama3.2-1b',                0.10,    0.10),
        ('llama3.2-3b',                0.15,    0.15),
        ('llama3.3-70b',               0.72,    0.72),
        ('llama4-maverick',            0.24,    0.97),
        ('mistral-large',              4.00,   12.00),
        ('mistral-large2',             2.00,    6.00),
        ('mistral-7b',                 0.15,    0.20),
        ('openai-gpt-oss-120b',        0.15,    0.60),
        ('snowflake-llama-3.3-70b',    0.72,    0.72)
) AS source
ON target.model_name = source.model_name
WHEN NOT MATCHED THEN INSERT (model_name, input_usd_per_m, output_usd_per_m)
VALUES (source.model_name, source.input_usd_per_m, source.output_usd_per_m);

CREATE TRANSIENT TABLE IF NOT EXISTS CORTEX_USAGE_SNAPSHOTS (
    snapshot_date               DATE        NOT NULL,
    service_type                VARCHAR(100),
    daily_unique_users          NUMBER,
    total_operations            NUMBER,
    total_credits               NUMBER(38,6),
    credits_per_user            NUMBER(38,6),
    credits_per_operation       NUMBER(38,6),
    snapshot_created_at         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'DEMO: Cortex Cost Intelligence - Daily usage snapshots for historical tracking | See deploy_all.sql for expiration';

CREATE OR REPLACE TASK TASK_DAILY_CORTEX_SNAPSHOT
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
    SCHEDULE = 'USING CRON 0 3 * * * America/Los_Angeles'
    COMMENT  = 'DEMO: Cortex Cost Intelligence - Daily snapshot of Cortex usage | See deploy_all.sql for expiration'
AS
    INSERT INTO CORTEX_USAGE_SNAPSHOTS (snapshot_date, service_type, daily_unique_users, total_operations, total_credits, credits_per_user, credits_per_operation)
    SELECT
        usage_date,
        service_type,
        daily_unique_users,
        total_operations,
        total_credits,
        credits_per_user,
        credits_per_operation
    FROM SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE.V_CORTEX_DAILY_SUMMARY
    WHERE usage_date = CURRENT_DATE() - 1
      AND NOT EXISTS (
          SELECT 1
          FROM CORTEX_USAGE_SNAPSHOTS s
          WHERE s.snapshot_date = V_CORTEX_DAILY_SUMMARY.usage_date
            AND s.service_type  = V_CORTEX_DAILY_SUMMARY.service_type
      );

ALTER TASK TASK_DAILY_CORTEX_SNAPSHOT RESUME;

SELECT 'Setup complete' AS status, COUNT(*) AS config_settings FROM CORTEX_USAGE_CONFIG;
