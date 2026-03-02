# Usage Guide

## Streamlit Dashboard

After deployment, find the dashboard in **Snowsight > Streamlit** as "Casino Campaign Engine".

### Campaign Targeting Tab

1. Select a **Campaign Type** from the dropdown (RETENTION, ACQUISITION, UPSELL, REACTIVATION)
2. Click **Score Audience** to run the ML classification model
3. View the top 50 candidate players ranked by predicted response probability
4. Click **Generate Recommendation** to get LLM-powered campaign messaging

### Player Lookalike Tab

1. Select up to **10 seed players** from the multi-select dropdown
2. Click **Find Similar Players**
3. View the 10 most similar players with cosine similarity scores
4. Compare behavioral metrics (daily wager, session frequency, lifetime wagered, game diversity)

## Cortex Intelligence Agent

Find the agent in **Snowsight > Cortex Intelligence** as "Campaign Analytics Agent".

### Example Questions

- "Which campaign type has the highest response rate?"
- "What is the average daily wagering for Diamond tier players?"
- "How many players have not visited in the last 30 days?"
- "Show me the response rate breakdown by loyalty tier"
- "Which campaigns generated the most redemption revenue?"

## Direct SQL Queries

### Find similar players

```sql
CALL SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.FIND_SIMILAR_PLAYERS(
    PARSE_JSON('[1, 5, 12, 23, 45, 67, 89, 101, 150, 200]')
);
```

### Score campaign audience

```sql
CALL SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.SCORE_CAMPAIGN_AUDIENCE('RETENTION');
```

### Generate recommendation

```sql
SELECT GENERATE_CAMPAIGN_RECOMMENDATION(
    campaign_type, avg_wager, avg_tier, avg_frequency, top_game_type, audience_size
) AS recommendation
FROM SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.V_CAMPAIGN_RECOMMENDATIONS
WHERE campaign_type = 'UPSELL';
```

### Query player features

```sql
SELECT player_id, loyalty_tier, avg_daily_wager, session_frequency, game_diversity
FROM SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE.DT_PLAYER_FEATURES
WHERE loyalty_tier = 'Diamond'
ORDER BY avg_daily_wager DESC
LIMIT 20;
```
