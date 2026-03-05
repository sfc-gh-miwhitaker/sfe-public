# Step 2: Sample Data

## AI-Pair Technique: Specify Constraints, Not Code

Don't write the GENERATOR() logic yourself. Tell the AI *what the data should look like* -- distributions, correlations, ranges, volumes -- and let it figure out the SQL. The statistical properties you specify here directly affect ML model quality in Step 5.

## Before You Start

- [ ] Step 1 complete: 4 tables exist in `CAMPAIGN_ENGINE` schema
- [ ] Tables are empty (no data loaded yet)

## The Prompt

Paste this into your AI tool:

> "Generate realistic synthetic casino data: 500 players across 5 loyalty tiers, ~10,000 activity records spanning 6 months across slots, table games, poker, and sports book, 8 marketing campaigns of different types, and ~2,000 campaign responses with roughly 30% positive response rate. Use Snowflake GENERATOR and UNIFORM functions -- no external data loads."

## Validate Your Work

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;

-- Row counts
SELECT 'RAW_PLAYERS' AS tbl, COUNT(*) AS counted_rows FROM RAW_PLAYERS
UNION ALL
SELECT 'RAW_PLAYER_ACTIVITY', COUNT(*) FROM RAW_PLAYER_ACTIVITY
UNION ALL
SELECT 'RAW_CAMPAIGNS', COUNT(*) FROM RAW_CAMPAIGNS
UNION ALL
SELECT 'RAW_CAMPAIGN_RESPONSES', COUNT(*) FROM RAW_CAMPAIGN_RESPONSES;

-- Loyalty tier distribution (should NOT be equal 20% each)
SELECT loyalty_tier, COUNT(*) AS cnt,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM RAW_PLAYERS
GROUP BY loyalty_tier
ORDER BY cnt DESC;

-- Response rate (should be roughly 30%)
SELECT
    COUNT_IF(responded) AS positive,
    COUNT(*) AS total,
    ROUND(COUNT_IF(responded) * 100.0 / COUNT(*), 1) AS response_rate_pct
FROM RAW_CAMPAIGN_RESPONSES;
```

Expected: ~500 players, ~10K activities, 8 campaigns, ~2K responses. Loyalty tiers should be skewed (more Bronze, fewer Diamond). Response rate should be near 30%.

## Common Mistake

**The lazy prompt:** "Generate 500 rows of test data" or "Fill the tables with sample data."

What goes wrong: Without distribution guidance, the AI generates equal loyalty tiers (100 per tier) and uniform wager amounts. Every player looks the same. When you train the ML model in Step 5, it has no signal to learn from -- all tiers respond at the same rate, all wagers are in the same range. The classifier either predicts everyone as positive or everyone as negative.

The fix: Specify the statistical properties that matter for downstream ML:
- **Weighted tier distribution** ("35% Bronze, 8% Diamond") creates class imbalance the model can learn from
- **Game-type-specific wager ranges** ("table games are higher-wager than slots") gives behavioral features real variance
- **Correlated response rates** ("Diamond responds more") gives the classifier a learnable pattern
- **~30% positive rate** prevents majority-class bias

You don't need to write the SQL -- you need to describe what realistic data looks like.

## What Just Happened

The AI made several decisions that improve ML training quality:

- **Weighted tier distribution** -- 35% Bronze, 25% Silver, 20% Gold, 12% Platinum, 8% Diamond mirrors real loyalty program pyramids
- **Game-type-specific wager ranges** -- Slots: $10-500, Table games: $50-5000, Poker: $100-3000. This gives the feature pipeline (Step 3) real signal to work with.
- **Weekend frequency bias** -- More sessions on weekends, creating a useful `weekend_pct` feature
- **INSERT OVERWRITE** -- Idempotent. Re-running doesn't double the data.
- **No external files** -- Everything uses GENERATOR() and UNIFORM(), deployable in any Snowflake account

## If Something Went Wrong

**Data looks too uniform?** Follow up with: "Make the data more realistic -- higher loyalty tiers should have higher average wagers, and Diamond players should respond to campaigns at a higher rate than Bronze."

**Response rate way off?** If it's 50% or 10% instead of ~30%, follow up with: "Adjust the response rate to roughly 30% positive. Use `UNIFORM(1, 100, RANDOM()) <= 30` as the responded threshold."

**Campaign dates in the future?** Follow up with: "All campaign dates should be in the past, spanning the last 6 months from CURRENT_DATE."

## What Was Generated

- 500 players with weighted loyalty tier distribution (more Bronze, fewer Diamond)
- ~10,000 activity records with game-type-specific wagering patterns
- 8 campaigns across 4 types with realistic date ranges
- ~2,000 campaign responses with ~30% response rate

## Reference Implementation

Compare your AI's output to [sql/02_data/02_load_sample_data.sql](../sql/02_data/02_load_sample_data.sql).
