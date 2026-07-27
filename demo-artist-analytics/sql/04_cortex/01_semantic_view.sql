/*==============================================================================
  04_cortex/01_semantic_view.sql
  Artist Analytics — Semantic View (DDL syntax)
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-23

  SV_ARTIST_ANALYTICS lives in SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS (shared schema).

  Four logical tables (no cross-table joins needed — each answers its own domain):
    streams  → V_STREAM_KPI       daily streams per platform
    social   → V_SOCIAL_KPI       daily impressions / engagement per social platform
    income   → FACT_INCOME        daily income breakdown
    shows    → V_SHOW_MOMENTUM    upcoming shows with momentum score

  The agent uses this as its single analytics tool (cortex_analyst_text_to_sql).
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_ARTIST_ANALYTICS_WH;

CREATE OR REPLACE SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_ARTIST_ANALYTICS

  TABLES (
    streams AS SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.V_STREAM_KPI
      PRIMARY KEY (stream_date, platform_name)
      WITH SYNONYMS ('streaming data', 'plays by platform', 'platform streams')
      COMMENT = 'Daily streaming counts per platform — past 90 days. Covers Spotify, Apple Music, Amazon Music, YouTube.',
    social AS SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.V_SOCIAL_KPI
      PRIMARY KEY (metric_date, social_platform)
      WITH SYNONYMS ('social media data', 'social metrics', 'social engagement')
      COMMENT = 'Daily social media impressions and engagement per platform — past 90 days. Covers TikTok, Instagram, YouTube Shorts, X.',
    income AS SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.FACT_INCOME
      PRIMARY KEY (income_id)
      WITH SYNONYMS ('revenue', 'earnings', 'money', 'financial data')
      COMMENT = 'Daily income: streaming royalties, merchandise, and sync licensing.',
    shows AS SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.V_SHOW_MOMENTUM
      PRIMARY KEY (show_id)
      WITH SYNONYMS ('tour dates', 'performances', 'concerts', 'upcoming shows')
      COMMENT = 'Upcoming tour dates with momentum scores. Momentum score > 100 means fan engagement is building vs baseline.'
  )

  FACTS (
    -- Streams (private — used only in metric aggregations)
    PRIVATE streams.raw_streams AS streams
      COMMENT = 'Raw daily stream count per platform',
    PRIVATE streams.raw_saves AS saves
      COMMENT = 'Raw daily save count per platform',
    PRIVATE streams.raw_listeners AS listeners
      COMMENT = 'Raw daily listener count per platform',
    -- Social (private — used only in metric aggregations)
    PRIVATE social.raw_impressions AS impressions
      COMMENT = 'Raw daily impressions per social platform',
    PRIVATE social.raw_engagements AS engagements
      COMMENT = 'Raw daily engagements per social platform',
    PRIVATE social.raw_shares AS shares
      COMMENT = 'Raw daily shares per social platform',
    -- Income
    income.stream_royalties AS stream_royalties,
    income.merch_estimate AS merch_estimate,
    income.sync_licensing AS sync_licensing,
    income.total_income AS total_income,
    -- Shows
    shows.ticket_capacity AS ticket_capacity,
    shows.ticket_price AS ticket_price,
    shows.days_until_show AS days_until_show,
    shows.baseline_daily_engagements AS baseline_daily_engagements,
    shows.pre_show_daily_engagements AS pre_show_daily_engagements,
    shows.momentum_score AS momentum_score
  )

  DIMENSIONS (
    streams.stream_date AS stream_date
      WITH SYNONYMS = ('streaming date', 'date', 'day')
      COMMENT = 'Date of the streaming data record',
    streams.streaming_platform AS platform_name
      WITH SYNONYMS = ('streaming service', 'platform', 'service')
      COMMENT = 'Streaming platform name'
      SAMPLE_VALUES ('Spotify', 'Apple Music', 'Amazon Music', 'YouTube')
      IS_ENUM,
    social.social_date AS metric_date
      WITH SYNONYMS = ('social date', 'engagement date')
      COMMENT = 'Date of the social media activity record',
    social.social_platform AS social_platform
      WITH SYNONYMS = ('social channel', 'social network', 'social app')
      COMMENT = 'Social media platform'
      SAMPLE_VALUES ('TikTok', 'Instagram', 'YouTube Shorts', 'X')
      IS_ENUM,
    social.engagement_rate_pct AS engagement_rate_pct
      WITH SYNONYMS = ('engagement rate', 'ER', 'interaction rate')
      COMMENT = 'Engagements as a percent of impressions',
    income.income_date AS income_date
      WITH SYNONYMS = ('earnings date', 'revenue date', 'payment date')
      COMMENT = 'Date of the income record',
    shows.show_name AS show_name
      WITH SYNONYMS = ('show', 'gig', 'concert name', 'performance')
      COMMENT = 'Name of the tour stop or concert',
    shows.venue_city AS venue_city
      WITH SYNONYMS = ('city', 'market', 'tour stop', 'location')
      COMMENT = 'City where the show takes place'
      SAMPLE_VALUES ('Nashville', 'Austin', 'Chicago', 'Los Angeles', 'New York')
      IS_ENUM,
    shows.show_date AS show_date
      WITH SYNONYMS = ('performance date', 'concert date', 'show day')
      COMMENT = 'Date of the upcoming performance',
    shows.momentum_label AS momentum_label
      WITH SYNONYMS = ('momentum status', 'engagement status', 'pre-show status')
      COMMENT = 'Qualitative interpretation of the momentum score'
      SAMPLE_VALUES ('Strong — fan base is activated', 'Building — slight positive trend', 'Needs push — below baseline')
      IS_ENUM
  )

  METRICS (
    -- Streaming metrics
    streams.m_total_streams AS SUM(raw_streams)
      WITH SYNONYMS = ('total plays', 'streams', 'total streams', 'stream count')
      COMMENT = 'Total streams across all platforms or filtered by platform',
    streams.m_total_saves AS SUM(raw_saves)
      WITH SYNONYMS = ('total saves', 'library adds', 'saves')
      COMMENT = 'Total times a song was saved to a library or playlist',
    streams.m_total_listeners AS SUM(raw_listeners)
      WITH SYNONYMS = ('total listeners', 'unique listeners', 'audience size')
      COMMENT = 'Total estimated listeners (lower than streams due to re-plays)',
    streams.m_avg_daily_streams AS AVG(raw_streams)
      WITH SYNONYMS = ('average daily streams', 'avg streams per day')
      COMMENT = 'Average daily streams — useful for trend comparisons',
    -- Social metrics
    social.m_total_impressions AS SUM(raw_impressions)
      WITH SYNONYMS = ('total reach', 'impressions', 'views', 'total views')
      COMMENT = 'Total content impressions across all social platforms',
    social.m_total_engagements AS SUM(raw_engagements)
      WITH SYNONYMS = ('total engagements', 'interactions', 'total interactions')
      COMMENT = 'Total engagements (likes, comments, saves, shares) across all social platforms',
    social.m_total_shares AS SUM(raw_shares)
      WITH SYNONYMS = ('total shares', 'reposts', 'viral spread')
      COMMENT = 'Total content shares or reposts — a signal of viral potential',
    -- Income metrics
    income.m_total_stream_royalties AS SUM(stream_royalties)
      WITH SYNONYMS = ('streaming income', 'royalty income', 'streaming revenue', 'royalties')
      COMMENT = 'Total streaming royalty income in USD',
    income.m_total_merch AS SUM(merch_estimate)
      WITH SYNONYMS = ('merch revenue', 'merchandise income', 'merchandise sales')
      COMMENT = 'Total estimated merchandise revenue',
    income.m_total_sync AS SUM(sync_licensing)
      WITH SYNONYMS = ('sync income', 'licensing revenue', 'placement income', 'sync deals')
      COMMENT = 'Total sync licensing income — music placed in commercials, TV, or film',
    income.m_total_income AS SUM(total_income)
      WITH SYNONYMS = ('total earnings', 'total revenue', 'all income', 'total money', 'total pay')
      COMMENT = 'Total income from all sources (royalties + merch + sync)',
    income.m_avg_daily_income AS AVG(total_income)
      WITH SYNONYMS = ('average daily income', 'avg daily earnings')
      COMMENT = 'Average daily income across the selected time period',
    -- Show metrics
    shows.m_avg_momentum AS AVG(momentum_score)
      WITH SYNONYMS = ('average momentum', 'overall momentum score', 'tour momentum')
      COMMENT = 'Average momentum score across upcoming shows',
    shows.m_max_momentum AS MAX(momentum_score)
      WITH SYNONYMS = ('best momentum', 'top momentum score', 'hottest market')
      COMMENT = 'Highest momentum score — the market with the most pre-show buzz',
    shows.m_sellout_potential AS SUM(ticket_capacity * ticket_price)
      WITH SYNONYMS = ('potential gross', 'max ticket revenue', 'sellout value')
      COMMENT = 'Total potential gross revenue if all upcoming shows sell out'
  )

  COMMENT = 'DEMO: Artist analytics for Jade Hollow — streaming, social, income, and show momentum. Expires: 2026-08-23'

  AI_SQL_GENERATION
    'This is data for a fictional indie pop artist named Jade Hollow.
     Data covers the past 90 days.
     Streaming platforms: Spotify, Apple Music, Amazon Music, YouTube.
     Social platforms: TikTok, Instagram, YouTube Shorts, X.
     Show cities: Nashville, Austin, Chicago, Los Angeles, New York.
     Momentum score > 100 means engagement is building vs the 30-day baseline. NULL means the 14-day pre-show window has not yet started.
     Income streams: stream_royalties (ongoing), merch_estimate (spikes near shows), sync_licensing (occasional lump sums).
     NEVER use ternary (? :) syntax — use CASE WHEN for conditionals.
     Format USD values with $ prefix and 2 decimal places. Format percentages to 1 decimal place.
     For "this month" queries: WHERE MONTH(date_col) = MONTH(CURRENT_DATE()) AND YEAR(date_col) = YEAR(CURRENT_DATE()).
     For "last 30 days": WHERE date_col >= DATEADD(''day'', -30, CURRENT_DATE()).'

  AI_VERIFIED_QUERIES (
    q_total_streams_last_month AS (
      QUESTION 'What were my total streams last month?'
      VERIFIED_AT 1753394400
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = se_community)'
      SQL 'SELECT SUM(streams) AS total_streams, SUM(saves) AS total_saves, SUM(listeners) AS total_listeners FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.FACT_DAILY_STREAMS WHERE stream_date >= DATE_TRUNC(''month'', DATEADD(''month'', -1, CURRENT_DATE())) AND stream_date < DATE_TRUNC(''month'', CURRENT_DATE())'
    ),
    q_streams_by_platform AS (
      QUESTION 'Which streaming platform has the most streams in the last 30 days?'
      VERIFIED_AT 1753394400
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = se_community)'
      SQL 'SELECT dp.platform_name, SUM(fds.streams) AS total_streams, SUM(fds.saves) AS total_saves, SUM(fds.listeners) AS total_listeners FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.FACT_DAILY_STREAMS fds JOIN SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.DIM_PLATFORM dp ON dp.platform_id = fds.platform_id WHERE fds.stream_date >= DATEADD(''day'', -30, CURRENT_DATE()) GROUP BY dp.platform_name ORDER BY total_streams DESC'
    ),
    q_momentum_by_show AS (
      QUESTION 'What is the momentum score for each of my upcoming shows?'
      VERIFIED_AT 1753394400
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = se_community)'
      SQL 'SELECT show_name, venue_city, show_date, days_until_show, COALESCE(momentum_score::VARCHAR, ''Pre-window'') AS momentum_score, momentum_label FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.V_SHOW_MOMENTUM ORDER BY show_date'
    ),
    q_total_income_this_month AS (
      QUESTION 'What is my total income so far this month?'
      VERIFIED_AT 1753394400
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = se_community)'
      SQL 'SELECT ROUND(SUM(stream_royalties), 2) AS streaming_royalties, ROUND(SUM(merch_estimate), 2) AS merch_income, ROUND(SUM(sync_licensing), 2) AS sync_income, ROUND(SUM(total_income), 2) AS total_income FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.FACT_INCOME WHERE MONTH(income_date) = MONTH(CURRENT_DATE()) AND YEAR(income_date) = YEAR(CURRENT_DATE())'
    ),
    q_social_engagement_by_platform AS (
      QUESTION 'Which social platform has the highest engagement rate in the last 30 days?'
      VERIFIED_AT 1753394400
      ONBOARDING_QUESTION FALSE
      VERIFIED_BY '(STEWARD = se_community)'
      SQL 'SELECT dsp.platform_name AS social_platform, SUM(fsm.impressions) AS total_impressions, SUM(fsm.engagements) AS total_engagements, ROUND(SUM(fsm.engagements) / NULLIF(SUM(fsm.impressions), 0) * 100, 2) AS engagement_rate_pct FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.FACT_SOCIAL_METRICS fsm JOIN SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.DIM_SOCIAL_PLATFORM dsp ON dsp.social_platform_id = fsm.social_platform_id WHERE fsm.metric_date >= DATEADD(''day'', -30, CURRENT_DATE()) GROUP BY dsp.platform_name ORDER BY engagement_rate_pct DESC'
    ),
    q_stream_growth_trend AS (
      QUESTION 'Show me my weekly stream trend over the last 60 days'
      VERIFIED_AT 1753394400
      ONBOARDING_QUESTION FALSE
      VERIFIED_BY '(STEWARD = se_community)'
      SQL 'SELECT DATE_TRUNC(''week'', stream_date) AS week_start, SUM(streams) AS total_streams, SUM(listeners) AS total_listeners FROM SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS.FACT_DAILY_STREAMS WHERE stream_date >= DATEADD(''day'', -60, CURRENT_DATE()) GROUP BY DATE_TRUNC(''week'', stream_date) ORDER BY week_start'
    )
  );

SELECT 'SV_ARTIST_ANALYTICS created in SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS' AS step_04_semantic_view;
