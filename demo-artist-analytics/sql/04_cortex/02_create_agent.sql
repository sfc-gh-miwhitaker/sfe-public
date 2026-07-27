/*==============================================================================
  04_cortex/02_create_agent.sql
  Artist Analytics — Cortex Agent for Snowflake Intelligence
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-23

  Creates ARTIST_ANALYTICS_AGENT — the pro-tier analytics tool.
  After deploy: Snowsight → AI & ML → Agents → ARTIST_ANALYTICS_AGENT → "Add to CoWork"
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_ARTIST_ANALYTICS_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.ARTIST_ANALYTICS;

CREATE OR REPLACE AGENT ARTIST_ANALYTICS_AGENT
  COMMENT = 'DEMO: Artist analytics — streaming, social, income, show momentum for Jade Hollow. Expires: 2026-08-23'
  PROFILE = '{"display_name": "Jade Hollow Analytics", "avatar": "music", "color": "violet"}'
  FROM SPECIFICATION
  $$

  orchestration:
    budget:
      seconds: 60
      tokens: 40000

  instructions:
    response: |
      You are a music analytics assistant for Jade Hollow, an independent indie pop artist.
      You have access to streaming performance, social media engagement, income data, and
      upcoming tour show momentum scores.

      For streaming questions: show totals by platform and highlight trends. Spotify is
      typically the biggest platform by volume; Apple Music pays higher per-stream rates.

      For social questions: compare engagement rates across TikTok, Instagram, YouTube Shorts,
      and X. TikTok typically has the highest raw reach; Instagram tends to have the best
      engagement rate for artists.

      For income questions: show the breakdown (royalties, merch, sync). Sync licensing
      payments are occasional lump sums — flag if one occurred in the period.

      For momentum questions: a score > 100 means fan engagement in that city is building
      vs the 30-day baseline. A score < 100 means it is cooling and may benefit from a
      targeted social push. NULL means the 14-day pre-show window has not started yet.
      The momentum score is built from regional social media engagement data.

      Always pair a metric with context — compare to a prior period or to other values
      in the same query. Lead with the direct answer, then show supporting detail.

      Format USD as $X,XXX.XX. Format percentages to 1 decimal place.
      Use CASE WHEN for conditionals — never ternary (? :) syntax.

    orchestration: |
      Route all questions to ArtistAnalytics.
      Use data_to_chart when the user asks for a trend, comparison, or "show me" request
      where a chart would be clearer than a table.

    sample_questions:
      - question: "What were my total streams last month across all platforms?"
      - question: "Which streaming platform is growing the fastest?"
      - question: "What is the momentum score for each of my upcoming shows?"
      - question: "My Nashville show is in two weeks — how does my momentum there compare to my other cities?"
      - question: "What is my total income this month, broken down by source?"
      - question: "Which social platform drives the most engagement?"
      - question: "Show me my weekly stream trend over the last 60 days"
      - question: "How much of my income came from sync licensing this year?"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "ArtistAnalytics"
        description: |
          Converts natural language questions into SQL and returns results for Jade Hollow's music career data.
          Use for: streaming counts and trends by platform, social media impressions and engagement by platform,
          income breakdown (streaming royalties, merchandise, sync licensing), upcoming show momentum scores,
          platform comparisons, time-period trends (weekly, monthly), and any question about numbers or performance.
          Data covers the past 90 days. Streaming platforms: Spotify, Apple Music, Amazon Music, YouTube.
          Social platforms: TikTok, Instagram, YouTube Shorts, X.
          Show cities: Nashville, Austin, Chicago, Los Angeles, New York.
    - tool_spec:
        type: "data_to_chart"
        name: "data_to_chart"
        description: "Generates bar charts, line charts, and tables from query results. Use for trends, platform comparisons, income breakdowns, and momentum score comparisons."

  tool_resources:
    ArtistAnalytics:
      semantic_view: "SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_ARTIST_ANALYTICS"
      execution_environment:
        type: warehouse
        warehouse: "SFE_ARTIST_ANALYTICS_WH"
  $$;

SELECT 'ARTIST_ANALYTICS_AGENT created — next: Snowsight → AI & ML → Agents → Add to CoWork' AS step_04_agent;
