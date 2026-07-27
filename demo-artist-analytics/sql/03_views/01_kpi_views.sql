/*==============================================================================
  03_views/01_kpi_views.sql
  Artist Analytics — KPI Views for Streamlit Dashboard
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-23

  Three views power the basic-tier Streamlit dashboard:
    V_STREAM_KPI  — daily streams aggregated across all platforms (+ 7d rolling avg)
    V_SOCIAL_KPI  — daily impressions and engagement rate by social platform
    V_INCOME_KPI  — daily income broken down by type, with 30d rolling total
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_ARTIST_ANALYTICS_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS;

-- ── V_STREAM_KPI ────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW V_STREAM_KPI
COMMENT = 'Daily streams per platform with 7-day rolling average'
AS
SELECT
    fds.stream_date,
    dp.platform_name,
    fds.streams,
    fds.saves,
    fds.listeners,
    AVG(fds.streams) OVER (
        PARTITION BY fds.platform_id
        ORDER BY fds.stream_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )::NUMBER(10,0) AS streams_7d_avg
FROM FACT_DAILY_STREAMS fds
JOIN DIM_PLATFORM dp ON dp.platform_id = fds.platform_id;

-- ── V_SOCIAL_KPI ────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW V_SOCIAL_KPI
COMMENT = 'Daily social impressions and engagement rate by platform, summed across regions'
AS
SELECT
    fsm.metric_date,
    dsp.platform_name                                          AS social_platform,
    SUM(fsm.impressions)                                       AS impressions,
    SUM(fsm.engagements)                                       AS engagements,
    SUM(fsm.shares)                                            AS shares,
    ROUND(
        SUM(fsm.engagements) / NULLIF(SUM(fsm.impressions), 0) * 100,
        2
    )                                                          AS engagement_rate_pct
FROM FACT_SOCIAL_METRICS fsm
JOIN DIM_SOCIAL_PLATFORM dsp ON dsp.social_platform_id = fsm.social_platform_id
GROUP BY fsm.metric_date, dsp.platform_name;

-- ── V_INCOME_KPI ─────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW V_INCOME_KPI
COMMENT = 'Daily income with 30-day rolling cumulative total'
AS
SELECT
    income_date,
    stream_royalties,
    merch_estimate,
    sync_licensing,
    total_income,
    SUM(total_income) OVER (
        ORDER BY income_date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    )::NUMBER(10,2) AS rolling_30d_income
FROM FACT_INCOME;

SELECT
    'V_STREAM_KPI'  AS view_name, COUNT(*) AS rows FROM V_STREAM_KPI
UNION ALL
SELECT 'V_SOCIAL_KPI',  COUNT(*) FROM V_SOCIAL_KPI
UNION ALL
SELECT 'V_INCOME_KPI',  COUNT(*) FROM V_INCOME_KPI;
