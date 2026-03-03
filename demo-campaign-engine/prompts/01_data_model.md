# Step 1: Data Model

## AI-Pair Technique: Describe the Problem, Not the Solution

Don't ask the AI to "create 4 tables with these columns." Describe your business domain and use cases -- the AI will infer the right schema, data types, and relationships. You'll get a better result because the AI understands *why* each column exists.

## Before You Start

- [ ] Snowflake schema `SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE` exists (see [GUIDED_BUILD.md](../GUIDED_BUILD.md#before-you-start))
- [ ] Warehouse `SFE_CAMPAIGN_ENGINE_WH` is running
- [ ] Your AI tool is open with this project directory as context

## The Prompt

Paste this into your AI tool:

> "I'm a casino operator. I have player activity data -- slot sessions, table game visits, poker hands, sports book bets. Players have loyalty tiers (Bronze through Diamond) and visit multiple properties. I run marketing campaigns (retention, acquisition, upsell, reactivation) and track which players respond. I need a data model that supports two use cases: identifying target audiences for campaigns using ML, and finding players with similar behavior patterns using vector similarity."

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

## Common Mistake

**The vague prompt:** "Build me a casino database" or "Create some tables for player data."

What goes wrong: The AI produces generic tables missing ML-critical columns. Without `responded` (BOOLEAN) on campaign responses, you can't train a classifier in Step 5. Without `session_duration_min` and `total_wagered` on activity, you can't compute meaningful behavioral features in Step 3. Without `redemption_amount`, your Cortex Agent in Step 7 can't answer revenue questions.

The fix: Mention your downstream use cases in the prompt. The phrase "identifying target audiences using ML" causes the AI to add a binary response column. The phrase "similar behavior patterns using vector similarity" causes it to include enough behavioral columns (duration, wager, device, game type) to build a meaningful feature vector.

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
