# Step 3: Feature Engineering Pipeline

## AI-Pair Technique: Name the Snowflake Feature

When you want the AI to use a specific Snowflake primitive, say its name. "Use Dynamic Tables with TARGET_LAG" and "store as VECTOR(FLOAT,16)" are not implementation details you're specifying too early -- they're design decisions that steer the AI to the right architecture. Without them, you'll get a regular VIEW and an ARRAY.

## Before You Start

- [ ] Step 2 complete: all 4 tables have data loaded
- [ ] `RAW_PLAYERS` has ~500 rows, `RAW_PLAYER_ACTIVITY` has ~10K rows

## The Prompt

Paste this into your AI tool:

> "Create a feature engineering pipeline that computes 16 behavioral metrics per player and stores them as a VECTOR(FLOAT,16) for similarity search. Use Dynamic Tables with TARGET_LAG for automatic refresh. Name the Dynamic Tables with a DT_ prefix (e.g. DT_PLAYER_FEATURES, DT_PLAYER_VECTORS). Normalize all features to 0-1 range using min-max scaling."

## What to Tell the AI (AGENTS.md v2)

After this step, replace your `AGENTS.md` with this updated version:

```markdown
# Casino Campaign Recommendation Engine

Campaign recommendation engine for casino operators with ML audience targeting and vector-based player lookalike matching.

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: CAMPAIGN_ENGINE
- Warehouse: SFE_CAMPAIGN_ENGINE_WH

## Key Patterns
- Dynamic Tables with TARGET_LAG = '1 hour' for automated feature engineering
- VECTOR(FLOAT, 16) data type for player behavior embeddings
- Min-max normalization across all players for each feature
- COALESCE/NULLIF guards against division by zero

## Development Standards
- Naming: RAW_ prefix for staging tables; SFE_ prefix for account-level objects only
- IDs: INTEGER primary keys (GENERATOR/UNIFORM for synthetic data)
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT = 'DEMO: <description> (Expires: 2026-05-01)' on all objects
- Constraints: PRIMARY KEY on every table, FOREIGN KEY where applicable
- Deploy: One-command deployment via deploy_all.sql
```

Notice what changed: the description now includes "ML audience targeting and vector-based player lookalike matching." Key Patterns is new. Development Standards carries forward v1's naming conventions and adds SQL and deployment patterns. From this point forward, the AI knows about Dynamic Tables and VECTOR when you ask it to build new features.

**Also add your actual column names.** The v2 template above tells the AI that 16 features exist, but not what they're called. Step 5's ML classifier must reference your exact column names in an OBJECT_CONSTRUCT -- if AGENTS.md doesn't list them, the AI has to guess. After validation, run this and append the output to your AGENTS.md Key Patterns section:

```sql
SELECT LISTAGG(COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY ORDINAL_POSITION)
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'CAMPAIGN_ENGINE'
  AND TABLE_NAME = 'DT_PLAYER_FEATURES'
  AND COLUMN_NAME != 'PLAYER_ID';
```

Add a line like: `- DT_PLAYER_FEATURES columns: avg_daily_wager, session_frequency, ...` (using your actual column names). This is the difference between the AI *knowing about* your features and *knowing what they're called*.

## Validate Your Work

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;

-- 1. Both Dynamic Tables should exist with DT_ prefix
SHOW DYNAMIC TABLES LIKE 'DT_%' IN SCHEMA CAMPAIGN_ENGINE;

-- 2. Feature table: 500 players, exactly 17 columns (player_id + 16 features)
SELECT COUNT(*) AS player_count FROM DT_PLAYER_FEATURES;

SELECT COUNT(*) AS column_count
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'CAMPAIGN_ENGINE'
  AND TABLE_NAME = 'DT_PLAYER_FEATURES';

-- 3. Vector table: VECTOR(FLOAT,16) column exists
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'CAMPAIGN_ENGINE'
  AND TABLE_NAME = 'DT_PLAYER_VECTORS'
  AND DATA_TYPE = 'VECTOR';

-- 4. Spot check: vectors should be in 0-1 range after normalization
-- (use your actual vector column name -- it may be behavior_vector,
--  feature_vector, player_vector, etc.)
SELECT player_id, *
FROM DT_PLAYER_VECTORS
LIMIT 3;
```

Expected:

1. 2 Dynamic Tables show up with DT_ prefix
2. ~500 players, 17 columns (player_id + 16 feature columns)
3. One column with DATA_TYPE = `VECTOR` (the column name may vary)
4. All vector values between 0.0 and 1.0 after min-max normalization

## Common Mistake

**The generic prompt:** "Create a view that computes player features."

What goes wrong: The AI creates a regular VIEW, not a Dynamic Table. It works fine initially -- you query it, features come back. The problem surfaces later: when you add new player activity data, the features are stale. You won't notice until Step 5 when the ML model trains on outdated data, or worse, in production when the dashboard shows yesterday's numbers.

A regular VIEW also won't have TARGET_LAG metadata, so there's no built-in mechanism to monitor freshness or set refresh expectations.

The fix: Name the Snowflake feature explicitly. "Use Dynamic Tables with TARGET_LAG" tells the AI to use CREATE DYNAMIC TABLE with WAREHOUSE and TARGET_LAG clauses. The result auto-refreshes without a Stream+Task pipeline.

Similarly, without "VECTOR(FLOAT,16)" the AI may store features as an ARRAY or 16 separate columns. Both technically work, but VECTOR enables VECTOR_COSINE_SIMILARITY in Step 4, which is dramatically faster than manual array math.

## What Just Happened

The AI created a two-stage pipeline:

1. **DT_PLAYER_FEATURES** -- Aggregates raw activity into 16 metrics per player. Your column names will differ from the reference implementation -- that's fine. What matters is the feature *categories* (see below).
2. **DT_PLAYER_VECTORS** -- Normalizes all 16 features to 0-1 via min-max scaling and packs them into `VECTOR(FLOAT,16)`.

Key patterns to notice:

- **NULLIF guards** -- `SUM(x) / NULLIF(COUNT(*), 0)` prevents division by zero for players with no activity
- **COALESCE defaults** -- Players with no activity get 0 for most metrics, 999 for days_since_last_visit
- **Two-stage pipeline** -- Raw features and normalized vectors are separate Dynamic Tables so you can query either layer independently
- **CROSS JOIN bounds** -- The normalization step computes global min/max once and joins to every player row

## If Something Went Wrong

**Dynamic Tables not named DT_?** If the AI named them PLAYER_FEATURES and PLAYER_VECTORS (or similar) without the DT_ prefix, follow up with: "Rename the Dynamic Tables to use a DT_ prefix: DT_PLAYER_FEATURES and DT_PLAYER_VECTORS. Steps 4 and 5 reference these names." You'll need to DROP and recreate since Dynamic Tables can't be renamed.

**Dynamic Tables stuck in SUSPENDED state?** Check `SHOW DYNAMIC TABLES` for the SCHEDULING_STATE column. If it's SUSPENDED, the warehouse may not exist: `ALTER DYNAMIC TABLE DT_PLAYER_FEATURES RESUME;`

**Vector column came back as ARRAY instead of VECTOR?** Follow up with: "Cast the final array to VECTOR(FLOAT, 16) using `::VECTOR(FLOAT, 16)`. The column type must be VECTOR, not ARRAY, for VECTOR_COSINE_SIMILARITY to work."

**Features include campaign response data (data leakage)?** If any features are derived from `RAW_CAMPAIGN_RESPONSES` (like response_rate or avg_redemption), the ML model in Step 5 will train on features that contain the answer. Follow up with: "Remove any features derived from campaign responses -- those are the target variable for the ML model. Replace them with behavioral features from player activity only, like weekend_pct or avg_bet_size."

**Only 16 features, but some are always 0?** This means some game types or devices aren't represented in your sample data. Go back to Step 2 and verify your data has all 4 game types and multiple devices.

## The 16 Features

Your AI will choose its own column names -- that's expected. What matters is that the 16 features cover these behavioral categories:

- **Wagering** -- total wagered, average wager, win/loss ratio (2-3 features)
- **Session behavior** -- session count, session duration, visit frequency (2-3 features)
- **Game preferences** -- percentage per game type: slots, table games, poker, sportsbook (4 features)
- **Recency** -- days since last visit, recent session count (1-2 features)
- **Diversity** -- game type diversity, device mix (1-2 features)
- **Player profile** -- loyalty tier (numeric), tenure/registration age (1-2 features)

The reference implementation uses: avg_daily_wager, session_frequency, avg_session_duration, win_rate, slots_pct, table_pct, poker_pct, sportsbook_pct, weekend_pct, mobile_pct, days_since_last_visit, lifetime_wagered, loyalty_tier_num, avg_bet_size, visit_consistency, game_diversity.

## Reference Implementation

Compare your AI's output to:
- [sql/03_features/01_player_features.sql](../sql/03_features/01_player_features.sql)
- [sql/03_features/02_player_vectors.sql](../sql/03_features/02_player_vectors.sql)
