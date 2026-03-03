# Step 5: ML Campaign Classifier

## AI-Pair Technique: Chain Multiple ML Patterns

One prompt can produce multiple connected artifacts -- a training view, a model, and a scoring procedure -- as long as you describe the full pipeline. The AI understands that training needs a view, the model needs SYSTEM$REFERENCE, and scoring needs to call MODEL!PREDICT. This is where maintaining AGENTS.md pays off: the AI reuses your exact table names and feature columns without you repeating them.

## Before You Start

- [ ] Step 4 complete: `FIND_SIMILAR_PLAYERS` procedure works
- [ ] `DT_PLAYER_FEATURES` has ~500 rows with 16 behavioral metrics
- [ ] `RAW_CAMPAIGN_RESPONSES` has ~2K rows with `responded` BOOLEAN
- [ ] **AGENTS.md is updated to v2** (from Step 3) -- this is critical

### Why AGENTS.md Matters Here

If you skipped the AGENTS.md update at Step 3, this is where it hurts. Without context about `DT_PLAYER_FEATURES` and its 16 columns, the AI may:
- Re-derive features from `RAW_PLAYER_ACTIVITY` instead of joining to the existing Dynamic Table
- Use different column names than what Step 3 created
- Choose a different number of features (8 or 32 instead of 16)

The fix is simple: make sure your AGENTS.md includes the Key Patterns section from Step 3 before you continue.

## The Prompt

Paste this into your AI tool:

> "Train a SNOWFLAKE.ML.CLASSIFICATION model on historical campaign responses joined to player features. Create a procedure that scores all players for a given campaign type and returns the top candidates ranked by predicted response probability."

## What to Tell the AI (AGENTS.md v3)

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
- VECTOR_COSINE_SIMILARITY for lookalike player matching
- SNOWFLAKE.ML.CLASSIFICATION for campaign audience scoring
- SNOWFLAKE.CORTEX.COMPLETE for campaign recommendation generation
- Python stored procedures for vector aggregation logic (VECTOR not supported in SQL scripting)
- ML models trained on views using SYSTEM$REFERENCE

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: One-command deployment via deploy_all.sql
- Naming: SFE_ prefix for account-level objects only; project objects scoped by schema
```

Key additions: VECTOR_COSINE_SIMILARITY, ML CLASSIFICATION, CORTEX.COMPLETE, Python proc constraint, SYSTEM$REFERENCE, and naming conventions. The AI now has enough context to build any new feature in this project consistently.

## Validate Your Work

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;

-- Training view should join responses to features
SELECT COUNT(*) AS training_rows FROM V_CLASSIFICATION_TRAINING;

-- ML model should exist
SHOW SNOWFLAKE.ML.CLASSIFICATION LIKE 'CAMPAIGN_RESPONSE_MODEL' IN SCHEMA CAMPAIGN_ENGINE;

-- Score an audience (this is the real test)
CALL SCORE_CAMPAIGN_AUDIENCE('RETENTION');

-- Also add an LLM recommendation function and view
-- (the prompt may or may not generate this -- it's a bonus)
SELECT *
FROM V_CAMPAIGN_RECOMMENDATIONS
LIMIT 4;
```

Expected: Training view has ~2K rows. Model exists. Scoring returns ranked players with response probabilities. If the AI also generated `GENERATE_CAMPAIGN_RECOMMENDATION` and `V_CAMPAIGN_RECOMMENDATIONS`, that's a bonus -- if not, you can prompt for it: "Use SNOWFLAKE.CORTEX.COMPLETE to generate campaign messaging and channel strategy recommendations given an audience profile."

## Common Mistake

**Skipping the AGENTS.md update** (context starvation)

What goes wrong: Without AGENTS.md v2, the AI doesn't know about `DT_PLAYER_FEATURES` or the 16 behavioral columns. It may:
- Create its own feature query from raw tables (duplicating Step 3)
- Use different column names like `daily_avg_wager` instead of `avg_daily_wager`
- Choose a different feature set entirely, breaking the scoring procedure

This is the inflection point of the workshop. Steps 1-4 work fine without AGENTS.md because each step is self-contained. But Step 5 must reference objects from Steps 1 and 3 simultaneously. AGENTS.md is what makes the AI aware of your full project state.

The fix: Update AGENTS.md to v2 (from Step 3) before running this prompt. The AI should reference `DT_PLAYER_FEATURES` by name and use all 16 column names exactly.

## What Just Happened

The AI produced three connected artifacts from one prompt:

1. **V_CLASSIFICATION_TRAINING** -- A view joining `RAW_CAMPAIGN_RESPONSES` to `DT_PLAYER_FEATURES` and `RAW_CAMPAIGNS`. All 16 behavioral features plus `campaign_type` become input features; `responded` (BOOLEAN) is the target.
2. **CAMPAIGN_RESPONSE_MODEL** -- `SNOWFLAKE.ML.CLASSIFICATION` trained via `SYSTEM$REFERENCE('VIEW', ...)`. This syntax is required -- you can't pass a table name as a string.
3. **SCORE_CAMPAIGN_AUDIENCE** -- A procedure that scores every player using `MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(...))` and returns the top candidates sorted by predicted probability.

Key patterns to notice:

- **SYSTEM$REFERENCE** -- ML model training requires this wrapper around the view name. If the AI used a string literal, the model creation will fail.
- **OBJECT_CONSTRUCT for prediction** -- Each feature must be passed as a named key-value pair. Missing a feature causes a prediction error, not a training error -- a hard-to-debug failure.
- **Boolean prediction output** -- `prediction:class::BOOLEAN` and `prediction:probability:True::FLOAT` are the specific JSON paths for CLASSIFICATION results.

## If Something Went Wrong

**Model training hangs or fails?** ML CLASSIFICATION requires Enterprise edition. Also check that `V_CLASSIFICATION_TRAINING` returns rows: `SELECT COUNT(*) FROM V_CLASSIFICATION_TRAINING;` -- if 0, the joins aren't matching (likely a column name mismatch between your tables and Dynamic Tables).

**SYSTEM$REFERENCE error?** The AI may have written `INPUT_DATA => 'V_CLASSIFICATION_TRAINING'` (a string). It must be `INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_CLASSIFICATION_TRAINING')`.

**Scoring returns 0 rows?** The WHERE clause filters for `prediction:class::BOOLEAN = TRUE`. If the model predicts all FALSE, lower the threshold or remove the filter to see all predictions.

## What Was Generated

- Training view joining campaign responses to player features
- SNOWFLAKE.ML.CLASSIFICATION model creation
- SCORE_CAMPAIGN_AUDIENCE stored procedure for on-demand scoring
- *(Optionally)* GENERATE_CAMPAIGN_RECOMMENDATION function using CORTEX.COMPLETE
- *(Optionally)* V_CAMPAIGN_RECOMMENDATIONS view with audience profiles

## Reference Implementation

Compare your AI's output to:
- [sql/04_engine/02_campaign_classifier.sql](../sql/04_engine/02_campaign_classifier.sql)
- [sql/04_engine/03_campaign_recommendations.sql](../sql/04_engine/03_campaign_recommendations.sql)
