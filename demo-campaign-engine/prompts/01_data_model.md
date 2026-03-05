# Step 1: Data Model

## AI-Pair Technique: Describe the Problem, Not the Solution

Don't specify column names and data types -- describe your business domain and use cases, and let the AI infer the right schema. You'll get a better result because the AI understands *why* each column exists. However, do include structural constraints (how many tables, flat vs. normalized) when you know what later steps require. Telling the AI "4 raw staging tables" isn't over-specifying -- it's preventing the AI from over-engineering a star schema that breaks your downstream pipeline.

## Before You Start

- [ ] Snowflake schema `SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE` exists (see [GUIDED_BUILD.md](../GUIDED_BUILD.md#before-you-start))
- [ ] Warehouse `SFE_CAMPAIGN_ENGINE_WH` is running
- [ ] Your AI tool is open with this project directory as context

## The Prompt

Paste this into your AI tool:

> "I'm a casino operator. I need 4 raw staging tables for a campaign recommendation engine. Players have loyalty tiers (Bronze through Diamond) and a home property. Player activity is a single event stream where each session has a game type (slots, table games, poker, sports book), duration, wager, and device. I run marketing campaigns (retention, acquisition, upsell, reactivation) and track which players respond. Keep the model flat -- these are raw tables that a feature engineering pipeline will build on in later steps. The two downstream use cases are ML audience targeting and vector-based player similarity."

## What to Tell the AI (AGENTS.md v1)

After this step, create an `AGENTS.md` file in your project root with this content:

```markdown
# Casino Campaign Recommendation Engine

Campaign recommendation engine for casino operators.

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: CAMPAIGN_ENGINE
- Warehouse: SFE_CAMPAIGN_ENGINE_WH
```

This is deliberately minimal. The AI only needs to know where things live. You'll add patterns and conventions as you build.

## Validate Your Work

Run these in Snowsight to confirm the step worked:

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;

-- Should return 4 tables
SELECT TABLE_NAME, ROW_COUNT
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'CAMPAIGN_ENGINE'
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

-- Confirm ML-critical columns exist
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'CAMPAIGN_ENGINE'
  AND TABLE_NAME = 'RAW_CAMPAIGN_RESPONSES'
  AND COLUMN_NAME IN ('RESPONDED', 'REDEMPTION_AMOUNT');
```

Expected: 4 tables (`RAW_CAMPAIGNS`, `RAW_CAMPAIGN_RESPONSES`, `RAW_PLAYER_ACTIVITY`, `RAW_PLAYERS`) and a `RESPONDED` column with BOOLEAN type.

## Common Mistakes

### Mistake 1: The vague prompt

"Build me a casino database" or "Create some tables for player data."

What goes wrong: The AI produces generic tables missing ML-critical columns. Without `responded` (BOOLEAN) on campaign responses, you can't train a classifier in Step 5. Without `session_duration_min` and `total_wagered` on activity, you can't compute meaningful behavioral features in Step 3. Without `redemption_amount`, your Cortex Agent in Step 7 can't answer revenue questions.

The fix: Mention your downstream use cases in the prompt. The phrase "ML audience targeting" causes the AI to add a binary response column. The phrase "vector-based player similarity" causes it to include enough behavioral columns (duration, wager, device, game type) to build a meaningful feature vector.

### Mistake 2: The over-engineered schema

The AI produces 10-12 tables -- DIM_PLAYER, DIM_PROPERTY, DIM_GAME_TYPE, separate fact tables per game type (FACT_SLOT_SESSION, FACT_TABLE_GAME_VISIT, FACT_POKER_HAND, FACT_SPORTSBOOK_BET), pre-computed PLAYER_FEATURES, PLAYER_EMBEDDINGS tables, and so on. A full normalized star schema.

What goes wrong: Every downstream step breaks. Step 2's data generation prompt expects 4 tables. Step 3 builds features from a single `RAW_PLAYER_ACTIVITY` table. Step 5 trains ML on `RAW_CAMPAIGN_RESPONSES.responded` (BOOLEAN). If your schema splits activity into 4 fact tables, the feature pipeline has no single table to aggregate. If the AI pre-computes features at Step 1, Step 3's Dynamic Tables are redundant.

Why it happens: Phrases like "slot sessions, table game visits, poker hands, sports book bets" read as 4 entity types. Mentioning "ML" and "vector similarity" triggers the AI to add pre-computed feature tables. Saying "multiple properties" invites a dimension table.

The fix: The prompt says "4 raw staging tables" and "keep the model flat." Activity is a single event stream with a `game_type` column, not 4 separate fact tables. Feature engineering happens in Step 3 as Dynamic Tables. If your AI over-engineered, follow up with: "Simplify to exactly 4 flat tables with RAW_ prefix: RAW_PLAYERS, RAW_PLAYER_ACTIVITY (single table for all game types), RAW_CAMPAIGNS, RAW_CAMPAIGN_RESPONSES. No dimensions, no pre-computed features, no star schema."

## What Just Happened

Notice what the AI chose without you specifying it:

- **NUMBER(38,2) for monetary amounts** -- not INTEGER, not FLOAT. The AI knows currency needs fixed precision.
- **BOOLEAN for responded** -- not VARCHAR('Y'/'N'), not NUMBER(1). Clean ML target variable.
- **VARCHAR for categorical fields** -- game_type, device, loyalty_tier stay flexible rather than being constrained to ENUMs.
- **Separate tables for campaigns vs. responses** -- proper normalization. Campaign metadata lives in one place; response events reference it.

The AI made these decisions because the prompt described *what the data means*, not *what types to use*.

## If Something Went Wrong

**Missing a table?** The AI occasionally combines campaigns and responses into one table. Follow up with: "Separate campaign definitions from campaign responses -- I need a normalized schema where campaign metadata is defined once and responses reference it."

**Wrong column types?** If `responded` came back as VARCHAR, follow up with: "The responded column should be BOOLEAN -- it's the target variable for ML CLASSIFICATION which requires a binary class."

## What Was Generated

- `RAW_PLAYERS` -- Player demographics with loyalty tier and home property
- `RAW_PLAYER_ACTIVITY` -- Game session events across 4 game types and 3 devices
- `RAW_CAMPAIGNS` -- Campaign definitions with type and target segment
- `RAW_CAMPAIGN_RESPONSES` -- Historical response data for ML training

## Reference Implementation

Compare your AI's output to [sql/02_data/01_create_tables.sql](../sql/02_data/01_create_tables.sql).
