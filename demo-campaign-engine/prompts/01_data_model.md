# Step 1: Data Model

## AI-Pair Technique: Describe the Problem, Not the Solution

Don't specify column names and data types -- describe your business domain and use cases, and let the AI infer the right schema. You'll get a better result because the AI understands *why* each column exists. However, do include structural constraints (how many tables, flat vs. normalized) when you know what later steps require. Telling the AI "4 raw staging tables" isn't over-specifying -- it's preventing the AI from over-engineering a star schema that breaks your downstream pipeline.

## Before You Start

- [ ] Snowflake schema `SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE` exists (see [GUIDED_BUILD.md](../GUIDED_BUILD.md#before-you-start))
- [ ] Warehouse `SFE_CAMPAIGN_ENGINE_WH` is running
- [ ] `AGENTS.md` exists in your project root with naming conventions (see [GUIDED_BUILD.md](../GUIDED_BUILD.md#2-create-agentsmd-project-context))
- [ ] Your AI tool is open with this project directory as context (start a **fresh conversation** so AGENTS.md is loaded)

## The Prompt

Paste this into your AI tool:

> "I'm a casino operator. I need 4 raw staging tables for a campaign recommendation engine. Players have loyalty tiers (Bronze through Diamond) and a home property. Player activity is a single event stream where each session has a game type (slots, table games, poker, sports book), duration, wager, and device. I run marketing campaigns (retention, acquisition, upsell, reactivation) and track which players respond with a simple boolean. Keep the model flat -- these are raw tables that a feature engineering pipeline will build on in later steps. The two downstream use cases are ML audience targeting and vector-based player similarity. Create only the CREATE TABLE DDL -- do not generate sample data."

## Validate Your Work

Run these in Snowsight to confirm the step worked:

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;

-- 1. Should return exactly 4 tables, all with RAW_ prefix
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'CAMPAIGN_ENGINE'
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

-- 2. Primary keys should be NUMBER (integer), not VARCHAR/UUID
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'CAMPAIGN_ENGINE'
  AND COLUMN_NAME LIKE '%\_ID' ESCAPE '\\'
  AND ORDINAL_POSITION = 1
ORDER BY TABLE_NAME;

-- 3. ML-critical: responded BOOLEAN + redemption_amount on responses
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'CAMPAIGN_ENGINE'
  AND TABLE_NAME = 'RAW_CAMPAIGN_RESPONSES'
  AND COLUMN_NAME IN ('RESPONDED', 'REDEMPTION_AMOUNT');

-- 4. Feature-critical columns on activity table
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'CAMPAIGN_ENGINE'
  AND TABLE_NAME = 'RAW_PLAYER_ACTIVITY'
  AND COLUMN_NAME IN ('GAME_TYPE', 'GAME_NAME', 'SESSION_DURATION_MIN',
                       'TOTAL_WAGERED', 'TOTAL_WON', 'DEVICE');
```

Expected:

1. Exactly 4 tables: `RAW_CAMPAIGNS`, `RAW_CAMPAIGN_RESPONSES`, `RAW_PLAYER_ACTIVITY`, `RAW_PLAYERS`
2. All `_ID` columns are `NUMBER` (not `VARCHAR`) -- Step 2 needs integer IDs for GENERATOR
3. `RESPONDED` is `BOOLEAN`, `REDEMPTION_AMOUNT` is `NUMBER` -- Step 5 ML needs a binary target
4. All 6 columns present -- Step 3 feature pipeline needs game_type, game_name, duration, wager, winnings, and device

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

### Mistake 3: Right tables, wrong columns

The AI produces exactly 4 tables but with different column choices: UUIDs instead of integers, a marketing funnel (sent_at/opened_at/clicked_at/converted_at) instead of a simple `responded` boolean, date_of_birth instead of age_band, or first_name/last_name instead of a single name column.

Why it happens: Without naming conventions in AGENTS.md, the AI applies generic best practices -- UUIDs are "standard" for distributed systems, marketing funnels are "richer" than boolean flags, exact birth dates are "more flexible" than age bands. These are reasonable choices in isolation but break the downstream pipeline.

Why it breaks: Step 2's GENERATOR() produces integer sequences, not UUIDs. Step 5's ML classifier needs `responded` as a BOOLEAN target variable. Step 3 computes `loyalty_tier_num` from mixed-case tier names ('Bronze', not 'BRONZE'). Each deviation creates a mismatch that surfaces 2-3 steps later.

The fix: Verify AGENTS.md v1 exists with naming conventions before running the prompt. The Development Standards (RAW_ prefix, integer PKs) prevent the most common deviations. For column-level drift, run the validation queries and use the recovery prompts in "If Something Went Wrong."

### Mistake 4: The AI runs ahead

You asked for CREATE TABLE statements but the AI also generated INSERT statements with sample data. Now you have 10 rows per table with hand-crafted values instead of the 500 players and 10K activities that Step 2 will generate with proper statistical distributions.

Why it happens: The AI sees "campaign engine" and infers the full lifecycle -- schema, data, features. It's trying to be helpful by giving you a complete, runnable script.

Why it breaks: Step 2 teaches a different AI-pair technique (specify constraints, not code) and requires specific statistical properties -- weighted tier distributions, game-type-specific wager ranges, ~30% response rate. Hand-crafted sample data has none of these properties, so the ML model in Step 5 has no signal to learn from.

The fix: The prompt ends with "Create only the CREATE TABLE DDL -- do not generate sample data." If the AI ran ahead anyway, keep only the CREATE TABLE statements and discard the INSERTs. This is a transferable pattern: always scope your prompt to one deliverable so you can validate before the next step.

## What Just Happened

Notice what the AI chose without you specifying it:

- **NUMBER(38,2) for monetary amounts** -- not INTEGER, not FLOAT. The AI knows currency needs fixed precision.
- **BOOLEAN for responded** -- not VARCHAR('Y'/'N'), not NUMBER(1). Clean ML target variable.
- **VARCHAR for categorical fields** -- game_type, device, loyalty_tier stay flexible rather than being constrained to ENUMs.
- **Separate tables for campaigns vs. responses** -- proper normalization. Campaign metadata lives in one place; response events reference it.

The AI made these decisions because the prompt described *what the data means*, not *what types to use*.

## If Something Went Wrong

**Wrong prefix (STG_, DIM_, FACT_)?** Follow up with: "Rename all tables to use RAW_ prefix: RAW_PLAYERS, RAW_PLAYER_ACTIVITY, RAW_CAMPAIGNS, RAW_CAMPAIGN_RESPONSES. Check that your AGENTS.md naming conventions are loaded."

**UUID primary keys instead of integers?** Follow up with: "Change all primary keys to NUMBER(38,0) NOT NULL. Step 2 uses GENERATOR() and UNIFORM() which produce integer sequences -- UUIDs won't work."

**Marketing funnel instead of `responded` boolean?** If you got sent_at/opened_at/clicked_at/converted_at columns, follow up with: "Replace the funnel timestamp columns with a single `responded BOOLEAN NOT NULL` column and a `response_date DATE`. The ML classifier in Step 5 needs a binary target variable, not a multi-stage funnel."

**Missing `game_name`?** Follow up with: "Add a `game_name VARCHAR(50)` column to the activity table -- each game type has specific titles (e.g. 'Lucky 7s' for slots, 'Blackjack' for table games). The feature pipeline needs this for game diversity metrics."

**`date_of_birth` instead of `age_band`?** Follow up with: "Replace date_of_birth with `age_band VARCHAR(10)` using bands like '21-30', '31-40', etc. Pre-banded ages are simpler for ML features and avoid PII concerns."

**Missing a table?** The AI occasionally combines campaigns and responses into one table. Follow up with: "Separate campaign definitions from campaign responses -- I need a normalized schema where campaign metadata is defined once and responses reference it."

**No constraints?** Follow up with: "Add PRIMARY KEY constraint on each table's ID column and FOREIGN KEY constraints linking player_id and campaign_id in the activity and response tables to their parent tables."

**AI also generated sample data?** If you got INSERT statements alongside the CREATE TABLEs, discard the data portion. Step 2 has its own prompt with specific statistical requirements (tier distributions, wager ranges, response rates). Run the CREATE TABLE statements only, then move to [Step 2](02_sample_data.md).

## What Was Generated

- `RAW_PLAYERS` -- Player demographics with loyalty tier and home property
- `RAW_PLAYER_ACTIVITY` -- Game session events across 4 game types and 3 devices
- `RAW_CAMPAIGNS` -- Campaign definitions with type and target segment
- `RAW_CAMPAIGN_RESPONSES` -- Historical response data for ML training

## Reference Implementation

Compare your AI's output to [sql/02_data/01_create_tables.sql](../sql/02_data/01_create_tables.sql).
