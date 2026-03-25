/*==============================================================================
SEMANTIC VIEW - Gaming Player Analytics
Semantic model for Snowflake Intelligence over the analytics layer.
FACTS before DIMENSIONS (clause order matters).
==============================================================================*/

USE WAREHOUSE SFE_GAMING_PLAYER_ANALYTICS_WH;

CREATE OR REPLACE SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_GAMING_PLAYER_ANALYTICS

  TABLES (
    player AS SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS.DIM_PLAYERS
      PRIMARY KEY (player_id)
      WITH SYNONYMS = ('gamer', 'user', 'account')
      COMMENT = 'Players with AI-assigned behavioral cohorts and engagement features',

    lifetime AS SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS.FACT_PLAYER_LIFETIME
      PRIMARY KEY (player_id)
      WITH SYNONYMS = ('player lifetime', 'LTV', 'lifetime value', 'player stats')
      COMMENT = 'Per-player lifetime spend, sessions, churn risk, and value-risk segmentation',

    daily AS SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS.FACT_DAILY_ENGAGEMENT
      PRIMARY KEY (event_date, ai_player_cohort)
      WITH SYNONYMS = ('daily metrics', 'DAU', 'daily active', 'engagement')
      COMMENT = 'Daily engagement aggregates by player cohort including revenue and session counts',

    feedback AS SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS.DT_FEEDBACK_ENRICHED
      PRIMARY KEY (feedback_id)
      WITH SYNONYMS = ('review', 'ticket', 'player feedback', 'survey')
      COMMENT = 'Player feedback with AI-classified sentiment and extracted topic metadata',

    dates AS SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS.DIM_DATES
      PRIMARY KEY (date_key)
      WITH SYNONYMS = ('calendar', 'date dimension')
      COMMENT = 'Date dimension for time-series analysis'
  )

  RELATIONSHIPS (
    lifetime_player AS lifetime (player_id) REFERENCES player (player_id),
    feedback_player AS feedback (player_id) REFERENCES player (player_id),
    daily_date AS daily (event_date) REFERENCES dates (date_key)
  )

  FACTS (
    lifetime.lifetime_spend AS lifetime.lifetime_spend
      WITH SYNONYMS = ('total spend', 'LTV', 'total revenue', 'money spent')
      COMMENT = 'Total USD spent by the player across all in-app purchases',

    lifetime.lifetime_purchases AS lifetime.lifetime_purchases
      WITH SYNONYMS = ('purchase count', 'total purchases', 'transactions')
      COMMENT = 'Total number of in-app purchase transactions',

    lifetime.lifetime_sessions AS lifetime.lifetime_sessions
      WITH SYNONYMS = ('total sessions', 'session count', 'times played')
      COMMENT = 'Total number of play sessions across the player lifetime',

    lifetime.active_days_last_30 AS lifetime.active_days_last_30
      WITH SYNONYMS = ('recent activity', 'days active', 'monthly active days')
      COMMENT = 'Number of days the player was active in the last 30 days',

    lifetime.sessions_last_30 AS lifetime.sessions_last_30
      WITH SYNONYMS = ('recent sessions', 'monthly sessions')
      COMMENT = 'Number of play sessions in the last 30 days',

    lifetime.avg_daily_playtime_minutes AS lifetime.avg_daily_playtime_minutes
      WITH SYNONYMS = ('playtime', 'average session length', 'minutes played')
      COMMENT = 'Average daily playtime in minutes over the last 30 days',

    lifetime.dau_mau_ratio AS lifetime.dau_mau_ratio
      WITH SYNONYMS = ('stickiness', 'engagement ratio', 'DAU/MAU')
      COMMENT = 'Ratio of daily to monthly active days (0-1, higher = stickier)',

    lifetime.feedback_count AS lifetime.feedback_count
      WITH SYNONYMS = ('reviews', 'tickets submitted', 'feedback given')
      COMMENT = 'Number of feedback entries submitted by the player',

    daily.daily_active_players AS daily.daily_active_players
      WITH SYNONYMS = ('DAU', 'active users', 'players today')
      COMMENT = 'Count of unique players active on this date for this cohort',

    daily.total_sessions AS daily.total_sessions
      WITH SYNONYMS = ('sessions', 'plays')
      COMMENT = 'Total play sessions on this date for this cohort',

    daily.avg_playtime_minutes AS daily.avg_playtime_minutes
      WITH SYNONYMS = ('average playtime', 'session length')
      COMMENT = 'Average playtime in minutes per player on this date',

    daily.total_levels_completed AS daily.total_levels_completed
      WITH SYNONYMS = ('levels beaten', 'completions')
      COMMENT = 'Total levels completed on this date for this cohort',

    daily.total_ads_viewed AS daily.total_ads_viewed
      WITH SYNONYMS = ('ad views', 'ads watched', 'ad impressions')
      COMMENT = 'Total ad views on this date for this cohort',

    daily.daily_revenue AS daily.daily_revenue
      WITH SYNONYMS = ('revenue', 'daily income', 'IAP revenue')
      COMMENT = 'Total in-app purchase revenue on this date for this cohort'
  )

  DIMENSIONS (
    player.username AS player.username
      WITH SYNONYMS = ('player name', 'gamer tag', 'user name')
      COMMENT = 'Player username',

    player.platform AS player.platform
      WITH SYNONYMS = ('device', 'system', 'OS')
      COMMENT = 'Platform: iOS, Android, Steam, or Console',

    player.country AS player.country
      WITH SYNONYMS = ('region', 'location', 'geography')
      COMMENT = 'Player country',

    player.acquisition_source AS player.acquisition_source
      WITH SYNONYMS = ('how acquired', 'marketing source', 'channel')
      COMMENT = 'How the player was acquired: Organic, Paid Social, Influencer, App Store Feature, or Cross-Promo',

    player.ai_player_cohort AS player.ai_player_cohort
      WITH SYNONYMS = ('cohort', 'segment', 'player type', 'classification')
      COMMENT = 'AI-assigned player cohort: Whale, Casual, Churning, or New',

    player.churn_risk_level AS player.churn_risk_level
      WITH SYNONYMS = ('churn risk', 'risk level', 'at risk')
      COMMENT = 'Churn risk based on recency: High (14+ days inactive), Medium (7-14), Low (0-7)',

    lifetime.value_risk_segment AS lifetime.value_risk_segment
      WITH SYNONYMS = ('value segment', 'player segment', 'risk category')
      COMMENT = 'Combined value and risk: High Value Active, High Value At Risk, Low Value Active, Low Value At Risk',

    lifetime.dominant_feedback_sentiment AS lifetime.dominant_feedback_sentiment
      WITH SYNONYMS = ('sentiment', 'mood', 'satisfaction')
      COMMENT = 'Most common feedback sentiment for this player: Positive, Negative, or Neutral',

    feedback.ai_sentiment AS feedback.ai_sentiment
      WITH SYNONYMS = ('feedback sentiment', 'review sentiment')
      COMMENT = 'AI-classified sentiment of this specific feedback entry',

    feedback.feedback_topic AS feedback.feedback_topic
      WITH SYNONYMS = ('topic', 'subject', 'category', 'what about')
      COMMENT = 'AI-extracted topic from the feedback text',

    feedback.feedback_urgency AS feedback.feedback_urgency
      WITH SYNONYMS = ('urgency', 'priority')
      COMMENT = 'AI-assessed urgency: HIGH, MEDIUM, or LOW',

    feedback.feedback_source AS feedback.feedback_source
      WITH SYNONYMS = ('source', 'channel', 'where from')
      COMMENT = 'Where the feedback came from: App Store Review, Support Ticket, In-Game Survey, or Discord',

    daily.event_date AS daily.event_date
      WITH SYNONYMS = ('date', 'day', 'when')
      COMMENT = 'Date of the daily engagement metrics',

    daily.ai_player_cohort AS daily.ai_player_cohort
      WITH SYNONYMS = ('cohort', 'daily cohort')
      COMMENT = 'Player cohort for this daily aggregate row'
  )

  METRICS (
    lifetime.avg_lifetime_spend AS AVG(lifetime.lifetime_spend)
      WITH SYNONYMS = ('average LTV', 'mean spend')
      COMMENT = 'Average lifetime spend per player',

    daily.total_dau AS SUM(daily.daily_active_players)
      WITH SYNONYMS = ('total DAU', 'all active players')
      COMMENT = 'Total daily active players across all cohorts',

    daily.total_daily_revenue AS SUM(daily.daily_revenue)
      WITH SYNONYMS = ('total revenue', 'daily total')
      COMMENT = 'Total revenue across all cohorts for a given day'
  )

  COMMENT = 'DEMO: Semantic model for gaming player analytics — engagement, revenue, cohorts, churn risk, feedback (Expires: 2026-04-24)'

  AI_SQL_GENERATION
    'This semantic model covers a mobile gaming studio player analytics system.
     The studio tracks 500 players across iOS, Android, Steam, and Console platforms.
     Players are AI-classified into cohorts: Whale (high spender), Casual (moderate activity),
     Churning (declining activity), and New (recent signup).
     Key analysis patterns:
     - Churn risk: use churn_risk_level or value_risk_segment from lifetime table
     - Cohort comparison: group by ai_player_cohort
     - Revenue trends: use daily_revenue from daily table, group by event_date
     - Player lookup: use username from player dimension
     - Feedback analysis: use ai_sentiment and feedback_topic from feedback table
     - Engagement stickiness: use dau_mau_ratio (0-1 scale, higher is better)
     - When asked about "best" or "most engaged" players, use dau_mau_ratio or active_days_last_30
     - When asked about "at risk" players, use churn_risk_level = High or value_risk_segment containing At Risk'

  AI_QUESTION_CATEGORIZATION
    'Questions about individual players, cohorts, or segments should use the player and lifetime tables.
     Questions about daily trends, DAU, or revenue over time should use the daily table.
     Questions about feedback, sentiment, reviews, or feature requests should use the feedback table.
     Questions about churn, risk, or retention should use the lifetime table with churn_risk_level or value_risk_segment.';
