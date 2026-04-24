/*==============================================================================
PLAYER PROFILES - Dynamic Table with AI Cohort Assignment
AI_CLASSIFY segments players into Whale/Casual/Churning/New based on behavior.
CTE ensures AI function is called once per player.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS;
USE WAREHOUSE SFE_GAMING_PLAYER_ANALYTICS_WH;

CREATE OR REPLACE DYNAMIC TABLE DT_PLAYER_PROFILES
  TARGET_LAG = '1 hour'
  WAREHOUSE = SFE_GAMING_PLAYER_ANALYTICS_WH
  COMMENT = 'DEMO: Player profiles enriched with AI cohort classification (Expires: 2026-04-24)'
AS
WITH player_stats AS (
    SELECT
        p.player_id,
        p.username,
        p.signup_date,
        p.platform,
        p.country,
        p.acquisition_source,
        DATEDIFF('day', p.signup_date, CURRENT_DATE()) AS days_since_signup,
        COALESCE(purchase_summary.total_spent, 0) AS total_spent,
        COALESCE(purchase_summary.purchase_count, 0) AS purchase_count,
        COALESCE(event_summary.total_sessions, 0) AS total_sessions,
        COALESCE(event_summary.last_active_date, p.signup_date) AS last_active_date,
        DATEDIFF('day', COALESCE(event_summary.last_active_date, p.signup_date), CURRENT_DATE()) AS days_since_last_active
    FROM RAW_PLAYERS p
    LEFT JOIN (
        SELECT
            player_id,
            SUM(amount_usd) AS total_spent,
            COUNT(*) AS purchase_count
        FROM RAW_IN_APP_PURCHASES
        GROUP BY player_id
    ) purchase_summary ON p.player_id = purchase_summary.player_id
    LEFT JOIN (
        SELECT
            player_id,
            COUNT(DISTINCT session_id) AS total_sessions,
            MAX(event_date) AS last_active_date
        FROM RAW_PLAYER_EVENTS
        GROUP BY player_id
    ) event_summary ON p.player_id = event_summary.player_id
),
ai_classified AS (
    SELECT
        *,
        AI_CLASSIFY(
            'Player spent $' || total_spent::VARCHAR || ' across ' || purchase_count::VARCHAR ||
            ' purchases. ' || total_sessions::VARCHAR || ' total sessions over ' ||
            days_since_signup::VARCHAR || ' days. Last active ' ||
            days_since_last_active::VARCHAR || ' days ago.',
            ['Whale', 'Casual', 'Churning', 'New'],
            {'task_description': 'Classify this mobile game player into a behavioral cohort based on their spending, session activity, and recency. Whale = high spender. Casual = moderate activity, low spend. Churning = was active but inactive recently. New = signed up recently with limited data.'}
        ):labels[0]::VARCHAR AS ai_player_cohort
    FROM player_stats
)
SELECT
    player_id,
    username,
    signup_date,
    platform,
    country,
    acquisition_source,
    days_since_signup,
    total_spent,
    purchase_count,
    total_sessions,
    last_active_date,
    days_since_last_active,
    ai_player_cohort
FROM ai_classified;
