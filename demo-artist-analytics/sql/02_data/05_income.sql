/*==============================================================================
  02_data/05_income.sql
  Artist Analytics — Synthetic Income Data (90 days)
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-23

  Generates FACT_INCOME: one row per day.
  Three income streams:
    - STREAM_ROYALTIES  : computed from FACT_DAILY_STREAMS weighted by ROYALTY_RATE
    - MERCH_ESTIMATE    : random daily merch revenue (spikes around show dates)
    - SYNC_LICENSING    : occasional lump payments (music in ads/TV/film)
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_ARTIST_ANALYTICS_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS;

CREATE OR REPLACE TABLE FACT_INCOME (
    INCOME_ID        NUMBER(8)      NOT NULL,
    INCOME_DATE      DATE           NOT NULL,
    STREAM_ROYALTIES NUMBER(10,2)   NOT NULL COMMENT 'Sum of streams × platform royalty rate',
    MERCH_ESTIMATE   NUMBER(10,2)   NOT NULL COMMENT 'Estimated merch revenue',
    SYNC_LICENSING   NUMBER(10,2)   NOT NULL COMMENT 'Sync licensing (TV, ads, film — occasional)',
    TOTAL_INCOME     NUMBER(10,2)   NOT NULL COMMENT 'Sum of all income streams',
    CONSTRAINT PK_FACT_INCOME PRIMARY KEY (INCOME_ID)
)
COMMENT = 'Daily income aggregated across streaming royalties, merch, and sync licensing';

INSERT INTO FACT_INCOME (INCOME_ID, INCOME_DATE, STREAM_ROYALTIES, MERCH_ESTIMATE, SYNC_LICENSING, TOTAL_INCOME)
WITH royalties AS (
    -- Aggregate actual stream royalties from fact table + dim rates
    SELECT
        fds.stream_date       AS income_date,
        SUM(fds.streams * dp.royalty_rate) AS stream_royalties
    FROM FACT_DAILY_STREAMS fds
    JOIN DIM_PLATFORM dp ON dp.platform_id = fds.platform_id
    GROUP BY fds.stream_date
),
show_proximity AS (
    -- Flag days within 7 days of a show date (merch spike)
    SELECT
        d.income_date,
        COALESCE(
            MAX(CASE
                WHEN ABS(DATEDIFF('day', d.income_date, s.show_date)) <= 7
                THEN 2.5 ELSE NULL
            END),
            1.0
        ) AS merch_multiplier
    FROM royalties d
    CROSS JOIN DIM_SHOW s
    GROUP BY d.income_date
),
dates_merged AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY r.income_date) AS income_id,
        r.income_date,
        ROUND(r.stream_royalties, 2) AS stream_royalties,
        sp.merch_multiplier,
        -- Base merch: $5-40/day; multiplied near shows
        UNIFORM(500, 4000, RANDOM()) / 100.0 AS base_merch,
        -- Sync: ~5% of days get a payment; otherwise 0
        CASE WHEN UNIFORM(1, 100, RANDOM()) <= 5
             THEN ROUND(UNIFORM(50000, 300000, RANDOM()) / 100.0, 2)
             ELSE 0.00
        END AS sync_licensing
    FROM royalties r
    JOIN show_proximity sp ON sp.income_date = r.income_date
)
SELECT
    income_id,
    income_date,
    stream_royalties,
    ROUND(base_merch * merch_multiplier, 2) AS merch_estimate,
    sync_licensing,
    ROUND(stream_royalties + base_merch * merch_multiplier + sync_licensing, 2) AS total_income
FROM dates_merged;

SELECT
    COUNT(*)                       AS total_days,
    ROUND(SUM(stream_royalties),2) AS total_royalties,
    ROUND(SUM(merch_estimate),2)   AS total_merch,
    ROUND(SUM(sync_licensing),2)   AS total_sync,
    ROUND(SUM(total_income),2)     AS total_income
FROM FACT_INCOME;
