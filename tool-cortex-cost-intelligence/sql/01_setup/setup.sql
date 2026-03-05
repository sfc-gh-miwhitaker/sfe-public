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
