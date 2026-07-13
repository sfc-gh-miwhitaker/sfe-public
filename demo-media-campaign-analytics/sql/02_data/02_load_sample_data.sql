/*==============================================================================
  02_data/02_load_sample_data.sql
  Media Campaign Analytics — Synthetic Data Load
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-12

  Generates:
    - 20 fictional clients (Client Alpha through Client Tango)
    - 5 media channels
    - ~300 campaigns (15 per client, distributed across channels)
    - ~30K daily performance rows (Jan 2025 – Jun 2026)
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_MEDIA_CAMPAIGN_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS;

-- ── DIM_CLIENT ────────────────────────────────────────────────────────────────
INSERT INTO DIM_CLIENT (CLIENT_ID, CLIENT_NAME, VERTICAL, TIER, COMMENT)
VALUES
    (1,  'Client Alpha',    'Retail',          'Enterprise', NULL),
    (2,  'Client Bravo',    'Finance',         'Enterprise', NULL),
    (3,  'Client Charlie',  'Healthcare',      'Enterprise', NULL),
    (4,  'Client Delta',    'Technology',      'Enterprise', NULL),
    (5,  'Client Echo',     'Consumer Goods',  'Enterprise', NULL),
    (6,  'Client Foxtrot',  'Retail',          'Mid-Market', NULL),
    (7,  'Client Golf',     'Finance',         'Mid-Market', NULL),
    (8,  'Client Hotel',    'Healthcare',      'Mid-Market', NULL),
    (9,  'Client India',    'Technology',      'Mid-Market', NULL),
    (10, 'Client Juliet',   'Consumer Goods',  'Mid-Market', NULL),
    (11, 'Client Kilo',     'Retail',          'Mid-Market', NULL),
    (12, 'Client Lima',     'Finance',         'Mid-Market', NULL),
    (13, 'Client Mike',     'Healthcare',      'Mid-Market', NULL),
    (14, 'Client November', 'Technology',      'SMB',        NULL),
    (15, 'Client Oscar',    'Consumer Goods',  'SMB',        NULL),
    (16, 'Client Papa',     'Retail',          'SMB',        NULL),
    (17, 'Client Quebec',   'Finance',         'SMB',        NULL),
    (18, 'Client Romeo',    'Healthcare',      'SMB',        NULL),
    (19, 'Client Sierra',   'Technology',      'SMB',        NULL),
    (20, 'Client Tango',    'Consumer Goods',  'SMB',        NULL);

-- ── DIM_CHANNEL ───────────────────────────────────────────────────────────────
INSERT INTO DIM_CHANNEL (CHANNEL_ID, CHANNEL_NAME, CHANNEL_TYPE)
VALUES
    (1, 'Paid Search',      'Digital'),
    (2, 'Social Media',     'Digital'),
    (3, 'Display',          'Digital'),
    (4, 'Connected TV',     'Video'),
    (5, 'Streaming Audio',  'Audio');

-- ── DIM_CAMPAIGN ─────────────────────────────────────────────────────────────
-- 15 campaigns per client × 20 clients = 300 campaigns
-- Distributed: 3 per channel per client
-- Start dates span Jan–Sep 2025 so campaigns fall within the fact data window
INSERT INTO DIM_CAMPAIGN (CAMPAIGN_ID, CLIENT_ID, CHANNEL_ID, CAMPAIGN_NAME, OBJECTIVE, BUDGET, START_DATE, END_DATE, STATUS)
WITH seq AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS rn
    FROM TABLE(GENERATOR(ROWCOUNT => 300))
),
params AS (
    SELECT
        rn                                          AS campaign_id,
        CEIL(rn / 15.0)                             AS client_id,       -- 1-20
        MOD(rn - 1, 5) + 1                          AS channel_id,      -- 1-5 cycling
        'Campaign_' || LPAD(rn::VARCHAR, 4, '0')    AS campaign_name,
        CASE MOD(rn, 4)
            WHEN 0 THEN 'Brand Awareness'
            WHEN 1 THEN 'Lead Generation'
            WHEN 2 THEN 'Direct Response'
            ELSE        'Retargeting'
        END AS objective,
        -- Budget: enterprise clients get larger budgets
        ROUND(
            UNIFORM(5000, 80000, RANDOM()) *
            CASE WHEN CEIL(rn / 15.0) <= 5 THEN 2.0    -- Enterprise
                 WHEN CEIL(rn / 15.0) <= 13 THEN 1.0   -- Mid-Market
                 ELSE 0.5 END,                          -- SMB
        -3)::NUMBER(12,2) AS budget,
        -- Start dates spread across Jan-Sep 2025
        DATEADD('day', UNIFORM(0, 270, RANDOM()), '2025-01-01')::DATE AS start_date
    FROM seq
)
SELECT
    p.campaign_id,
    p.client_id,
    p.channel_id,
    p.campaign_name,
    p.objective,
    p.budget,
    p.start_date,
    DATEADD('day', UNIFORM(60, 180, RANDOM()), p.start_date)::DATE AS end_date,
    CASE
        WHEN DATEADD('day', UNIFORM(60, 180, RANDOM()), p.start_date) >= CURRENT_DATE() THEN 'Active'
        ELSE 'Completed'
    END AS status
FROM params p;

-- Fix status after end_date is computed (status derived from actual end_date)
UPDATE DIM_CAMPAIGN
SET STATUS = CASE WHEN END_DATE >= CURRENT_DATE() THEN 'Active' ELSE 'Completed' END;

-- ── FACT_DAILY_PERFORMANCE ────────────────────────────────────────────────────
-- One row per campaign per day the campaign was running
-- Channel-specific performance characteristics applied via CASE expressions
-- CTV has 0 clicks (impression-based medium)
INSERT INTO FACT_DAILY_PERFORMANCE
    (PERF_ID, CAMPAIGN_ID, CHANNEL_ID, CLIENT_ID, PERF_DATE,
     IMPRESSIONS, CLICKS, CONVERSIONS, SPEND, REVENUE, DAILY_BUDGET_ALLOCATION)
WITH date_range AS (
    SELECT
        DATEADD('day', ROW_NUMBER() OVER (ORDER BY seq4()) - 1, '2025-01-01')::DATE AS d
    FROM TABLE(GENERATOR(ROWCOUNT => 547))    -- Jan 1 2025 – Jun 30 2026
),
campaign_dates AS (
    SELECT
        c.campaign_id,
        c.channel_id,
        c.client_id,
        c.budget,
        c.start_date,
        c.end_date,
        GREATEST(DATEDIFF('day', c.start_date, c.end_date), 1) AS duration_days
    FROM DIM_CAMPAIGN c
),
daily_rows AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY cd.campaign_id, d.d)  AS perf_id,
        cd.campaign_id,
        cd.channel_id,
        cd.client_id,
        d.d                                                AS perf_date,
        cd.budget / cd.duration_days                       AS daily_budget_allocation
    FROM campaign_dates cd
    JOIN date_range d ON d.d >= cd.start_date AND d.d <= cd.end_date
),
with_metrics AS (
    SELECT
        dr.perf_id,
        dr.campaign_id,
        dr.channel_id,
        dr.client_id,
        dr.perf_date,
        dr.daily_budget_allocation,

        -- Impressions by channel type
        CASE dr.channel_id
            WHEN 1 THEN UNIFORM(8000,   60000,   RANDOM())   -- Paid Search
            WHEN 2 THEN UNIFORM(30000,  250000,  RANDOM())   -- Social Media
            WHEN 3 THEN UNIFORM(200000, 1500000, RANDOM())   -- Display
            WHEN 4 THEN UNIFORM(15000,  120000,  RANDOM())   -- Connected TV
            WHEN 5 THEN UNIFORM(25000,  150000,  RANDOM())   -- Streaming Audio
        END::NUMBER(15,0) AS impressions,

        -- Click-through rate by channel (CTV = 0)
        CASE dr.channel_id
            WHEN 1 THEN UNIFORM(300,  500,  RANDOM()) / 10000.0   -- 3-5% CTR
            WHEN 2 THEN UNIFORM(100,  200,  RANDOM()) / 10000.0   -- 1-2%
            WHEN 3 THEN UNIFORM(10,   30,   RANDOM()) / 10000.0   -- 0.1-0.3%
            WHEN 4 THEN 0.0                                        -- CTV: no clicks
            WHEN 5 THEN UNIFORM(10,   50,   RANDOM()) / 10000.0   -- 0.1-0.5%
        END AS ctr,

        -- Conversion rate (% of clicks; 0 for CTV)
        CASE dr.channel_id
            WHEN 1 THEN UNIFORM(200, 400, RANDOM()) / 10000.0   -- 2-4% CVR
            WHEN 2 THEN UNIFORM(100, 300, RANDOM()) / 10000.0   -- 1-3%
            WHEN 3 THEN UNIFORM(50,  100, RANDOM()) / 10000.0   -- 0.5-1%
            WHEN 4 THEN 0.0                                      -- CTV: no conversions
            WHEN 5 THEN UNIFORM(50,  100, RANDOM()) / 10000.0   -- 0.5-1%
        END AS cvr,

        -- CPM by channel ($)
        CASE dr.channel_id
            WHEN 1 THEN UNIFORM(800,  1500, RANDOM()) / 100.0    -- $8-15
            WHEN 2 THEN UNIFORM(1000, 2500, RANDOM()) / 100.0    -- $10-25
            WHEN 3 THEN UNIFORM(200,  800,  RANDOM()) / 100.0    -- $2-8
            WHEN 4 THEN UNIFORM(2500, 4500, RANDOM()) / 100.0    -- $25-45
            WHEN 5 THEN UNIFORM(1000, 2000, RANDOM()) / 100.0    -- $10-20
        END AS cpm,

        -- ROAS multiplier by channel
        CASE dr.channel_id
            WHEN 1 THEN UNIFORM(300,  500,  RANDOM()) / 100.0   -- 3-5x
            WHEN 2 THEN UNIFORM(150,  300,  RANDOM()) / 100.0   -- 1.5-3x
            WHEN 3 THEN UNIFORM(100,  200,  RANDOM()) / 100.0   -- 1-2x
            WHEN 4 THEN UNIFORM(50,   150,  RANDOM()) / 100.0   -- 0.5-1.5x (brand)
            WHEN 5 THEN UNIFORM(100,  200,  RANDOM()) / 100.0   -- 1-2x
        END AS roas_multiplier

    FROM daily_rows dr
)
SELECT
    perf_id,
    campaign_id,
    channel_id,
    client_id,
    perf_date,
    impressions,
    FLOOR(impressions * ctr)::NUMBER(12,0)                                   AS clicks,
    FLOOR(impressions * ctr * cvr)::NUMBER(10,0)                             AS conversions,
    ROUND((impressions / 1000.0) * cpm, 2)                                   AS spend,
    ROUND((impressions / 1000.0) * cpm * roas_multiplier, 2)                 AS revenue,
    ROUND(daily_budget_allocation, 2)                                         AS daily_budget_allocation
FROM with_metrics;
