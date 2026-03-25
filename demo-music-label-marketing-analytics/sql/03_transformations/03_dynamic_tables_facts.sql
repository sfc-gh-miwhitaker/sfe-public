/*==============================================================================
DYNAMIC TABLES - Facts
Fact tables joining spend, performance, streams, and royalties.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.MUSIC_MARKETING;
USE WAREHOUSE SFE_MUSIC_MARKETING_WH;

-- Marketing spend fact (daily grain)
CREATE OR REPLACE DYNAMIC TABLE FACT_MARKETING_SPEND
  TARGET_LAG = '1 hour'
  WAREHOUSE = SFE_MUSIC_MARKETING_WH
  COMMENT = 'DEMO: Daily marketing spend with budget comparison (Expires: 2026-04-24)'
AS
SELECT
    s.spend_id,
    s.campaign_id,
    s.artist_id,
    s.channel,
    s.spend_date,
    s.amount       AS actual_spend,
    s.impressions,
    s.clicks,
    s.conversions,
    b.allocated_amount AS monthly_budget,
    CASE
        WHEN b.allocated_amount > 0
        THEN ROUND(s.amount / (b.allocated_amount / 30.0), 4)
        ELSE NULL
    END AS daily_budget_utilization
FROM RAW_MARKETING_SPEND s
LEFT JOIN RAW_MARKETING_BUDGET b
    ON s.campaign_id = b.campaign_id
    AND s.channel = b.channel
    AND DATE_TRUNC('month', s.spend_date) = b.budget_period;

-- Campaign performance fact (campaign grain)
-- Sources from DIM_CAMPAIGN to get AI-enriched resolved_campaign_type and resolved_territory
CREATE OR REPLACE DYNAMIC TABLE FACT_CAMPAIGN_PERFORMANCE
  TARGET_LAG = '1 hour'
  WAREHOUSE = SFE_MUSIC_MARKETING_WH
  COMMENT = 'DEMO: Campaign-level performance aggregates with ROI (Expires: 2026-04-24)'
AS
SELECT
    dc.campaign_id,
    dc.campaign_name,
    dc.artist_id,
    dc.channel,
    dc.resolved_campaign_type,
    COALESCE(dc.resolved_territory, a.territory) AS territory,
    dc.start_date,
    dc.end_date,
    DATEDIFF('day', dc.start_date, dc.end_date) AS campaign_duration_days,
    COALESCE(spend.total_spend, 0)       AS total_spend,
    COALESCE(spend.total_impressions, 0) AS total_impressions,
    COALESCE(spend.total_clicks, 0)      AS total_clicks,
    COALESCE(spend.total_conversions, 0) AS total_conversions,
    COALESCE(streams.total_streams, 0)   AS total_streams_during_campaign,
    COALESCE(royalties.total_royalties, 0) AS total_royalties_during_campaign,
    CASE
        WHEN COALESCE(spend.total_spend, 0) > 0
        THEN ROUND(COALESCE(royalties.total_royalties, 0) / spend.total_spend, 4)
        ELSE NULL
    END AS roi,
    CASE
        WHEN COALESCE(spend.total_impressions, 0) > 0
        THEN ROUND(spend.total_spend / (spend.total_impressions / 1000.0), 2)
        ELSE NULL
    END AS cpm,
    CASE
        WHEN COALESCE(spend.total_clicks, 0) > 0
        THEN ROUND(spend.total_spend / spend.total_clicks, 2)
        ELSE NULL
    END AS cpc,
    CASE
        WHEN COALESCE(spend.total_spend, 0) > 0
        THEN ROUND(COALESCE(streams.total_streams, 0) / spend.total_spend, 2)
        ELSE NULL
    END AS streams_per_dollar
FROM DIM_CAMPAIGN dc
JOIN DIM_ARTIST a ON dc.artist_id = a.artist_id
LEFT JOIN (
    SELECT campaign_id,
           SUM(amount) AS total_spend,
           SUM(impressions) AS total_impressions,
           SUM(clicks) AS total_clicks,
           SUM(conversions) AS total_conversions
    FROM RAW_MARKETING_SPEND
    GROUP BY campaign_id
) spend ON dc.campaign_id = spend.campaign_id
LEFT JOIN (
    SELECT s.artist_id,
           c2.campaign_id,
           SUM(s.stream_count) AS total_streams
    FROM RAW_STREAMS s
    JOIN RAW_CAMPAIGNS c2 ON s.artist_id = c2.artist_id
        AND s.stream_date >= c2.start_date
        AND s.stream_date <= c2.end_date
    GROUP BY s.artist_id, c2.campaign_id
) streams ON dc.campaign_id = streams.campaign_id
LEFT JOIN (
    SELECT r.artist_id,
           c3.campaign_id,
           SUM(r.amount) AS total_royalties
    FROM RAW_ROYALTIES r
    JOIN RAW_CAMPAIGNS c3 ON r.artist_id = c3.artist_id
        AND r.royalty_period >= DATE_TRUNC('month', c3.start_date)
        AND r.royalty_period <= DATE_TRUNC('month', c3.end_date)
    GROUP BY r.artist_id, c3.campaign_id
) royalties ON dc.campaign_id = royalties.campaign_id;

-- Streaming fact (daily grain)
CREATE OR REPLACE DYNAMIC TABLE FACT_STREAMS
  TARGET_LAG = '1 hour'
  WAREHOUSE = SFE_MUSIC_MARKETING_WH
  COMMENT = 'DEMO: Daily streaming counts by artist, track, and platform (Expires: 2026-04-24)'
AS
SELECT
    stream_id,
    artist_id,
    track_name,
    platform,
    stream_date,
    stream_count
FROM RAW_STREAMS;

-- Royalty fact (monthly grain)
CREATE OR REPLACE DYNAMIC TABLE FACT_ROYALTIES
  TARGET_LAG = '1 hour'
  WAREHOUSE = SFE_MUSIC_MARKETING_WH
  COMMENT = 'DEMO: Monthly royalty payments by artist and source (Expires: 2026-04-24)'
AS
SELECT
    royalty_id,
    artist_id,
    royalty_period,
    source,
    amount AS royalty_amount
FROM RAW_ROYALTIES;
