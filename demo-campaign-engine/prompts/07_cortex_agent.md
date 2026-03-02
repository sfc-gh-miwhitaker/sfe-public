# Prompt: Cortex Intelligence Agent

## The Prompt

"Create a Cortex Intelligence Agent with a semantic view over player features, campaigns, and campaign responses. The agent should answer natural-language questions about campaign performance, player behavior, and audience segments."

## What Was Generated

- `sql/05_cortex/01_create_semantic_view.sql` -- Semantic view with dimensions, facts, metrics
- `sql/05_cortex/02_create_agent.sql` -- Intelligence Agent specification

## Key Decisions Made by AI

- Semantic view spans DT_PLAYER_FEATURES, RAW_CAMPAIGNS, RAW_CAMPAIGN_RESPONSES
- Clause order matters: FACTS before DIMENSIONS (Snowflake syntax requirement)
- Dimensions: loyalty tier, campaign type, campaign name, target segment, responded
- Facts: wager amounts, session frequency, lifetime wagered, game diversity, slots/table pct, redemption
- Metrics: response rate, average wagering, player count, total redemption
- Agent uses CREATE AGENT with YAML specification (not the older JSON format)
- Tool type is `cortex_analyst_text_to_sql` with semantic view in `tool_resources`
- Agent sample questions mapped to verified queries
