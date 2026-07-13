/*==============================================================================
  03_transformations/01_create_views.sql
  Media Campaign Analytics — KPI Flattened View
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-12
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_MEDIA_CAMPAIGN_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS;

-- Flat view joining all dimensions onto daily performance rows
-- Used as the single logical table in the semantic view (simplifies relationships)
CREATE OR REPLACE VIEW V_CAMPAIGN_KPI
COMMENT = 'DEMO: Flattened daily campaign KPI view for semantic layer (Expires: 2026-08-12)'
AS
SELECT
    -- Date dimensions
    f.perf_date,
    DATE_TRUNC('month', f.perf_date)   AS perf_month,
    DATE_TRUNC('quarter', f.perf_date) AS perf_quarter,
    YEAR(f.perf_date)                  AS perf_year,

    -- Campaign dimensions
    c.campaign_id,
    c.campaign_name,
    c.objective,
    c.budget                           AS campaign_budget,
    c.start_date                       AS campaign_start_date,
    c.end_date                         AS campaign_end_date,
    c.status                           AS campaign_status,

    -- Client dimensions
    cl.client_id,
    cl.client_name,
    cl.vertical,
    cl.tier,

    -- Channel dimensions
    ch.channel_id,
    ch.channel_name,
    ch.channel_type,

    -- Raw performance measures
    f.impressions,
    f.clicks,
    f.conversions,
    f.spend,
    f.revenue,
    f.daily_budget_allocation

FROM FACT_DAILY_PERFORMANCE f
JOIN DIM_CAMPAIGN c  ON f.campaign_id = c.campaign_id
JOIN DIM_CLIENT   cl ON f.client_id   = cl.client_id
JOIN DIM_CHANNEL  ch ON f.channel_id  = ch.channel_id;
