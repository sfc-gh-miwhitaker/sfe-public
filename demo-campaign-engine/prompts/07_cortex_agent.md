# Prompt: Cortex Intelligence Agent

## The Prompt

"Create a Cortex Intelligence Agent with a semantic view over player features, campaigns, and campaign responses. The agent should answer natural-language questions about campaign performance, player behavior, and audience segments."

## What Was Generated

- `sql/05_cortex/01_create_semantic_view.sql` -- Semantic view with dimensions, facts, metrics
- `sql/05_cortex/02_create_agent.sql` -- Intelligence Agent specification

## Key Decisions Made by AI

- Semantic view spans DT_PLAYER_FEATURES, RAW_CAMPAIGNS, RAW_CAMPAIGN_RESPONSES
- Dimensions: loyalty tier, campaign type, game type, device, age band
- Facts: wager amounts, session counts, response counts
- Metrics: response rate, average wagering, player count, campaign ROI
- Agent sample questions mapped to verified queries
