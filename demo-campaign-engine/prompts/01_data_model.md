# Prompt: Data Model

## The Prompt

"I'm a casino operator. I have player activity data -- slot sessions, table game visits, poker hands, sports book bets. Players have loyalty tiers (Bronze through Diamond) and visit multiple properties. I run marketing campaigns (retention, acquisition, upsell, reactivation) and track which players respond. I need a data model that supports two use cases: identifying target audiences for campaigns using ML, and finding players with similar behavior patterns using vector similarity."

## What Was Generated

- `RAW_PLAYERS` -- Player demographics with loyalty tier and home property
- `RAW_PLAYER_ACTIVITY` -- Game session events across 4 game types and 3 devices
- `RAW_CAMPAIGNS` -- Campaign definitions with type and target segment
- `RAW_CAMPAIGN_RESPONSES` -- Historical response data for ML training
- `diagrams/data-model.md` -- Mermaid ER diagram

## Key Decisions Made by AI

- Chose NUMBER(38,2) for monetary amounts (wagered, won, redemption)
- Used VARCHAR for categorical fields (game_type, device) rather than enums
- Added BOOLEAN for campaign response (responded) -- clean ML target
- Included session_duration_min as INTEGER for behavioral features
- Separated campaign definitions from responses for proper normalization
