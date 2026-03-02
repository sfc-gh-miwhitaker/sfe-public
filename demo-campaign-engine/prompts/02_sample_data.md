# Prompt: Sample Data Generation

## The Prompt

"Generate realistic synthetic casino data: 500 players across 5 loyalty tiers, ~10,000 activity records spanning 6 months across slots, table games, poker, and sports book, 8 marketing campaigns of different types, and ~2,000 campaign responses with roughly 30% positive response rate. Use Snowflake GENERATOR and UNIFORM functions -- no external data loads."

## What Was Generated

- 500 players with weighted loyalty tier distribution (more Bronze, fewer Diamond)
- ~10,000 activity records with game-type-specific wagering patterns
- 8 campaigns across 4 types with realistic date ranges
- ~2,000 campaign responses with ~30% response rate

## Key Decisions Made by AI

- Loyalty tier distribution: 35% Bronze, 25% Silver, 20% Gold, 12% Platinum, 8% Diamond
- Higher-tier players have higher average wagers (correlated with tier)
- Slot sessions are shorter and lower-wager; table games are longer and higher-wager
- Weekend sessions are more frequent than weekday
- Response rates correlate with loyalty tier (Diamond responds more)
