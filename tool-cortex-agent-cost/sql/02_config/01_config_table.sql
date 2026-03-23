CREATE TABLE IF NOT EXISTS AGENT_COST_CONFIG (
    setting_name VARCHAR(100) NOT NULL,
    setting_value VARCHAR(500) NOT NULL,
    description VARCHAR(1000),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (setting_name)
) COMMENT = 'TOOL: Configuration for Cortex Agent Cost dashboard (Expires: 2026-04-22)';

MERGE INTO AGENT_COST_CONFIG tgt
USING (
    SELECT column1 AS setting_name, column2 AS setting_value, column3 AS description
    FROM VALUES
        ('LOOKBACK_DAYS',  '90',   'Number of days of history to display'),
        ('CREDIT_COST_USD','3.00', 'Cost per credit in USD for cost projections')
) src
ON tgt.setting_name = src.setting_name
WHEN NOT MATCHED THEN
    INSERT (setting_name, setting_value, description)
    VALUES (src.setting_name, src.setting_value, src.description);
