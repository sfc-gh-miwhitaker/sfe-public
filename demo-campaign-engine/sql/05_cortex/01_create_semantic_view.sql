/*==============================================================================
SEMANTIC VIEW
Generated from prompt: "Create a semantic view over player features, campaigns,
  and responses for natural-language analytics via Cortex Intelligence."
Tool: Cursor + Claude | Refined: 2 iteration(s)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-01
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;
USE WAREHOUSE SFE_CAMPAIGN_ENGINE_WH;

CREATE OR REPLACE SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_CAMPAIGN_ENGINE_ANALYTICS

  TABLES (
    player_features AS SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.DT_PLAYER_FEATURES
      PRIMARY KEY (player_id)
      WITH SYNONYMS = ('players', 'player behavior', 'player metrics')
      COMMENT = 'Aggregated behavioral features for each casino player including wagering patterns, game preferences, and loyalty tier',

    campaigns AS SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.RAW_CAMPAIGNS
      PRIMARY KEY (campaign_id)
      WITH SYNONYMS = ('marketing campaigns', 'promotions', 'offers')
      COMMENT = 'Marketing campaign definitions with type, target segment, and date ranges',

    campaign_responses AS SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.RAW_CAMPAIGN_RESPONSES
      PRIMARY KEY (response_id)
      WITH SYNONYMS = ('responses', 'campaign results', 'conversions')
      COMMENT = 'Historical record of player responses to marketing campaigns'
  )

  RELATIONSHIPS (
    response_to_player AS
      campaign_responses (player_id) REFERENCES player_features,
    response_to_campaign AS
      campaign_responses (campaign_id) REFERENCES campaigns
  )

  FACTS (
    player_features.avg_daily_wager AS player_features.avg_daily_wager
      COMMENT = 'Average amount wagered per active day in dollars',

    player_features.session_frequency AS player_features.session_frequency
      COMMENT = 'Average number of gaming sessions per week',

    player_features.lifetime_wagered AS player_features.lifetime_wagered
      COMMENT = 'Total lifetime wagering amount in dollars',

    player_features.days_since_last_visit AS player_features.days_since_last_visit
      COMMENT = 'Number of days since the players last gaming session',

    player_features.avg_bet_size AS player_features.avg_bet_size
      COMMENT = 'Average wager amount per session in dollars',

    player_features.game_diversity AS player_features.game_diversity
      COMMENT = 'Number of distinct game types played (1-4)',

    player_features.slots_pct AS player_features.slots_pct
      COMMENT = 'Percentage of sessions spent on slot machines (0.0-1.0)',

    player_features.table_pct AS player_features.table_pct
      COMMENT = 'Percentage of sessions spent on table games (0.0-1.0)',

    campaign_responses.redemption_amount AS campaign_responses.redemption_amount
      COMMENT = 'Dollar amount redeemed when player responded to campaign'
  )

  DIMENSIONS (
    player_features.loyalty_tier AS loyalty_tier
      WITH SYNONYMS = ('tier', 'loyalty level', 'VIP level')
      COMMENT = 'Player loyalty program tier: Bronze, Silver, Gold, Platinum, Diamond',

    player_features.loyalty_tier_num AS loyalty_tier_num
      COMMENT = 'Numeric encoding of loyalty tier (1=Bronze through 5=Diamond)',

    campaigns.campaign_type AS campaign_type
      WITH SYNONYMS = ('type', 'campaign category')
      COMMENT = 'Campaign category: RETENTION, ACQUISITION, UPSELL, or REACTIVATION',

    campaigns.campaign_name AS campaign_name
      WITH SYNONYMS = ('name', 'promotion name')
      COMMENT = 'Human-readable campaign name',

    campaigns.target_segment AS target_segment
      WITH SYNONYMS = ('segment', 'audience segment')
      COMMENT = 'Target audience segment for the campaign',

    campaign_responses.responded AS responded
      COMMENT = 'Whether the player responded positively to the campaign (TRUE/FALSE)'
  )

  METRICS (
    player_features.player_count AS COUNT(player_features.player_id)
      COMMENT = 'Total number of players',

    player_features.avg_wagering AS AVG(player_features.avg_daily_wager)
      COMMENT = 'Average daily wagering across players in dollars',

    player_features.total_lifetime_wagered AS SUM(player_features.lifetime_wagered)
      COMMENT = 'Sum of all player lifetime wagering in dollars',

    campaign_responses.response_count AS COUNT_IF(campaign_responses.responded = TRUE)
      COMMENT = 'Number of positive campaign responses',

    campaign_responses.total_responses AS COUNT(campaign_responses.response_id)
      COMMENT = 'Total number of campaign response records',

    campaign_responses.response_rate AS
      COUNT_IF(campaign_responses.responded = TRUE) / NULLIF(COUNT(campaign_responses.response_id), 0)
      COMMENT = 'Percentage of campaign targets that responded positively',

    campaign_responses.total_redemption AS SUM(campaign_responses.redemption_amount)
      COMMENT = 'Total dollar value of campaign redemptions'
  )

  COMMENT = 'DEMO: Semantic view for casino campaign analytics with player behavior and response data (Expires: 2026-04-01)';
