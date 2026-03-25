/*==============================================================================
SEMANTIC VIEW - Music Label Marketing Analytics
Semantic model for Snowflake Intelligence over the dimensional model.
FACTS before DIMENSIONS (clause order matters).
==============================================================================*/

USE WAREHOUSE SFE_MUSIC_MARKETING_WH;

CREATE OR REPLACE SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MUSIC_MARKETING

  TABLES (
    artist AS SNOWFLAKE_EXAMPLE.MUSIC_MARKETING.DIM_ARTIST
      PRIMARY KEY (artist_id)
      WITH SYNONYMS = ('musician', 'act', 'performer', 'talent')
      COMMENT = 'Artists signed to Apex Records across genres and territories',

    campaign AS SNOWFLAKE_EXAMPLE.MUSIC_MARKETING.DIM_CAMPAIGN
      PRIMARY KEY (campaign_id)
      WITH SYNONYMS = ('marketing campaign', 'promo', 'promotion', 'initiative')
      COMMENT = 'Marketing campaigns with AI-enriched metadata including auto-classified campaign types',

    channel AS SNOWFLAKE_EXAMPLE.MUSIC_MARKETING.DIM_CHANNEL
      PRIMARY KEY (channel_name)
      WITH SYNONYMS = ('marketing channel', 'ad platform', 'media channel')
      COMMENT = 'Marketing channels such as Meta, Google Ads, TikTok, Radio, and Spotify Ad Studio',

    spend AS SNOWFLAKE_EXAMPLE.MUSIC_MARKETING.FACT_MARKETING_SPEND
      PRIMARY KEY (spend_id)
      WITH SYNONYMS = ('marketing spend', 'ad spend', 'expenditure', 'cost')
      COMMENT = 'Daily marketing spend transactions with impressions, clicks, and conversions',

    perf AS SNOWFLAKE_EXAMPLE.MUSIC_MARKETING.FACT_CAMPAIGN_PERFORMANCE
      PRIMARY KEY (campaign_id)
      WITH SYNONYMS = ('campaign results', 'campaign metrics', 'campaign ROI')
      COMMENT = 'Campaign-level performance aggregates joining spend to streaming and royalty outcomes',

    streams AS SNOWFLAKE_EXAMPLE.MUSIC_MARKETING.FACT_STREAMS
      PRIMARY KEY (stream_id)
      WITH SYNONYMS = ('plays', 'listens', 'streaming data')
      COMMENT = 'Daily streaming counts by artist, track, and platform',

    royalties AS SNOWFLAKE_EXAMPLE.MUSIC_MARKETING.FACT_ROYALTIES
      PRIMARY KEY (royalty_id)
      WITH SYNONYMS = ('royalty payments', 'earnings', 'revenue', 'income')
      COMMENT = 'Monthly royalty payments by artist and revenue source'
  )

  RELATIONSHIPS (
    spend_artist AS spend (artist_id) REFERENCES artist (artist_id),
    spend_channel AS spend (channel) REFERENCES channel (channel_name),
    campaign_artist AS campaign (artist_id) REFERENCES artist (artist_id),
    perf_artist AS perf (artist_id) REFERENCES artist (artist_id),
    streams_artist AS streams (artist_id) REFERENCES artist (artist_id),
    royalties_artist AS royalties (artist_id) REFERENCES artist (artist_id)
  )

  FACTS (
    spend.actual_spend AS spend.actual_spend
      WITH SYNONYMS = ('amount spent', 'cost', 'spend amount')
      COMMENT = 'Actual marketing dollars spent on a given day for a campaign',

    spend.impressions AS spend.impressions
      WITH SYNONYMS = ('views', 'ad views', 'reach')
      COMMENT = 'Number of times the ad was displayed',

    spend.clicks AS spend.clicks
      WITH SYNONYMS = ('ad clicks', 'click-throughs')
      COMMENT = 'Number of clicks on the ad',

    spend.conversions AS spend.conversions
      WITH SYNONYMS = ('actions', 'goals completed')
      COMMENT = 'Number of conversion events from the ad',

    spend.monthly_budget AS spend.monthly_budget
      WITH SYNONYMS = ('budget allocation', 'planned budget', 'allocated amount')
      COMMENT = 'Monthly budget allocated for this campaign and channel',

    perf.total_spend AS perf.total_spend
      WITH SYNONYMS = ('campaign total cost', 'total investment')
      COMMENT = 'Total marketing dollars spent on the entire campaign',

    perf.total_streams_during_campaign AS perf.total_streams_during_campaign
      WITH SYNONYMS = ('campaign streams', 'streams driven')
      COMMENT = 'Total streaming plays during the campaign period for the artist',

    perf.total_royalties_during_campaign AS perf.total_royalties_during_campaign
      WITH SYNONYMS = ('campaign royalties', 'revenue during campaign')
      COMMENT = 'Total royalty revenue earned during the campaign period',

    perf.roi AS perf.roi
      WITH SYNONYMS = ('return on investment', 'campaign ROI', 'payback')
      COMMENT = 'Ratio of royalty revenue to marketing spend (higher is better)',

    perf.cpm AS perf.cpm
      WITH SYNONYMS = ('cost per thousand', 'cost per mille')
      COMMENT = 'Cost per 1000 impressions in dollars',

    perf.cpc AS perf.cpc
      WITH SYNONYMS = ('cost per click')
      COMMENT = 'Cost per click in dollars',

    perf.streams_per_dollar AS perf.streams_per_dollar
      WITH SYNONYMS = ('streaming efficiency', 'streams per spend')
      COMMENT = 'Number of streams generated per dollar of marketing spend',

    streams.stream_count AS streams.stream_count
      WITH SYNONYMS = ('plays', 'listens', 'number of streams')
      COMMENT = 'Number of streaming plays on a given day',

    royalties.royalty_amount AS royalties.royalty_amount
      WITH SYNONYMS = ('earnings', 'payment', 'royalty payment')
      COMMENT = 'Royalty amount paid for a given period and source'
  )

  DIMENSIONS (
    artist.artist_name AS artist.artist_name
      WITH SYNONYMS = ('artist', 'performer name', 'act name')
      COMMENT = 'Name of the artist signed to the label',

    artist.genre AS artist.genre
      WITH SYNONYMS = ('music genre', 'style', 'category')
      COMMENT = 'Primary genre: Hip-Hop, R&B, Pop, Latin, or Indie',

    artist.territory AS artist.territory
      WITH SYNONYMS = ('region', 'market', 'geography')
      COMMENT = 'Primary territory: US, LATAM, Europe, or Asia-Pacific',

    artist.days_on_roster AS artist.days_on_roster
      WITH SYNONYMS = ('tenure', 'time on label')
      COMMENT = 'Number of days the artist has been signed to Apex Records',

    campaign.campaign_name AS campaign.campaign_name
      WITH SYNONYMS = ('campaign', 'promo name')
      COMMENT = 'Name of the marketing campaign',

    campaign.resolved_campaign_type AS campaign.resolved_campaign_type
      WITH SYNONYMS = ('campaign type', 'campaign category', 'type of campaign')
      COMMENT = 'AI-resolved campaign type: Single Launch, Album Cycle, Playlist Push, Tour Support, or TikTok Promo',

    campaign.resolved_territory AS campaign.resolved_territory
      WITH SYNONYMS = ('campaign region', 'target market')
      COMMENT = 'AI-resolved target territory for the campaign',

    campaign.channel AS campaign.channel
      WITH SYNONYMS = ('ad channel', 'marketing platform')
      COMMENT = 'Marketing channel used for the campaign',

    channel.channel_name AS channel.channel_name
      WITH SYNONYMS = ('channel', 'platform')
      COMMENT = 'Name of the marketing channel',

    channel.channel_category AS channel.channel_category
      WITH SYNONYMS = ('channel group', 'channel type')
      COMMENT = 'Channel grouping: Social, Search, Streaming, or Traditional',

    spend.spend_date AS spend.spend_date
      WITH SYNONYMS = ('date', 'day', 'when')
      COMMENT = 'Date of the marketing spend transaction',

    streams.platform AS streams.platform
      WITH SYNONYMS = ('streaming service', 'music platform')
      COMMENT = 'Streaming platform: Spotify, Apple Music, YouTube Music, Tidal, or Amazon Music',

    streams.track_name AS streams.track_name
      WITH SYNONYMS = ('song', 'track', 'title')
      COMMENT = 'Name of the track being streamed',

    streams.stream_date AS streams.stream_date
      WITH SYNONYMS = ('stream day', 'listening date')
      COMMENT = 'Date of the streaming activity',

    royalties.royalty_period AS royalties.royalty_period
      WITH SYNONYMS = ('payment period', 'royalty month')
      COMMENT = 'Month of the royalty payment',

    royalties.source AS royalties.source
      WITH SYNONYMS = ('revenue source', 'royalty type', 'income source')
      COMMENT = 'Royalty source: Streaming, Sync Licensing, Mechanical, or Performance'
  )

  METRICS (
    perf.avg_roi AS AVG(perf.roi)
      WITH SYNONYMS = ('average return on investment', 'mean ROI')
      COMMENT = 'Average ROI across campaigns',

    spend.total_marketing_spend AS SUM(spend.actual_spend)
      WITH SYNONYMS = ('total spend', 'total cost', 'total investment')
      COMMENT = 'Total marketing dollars spent',

    streams.total_streams AS SUM(streams.stream_count)
      WITH SYNONYMS = ('total plays', 'total listens')
      COMMENT = 'Total streaming plays',

    royalties.total_royalties AS SUM(royalties.royalty_amount)
      WITH SYNONYMS = ('total earnings', 'total revenue', 'total royalty payments')
      COMMENT = 'Total royalty payments received'
  )

  COMMENT = 'DEMO: Semantic model for music label marketing analytics — budget, spend, campaigns, streams, royalties (Expires: 2026-04-24)'

  AI_SQL_GENERATION
    'This semantic model covers a music label (Apex Records) marketing analytics system.
     The label tracks marketing spend across campaigns for 50 artists in 5 genres and 4 territories.
     Key analysis patterns:
     - Budget vs. Actual: compare monthly_budget to actual_spend
     - Campaign ROI: use the roi field from perf (ratio of royalties to spend)
     - Streams per dollar: use streams_per_dollar from perf to measure marketing efficiency
     - When asked about "best" or "top" campaigns, use ROI or streams_per_dollar
     - Territory breakdown: use artist.territory or campaign.resolved_territory
     - Channel comparison: join through spend_channel relationship
     - Time-based analysis: use spend_date for daily, group by month/quarter as needed'

  AI_QUESTION_CATEGORIZATION
    'Questions about budget, spend, cost, or allocation should use the spend table.
     Questions about ROI, performance, or campaign results should use the perf table.
     Questions about streams, plays, or listens should use the streams table.
     Questions about royalties, earnings, or revenue should use the royalties table.
     Questions about artists, genres, or territories should use the artist table.';
