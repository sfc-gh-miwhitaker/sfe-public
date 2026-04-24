/*==============================================================================
BUDGET ALERTS - Task-based overspend monitoring
Flags campaigns exceeding budget thresholds.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.MUSIC_MARKETING;
USE WAREHOUSE SFE_MUSIC_MARKETING_WH;

-- View that identifies campaigns currently overspending
CREATE OR REPLACE VIEW V_BUDGET_ALERTS
  COMMENT = 'DEMO: Campaigns exceeding budget thresholds (Expires: 2026-04-24)'
AS
SELECT
    b.campaign_id,
    c.campaign_name,
    a.artist_name,
    b.channel,
    b.territory,
    b.budget_period,
    b.allocated_amount AS monthly_budget,
    COALESCE(s.actual_spend, 0) AS actual_spend,
    COALESCE(s.actual_spend, 0) - b.allocated_amount AS variance,
    ROUND(COALESCE(s.actual_spend, 0) / NULLIF(b.allocated_amount, 0) * 100, 1) AS pct_of_budget,
    CASE
        WHEN COALESCE(s.actual_spend, 0) > b.allocated_amount * 1.2 THEN 'CRITICAL'
        WHEN COALESCE(s.actual_spend, 0) > b.allocated_amount * 1.0 THEN 'WARNING'
        WHEN COALESCE(s.actual_spend, 0) > b.allocated_amount * 0.8 THEN 'ON TRACK'
        ELSE 'UNDER BUDGET'
    END AS alert_status
FROM RAW_MARKETING_BUDGET b
JOIN RAW_ARTISTS a ON b.artist_id = a.artist_id
LEFT JOIN RAW_CAMPAIGNS c ON b.campaign_id = c.campaign_id
LEFT JOIN (
    SELECT
        campaign_id,
        channel,
        DATE_TRUNC('month', spend_date) AS spend_month,
        SUM(amount) AS actual_spend
    FROM RAW_MARKETING_SPEND
    GROUP BY campaign_id, channel, DATE_TRUNC('month', spend_date)
) s ON b.campaign_id = s.campaign_id
    AND b.channel = s.channel
    AND b.budget_period = s.spend_month;

-- Task that logs overspend alerts (runs hourly to match Dynamic Table lag)
CREATE OR REPLACE TABLE BUDGET_ALERT_LOG (
    alert_id        INTEGER AUTOINCREMENT PRIMARY KEY,
    alert_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    campaign_id     INTEGER,
    campaign_name   VARCHAR(500),
    artist_name     VARCHAR(200),
    channel         VARCHAR(100),
    budget_period   DATE,
    monthly_budget  NUMBER(12,2),
    actual_spend    NUMBER(12,2),
    variance        NUMBER(12,2),
    pct_of_budget   NUMBER(6,1),
    alert_status    VARCHAR(20)
) COMMENT = 'DEMO: Budget overspend alert log (Expires: 2026-04-24)';

CREATE OR REPLACE TASK BUDGET_ALERT_TASK
  WAREHOUSE = SFE_MUSIC_MARKETING_WH
  SCHEDULE = 'USING CRON 0 * * * * America/Los_Angeles'
  COMMENT = 'DEMO: Hourly budget alert monitor (Expires: 2026-04-24)'
AS
INSERT INTO BUDGET_ALERT_LOG (campaign_id, campaign_name, artist_name, channel,
    budget_period, monthly_budget, actual_spend, variance, pct_of_budget, alert_status)
SELECT campaign_id, campaign_name, artist_name, channel,
    budget_period, monthly_budget, actual_spend, variance, pct_of_budget, alert_status
FROM V_BUDGET_ALERTS
WHERE alert_status IN ('CRITICAL', 'WARNING')
  AND budget_period = DATE_TRUNC('month', CURRENT_DATE());

ALTER TASK BUDGET_ALERT_TASK RESUME;
