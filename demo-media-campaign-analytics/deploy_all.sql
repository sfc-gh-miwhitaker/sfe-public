/*==============================================================================
DEPLOY ALL - Media Campaign Analytics
Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-12

INSTRUCTIONS:
  1. Open Snowsight → New Worksheet
  2. Paste this entire file
  3. Click "Run All"
  Expected runtime: ~5 minutes

WHAT GETS CREATED:
  Database:  SNOWFLAKE_EXAMPLE (shared, if not exists)
  Schema:    SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS
  Schema:    SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS (shared, if not exists)
  Warehouse: SFE_MEDIA_CAMPAIGN_WH
  Tables:    DIM_CLIENT, DIM_CHANNEL, DIM_CAMPAIGN, FACT_DAILY_PERFORMANCE
  View:      V_CAMPAIGN_KPI
  Sem View:  SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS
  Agent:     SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.MEDIA_CAMPAIGN_AGENT

AFTER DEPLOY:
  1. Snowsight → AI & ML → Agents → MEDIA_CAMPAIGN_AGENT → "Add to CoWork"
  2. Open CoWork, select Campaign Analytics agent
  3. Try: "Which channel has the highest ROAS this year?"
==============================================================================*/

-- ── 1. Expiration check ───────────────────────────────────────────────────────
SELECT
    '2026-08-12'::DATE AS expiration_date,
    CURRENT_DATE()     AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2026-08-12'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-08-12'::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2026-08-12'::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), '2026-08-12'::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), '2026-08-12'::DATE) || ' days remaining'
    END AS demo_status;

-- ── 2. Infrastructure ─────────────────────────────────────────────────────────
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'Shared database for SE demo projects';

CREATE WAREHOUSE IF NOT EXISTS SFE_MEDIA_CAMPAIGN_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 300
  COMMENT = 'DEMO: Media campaign analytics compute (Expires: 2026-08-12)';

USE WAREHOUSE SFE_MEDIA_CAMPAIGN_WH;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS
  COMMENT = 'Shared schema for semantic views across SE demo projects';

CREATE OR REPLACE SCHEMA SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS
  COMMENT = 'DEMO: Paid media campaign performance analytics (Expires: 2026-08-12)';

USE SCHEMA SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS;

-- ── 3. Tables ─────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE DIM_CLIENT (
    CLIENT_ID    NUMBER        NOT NULL PRIMARY KEY,
    CLIENT_NAME  VARCHAR(50)   NOT NULL,
    VERTICAL     VARCHAR(30)   NOT NULL,
    TIER         VARCHAR(20)   NOT NULL,
    COMMENT      VARCHAR(200)
) COMMENT = 'DEMO: Advertising client dimension — 20 fictional clients (Expires: 2026-08-12)';

CREATE OR REPLACE TABLE DIM_CHANNEL (
    CHANNEL_ID    NUMBER       NOT NULL PRIMARY KEY,
    CHANNEL_NAME  VARCHAR(50)  NOT NULL,
    CHANNEL_TYPE  VARCHAR(30)  NOT NULL
) COMMENT = 'DEMO: Media channel dimension — 5 paid media channels (Expires: 2026-08-12)';

CREATE OR REPLACE TABLE DIM_CAMPAIGN (
    CAMPAIGN_ID    NUMBER        NOT NULL PRIMARY KEY,
    CLIENT_ID      NUMBER        NOT NULL,
    CHANNEL_ID     NUMBER        NOT NULL,
    CAMPAIGN_NAME  VARCHAR(100)  NOT NULL,
    OBJECTIVE      VARCHAR(50)   NOT NULL,
    BUDGET         NUMBER(12,2)  NOT NULL,
    START_DATE     DATE          NOT NULL,
    END_DATE       DATE          NOT NULL,
    STATUS         VARCHAR(20)   NOT NULL
) COMMENT = 'DEMO: Campaign dimension — ~300 synthetic campaigns (Expires: 2026-08-12)';

CREATE OR REPLACE TABLE FACT_DAILY_PERFORMANCE (
    PERF_ID                 NUMBER        NOT NULL PRIMARY KEY,
    CAMPAIGN_ID             NUMBER        NOT NULL,
    CHANNEL_ID              NUMBER        NOT NULL,
    CLIENT_ID               NUMBER        NOT NULL,
    PERF_DATE               DATE          NOT NULL,
    IMPRESSIONS             NUMBER(15,0)  NOT NULL,
    CLICKS                  NUMBER(12,0)  NOT NULL,
    CONVERSIONS             NUMBER(10,0)  NOT NULL,
    SPEND                   NUMBER(12,2)  NOT NULL,
    REVENUE                 NUMBER(14,2)  NOT NULL,
    DAILY_BUDGET_ALLOCATION NUMBER(12,2)  NOT NULL
) COMMENT = 'DEMO: Daily campaign performance fact table — Jan 2025 to Jun 2026 (Expires: 2026-08-12)';

-- ── 4. Dimension data ─────────────────────────────────────────────────────────
INSERT INTO DIM_CLIENT (CLIENT_ID, CLIENT_NAME, VERTICAL, TIER, COMMENT) VALUES
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

INSERT INTO DIM_CHANNEL (CHANNEL_ID, CHANNEL_NAME, CHANNEL_TYPE) VALUES
    (1, 'Paid Search',      'Digital'),
    (2, 'Social Media',     'Digital'),
    (3, 'Display',          'Digital'),
    (4, 'Connected TV',     'Video'),
    (5, 'Streaming Audio',  'Audio');

-- ── 5. Campaign data (300 rows via GENERATOR) ─────────────────────────────────
INSERT INTO DIM_CAMPAIGN (CAMPAIGN_ID, CLIENT_ID, CHANNEL_ID, CAMPAIGN_NAME, OBJECTIVE, BUDGET, START_DATE, END_DATE, STATUS)
WITH seq AS (
    SELECT ROW_NUMBER() OVER (ORDER BY seq4()) AS rn
    FROM TABLE(GENERATOR(ROWCOUNT => 300))
),
params AS (
    SELECT
        rn                                        AS campaign_id,
        CEIL(rn / 15.0)                           AS client_id,
        MOD(rn - 1, 5) + 1                        AS channel_id,
        'Campaign_' || LPAD(rn::VARCHAR, 4, '0')  AS campaign_name,
        CASE MOD(rn, 4)
            WHEN 0 THEN 'Brand Awareness'
            WHEN 1 THEN 'Lead Generation'
            WHEN 2 THEN 'Direct Response'
            ELSE        'Retargeting'
        END AS objective,
        ROUND(
            UNIFORM(5000, 80000, RANDOM()) *
            CASE WHEN CEIL(rn / 15.0) <= 5  THEN 2.0
                 WHEN CEIL(rn / 15.0) <= 13 THEN 1.0
                 ELSE 0.5 END,
        -3)::NUMBER(12,2) AS budget,
        DATEADD('day', UNIFORM(0, 270, RANDOM()), '2025-01-01')::DATE AS start_date
    FROM seq
),
with_end AS (
    SELECT
        campaign_id, client_id, channel_id, campaign_name, objective, budget,
        start_date,
        DATEADD('day', UNIFORM(60, 180, RANDOM()), start_date)::DATE AS end_date
    FROM params
)
SELECT
    campaign_id, client_id, channel_id, campaign_name, objective, budget,
    start_date, end_date,
    CASE WHEN end_date >= CURRENT_DATE() THEN 'Active' ELSE 'Completed' END AS status
FROM with_end;

-- ── 6. Fact data (daily performance via GENERATOR × campaign dates) ────────────
INSERT INTO FACT_DAILY_PERFORMANCE
    (PERF_ID, CAMPAIGN_ID, CHANNEL_ID, CLIENT_ID, PERF_DATE,
     IMPRESSIONS, CLICKS, CONVERSIONS, SPEND, REVENUE, DAILY_BUDGET_ALLOCATION)
WITH date_range AS (
    SELECT DATEADD('day', ROW_NUMBER() OVER (ORDER BY seq4()) - 1, '2025-01-01')::DATE AS d
    FROM TABLE(GENERATOR(ROWCOUNT => 547))
),
campaign_dates AS (
    SELECT
        campaign_id, channel_id, client_id, budget,
        start_date, end_date,
        GREATEST(DATEDIFF('day', start_date, end_date), 1) AS duration_days
    FROM DIM_CAMPAIGN
),
daily_rows AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY cd.campaign_id, d.d) AS perf_id,
        cd.campaign_id,
        cd.channel_id,
        cd.client_id,
        d.d AS perf_date,
        cd.budget / cd.duration_days AS daily_budget_allocation
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
        CASE dr.channel_id
            WHEN 1 THEN UNIFORM(8000,   60000,   RANDOM())
            WHEN 2 THEN UNIFORM(30000,  250000,  RANDOM())
            WHEN 3 THEN UNIFORM(200000, 1500000, RANDOM())
            WHEN 4 THEN UNIFORM(15000,  120000,  RANDOM())
            WHEN 5 THEN UNIFORM(25000,  150000,  RANDOM())
        END::NUMBER(15,0) AS impressions,
        CASE dr.channel_id
            WHEN 1 THEN UNIFORM(300,  500,  RANDOM()) / 10000.0
            WHEN 2 THEN UNIFORM(100,  200,  RANDOM()) / 10000.0
            WHEN 3 THEN UNIFORM(10,   30,   RANDOM()) / 10000.0
            WHEN 4 THEN 0.0
            WHEN 5 THEN UNIFORM(10,   50,   RANDOM()) / 10000.0
        END AS ctr,
        CASE dr.channel_id
            WHEN 1 THEN UNIFORM(200, 400, RANDOM()) / 10000.0
            WHEN 2 THEN UNIFORM(100, 300, RANDOM()) / 10000.0
            WHEN 3 THEN UNIFORM(50,  100, RANDOM()) / 10000.0
            WHEN 4 THEN 0.0
            WHEN 5 THEN UNIFORM(50,  100, RANDOM()) / 10000.0
        END AS cvr,
        CASE dr.channel_id
            WHEN 1 THEN UNIFORM(800,  1500, RANDOM()) / 100.0
            WHEN 2 THEN UNIFORM(1000, 2500, RANDOM()) / 100.0
            WHEN 3 THEN UNIFORM(200,  800,  RANDOM()) / 100.0
            WHEN 4 THEN UNIFORM(2500, 4500, RANDOM()) / 100.0
            WHEN 5 THEN UNIFORM(1000, 2000, RANDOM()) / 100.0
        END AS cpm,
        CASE dr.channel_id
            WHEN 1 THEN UNIFORM(300,  500,  RANDOM()) / 100.0
            WHEN 2 THEN UNIFORM(150,  300,  RANDOM()) / 100.0
            WHEN 3 THEN UNIFORM(100,  200,  RANDOM()) / 100.0
            WHEN 4 THEN UNIFORM(50,   150,  RANDOM()) / 100.0
            WHEN 5 THEN UNIFORM(100,  200,  RANDOM()) / 100.0
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
    FLOOR(impressions * ctr)::NUMBER(12,0)                    AS clicks,
    FLOOR(impressions * ctr * cvr)::NUMBER(10,0)              AS conversions,
    ROUND((impressions / 1000.0) * cpm, 2)                    AS spend,
    ROUND((impressions / 1000.0) * cpm * roas_multiplier, 2)  AS revenue,
    ROUND(daily_budget_allocation, 2)                          AS daily_budget_allocation
FROM with_metrics;

-- ── 7. KPI view ───────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW V_CAMPAIGN_KPI
COMMENT = 'DEMO: Flattened daily campaign KPI view for semantic layer (Expires: 2026-08-12)'
AS
SELECT
    f.perf_date,
    DATE_TRUNC('month', f.perf_date)   AS perf_month,
    DATE_TRUNC('quarter', f.perf_date) AS perf_quarter,
    YEAR(f.perf_date)                  AS perf_year,
    c.campaign_id,
    c.campaign_name,
    c.objective,
    c.budget                           AS campaign_budget,
    c.start_date                       AS campaign_start_date,
    c.end_date                         AS campaign_end_date,
    c.status                           AS campaign_status,
    cl.client_id,
    cl.client_name,
    cl.vertical,
    cl.tier,
    ch.channel_id,
    ch.channel_name,
    ch.channel_type,
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

-- ── 8. Semantic view ──────────────────────────────────────────────────────────
CREATE OR REPLACE SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS

  TABLES (
    kpi AS SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.V_CAMPAIGN_KPI
      PRIMARY KEY (campaign_id, perf_date)
      WITH SYNONYMS ('campaign performance', 'media analytics', 'ad performance')
      COMMENT = 'Daily paid media performance — one row per campaign per day. 20 clients, 5 channels, Jan 2025 to Jun 2026.'
  )

  DIMENSIONS (
    kpi.dim_date AS perf_date
      WITH SYNONYMS = ('date', 'day', 'performance date')
      COMMENT = 'Calendar date of the performance record',

    kpi.dim_month AS perf_month
      WITH SYNONYMS = ('month', 'calendar month')
      COMMENT = 'Month of the performance record',

    kpi.dim_quarter AS perf_quarter
      WITH SYNONYMS = ('quarter', 'fiscal quarter', 'Q1', 'Q2', 'Q3', 'Q4')
      COMMENT = 'Quarter of the performance record',

    kpi.dim_year AS perf_year
      WITH SYNONYMS = ('year', 'annual')
      COMMENT = 'Calendar year of the performance record',

    kpi.dim_campaign_name AS campaign_name
      WITH SYNONYMS = ('campaign', 'ad campaign', 'campaign name')
      COMMENT = 'Name of the advertising campaign',

    kpi.dim_objective AS objective
      WITH SYNONYMS = ('campaign objective', 'goal', 'campaign goal', 'campaign type')
      COMMENT = 'Campaign objective'
      SAMPLE_VALUES ('Brand Awareness', 'Lead Generation', 'Direct Response', 'Retargeting')
      IS_ENUM,

    kpi.dim_campaign_status AS campaign_status
      WITH SYNONYMS = ('status', 'active', 'completed')
      COMMENT = 'Campaign lifecycle status'
      SAMPLE_VALUES ('Active', 'Completed')
      IS_ENUM,

    kpi.dim_campaign_start AS campaign_start_date
      WITH SYNONYMS = ('start date', 'launch date', 'flight start')
      COMMENT = 'Date the campaign began running',

    kpi.dim_campaign_end AS campaign_end_date
      WITH SYNONYMS = ('end date', 'flight end')
      COMMENT = 'Date the campaign stopped running',

    kpi.dim_client_name AS client_name
      WITH SYNONYMS = ('client', 'advertiser', 'account', 'brand')
      COMMENT = 'Name of the advertising client',

    kpi.dim_vertical AS vertical
      WITH SYNONYMS = ('industry', 'sector', 'vertical', 'category')
      COMMENT = 'Client industry vertical'
      SAMPLE_VALUES ('Retail', 'Finance', 'Healthcare', 'Technology', 'Consumer Goods')
      IS_ENUM,

    kpi.dim_tier AS tier
      WITH SYNONYMS = ('client tier', 'account tier', 'segment', 'size')
      COMMENT = 'Client tier by spend size'
      SAMPLE_VALUES ('Enterprise', 'Mid-Market', 'SMB')
      IS_ENUM,

    kpi.dim_channel_name AS channel_name
      WITH SYNONYMS = ('channel', 'media channel', 'media type', 'placement')
      COMMENT = 'Media channel where ads ran'
      SAMPLE_VALUES ('Paid Search', 'Social Media', 'Display', 'Connected TV', 'Streaming Audio')
      IS_ENUM,

    kpi.dim_channel_type AS channel_type
      WITH SYNONYMS = ('channel category', 'media category', 'medium')
      COMMENT = 'Broad channel category'
      SAMPLE_VALUES ('Digital', 'Video', 'Audio')
      IS_ENUM
  )

  FACTS (
    PRIVATE kpi.f_impressions AS impressions
      COMMENT = 'Raw daily impression count',

    PRIVATE kpi.f_clicks AS clicks
      COMMENT = 'Raw daily click count (0 for Connected TV)',

    PRIVATE kpi.f_conversions AS conversions
      COMMENT = 'Raw daily conversion count',

    PRIVATE kpi.f_spend AS spend
      COMMENT = 'Raw daily media spend in USD',

    PRIVATE kpi.f_revenue AS revenue
      COMMENT = 'Raw daily attributed revenue in USD',

    PRIVATE kpi.f_daily_budget AS daily_budget_allocation
      COMMENT = 'Campaign budget divided by campaign duration days'
  )

  METRICS (
    kpi.m_impressions AS SUM(impressions)
      WITH SYNONYMS = ('total impressions', 'impressions delivered', 'reach')
      COMMENT = 'Total ad impressions delivered',

    kpi.m_clicks AS SUM(clicks)
      WITH SYNONYMS = ('total clicks', 'link clicks')
      COMMENT = 'Total ad clicks (0 for Connected TV)',

    kpi.m_conversions AS SUM(conversions)
      WITH SYNONYMS = ('total conversions', 'actions', 'acquisitions')
      COMMENT = 'Total attributed conversions',

    kpi.m_spend AS SUM(spend)
      WITH SYNONYMS = ('total spend', 'media spend', 'ad spend', 'cost', 'investment')
      COMMENT = 'Total paid media spend in USD',

    kpi.m_revenue AS SUM(revenue)
      WITH SYNONYMS = ('total revenue', 'attributed revenue', 'return')
      COMMENT = 'Total attributed revenue in USD',

    PRIVATE kpi.m_budget_allocation AS SUM(daily_budget_allocation)
      COMMENT = 'Sum of daily budget allocations',

    m_roas AS ROUND(kpi.m_revenue / NULLIF(kpi.m_spend, 0), 2)
      WITH SYNONYMS = ('ROAS', 'return on ad spend', 'return on investment', 'ROI')
      COMMENT = 'Return on Ad Spend = Total Revenue / Total Spend',

    m_ctr_pct AS ROUND(kpi.m_clicks / NULLIF(kpi.m_impressions, 0) * 100, 3)
      WITH SYNONYMS = ('CTR', 'click through rate', 'click rate')
      COMMENT = 'Click-Through Rate % = Clicks / Impressions × 100. Not applicable for Connected TV.',

    m_cpm AS ROUND(kpi.m_spend / NULLIF(kpi.m_impressions, 0) * 1000, 2)
      WITH SYNONYMS = ('CPM', 'cost per thousand', 'cost per mille')
      COMMENT = 'Cost Per Thousand Impressions',

    m_cpc AS ROUND(kpi.m_spend / NULLIF(kpi.m_clicks, 0), 2)
      WITH SYNONYMS = ('CPC', 'cost per click', 'cost per visit')
      COMMENT = 'Cost Per Click. NULL for Connected TV.',

    m_cvr_pct AS ROUND(kpi.m_conversions / NULLIF(kpi.m_clicks, 0) * 100, 2)
      WITH SYNONYMS = ('CVR', 'conversion rate', 'click to conversion rate')
      COMMENT = 'Conversion Rate % = Conversions / Clicks × 100. NULL for Connected TV.',

    m_budget_utilization_pct AS ROUND(kpi.m_spend / NULLIF(kpi.m_budget_allocation, 0) * 100, 1)
      WITH SYNONYMS = ('budget utilization', 'budget pacing', 'pacing', 'spend vs budget', 'budget burn')
      COMMENT = 'Budget Utilization % = Spend / Budget Allocation × 100'
  )

  AI_SQL_GENERATION
    'Round all percentage metrics to 1 decimal place in output.
     When comparing time periods, show both periods side by side.
     For budget pacing, filter to Active campaigns unless asked otherwise.
     Connected TV has zero clicks and conversions by design — do not flag as missing data.'

  AI_VERIFIED_QUERIES (
    q_roas_by_channel AS (
      QUESTION 'Which channel has the highest ROAS this year?'
      VERIFIED_AT 1752440400
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = se_community)'
      SQL 'SELECT
               ch.channel_name,
               ROUND(SUM(f.revenue) / NULLIF(SUM(f.spend), 0), 2) AS roas
           FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE f
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CHANNEL ch ON f.channel_id = ch.channel_id
           WHERE f.perf_date >= DATE_TRUNC(''year'', CURRENT_DATE())
           GROUP BY ch.channel_name
           ORDER BY roas DESC NULLS LAST'
    ),

    q_over_budget_campaigns AS (
      QUESTION 'Which active campaigns are pacing over budget?'
      VERIFIED_AT 1752440400
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = se_community)'
      SQL 'SELECT
               c.campaign_name,
               cl.client_name,
               ch.channel_name,
               c.budget,
               ROUND(SUM(f.spend), 2) AS total_spend,
               ROUND(SUM(f.spend) / NULLIF(c.budget, 0) * 100, 1) AS budget_utilization_pct
           FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE f
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CAMPAIGN c ON f.campaign_id = c.campaign_id
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CLIENT cl ON f.client_id = cl.client_id
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CHANNEL ch ON f.channel_id = ch.channel_id
           WHERE c.status = ''Active''
           GROUP BY c.campaign_name, cl.client_name, ch.channel_name, c.budget
           HAVING SUM(f.spend) > c.budget
           ORDER BY budget_utilization_pct DESC
           LIMIT 20'
    ),

    q_ctr_by_channel AS (
      QUESTION 'Compare click-through rates across channels this year'
      VERIFIED_AT 1752440400
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = se_community)'
      SQL 'SELECT
               ch.channel_name,
               ROUND(SUM(f.clicks) / NULLIF(SUM(f.impressions), 0) * 100, 3) AS ctr_pct,
               SUM(f.impressions) AS total_impressions,
               SUM(f.clicks) AS total_clicks
           FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE f
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CHANNEL ch ON f.channel_id = ch.channel_id
           WHERE f.perf_date >= DATE_TRUNC(''year'', CURRENT_DATE())
             AND ch.channel_name != ''Connected TV''
           GROUP BY ch.channel_name
           ORDER BY ctr_pct DESC'
    ),

    q_spend_last_30_days AS (
      QUESTION 'What is total spend by channel for the last 30 days?'
      VERIFIED_AT 1752440400
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = se_community)'
      SQL 'SELECT
               ch.channel_name,
               ROUND(SUM(f.spend), 0) AS total_spend,
               ROUND(SUM(f.revenue), 0) AS total_revenue,
               ROUND(SUM(f.revenue) / NULLIF(SUM(f.spend), 0), 2) AS roas
           FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE f
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CHANNEL ch ON f.channel_id = ch.channel_id
           WHERE f.perf_date >= DATEADD(''day'', -30, CURRENT_DATE())
           GROUP BY ch.channel_name
           ORDER BY total_spend DESC'
    ),

    q_bottom_campaigns_cvr AS (
      QUESTION 'Show the bottom 5 campaigns by conversion rate'
      VERIFIED_AT 1752440400
      ONBOARDING_QUESTION FALSE
      VERIFIED_BY '(STEWARD = se_community)'
      SQL 'SELECT
               c.campaign_name,
               cl.client_name,
               ch.channel_name,
               ROUND(SUM(f.conversions) / NULLIF(SUM(f.clicks), 0) * 100, 2) AS cvr_pct,
               SUM(f.clicks) AS total_clicks,
               SUM(f.conversions) AS total_conversions
           FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE f
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CAMPAIGN c ON f.campaign_id = c.campaign_id
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CLIENT cl ON f.client_id = cl.client_id
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CHANNEL ch ON f.channel_id = ch.channel_id
           WHERE ch.channel_name != ''Connected TV''
             AND f.perf_date >= DATE_TRUNC(''year'', CURRENT_DATE())
           GROUP BY c.campaign_name, cl.client_name, ch.channel_name
           HAVING SUM(f.clicks) > 1000
           ORDER BY cvr_pct ASC NULLS LAST
           LIMIT 5'
    ),

    q_ctv_spend_quarterly AS (
      QUESTION 'How has Connected TV spend trended by quarter?'
      VERIFIED_AT 1752440400
      ONBOARDING_QUESTION FALSE
      VERIFIED_BY '(STEWARD = se_community)'
      SQL 'SELECT
               DATE_TRUNC(''quarter'', f.perf_date) AS quarter,
               ROUND(SUM(f.spend), 0) AS total_spend,
               SUM(f.impressions) AS total_impressions,
               ROUND(SUM(f.spend) / NULLIF(SUM(f.impressions), 0) * 1000, 2) AS cpm
           FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE f
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CHANNEL ch ON f.channel_id = ch.channel_id
           WHERE ch.channel_name = ''Connected TV''
           GROUP BY DATE_TRUNC(''quarter'', f.perf_date)
           ORDER BY quarter'
    ),

    q_roas_by_client AS (
      QUESTION 'Which clients have the highest ROAS this quarter?'
      VERIFIED_AT 1752440400
      ONBOARDING_QUESTION FALSE
      VERIFIED_BY '(STEWARD = se_community)'
      SQL 'SELECT
               cl.client_name,
               cl.vertical,
               ROUND(SUM(f.revenue) / NULLIF(SUM(f.spend), 0), 2) AS roas,
               ROUND(SUM(f.spend), 0) AS total_spend,
               ROUND(SUM(f.revenue), 0) AS total_revenue
           FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE f
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CLIENT cl ON f.client_id = cl.client_id
           WHERE f.perf_date >= DATE_TRUNC(''quarter'', CURRENT_DATE())
           GROUP BY cl.client_name, cl.vertical
           ORDER BY roas DESC NULLS LAST
           LIMIT 10'
    ),

    q_spend_by_objective AS (
      QUESTION 'Break down total spend by campaign objective this year'
      VERIFIED_AT 1752440400
      ONBOARDING_QUESTION FALSE
      VERIFIED_BY '(STEWARD = se_community)'
      SQL 'SELECT
               c.objective,
               ROUND(SUM(f.spend), 0) AS total_spend,
               ROUND(SUM(f.revenue), 0) AS total_revenue,
               ROUND(SUM(f.revenue) / NULLIF(SUM(f.spend), 0), 2) AS roas,
               COUNT(DISTINCT c.campaign_id) AS campaign_count
           FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE f
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CAMPAIGN c ON f.campaign_id = c.campaign_id
           WHERE f.perf_date >= DATE_TRUNC(''year'', CURRENT_DATE())
           GROUP BY c.objective
           ORDER BY total_spend DESC'
    )
  )

  COMMENT = 'DEMO: Paid media campaign analytics semantic view — 20 clients, 5 channels, 18 months. Expires: 2026-08-12';

-- ── 9. Agent ──────────────────────────────────────────────────────────────────
USE SCHEMA SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS;

CREATE OR REPLACE AGENT MEDIA_CAMPAIGN_AGENT
  COMMENT = 'DEMO: Media campaign performance analytics agent — natural language over paid media KPIs. Expires: 2026-08-12'
  PROFILE = '{"display_name": "Campaign Analytics", "avatar": "chart-bar", "color": "blue"}'
  FROM SPECIFICATION
  $$

  orchestration:
    budget:
      seconds: 45
      tokens: 32000

  instructions:
    response: |
      You are a media analytics assistant helping agency teams understand paid media performance.
      Always show numbers in context — pair a metric with a comparison (vs last period, vs benchmark, vs budget).
      Format currency as $X,XXX. Format percentages to 1 decimal place.
      When a channel is Connected TV, note that CTR and CVR are not applicable (impression-only medium).
      Keep responses concise — lead with the key number, follow with context.
    orchestration: |
      Use the CampaignAnalytics tool for all questions about campaign performance, spend, ROAS, CTR,
      conversions, budgets, and channel comparisons. Use data_to_chart whenever the user asks for a chart,
      trend, comparison across more than 3 items, or when the result is a ranking.
    sample_questions:
      - question: "Which channel has the highest ROAS this year?"
      - question: "Which active campaigns are pacing over budget?"
      - question: "Compare click-through rates across channels this year"
      - question: "What is total spend by channel for the last 30 days?"
      - question: "Which clients have the highest ROAS this quarter?"
      - question: "How has Connected TV spend trended by quarter?"
      - question: "Break down total spend by campaign objective this year"
      - question: "Show the bottom 5 campaigns by conversion rate"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "CampaignAnalytics"
        description: |
          Converts natural language questions about paid media performance into SQL and returns results.
          Use for: spend, ROAS, CTR, CPM, CPC, CVR, conversions, impressions, budget pacing,
          channel comparisons, client rankings, campaign performance, time-period comparisons,
          and any KPI trending. Data covers 20 clients across 5 channels (Paid Search, Social Media,
          Display, Connected TV, Streaming Audio) from January 2025 through June 2026.
    - tool_spec:
        type: "data_to_chart"
        name: "data_to_chart"
        description: "Generates bar charts, line charts, and tables from query results. Use for trends, rankings, and multi-item comparisons."

  tool_resources:
    CampaignAnalytics:
      semantic_view: "SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS"
      execution_environment:
        type: warehouse
        warehouse: "SFE_MEDIA_CAMPAIGN_WH"
  $$;

-- ── 10. Final validation (the only result shown in Run All) ───────────────────
SELECT
    'Media Campaign Analytics' AS demo,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CLIENT)             AS clients,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CAMPAIGN)           AS campaigns,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE) AS fact_rows,
    'Snowsight → AI & ML → Agents → MEDIA_CAMPAIGN_AGENT'                                    AS next_step;
