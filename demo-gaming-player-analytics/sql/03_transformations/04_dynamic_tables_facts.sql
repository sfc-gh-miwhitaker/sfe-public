/*==============================================================================
FACT + DIMENSION TABLES - Analytics Layer
Fact tables for lifetime value and daily engagement.
Dimension tables for players and dates.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS;
USE WAREHOUSE SFE_GAMING_PLAYER_ANALYTICS_WH;

-- DIM_PLAYERS: Player dimension with AI-assigned cohort
CREATE OR REPLACE DYNAMIC TABLE DIM_PLAYERS
  TARGET_LAG = '1 hour'
  WAREHOUSE = SFE_GAMING_PLAYER_ANALYTICS_WH
  COMMENT = 'DEMO: Player dimension with AI cohort and engagement features (Expires: 2026-04-24)'
AS
SELECT
    p.player_id,
    p.username,
    p.signup_date,
    p.platform,
    p.country,
    p.acquisition_source,
    p.days_since_signup,
    p.ai_player_cohort,
    p.total_spent,
    p.purchase_count,
    p.total_sessions,
    p.last_active_date,
    p.days_since_last_active,
    COALESCE(e.churn_risk_level, 'Unknown') AS churn_risk_level,
    COALESCE(e.active_days_last_30, 0) AS active_days_last_30,
    COALESCE(e.avg_daily_playtime_minutes, 0) AS avg_daily_playtime_minutes,
    COALESCE(e.dau_mau_ratio, 0) AS dau_mau_ratio
FROM DT_PLAYER_PROFILES p
LEFT JOIN DT_ENGAGEMENT_FEATURES e ON p.player_id = e.player_id;

-- DIM_DATES: Standard date dimension (static, not a DT)
CREATE OR REPLACE TABLE DIM_DATES
  COMMENT = 'DEMO: Date dimension for time-series analysis (Expires: 2026-04-24)'
AS
SELECT
    DATEADD('day', SEQ4(), DATEADD('year', -1, CURRENT_DATE())) AS date_key,
    DAYNAME(DATEADD('day', SEQ4(), DATEADD('year', -1, CURRENT_DATE()))) AS day_of_week,
    DAYOFWEEK(DATEADD('day', SEQ4(), DATEADD('year', -1, CURRENT_DATE()))) AS day_of_week_num,
    WEEKOFYEAR(DATEADD('day', SEQ4(), DATEADD('year', -1, CURRENT_DATE()))) AS week_of_year,
    MONTH(DATEADD('day', SEQ4(), DATEADD('year', -1, CURRENT_DATE()))) AS month_num,
    MONTHNAME(DATEADD('day', SEQ4(), DATEADD('year', -1, CURRENT_DATE()))) AS month_name,
    QUARTER(DATEADD('day', SEQ4(), DATEADD('year', -1, CURRENT_DATE()))) AS quarter_num,
    YEAR(DATEADD('day', SEQ4(), DATEADD('year', -1, CURRENT_DATE()))) AS year_num,
    CASE WHEN DAYOFWEEK(DATEADD('day', SEQ4(), DATEADD('year', -1, CURRENT_DATE()))) IN (0, 6)
         THEN TRUE ELSE FALSE END AS is_weekend
FROM TABLE(GENERATOR(ROWCOUNT => 730));

-- FACT_PLAYER_LIFETIME: Per-player lifetime value and engagement summary
CREATE OR REPLACE DYNAMIC TABLE FACT_PLAYER_LIFETIME
  TARGET_LAG = '1 hour'
  WAREHOUSE = SFE_GAMING_PLAYER_ANALYTICS_WH
  COMMENT = 'DEMO: Player lifetime value, engagement, and churn risk metrics (Expires: 2026-04-24)'
AS
SELECT
    p.player_id,
    p.ai_player_cohort,
    p.total_spent AS lifetime_spend,
    p.purchase_count AS lifetime_purchases,
    p.total_sessions AS lifetime_sessions,
    p.days_since_signup,
    p.days_since_last_active,
    COALESCE(e.active_days_last_30, 0) AS active_days_last_30,
    COALESCE(e.sessions_last_30, 0) AS sessions_last_30,
    COALESCE(e.avg_daily_playtime_minutes, 0) AS avg_daily_playtime_minutes,
    COALESCE(e.dau_mau_ratio, 0) AS dau_mau_ratio,
    COALESCE(e.churn_risk_level, 'Unknown') AS churn_risk_level,
    CASE
        WHEN p.total_spent >= 100 AND p.days_since_last_active <= 7 THEN 'High Value Active'
        WHEN p.total_spent >= 100 AND p.days_since_last_active > 7  THEN 'High Value At Risk'
        WHEN p.total_spent < 100  AND p.days_since_last_active <= 7 THEN 'Low Value Active'
        ELSE 'Low Value At Risk'
    END AS value_risk_segment,
    COALESCE(fb.feedback_count, 0) AS feedback_count,
    fb.avg_sentiment_label AS dominant_feedback_sentiment
FROM DT_PLAYER_PROFILES p
LEFT JOIN DT_ENGAGEMENT_FEATURES e ON p.player_id = e.player_id
LEFT JOIN (
    SELECT
        player_id,
        COUNT(*) AS feedback_count,
        MODE(ai_sentiment) AS avg_sentiment_label
    FROM DT_FEEDBACK_ENRICHED
    GROUP BY player_id
) fb ON p.player_id = fb.player_id;

-- FACT_DAILY_ENGAGEMENT: Daily aggregate metrics by cohort
CREATE OR REPLACE DYNAMIC TABLE FACT_DAILY_ENGAGEMENT
  TARGET_LAG = '1 hour'
  WAREHOUSE = SFE_GAMING_PLAYER_ANALYTICS_WH
  COMMENT = 'DEMO: Daily engagement aggregates by player cohort (Expires: 2026-04-24)'
AS
SELECT
    sm.event_date,
    p.ai_player_cohort,
    COUNT(DISTINCT sm.player_id) AS daily_active_players,
    SUM(sm.session_count) AS total_sessions,
    ROUND(AVG(sm.total_playtime_minutes), 1) AS avg_playtime_minutes,
    SUM(sm.levels_completed) AS total_levels_completed,
    SUM(sm.ads_viewed) AS total_ads_viewed,
    COALESCE(rev.daily_revenue, 0) AS daily_revenue
FROM DT_SESSION_METRICS sm
JOIN DT_PLAYER_PROFILES p ON sm.player_id = p.player_id
LEFT JOIN (
    SELECT
        iap.purchase_timestamp::DATE AS purchase_date,
        pp.ai_player_cohort,
        SUM(iap.amount_usd) AS daily_revenue
    FROM RAW_IN_APP_PURCHASES iap
    JOIN DT_PLAYER_PROFILES pp ON iap.player_id = pp.player_id
    GROUP BY iap.purchase_timestamp::DATE, pp.ai_player_cohort
) rev ON sm.event_date = rev.purchase_date AND p.ai_player_cohort = rev.ai_player_cohort
GROUP BY sm.event_date, p.ai_player_cohort, rev.daily_revenue;
