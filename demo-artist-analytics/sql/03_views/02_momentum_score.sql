/*==============================================================================
  03_views/02_momentum_score.sql
  Artist Analytics — Show Momentum Score
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-23

  V_SHOW_MOMENTUM: one row per upcoming show.

  Momentum Score = (avg daily engagements in 14d pre-show window)
                  / (avg daily engagements in the 30d baseline window ending 15d before show)
                  × 100

  Score > 100  → building momentum in that market
  Score = 100  → flat (no change from baseline)
  Score < 100  → cooling off (may need a push)

  Baseline window: [show_date - 44d, show_date - 15d]  (30 days)
  Pre-show window: [show_date - 14d, show_date - 1d]   (14 days)

  Only rows where the window falls within available data are included.
  If the pre-show window starts in the future (show > 14 days away),
  pre_show_avg will be NULL and score will be NULL — expected behavior.
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_ARTIST_ANALYTICS_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS;

CREATE OR REPLACE VIEW V_SHOW_MOMENTUM
COMMENT = 'Momentum score per upcoming show: social engagement velocity vs baseline'
AS
WITH show_windows AS (
    SELECT
        show_id,
        show_name,
        venue_city,
        show_date,
        ticket_capacity,
        ticket_price,
        DATEADD('day', -14, show_date)  AS pre_show_start,
        DATEADD('day',  -1, show_date)  AS pre_show_end,
        DATEADD('day', -44, show_date)  AS baseline_start,
        DATEADD('day', -15, show_date)  AS baseline_end
    FROM DIM_SHOW
    WHERE show_date >= CURRENT_DATE()
),
regional_daily AS (
    -- Sum all social platforms per (date, region)
    SELECT
        metric_date,
        region,
        SUM(engagements)  AS total_engagements,
        SUM(impressions)  AS total_impressions
    FROM FACT_SOCIAL_METRICS
    GROUP BY metric_date, region
),
momentum_calc AS (
    SELECT
        sw.show_id,
        sw.show_name,
        sw.venue_city,
        sw.show_date,
        sw.ticket_capacity,
        sw.ticket_price,
        sw.pre_show_start,
        sw.pre_show_end,
        sw.baseline_start,
        sw.baseline_end,
        -- Pre-show average (may be NULL if window is in the future)
        AVG(CASE
            WHEN rd.metric_date >= sw.pre_show_start
             AND rd.metric_date <= sw.pre_show_end
             AND rd.region = sw.venue_city
            THEN rd.total_engagements
        END) AS pre_show_avg,
        -- Baseline average
        AVG(CASE
            WHEN rd.metric_date >= sw.baseline_start
             AND rd.metric_date <= sw.baseline_end
             AND rd.region = sw.venue_city
            THEN rd.total_engagements
        END) AS baseline_avg,
        -- How many days of pre-show data we actually have
        COUNT(CASE
            WHEN rd.metric_date >= sw.pre_show_start
             AND rd.metric_date <= LEAST(sw.pre_show_end, CURRENT_DATE() - 1)
             AND rd.region = sw.venue_city
            THEN 1
        END) AS pre_show_data_days
    FROM show_windows sw
    CROSS JOIN regional_daily rd
    GROUP BY
        sw.show_id, sw.show_name, sw.venue_city, sw.show_date,
        sw.ticket_capacity, sw.ticket_price,
        sw.pre_show_start, sw.pre_show_end, sw.baseline_start, sw.baseline_end
)
SELECT
    show_id,
    show_name,
    venue_city,
    show_date,
    ticket_capacity,
    ticket_price,
    DATEDIFF('day', CURRENT_DATE(), show_date)  AS days_until_show,
    ROUND(baseline_avg, 0)::NUMBER(10,0)        AS baseline_daily_engagements,
    ROUND(pre_show_avg, 0)::NUMBER(10,0)        AS pre_show_daily_engagements,
    pre_show_data_days,
    CASE
        WHEN pre_show_avg IS NULL OR baseline_avg IS NULL OR baseline_avg = 0
        THEN NULL
        ELSE ROUND((pre_show_avg / baseline_avg) * 100, 1)
    END::NUMBER(6,1)                            AS momentum_score,
    CASE
        WHEN pre_show_avg IS NULL OR baseline_avg IS NULL
        THEN 'Insufficient data'
        WHEN (pre_show_avg / NULLIF(baseline_avg, 0)) * 100 >= 120
        THEN 'Strong — fan base is activated'
        WHEN (pre_show_avg / NULLIF(baseline_avg, 0)) * 100 >= 100
        THEN 'Building — slight positive trend'
        ELSE 'Needs push — below baseline'
    END                                         AS momentum_label
FROM momentum_calc
ORDER BY show_date;

SELECT
    show_name, venue_city, show_date,
    days_until_show, momentum_score, momentum_label
FROM V_SHOW_MOMENTUM;
