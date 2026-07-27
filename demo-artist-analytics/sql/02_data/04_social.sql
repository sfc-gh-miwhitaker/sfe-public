/*==============================================================================
  02_data/04_social.sql
  Artist Analytics — Synthetic Social Media Data (90 days × 4 platforms × 5 regions)
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-23

  Generates FACT_SOCIAL_METRICS: one row per (date, social_platform, region).
  Regions match DIM_SHOW.VENUE_CITY so V_SHOW_MOMENTUM can join.

  Each show city gets a momentum bump in the 14 days before its show date,
  simulating a real fan engagement spike as the date approaches.
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_ARTIST_ANALYTICS_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS;

CREATE OR REPLACE TABLE FACT_SOCIAL_METRICS (
    SOCIAL_ID          NUMBER(10)  NOT NULL,
    METRIC_DATE        DATE        NOT NULL,
    SOCIAL_PLATFORM_ID NUMBER(4)   NOT NULL,
    REGION             VARCHAR(50) NOT NULL COMMENT 'Matches DIM_SHOW.VENUE_CITY for momentum scoring',
    IMPRESSIONS        NUMBER(12)  NOT NULL,
    ENGAGEMENTS        NUMBER(10)  NOT NULL,
    SHARES             NUMBER(8)   NOT NULL,
    CONSTRAINT PK_FACT_SOCIAL_METRICS PRIMARY KEY (SOCIAL_ID)
)
COMMENT = 'Daily social media metrics by platform and region — 90 days of synthetic data';

INSERT INTO FACT_SOCIAL_METRICS (SOCIAL_ID, METRIC_DATE, SOCIAL_PLATFORM_ID, REGION, IMPRESSIONS, ENGAGEMENTS, SHARES)
WITH dates AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) - 1 AS day_offset,
        DATEADD('day', -(90 - ROW_NUMBER() OVER (ORDER BY seq4()) + 1), CURRENT_DATE()) AS metric_date
    FROM TABLE(GENERATOR(ROWCOUNT => 90))
),
regions AS (
    SELECT COLUMN1 AS region
    FROM VALUES ('Nashville'), ('Austin'), ('Chicago'), ('Los Angeles'), ('New York')
),
social_platforms AS (
    SELECT SOCIAL_PLATFORM_ID FROM DIM_SOCIAL_PLATFORM
),
show_windows AS (
    -- Pre-compute which city has a show coming within 14 days of each date
    SELECT
        VENUE_CITY,
        SHOW_DATE,
        DATEADD('day', -14, SHOW_DATE) AS window_start,
        DATEADD('day',  -1, SHOW_DATE) AS window_end
    FROM DIM_SHOW
),
base_cross AS (
    SELECT
        d.metric_date,
        d.day_offset,
        r.region,
        s.social_platform_id,
        -- growth factor: +30% over 90 days (organic audience growth)
        1.0 + (d.day_offset / 90.0 * 0.30) AS growth_factor,
        -- momentum boost: 1.5x if within 14 days before a show in this region
        COALESCE(
            MAX(CASE
                WHEN d.metric_date >= sw.window_start
                  AND d.metric_date <= sw.window_end
                  AND r.region = sw.venue_city
                THEN 1.5
                ELSE NULL
            END) OVER (PARTITION BY d.metric_date, r.region),
            1.0
        ) AS momentum_boost
    FROM dates d
    CROSS JOIN regions r
    CROSS JOIN social_platforms s
    LEFT JOIN show_windows sw
        ON d.metric_date BETWEEN sw.window_start AND sw.window_end
        AND r.region = sw.venue_city
),
with_metrics AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY metric_date, region, social_platform_id) AS social_id,
        metric_date,
        social_platform_id,
        region,
        growth_factor * momentum_boost AS effective_multiplier,
        -- Base impressions by platform
        CASE social_platform_id
            WHEN 1 THEN UNIFORM(8000,   25000,  RANDOM())   -- TikTok: highest reach
            WHEN 2 THEN UNIFORM(5000,   18000,  RANDOM())   -- Instagram
            WHEN 3 THEN UNIFORM(3000,   12000,  RANDOM())   -- YouTube Shorts
            WHEN 4 THEN UNIFORM(1500,    6000,  RANDOM())   -- X
        END AS base_impressions,
        -- Engagement rate by platform
        CASE social_platform_id
            WHEN 1 THEN UNIFORM(400,  800,  RANDOM()) / 10000.0   -- TikTok: 4-8%
            WHEN 2 THEN UNIFORM(300,  600,  RANDOM()) / 10000.0   -- Instagram: 3-6%
            WHEN 3 THEN UNIFORM(200,  500,  RANDOM()) / 10000.0   -- YouTube: 2-5%
            WHEN 4 THEN UNIFORM(100,  300,  RANDOM()) / 10000.0   -- X: 1-3%
        END AS engagement_rate,
        -- Share rate: 0.5-2% of engagements
        UNIFORM(50, 200, RANDOM()) / 10000.0 AS share_rate
    FROM base_cross
)
SELECT
    social_id,
    metric_date,
    social_platform_id,
    region,
    FLOOR(base_impressions * effective_multiplier)::NUMBER(12)                         AS impressions,
    FLOOR(base_impressions * effective_multiplier * engagement_rate)::NUMBER(10)       AS engagements,
    FLOOR(base_impressions * effective_multiplier * engagement_rate * share_rate)::NUMBER(8) AS shares
FROM with_metrics;

SELECT
    COUNT(*)          AS total_rows,
    MIN(metric_date)  AS earliest_date,
    MAX(metric_date)  AS latest_date,
    SUM(impressions)  AS total_impressions,
    SUM(engagements)  AS total_engagements,
    ROUND(SUM(engagements) / NULLIF(SUM(impressions), 0) * 100, 2) AS avg_engagement_rate_pct
FROM FACT_SOCIAL_METRICS;
