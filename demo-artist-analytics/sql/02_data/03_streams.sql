/*==============================================================================
  02_data/03_streams.sql
  Artist Analytics — Synthetic Streaming Data (90 days)
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-23

  Generates FACT_DAILY_STREAMS: one row per (date, platform) for the past 90 days.
  4 platforms × 90 days = 360 rows.

  Stream volumes reflect realistic indie-tier numbers with a mild upward trend
  built in via a growth multiplier.
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_ARTIST_ANALYTICS_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS;

CREATE OR REPLACE TABLE FACT_DAILY_STREAMS (
    STREAM_ID   NUMBER(8)   NOT NULL,
    STREAM_DATE DATE        NOT NULL,
    PLATFORM_ID NUMBER(4)   NOT NULL,
    STREAMS     NUMBER(10)  NOT NULL,
    SAVES       NUMBER(10)  NOT NULL,
    LISTENERS   NUMBER(10)  NOT NULL,
    CONSTRAINT PK_FACT_DAILY_STREAMS PRIMARY KEY (STREAM_ID)
)
COMMENT = 'Daily streaming counts per platform — 90 days of synthetic data';

INSERT INTO FACT_DAILY_STREAMS (STREAM_ID, STREAM_DATE, PLATFORM_ID, STREAMS, SAVES, LISTENERS)
WITH dates AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) - 1          AS day_offset,
        DATEADD('day', -(90 - ROW_NUMBER() OVER (ORDER BY seq4()) + 1), CURRENT_DATE()) AS stream_date
    FROM TABLE(GENERATOR(ROWCOUNT => 90))
),
platforms AS (
    SELECT PLATFORM_ID FROM DIM_PLATFORM
),
cross_dates AS (
    SELECT
        d.stream_date,
        p.platform_id,
        d.day_offset,
        -- mild upward growth: +25% over 90 days
        1.0 + (d.day_offset / 90.0 * 0.25) AS growth_factor
    FROM dates d
    CROSS JOIN platforms p
),
with_metrics AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY stream_date, platform_id) AS stream_id,
        stream_date,
        platform_id,
        growth_factor,
        -- Base volumes by platform (indie artist tier)
        CASE platform_id
            WHEN 1 THEN UNIFORM(3000,  8000,  RANDOM())   -- Spotify: biggest share
            WHEN 2 THEN UNIFORM(1200,  3500,  RANDOM())   -- Apple Music
            WHEN 3 THEN UNIFORM(800,   2500,  RANDOM())   -- Amazon Music
            WHEN 4 THEN UNIFORM(500,   2000,  RANDOM())   -- YouTube
        END AS base_streams,
        -- Save rate: 2-6% of streams
        UNIFORM(200, 600, RANDOM()) / 10000.0 AS save_rate,
        -- Listener ratio: 65-80% of streams (some re-listens)
        UNIFORM(650, 800, RANDOM()) / 1000.0  AS listener_ratio
    FROM cross_dates
)
SELECT
    stream_id,
    stream_date,
    platform_id,
    FLOOR(base_streams * growth_factor)::NUMBER(10)                AS streams,
    FLOOR(base_streams * growth_factor * save_rate)::NUMBER(10)    AS saves,
    FLOOR(base_streams * growth_factor * listener_ratio)::NUMBER(10) AS listeners
FROM with_metrics;

SELECT
    COUNT(*)                     AS total_rows,
    MIN(stream_date)             AS earliest_date,
    MAX(stream_date)             AS latest_date,
    SUM(streams)                 AS total_streams,
    SUM(streams * 0.004)::NUMBER(10,2) AS estimated_royalties_usd
FROM FACT_DAILY_STREAMS;
