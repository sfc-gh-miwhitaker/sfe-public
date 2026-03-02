# Prompt: Feature Engineering Pipeline

## The Prompt

"Create a feature engineering pipeline that computes 16 behavioral metrics per player and stores them as a VECTOR(FLOAT,16) for similarity search. Use Dynamic Tables with TARGET_LAG for automatic refresh. Normalize all features to 0-1 range using min-max scaling."

## What Was Generated

- `DT_PLAYER_FEATURES` -- Dynamic Table computing 16 raw behavioral metrics
- `DT_PLAYER_VECTORS` -- Dynamic Table normalizing features and constructing VECTOR(FLOAT,16)

## The 16 Features

1. avg_daily_wager, 2. session_frequency, 3. avg_session_duration, 4. win_rate,
5. slots_pct, 6. table_pct, 7. poker_pct, 8. sportsbook_pct,
9. weekend_pct, 10. mobile_pct, 11. days_since_last_visit, 12. lifetime_wagered,
13. loyalty_tier_num, 14. avg_bet_size, 15. visit_consistency, 16. game_diversity

## Key Decisions Made by AI

- Used Dynamic Tables instead of Stream+Task for declarative pipeline
- Min-max normalization across all players for each feature
- VECTOR(FLOAT, 16) constructed via ARRAY_CONSTRUCT()::VECTOR(FLOAT, 16)
- TARGET_LAG = '1 hour' balances freshness with compute cost
- NULLIF/COALESCE guards against division by zero
