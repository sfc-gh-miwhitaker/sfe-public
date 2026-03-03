/*==============================================================================
CORTEX INTELLIGENCE AGENT
Generated from prompt: "Create a Cortex Intelligence Agent for natural-language
  queries about campaign performance, player behavior, and audience segments."
Tool: Cursor + Claude | Refined: 1 iteration(s)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-05-01
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;
USE WAREHOUSE SFE_CAMPAIGN_ENGINE_WH;

CREATE OR REPLACE AGENT SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.CAMPAIGN_ANALYTICS_AGENT
  COMMENT = 'DEMO: NL analytics agent for campaign and player data (Expires: 2026-05-01)'
  PROFILE = '{"display_name": "Campaign Analytics", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  instructions:
    response: >-
      You are a casino marketing analytics assistant. Answer questions about
      campaign performance, player behavior, and audience segmentation using
      the campaign data tool. Be specific with numbers and percentages.
    sample_questions:
      - question: 'Which campaign type has the highest response rate?'
      - question: 'What is the average daily wagering for Diamond tier players?'
      - question: 'How many players have not visited in the last 30 days?'
      - question: 'Show me the response rate breakdown by loyalty tier'
      - question: 'Which campaigns generated the most redemption revenue?'
      - question: 'Compare average session frequency between slot players and table game players'

  tools:
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: campaign_data
        description: >-
          Answers data questions about casino players, their behavioral metrics
          (wagering, session frequency, game preferences, loyalty tier), marketing
          campaigns (retention, acquisition, upsell, reactivation), and campaign
          response history. Use this tool for any question involving player counts,
          averages, trends, comparisons, or campaign performance metrics like
          response rate and redemption amounts.
    - tool_spec:
        type: data_to_chart
        name: data_to_chart
        description: 'Generates visualizations from data'

  tool_resources:
    campaign_data:
      semantic_view: SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_CAMPAIGN_ENGINE_ANALYTICS
  $$;

----------------------------------------------------------------------
-- Register agent with Snowflake Intelligence
----------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
  ADD AGENT SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.CAMPAIGN_ANALYTICS_AGENT;

GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
  TO ROLE PUBLIC;

USE ROLE SYSADMIN;
