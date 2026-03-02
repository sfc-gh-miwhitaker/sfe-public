/*******************************************************************************
 * DEMO PROJECT: Cortex Cost Calculator - Configuration Management
 *
 * AUTHOR: SE Community
 * CREATED: 2026-01-05
 * See deploy_all.sql for expiration (30 days)
 *
 * PURPOSE:
 *   Centralized configuration management for Cortex Cost Calculator.
 *   Eliminates hardcoded values and enables runtime configuration changes.
 *
 * DEPLOYMENT METHOD: Run before or after deploy_cortex_monitoring.sql
 *
 * USAGE:
 *   -- Update a setting
 *   UPDATE SNOWFLAKE_EXAMPLE.CORTEX_USAGE.CORTEX_USAGE_CONFIG
 *   SET setting_value = '180'
 *   WHERE setting_name = 'LOOKBACK_DAYS';
 *
 *   -- Read a setting in a view
 *   SELECT setting_value
 *   FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.CORTEX_USAGE_CONFIG
 *   WHERE setting_name = 'CREDIT_COST_USD';
 *
 * VERSION: 1.0
 * LAST UPDATED: 2026-02-18
 ******************************************************************************/

-- ===========================================================================
-- SETUP: USE CORTEX_USAGE SCHEMA
-- ===========================================================================

USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_USAGE;

-- ===========================================================================
-- EXPIRATION CHECK (MANDATORY)
-- ===========================================================================
DECLARE
    demo_expired EXCEPTION (-20001, 'DEMO EXPIRED: Do not deploy. Fork the repository and update expiration + syntax.');
    expiration_date DATE := $demo_expiration_date::DATE;
BEGIN
    IF (CURRENT_DATE() > expiration_date) THEN
        RAISE demo_expired;
    END IF;
END;

-- ===========================================================================
-- CREATE CONFIGURATION TABLE
-- ===========================================================================

CREATE TRANSIENT TABLE IF NOT EXISTS CORTEX_USAGE_CONFIG (
    setting_name VARCHAR(100) PRIMARY KEY,
    setting_value VARCHAR(1000) NOT NULL,
    description VARCHAR(500),
    data_type VARCHAR(50) DEFAULT 'STRING',
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_by VARCHAR(100) DEFAULT CURRENT_USER()
)
COMMENT = 'DEMO: cortex-trail - Configuration settings for Cortex Cost Calculator | See deploy_all.sql for expiration';

-- ===========================================================================
-- INSERT DEFAULT CONFIGURATION VALUES
-- ===========================================================================

-- Merge configuration values (upsert pattern)
MERGE INTO CORTEX_USAGE_CONFIG AS target
USING (
    SELECT column1 AS setting_name, column2 AS setting_value, column3 AS description, column4 AS data_type
    FROM VALUES
        -- Data retention and lookback
        ('LOOKBACK_DAYS', '90', 'Default lookback period for monitoring views (days)', 'INTEGER'),
        ('SNAPSHOT_RETENTION_DAYS', '365', 'How long to keep historical snapshots (days)', 'INTEGER'),

        -- Pricing configuration
        ('CREDIT_COST_USD', '3.00', 'Default Snowflake credit cost in USD', 'DECIMAL'),
        ('CREDIT_COST_EUR', '2.70', 'Default Snowflake credit cost in EUR', 'DECIMAL'),
        ('CREDIT_COST_GBP', '2.40', 'Default Snowflake credit cost in GBP', 'DECIMAL'),
        ('CREDIT_COST_JPY', '420.00', 'Default Snowflake credit cost in JPY', 'DECIMAL'),

        -- Task scheduling
        ('SNAPSHOT_SCHEDULE', '0 3 * * *', 'Cron schedule for daily snapshot task (3 AM daily)', 'STRING'),
        ('SNAPSHOT_TASK_WAREHOUSE', 'COMPUTE_WH', 'Warehouse for snapshot task (use SERVERLESS for serverless)', 'STRING'),

        -- Alerting thresholds
        ('ANOMALY_THRESHOLD_HIGH', '0.50', 'Week-over-week growth threshold for HIGH alerts (50%)', 'DECIMAL'),
        ('ANOMALY_THRESHOLD_MEDIUM', '0.25', 'Week-over-week growth threshold for MEDIUM alerts (25%)', 'DECIMAL'),

        -- Forecasting parameters
        ('FORECAST_ENABLED', 'TRUE', 'Enable ML.FORECAST model for projections', 'BOOLEAN'),
        ('FORECAST_HORIZON_DAYS', '365', 'Forecast horizon in days (12 months)', 'INTEGER'),

        -- Data quality
        ('MIN_DATA_POINTS_FOR_FORECAST', '14', 'Minimum days of data required for forecasting', 'INTEGER'),
        ('MAX_CSV_UPLOAD_ROWS', '100000', 'Maximum rows allowed in CSV uploads', 'INTEGER'),

        -- Feature flags
        ('ENABLE_USER_ATTRIBUTION', 'TRUE', 'Enable user-level spend attribution tracking', 'BOOLEAN'),
        ('ENABLE_QUERY_COST_ANALYSIS', 'TRUE', 'Enable query-level cost analysis', 'BOOLEAN'),
        ('ENABLE_ML_FORECAST', 'FALSE', 'Enable ML-based forecasting (requires ML.FORECAST privileges)', 'BOOLEAN'),

        -- Display preferences
        ('DEFAULT_CURRENCY', 'USD', 'Default currency for cost display', 'STRING'),
        ('DECIMAL_PLACES', '2', 'Decimal places for currency display', 'INTEGER'),

        -- System metadata
        ('CONFIG_VERSION', '1.0', 'Configuration schema version', 'STRING'),
        ('DEPLOYMENT_DATE', CURRENT_TIMESTAMP()::VARCHAR, 'Date of configuration deployment', 'TIMESTAMP')
) AS source
ON target.setting_name = source.setting_name
WHEN MATCHED THEN UPDATE SET
    target.description = source.description,
    target.data_type = source.data_type
WHEN NOT MATCHED THEN INSERT (setting_name, setting_value, description, data_type)
VALUES (source.setting_name, source.setting_value, source.description, source.data_type);

-- ===========================================================================
-- CREATE HELPER FUNCTION FOR READING CONFIG
-- ===========================================================================

-- Function to get a configuration value
CREATE OR REPLACE FUNCTION GET_CONFIG(setting_name_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT setting_value
    FROM SNOWFLAKE_EXAMPLE.CORTEX_USAGE.CORTEX_USAGE_CONFIG
    WHERE setting_name = setting_name_param
$$;

-- ===========================================================================
-- DEPLOYMENT COMPLETE
-- ===========================================================================

SELECT
    'Configuration system deployed successfully' AS status,
    COUNT(*) AS settings_count,
    MAX(updated_at) AS last_updated
FROM CORTEX_USAGE_CONFIG;

-- View all configuration settings
SELECT
    setting_name,
    setting_value,
    description,
    data_type,
    updated_at
FROM CORTEX_USAGE_CONFIG
ORDER BY setting_name;
