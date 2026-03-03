# Step 3: Feature Engineering Pipeline

## AI-Pair Technique: Name the Snowflake Feature

When you want the AI to use a specific Snowflake primitive, say its name. "Use Dynamic Tables with TARGET_LAG" and "store as VECTOR(FLOAT,16)" are not implementation details you're specifying too early -- they're design decisions that steer the AI to the right architecture. Without them, you'll get a regular VIEW and an ARRAY.

## Before You Start

- [ ] Step 2 complete: all 4 tables have data loaded
- [ ] `RAW_PLAYERS` has ~500 rows, `RAW_PLAYER_ACTIVITY` has ~10K rows

## The Prompt

Paste this into your AI tool:

> "Create a feature engineering pipeline that computes 16 behavioral metrics per player and stores them as a VECTOR(FLOAT,16) for similarity search. Use Dynamic Tables with TARGET_LAG for automatic refresh. Normalize all features to 0-1 range using min-max scaling."

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
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy_all.sql
```

Notice what changed: the description now includes "ML audience targeting and vector-based player lookalike matching." Key Patterns and Development Standards sections are new. From this point forward, the AI knows about Dynamic Tables and VECTOR when you ask it to build new features.

## Validate Your Work

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;

-- Both Dynamic Tables should exist and be refreshing
SHOW DYNAMIC TABLES LIKE 'DT_%' IN SCHEMA CAMPAIGN_ENGINE;

-- Feature table should have all 500 players with 16 metrics
SELECT COUNT(*) AS player_count,
       COUNT_IF(avg_daily_wager IS NOT NULL) AS has_features
FROM DT_PLAYER_FEATURES;

-- Vector table should have VECTOR(FLOAT,16) per player
SELECT COUNT(*) AS vector_count,
       MIN(behavior_vector IS NOT NULL)::BOOLEAN AS all_non_null
FROM DT_PLAYER_VECTORS;

-- Spot check: vectors should be in 0-1 range after normalization
SELECT player_id,
       behavior_vector::ARRAY AS bv
FROM DT_PLAYER_VECTORS
LIMIT 3;
```

Expected: 2 Dynamic Tables. ~500 rows in each. All vector values between 0.0 and 1.0.

## Common Mistake

**The generic prompt:** "Create a view that computes player features."

What goes wrong: The AI creates a regular VIEW, not a Dynamic Table. It works fine initially -- you query it, features come back. The problem surfaces later: when you add new player activity data, the features are stale. You won't notice until Step 5 when the ML model trains on outdated data, or worse, in production when the dashboard shows yesterday's numbers.

A regular VIEW also won't have TARGET_LAG metadata, so there's no built-in mechanism to monitor freshness or set refresh expectations.

The fix: Name the Snowflake feature explicitly. "Use Dynamic Tables with TARGET_LAG" tells the AI to use CREATE DYNAMIC TABLE with WAREHOUSE and TARGET_LAG clauses. The result auto-refreshes without a Stream+Task pipeline.

Similarly, without "VECTOR(FLOAT,16)" the AI may store features as an ARRAY or 16 separate columns. Both technically work, but VECTOR enables VECTOR_COSINE_SIMILARITY in Step 4, which is dramatically faster than manual array math.

## What Just Happened

The AI created a two-stage pipeline:

1. **DT_PLAYER_FEATURES** -- Aggregates raw activity into 16 metrics: avg_daily_wager, session_frequency, game type percentages, days_since_last_visit, game_diversity, etc.
2. **DT_PLAYER_VECTORS** -- Normalizes all 16 features to 0-1 via min-max scaling and packs them into `VECTOR(FLOAT,16)`.

Key patterns to notice:

- **NULLIF guards** -- `SUM(x) / NULLIF(COUNT(*), 0)` prevents division by zero for players with no activity
- **COALESCE defaults** -- Players with no activity get 0 for most metrics, 999 for days_since_last_visit
- **Two-stage pipeline** -- Raw features and normalized vectors are separate Dynamic Tables so you can query either layer independently
- **CROSS JOIN bounds** -- The normalization step computes global min/max once and joins to every player row

## If Something Went Wrong

**Dynamic Tables stuck in SUSPENDED state?** Check `SHOW DYNAMIC TABLES` for the SCHEDULING_STATE column. If it's SUSPENDED, the warehouse may not exist: `ALTER DYNAMIC TABLE DT_PLAYER_FEATURES RESUME;`

**Vector column came back as ARRAY instead of VECTOR?** Follow up with: "Cast the final array to VECTOR(FLOAT, 16) using `::VECTOR(FLOAT, 16)`. The column type must be VECTOR, not ARRAY, for VECTOR_COSINE_SIMILARITY to work."

**Only 16 features, but some are always 0?** This means some game types or devices aren't represented in your sample data. Go back to Step 2 and verify your data has all 4 game types and multiple devices.

## The 16 Features

1. avg_daily_wager, 2. session_frequency, 3. avg_session_duration, 4. win_rate,
5. slots_pct, 6. table_pct, 7. poker_pct, 8. sportsbook_pct,
9. weekend_pct, 10. mobile_pct, 11. days_since_last_visit, 12. lifetime_wagered,
13. loyalty_tier_num, 14. avg_bet_size, 15. visit_consistency, 16. game_diversity

## Reference Implementation

Compare your AI's output to:
- [sql/03_features/01_player_features.sql](../sql/03_features/01_player_features.sql)
- [sql/03_features/02_player_vectors.sql](../sql/03_features/02_player_vectors.sql)
