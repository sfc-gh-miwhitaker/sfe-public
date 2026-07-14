/*==============================================================================
  04_cortex/01_create_semantic_view.sql
  Media Campaign Analytics — Semantic View
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-12

  Single-table semantic view on V_CAMPAIGN_KPI.
  Derived metrics (ROAS, CTR, CPM, CPC, CVR, budget utilization) computed
  from base metrics using NULLIF guards to prevent division-by-zero on
  CTV rows where clicks = 0.
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_MEDIA_CAMPAIGN_WH;

CREATE OR REPLACE SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS

  TABLES (
    kpi AS SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.V_CAMPAIGN_KPI
      PRIMARY KEY (campaign_id, perf_date)
      WITH SYNONYMS ('campaign performance', 'media analytics', 'ad performance')
      COMMENT = 'Daily paid media performance — one row per campaign per day, Jan 2025 to Jun 2026. Covers 20 fictional clients across 5 channels.'
  )

  FACTS (
    PRIVATE kpi.impressions AS impressions
      COMMENT = 'Raw daily impression count',

    PRIVATE kpi.clicks AS clicks
      COMMENT = 'Raw daily click count (0 for Connected TV)',

    PRIVATE kpi.conversions AS conversions
      COMMENT = 'Raw daily conversion count',

    PRIVATE kpi.spend AS spend
      COMMENT = 'Raw daily media spend in USD',

    PRIVATE kpi.revenue AS revenue
      COMMENT = 'Raw daily attributed revenue in USD',

    PRIVATE kpi.daily_budget_allocation AS daily_budget_allocation
      COMMENT = 'Campaign total budget divided by campaign duration days'
  )

  DIMENSIONS (
    -- Date
    kpi.perf_date AS perf_date
      WITH SYNONYMS = ('date', 'day', 'performance date')
      COMMENT = 'Calendar date of the performance record',

    kpi.perf_month AS perf_month
      WITH SYNONYMS = ('month', 'calendar month')
      COMMENT = 'Month of the performance record (truncated to first of month)',

    kpi.perf_quarter AS perf_quarter
      WITH SYNONYMS = ('quarter', 'fiscal quarter', 'Q1', 'Q2', 'Q3', 'Q4')
      COMMENT = 'Quarter of the performance record (truncated to first day of quarter)',

    kpi.perf_year AS perf_year
      WITH SYNONYMS = ('year', 'annual')
      COMMENT = 'Calendar year of the performance record',

    -- Campaign
    kpi.campaign_name AS campaign_name
      WITH SYNONYMS = ('campaign', 'ad campaign', 'campaign name')
      COMMENT = 'Name of the advertising campaign',

    kpi.objective AS objective
      WITH SYNONYMS = ('campaign objective', 'goal', 'campaign goal', 'campaign type')
      COMMENT = 'Campaign objective: Brand Awareness, Lead Generation, Direct Response, or Retargeting'
      SAMPLE_VALUES ('Brand Awareness', 'Lead Generation', 'Direct Response', 'Retargeting')
      IS_ENUM,

    kpi.campaign_status AS campaign_status
      WITH SYNONYMS = ('status', 'active', 'completed', 'campaign status')
      COMMENT = 'Campaign lifecycle status'
      SAMPLE_VALUES ('Active', 'Completed')
      IS_ENUM,

    kpi.campaign_start_date AS campaign_start_date
      WITH SYNONYMS = ('start date', 'launch date', 'flight start')
      COMMENT = 'Date the campaign began running',

    kpi.campaign_end_date AS campaign_end_date
      WITH SYNONYMS = ('end date', 'flight end', 'expiry date')
      COMMENT = 'Date the campaign stopped running',

    -- Client
    kpi.client_name AS client_name
      WITH SYNONYMS = ('client', 'advertiser', 'account', 'brand')
      COMMENT = 'Name of the advertising client',

    kpi.vertical AS vertical
      WITH SYNONYMS = ('industry', 'sector', 'vertical', 'category')
      COMMENT = 'Client industry vertical'
      SAMPLE_VALUES ('Retail', 'Finance', 'Healthcare', 'Technology', 'Consumer Goods')
      IS_ENUM,

    kpi.tier AS tier
      WITH SYNONYMS = ('client tier', 'account tier', 'segment', 'size')
      COMMENT = 'Client tier by spend size'
      SAMPLE_VALUES ('Enterprise', 'Mid-Market', 'SMB')
      IS_ENUM,

    -- Channel
    kpi.channel_name AS channel_name
      WITH SYNONYMS = ('channel', 'media channel', 'media type', 'placement')
      COMMENT = 'Media channel where ads ran'
      SAMPLE_VALUES ('Paid Search', 'Social Media', 'Display', 'Connected TV', 'Streaming Audio')
      IS_ENUM,

    kpi.channel_type AS channel_type
      WITH SYNONYMS = ('channel category', 'media category', 'medium')
      COMMENT = 'Broad channel category'
      SAMPLE_VALUES ('Digital', 'Video', 'Audio')
      IS_ENUM
  )

  METRICS (
    -- Volume metrics
    kpi.m_impressions AS SUM(impressions)
      WITH SYNONYMS = ('total impressions', 'impressions delivered', 'reach')
      COMMENT = 'Total ad impressions delivered',

    kpi.m_clicks AS SUM(clicks)
      WITH SYNONYMS = ('total clicks', 'link clicks')
      COMMENT = 'Total ad clicks (0 for Connected TV which is impression-only)',

    kpi.m_conversions AS SUM(conversions)
      WITH SYNONYMS = ('total conversions', 'actions', 'acquisitions')
      COMMENT = 'Total attributed conversions',

    -- Spend and revenue metrics
    kpi.m_spend AS SUM(spend)
      WITH SYNONYMS = ('total spend', 'media spend', 'ad spend', 'cost', 'investment')
      COMMENT = 'Total paid media spend in USD',

    kpi.m_revenue AS SUM(revenue)
      WITH SYNONYMS = ('total revenue', 'attributed revenue', 'return')
      COMMENT = 'Total attributed revenue in USD',

    -- Budget metric for utilization
    PRIVATE kpi.m_budget_allocation AS SUM(daily_budget_allocation)
      COMMENT = 'Sum of daily budget allocations (equals total campaign budget when aggregated over full flight)',

    -- Derived efficiency metrics (view-scoped — no table prefix)
    m_roas AS ROUND(kpi.m_revenue / NULLIF(kpi.m_spend, 0), 2)
      WITH SYNONYMS = ('ROAS', 'return on ad spend', 'return on investment', 'ROI')
      COMMENT = 'Return on Ad Spend = Total Revenue / Total Spend. Higher is better.',

    m_ctr_pct AS ROUND(kpi.m_clicks / NULLIF(kpi.m_impressions, 0) * 100, 3)
      WITH SYNONYMS = ('CTR', 'click through rate', 'click rate')
      COMMENT = 'Click-Through Rate % = Clicks / Impressions × 100. Not meaningful for Connected TV.',

    m_cpm AS ROUND(kpi.m_spend / NULLIF(kpi.m_impressions, 0) * 1000, 2)
      WITH SYNONYMS = ('CPM', 'cost per thousand', 'cost per mille', 'cost per impression')
      COMMENT = 'Cost Per Thousand Impressions = Spend / Impressions × 1000',

    m_cpc AS ROUND(kpi.m_spend / NULLIF(kpi.m_clicks, 0), 2)
      WITH SYNONYMS = ('CPC', 'cost per click', 'cost per visit')
      COMMENT = 'Cost Per Click = Spend / Clicks. NULL for Connected TV (no clicks).',

    m_cvr_pct AS ROUND(kpi.m_conversions / NULLIF(kpi.m_clicks, 0) * 100, 2)
      WITH SYNONYMS = ('CVR', 'conversion rate', 'click to conversion rate')
      COMMENT = 'Conversion Rate % = Conversions / Clicks × 100. NULL for Connected TV.',

    m_budget_utilization_pct AS ROUND(kpi.m_spend / NULLIF(kpi.m_budget_allocation, 0) * 100, 1)
      WITH SYNONYMS = ('budget utilization', 'budget pacing', 'pacing', 'spend vs budget', 'budget burn')
      COMMENT = 'Budget Utilization % = Spend / Budget Allocation × 100. >100% = overspending.'
  )

  COMMENT = 'DEMO: Paid media campaign analytics semantic view — 20 clients, 5 channels, 18 months. Expires: 2026-08-12'

  AI_SQL_GENERATION
    'Round all percentage metrics to 1 decimal place in output.
     When comparing time periods (e.g. "vs last quarter"), always show both periods.
     For budget pacing questions, filter to Active campaigns unless the user asks otherwise.
     Connected TV (CTV) has zero clicks and conversions by design — do not flag this as missing data.'

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
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CHANNEL ch
               ON f.channel_id = ch.channel_id
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
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CAMPAIGN c
               ON f.campaign_id = c.campaign_id
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CLIENT cl
               ON f.client_id = cl.client_id
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CHANNEL ch
               ON f.channel_id = ch.channel_id
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
               SUM(f.clicks)      AS total_clicks
           FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE f
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CHANNEL ch
               ON f.channel_id = ch.channel_id
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
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CHANNEL ch
               ON f.channel_id = ch.channel_id
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
               SUM(f.clicks)       AS total_clicks,
               SUM(f.conversions)  AS total_conversions
           FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE f
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CAMPAIGN c
               ON f.campaign_id = c.campaign_id
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CLIENT cl
               ON f.client_id = cl.client_id
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CHANNEL ch
               ON f.channel_id = ch.channel_id
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
               ROUND(SUM(f.spend), 0)               AS total_spend,
               SUM(f.impressions)                   AS total_impressions,
               ROUND(SUM(f.spend) / NULLIF(SUM(f.impressions), 0) * 1000, 2) AS cpm
           FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE f
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CHANNEL ch
               ON f.channel_id = ch.channel_id
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
               ROUND(SUM(f.spend), 0)   AS total_spend,
               ROUND(SUM(f.revenue), 0) AS total_revenue
           FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE f
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CLIENT cl
               ON f.client_id = cl.client_id
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
               ROUND(SUM(f.spend), 0)   AS total_spend,
               ROUND(SUM(f.revenue), 0) AS total_revenue,
               ROUND(SUM(f.revenue) / NULLIF(SUM(f.spend), 0), 2) AS roas,
               COUNT(DISTINCT c.campaign_id) AS campaign_count
           FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE f
           JOIN SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CAMPAIGN c
               ON f.campaign_id = c.campaign_id
           WHERE f.perf_date >= DATE_TRUNC(''year'', CURRENT_DATE())
           GROUP BY c.objective
           ORDER BY total_spend DESC'
    )
  );
