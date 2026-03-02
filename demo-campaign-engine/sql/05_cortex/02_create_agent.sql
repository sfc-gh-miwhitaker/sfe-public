/*==============================================================================
CORTEX INTELLIGENCE AGENT
Generated from prompt: "Create a Cortex Intelligence Agent for natural-language
  queries about campaign performance, player behavior, and audience segments."
Tool: Cursor + Claude | Refined: 1 iteration(s)
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-01
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;
USE WAREHOUSE SFE_CAMPAIGN_ENGINE_WH;

CREATE OR REPLACE CORTEX AGENT SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.CAMPAIGN_ANALYTICS_AGENT
FROM SPECIFICATION $$
{
  "type": "cortex_agent",
  "name": "Campaign Analytics Agent",
  "description": "Natural-language analytics for casino campaign performance, player behavior, and audience segmentation. Ask questions about campaign response rates, player wagering patterns, loyalty tiers, and more.",
  "tools": [
    {
      "type": "cortex_analyst_tool",
      "name": "campaign_data",
      "description": "Answers data questions about casino players, their behavioral metrics (wagering, session frequency, game preferences, loyalty tier), marketing campaigns (retention, acquisition, upsell, reactivation), and campaign response history. Use this tool for any question involving player counts, averages, trends, comparisons, or campaign performance metrics like response rate and redemption amounts.",
      "semantic_views": [
        "SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_CAMPAIGN_ENGINE_ANALYTICS"
      ]
    }
  ],
  "tool_choice": "auto",
  "sample_questions": [
    "Which campaign type has the highest response rate?",
    "What is the average daily wagering for Diamond tier players?",
    "How many players have not visited in the last 30 days?",
    "Show me the response rate breakdown by loyalty tier",
    "Which campaigns generated the most redemption revenue?",
    "Compare average session frequency between slot players and table game players"
  ]
}
$$
COMMENT = 'DEMO: NL analytics agent for campaign and player data (Expires: 2026-04-01)';
