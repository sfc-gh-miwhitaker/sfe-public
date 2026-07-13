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
  Tables:    DIM_CLIENT, DIM_CHANNEL, DIM_CAMPAIGN, FACT_DAILY_PERFORMANCE, DOC_CAMPAIGN_CONTENT
  View:      V_CAMPAIGN_KPI
  Search:    CAMPAIGN_DOCS_SEARCH (Cortex Search over campaign documents)
  Sem View:  SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS
  Agent:     SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.MEDIA_CAMPAIGN_AGENT

AFTER DEPLOY:
  1. Snowsight → AI & ML → Agents → MEDIA_CAMPAIGN_AGENT → "Add to CoWork"
  2. Open CoWork, select Campaign Analytics agent
  3. Try: "Which channel has the highest ROAS this year?"
  4. Try: "What was the creative strategy for Client Alpha's social campaigns?"
  5. Try: "Client Delta's CTV spend is high — why did we choose that channel?"
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

CREATE OR REPLACE TABLE DOC_CAMPAIGN_CONTENT (
    DOC_ID        NUMBER        NOT NULL PRIMARY KEY,
    CLIENT_ID     NUMBER        NOT NULL,
    CAMPAIGN_ID   NUMBER,
    DOC_TYPE      VARCHAR(30)   NOT NULL,
    TITLE         VARCHAR(200)  NOT NULL,
    CONTENT       VARCHAR(4000) NOT NULL,
    CREATED_DATE  DATE          NOT NULL
) COMMENT = 'DEMO: Campaign documents for Cortex Search — briefs, copy, strategy notes (Expires: 2026-08-12)';

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

-- ── 6b. Campaign documents (unstructured content for Cortex Search) ──────────
INSERT INTO DOC_CAMPAIGN_CONTENT (DOC_ID, CLIENT_ID, CAMPAIGN_ID, DOC_TYPE, TITLE, CONTENT, CREATED_DATE)
VALUES
-- Client Notes (account-level context)
(1, 1, NULL, 'Client Notes', 'Client Alpha — Account Overview',
 'Client Alpha is an Enterprise-tier retail brand with 400+ physical stores and a rapidly growing DTC e-commerce business. Primary KPI is blended ROAS across all channels. Their CMO is data-driven and expects weekly performance summaries with channel-level attribution. They have historically over-indexed on paid search and are open to diversifying into connected TV for brand awareness. Budget decisions are made quarterly with a 60-day planning horizon.', '2025-01-05'),
(2, 2, NULL, 'Client Notes', 'Client Bravo — Account Overview',
 'Client Bravo is an Enterprise financial services firm focused on lead generation for wealth management products. Strict compliance requirements limit creative flexibility — all copy must pass legal review (5-day turnaround). They prioritize cost-per-lead over ROAS and measure success at the 90-day attribution window. Social media performance has been inconsistent; they prefer paid search and display retargeting. Budget is allocated monthly from a fixed annual plan.', '2025-01-08'),
(3, 3, NULL, 'Client Notes', 'Client Charlie — Account Overview',
 'Client Charlie is an Enterprise healthcare brand marketing elective procedures and wellness services. HIPAA-adjacent content restrictions apply — no patient testimonials, no before/after imagery in certain channels. They measure success via consultation bookings (tracked as conversions). Connected TV has been their fastest-growing channel due to the ability to tell longer-form stories. They run seasonal campaigns aligned with insurance deductible resets (January, July).', '2025-01-10'),
(4, 4, NULL, 'Client Notes', 'Client Delta — Account Overview',
 'Client Delta is an Enterprise B2B technology company selling cloud infrastructure. Long sales cycles (90-180 days) make direct-response attribution challenging. They invest heavily in brand awareness via connected TV and streaming audio to stay top-of-mind with IT decision-makers. Lead gen campaigns target technical content downloads (whitepapers, webinars). Their ICP is enterprise companies with 1000+ employees in manufacturing and logistics verticals.', '2025-01-12'),
(5, 5, NULL, 'Client Notes', 'Client Echo — Account Overview',
 'Client Echo is an Enterprise CPG brand with a portfolio of household cleaning products. Highly seasonal business — peaks around spring cleaning (March-April) and back-to-school (August). Mass-reach channels (display, streaming audio) drive brand recall; paid search captures in-market shoppers. They A/B test creative aggressively and rotate copy every 2 weeks. ROAS targets are lower (2-3x) because they optimize for market share, not margin.', '2025-01-15'),
-- Campaign Briefs
(6, 1, 1, 'Campaign Brief', 'Client Alpha — Q1 Paid Search Lead Gen Brief',
 'Objective: Drive qualified traffic to spring collection landing pages. Target audience: Women 25-44 in top 50 DMAs with household income $75K+. KPIs: CTR > 4%, CPC < $2.50, ROAS > 4x. Messaging pillars: New arrivals, limited-time offers, free shipping over $99. Competitive context: Main competitor increasing search spend 20% this quarter. Budget: $120K over 90 days.', '2025-01-10'),
(7, 1, 2, 'Campaign Brief', 'Client Alpha — Spring Social Awareness Brief',
 'Objective: Build brand awareness for the spring/summer 2025 collection among new-to-brand audiences. Target: Lookalike audiences built from top 10% LTV customers. Channels: Instagram Reels and TikTok. KPIs: Reach 2M unique users, video completion rate > 30%, brand lift +5pts. Creative direction: lifestyle-first, diverse casting, outdoor settings. No hard sell — focus on brand world. Budget: $85K.', '2025-01-20'),
(8, 3, 31, 'Campaign Brief', 'Client Charlie — January Wellness Push Brief',
 'Objective: Capture demand from insurance deductible resets. Target: Adults 30-60 within 25-mile radius of clinic locations. Channels: Connected TV (30-second spots) + retargeting display. KPIs: Consultation bookings target 200 in Q1, cost per booking < $350. Creative: Doctor testimonials, patient journey stories (no identifiable patient info). Budget: $140K.', '2025-01-03'),
(9, 4, 46, 'Campaign Brief', 'Client Delta — Cloud Infrastructure Awareness Brief',
 'Objective: Position Client Delta as the #1 choice for enterprise cloud migration. Target: CIOs and VP-level IT leaders at companies with 1000+ employees in manufacturing and logistics. Channels: Connected TV (premium business content — CNBC, Bloomberg). KPIs: Aided brand awareness +10pts, target 500K impressions among ICP. No direct-response expectation — pure top-of-funnel. Budget: $200K.', '2025-01-08'),
(10, 5, 61, 'Campaign Brief', 'Client Echo — Spring Cleaning Campaign Brief',
 'Objective: Drive seasonal sales uplift for all-purpose cleaner and disinfectant lines. Target: Household decision-makers 25-54. Channels: Streaming audio (Spotify, iHeart) for frequency + display for reach. KPIs: Brand search lift > 15%, display CTR > 0.2%, ROAS > 2.5x. Creative: "Fresh Start" messaging — new year, new clean. Audio ads 30 seconds, casual conversational tone. Budget: $160K.', '2025-02-01'),
-- Creative Copy
(11, 1, 1, 'Creative Copy', 'Client Alpha — Paid Search Ad Copy Set A',
 'Headline 1: New Spring Styles Just Dropped | Free Shipping $99+ | Headline 2: Shop the Spring Collection — 400+ New Arrivals | Description: Discover the latest trends in women''s fashion. Free shipping on orders over $99. Easy 30-day returns. Shop now. | CTA: Shop Now | Notes: A/B test headline 1 vs headline 2 for CTR.', '2025-01-12'),
(12, 1, 2, 'Creative Copy', 'Client Alpha — Social Video Script (Instagram Reels)',
 'Format: 15-second vertical video. Visual: Model walking through a sunlit garden, cuts between 3 outfits. Audio: Upbeat indie track. Text overlay: "Your spring uniform" (frame 1), "New drops weekly" (frame 2), brand logo (frame 3). CTA: Tap to explore. No price claims — awareness only. 3 versions with different model/outfit combinations for creative fatigue testing.', '2025-01-22'),
(13, 3, 31, 'Creative Copy', 'Client Charlie — Connected TV Spot Script (30s)',
 'Title: "New Year, New You". Open: Wide shot of confident woman walking into modern clinic lobby. :05 — Doctor on camera: "Every January, people tell me they finally have the benefits to invest in themselves." :12 — Montage: consultation room, patient smiling at results. :18 — Doctor VO: "Whether it''s rejuvenation, wellness, or just feeling like yourself again — this is your year." :25 — Card: Clinic logo + URL. Compliance: No identifiable patient imagery.', '2025-01-03'),
(14, 5, 61, 'Creative Copy', 'Client Echo — Streaming Audio Ad (30s)',
 '"Hey — quick question. When was the last time you actually enjoyed cleaning? Yeah, us neither. But Client Echo all-purpose cleaner makes it weirdly satisfying. One spray, one wipe, done. No residue, no harsh smell, just... clean. Grab a bottle at Target or Walmart. Client Echo. A fresh start, every time." Tone: casual, friendly neighbor, NOT announcer.', '2025-02-03'),
-- Channel Strategy
(15, 1, 1, 'Channel Strategy', 'Client Alpha — Paid Search Strategy Rationale',
 'Paid search is Client Alpha''s highest-converting channel (ROAS 4-5x historically) because their customers actively search for fashion terms when ready to buy. We allocate 35% of total budget here. Strategy: defend branded terms (competitor conquesting has increased 20%), expand non-brand into "spring outfits" and "women''s workwear" categories. Key risk: rising CPCs in fashion vertical. Monthly budget pacing review on the 15th.', '2025-01-08'),
(16, 3, 31, 'Channel Strategy', 'Client Charlie — Connected TV Strategy Rationale',
 'Connected TV is ideal for healthcare because it allows longer-form storytelling (15-30s) that builds trust — critical for elective procedures. Unlike display or search, CTV lets us show doctor testimonials in a premium, brand-safe environment. We target health-conscious audiences on Hulu, Peacock, and YouTube TV. No click attribution exists for CTV, so we measure via pre/post brand studies and consultation booking correlation.', '2025-01-05'),
(17, 4, 46, 'Channel Strategy', 'Client Delta — Connected TV Strategy Rationale',
 'For a B2B company selling to CIOs, connected TV might seem unusual — but premium business content (CNBC, Bloomberg, WSJ) reaches exactly our ICP during market hours. CTV impressions among IT leaders are 3x cheaper than LinkedIn InMail and create top-of-funnel awareness that shortens sales cycles downstream. We pair CTV with display retargeting to re-engage viewers who visit the site after exposure.', '2025-01-09'),
(18, 5, 61, 'Channel Strategy', 'Client Echo — Streaming Audio Strategy Rationale',
 'Streaming audio drives frequency at low cost for Echo''s spring cleaning campaign. Our target (household shoppers 25-54) over-indexes on music streaming during chores and commutes — exactly when cleaning products are top of mind. Audio CPMs are $10-20 vs $25-45 for CTV, allowing 3-4x more frequency within budget. Success metric: brand search lift measured via Google Trends correlation.', '2025-02-01'),
-- Client retrospective notes
(19, 1, NULL, 'Client Notes', 'Client Alpha — Q1 2025 Retrospective',
 'Q1 results: Total spend $250K, blended ROAS 4.2x (above 3.8x target). Paid search carried performance (ROAS 5.1x) while social awareness campaigns hit 2.1M unique reach. Display retargeting ROAS was 7.3x but volume-limited by site traffic. Action items for Q2: Increase social spend to feed retargeting pool, test connected TV for the first time with summer collection, explore streaming audio.', '2025-04-05'),
(20, 4, NULL, 'Client Notes', 'Client Delta — Sales Cycle Attribution Analysis',
 'Analysis period: Jan–Jun 2025. Average sales cycle: 127 days. Connected TV impressions appear in 73% of winning deal journeys (vs 31% of lost deals). Streaming audio appears in 52% of wins. Key finding: deals exposed to both CTV + audio close 23% faster than single-channel exposure. The surround-sound strategy is working. Attribution window must remain at 90+ days for these results to surface.', '2025-07-10');

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

-- ── 8b. Cortex Search Service (document search) ─────────────────────────────
CREATE OR REPLACE CORTEX SEARCH SERVICE CAMPAIGN_DOCS_SEARCH
  ON content
  ATTRIBUTES doc_type, client_name, channel_name, campaign_name
  WAREHOUSE = SFE_MEDIA_CAMPAIGN_WH
  TARGET_LAG = '1 minute'
  COMMENT = 'DEMO: Campaign document search — briefs, copy, strategy notes, client context (Expires: 2026-08-12)'
AS (
  SELECT
      d.doc_id,
      d.doc_type,
      d.title,
      d.content,
      cl.client_name,
      COALESCE(ch.channel_name, 'N/A') AS channel_name,
      COALESCE(c.campaign_name, 'N/A') AS campaign_name,
      d.created_date
  FROM DOC_CAMPAIGN_CONTENT d
  JOIN DIM_CLIENT cl ON d.client_id = cl.client_id
  LEFT JOIN DIM_CAMPAIGN c ON d.campaign_id = c.campaign_id
  LEFT JOIN DIM_CHANNEL ch ON c.channel_id = ch.channel_id
);

-- ── 9. Agent ──────────────────────────────────────────────────────────────────
USE SCHEMA SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS;

CREATE OR REPLACE AGENT MEDIA_CAMPAIGN_AGENT
  COMMENT = 'DEMO: Media campaign analytics — structured KPIs + document search in one agent. Expires: 2026-08-12'
  PROFILE = '{"display_name": "Campaign Analytics", "avatar": "chart-bar", "color": "blue"}'
  FROM SPECIFICATION
  $$

  orchestration:
    budget:
      seconds: 60
      tokens: 40000

  instructions:
    response: |
      You are a media analytics assistant helping agency teams understand paid media performance
      and campaign strategy. You have access to both quantitative data (spend, ROAS, CTR, etc.)
      and qualitative documents (campaign briefs, creative copy, channel strategies, client notes).

      For numbers: always show context — pair a metric with a comparison (vs last period, vs benchmark, vs budget).
      Format currency as $X,XXX. Format percentages to 1 decimal place.
      When a channel is Connected TV, note that CTR and CVR metrics are not applicable (impression-only medium).

      For documents: cite the document title and relevant excerpt. Summarize key points rather than dumping full text.

      For hybrid questions (e.g., "ROAS dropped — what does the brief say about the strategy?"):
      use both tools and synthesize the quantitative finding with the qualitative context.

      Keep responses concise — lead with the answer, follow with supporting detail.
    orchestration: |
      Route questions to the right tool:
      - Quantitative (spend, ROAS, CTR, impressions, conversions, budgets, rankings, trends) → CampaignAnalytics
      - Qualitative (strategy, briefs, creative copy, client context, "why", relationships, preferences) → CampaignDocs
      - Mixed ("ROAS dropped — what does the brief say?") → use BOTH tools and synthesize
      Use data_to_chart when the user asks for a chart, trend visualization, or when comparing 3+ items.
    sample_questions:
      - question: "Which channel has the highest ROAS this year?"
      - question: "What was the creative strategy for Client Alpha's social campaigns?"
      - question: "Which active campaigns are pacing over budget?"
      - question: "Show me the ad copy for Client Echo's streaming audio campaign"
      - question: "Client Bravo's ROAS dropped — what does their brief say about target audience?"
      - question: "What is total spend by channel for the last 30 days?"
      - question: "Why did we choose Connected TV for Client Charlie?"
      - question: "How has Connected TV spend trended by quarter?"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "CampaignAnalytics"
        description: |
          Converts natural language questions about paid media performance into SQL and returns results.
          Use for: spend, ROAS, CTR, CPM, CPC, CVR, conversions, impressions, budget pacing, channel comparisons,
          client rankings, campaign performance, time-period comparisons (YoY, QoQ, MoM), and any KPI trending.
          Data covers 20 clients across 5 channels (Paid Search, Social Media, Display, Connected TV,
          Streaming Audio) from January 2025 through June 2026.
    - tool_spec:
        type: "cortex_search"
        name: "CampaignDocs"
        description: |
          Searches campaign documents including briefs, creative copy, channel strategy rationale,
          and client relationship notes. Use for questions about WHY a campaign exists, WHAT the
          creative looks like, WHO the client is, and HOW channel decisions were made.
          Document types: Campaign Brief, Creative Copy, Channel Strategy, Client Notes.
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
    CampaignDocs:
      name: "SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.CAMPAIGN_DOCS_SEARCH"
      max_results: "5"
      title_column: "TITLE"
      id_column: "DOC_ID"
      columns_and_descriptions:
        content:
          description: "Full document text — campaign briefs, creative copy, strategy rationale, client relationship context"
          type: "string"
          searchable: true
          filterable: false
        doc_type:
          description: "Document category. Valid values: Campaign Brief, Creative Copy, Channel Strategy, Client Notes"
          type: "string"
          searchable: false
          filterable: true
        client_name:
          description: "Client name the document relates to. Values: Client Alpha through Client Tango"
          type: "string"
          searchable: false
          filterable: true
        channel_name:
          description: "Media channel. Valid values: Paid Search, Social Media, Display, Connected TV, Streaming Audio, N/A"
          type: "string"
          searchable: false
          filterable: true
  $$;

-- ── 10. Final validation (the only result shown in Run All) ───────────────────
SELECT
    'Media Campaign Analytics' AS demo,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CLIENT)             AS clients,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DIM_CAMPAIGN)           AS campaigns,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.FACT_DAILY_PERFORMANCE) AS fact_rows,
    (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.DOC_CAMPAIGN_CONTENT)   AS documents,
    'Snowsight → AI & ML → Agents → MEDIA_CAMPAIGN_AGENT'                                    AS next_step;
