# Usage Guide

## Streamlit Dashboard

Navigate to **Projects > Streamlit > GAMING_PLAYER_ANALYTICS_APP** in Snowsight.

### Page 1: Player Cohorts

AI-classified player segments based on spending, engagement, and recency. Shows:
- Cohort summary metrics (count, avg LTV, stickiness)
- Cohort-by-platform breakdown
- Cohort-by-acquisition-source breakdown

### Page 2: Engagement Trends

Daily active players, session counts, and revenue over time:
- Latest-day DAU, sessions, and revenue KPIs
- 30-day DAU trend by cohort (area chart)
- 30-day revenue trend by cohort (bar chart)
- Average session length comparison

### Page 3: Churn Risk

Players at risk of leaving, segmented by value and recency:
- Churn risk distribution (High / Medium / Low)
- Value-risk matrix (4 segments)
- High-value at-risk player list (actionable retention targets)
- Churn risk by cohort cross-tab

### Page 4: Feedback Analysis

AI-enriched player feedback with sentiment, topic, and urgency:
- Sentiment distribution (Positive / Negative / Neutral)
- Topic-by-sentiment breakdown (filterable by source)
- High-urgency feedback list
- Feature request extraction
- Recent feedback browser

## Intelligence Agent

Navigate to **AI & ML > Snowflake Intelligence** in Snowsight.

Find **Pixel Forge Player Analyst** and try these questions:

- "Which player cohort has the highest churn risk?"
- "What's the average session length trend for whales?"
- "Show me the top 10 players by lifetime spend who haven't played in 30 days"
- "What are the most common negative feedback topics?"
- "How does daily revenue compare across cohorts this month?"
- "Which acquisition source produces the most whales?"

## Direct SQL Exploration

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.GAMING_PLAYER_ANALYTICS;

-- Cohort distribution
SELECT ai_player_cohort, COUNT(*) AS players, ROUND(AVG(total_spent), 2) AS avg_ltv
FROM DIM_PLAYERS GROUP BY ai_player_cohort ORDER BY avg_ltv DESC;

-- High-value at-risk players
SELECT username, lifetime_spend, days_since_last_active, churn_risk_level
FROM FACT_PLAYER_LIFETIME f JOIN DIM_PLAYERS p ON f.player_id = p.player_id
WHERE value_risk_segment = 'High Value At Risk' ORDER BY lifetime_spend DESC;

-- Negative feedback topics
SELECT feedback_topic, COUNT(*) AS count
FROM DT_FEEDBACK_ENRICHED WHERE ai_sentiment = 'Negative'
GROUP BY feedback_topic ORDER BY count DESC;
```
