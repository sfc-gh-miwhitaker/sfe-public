# Deployment Guide

## Prerequisites

- Snowflake account with **Enterprise** edition or higher (required for ML CLASSIFICATION and Dynamic Tables)
- `SYSADMIN` role access
- `ACCOUNTADMIN` role access (required for `CREATE API INTEGRATION`)

## Quick Deploy

1. Open **Snowsight** in your browser
2. Create a new SQL worksheet
3. Paste the entire contents of `deploy_all.sql`
4. Click **Run All**

**Expected runtime:** ~3-5 minutes (ML model training is the longest step)

## What Gets Created

| Object | Type | Description |
|---|---|---|
| `SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE` | Schema | Project schema |
| `SFE_CAMPAIGN_ENGINE_WH` | Warehouse | X-SMALL, auto-suspend 60s |
| `RAW_PLAYERS` | Table | 500 synthetic player records |
| `RAW_PLAYER_ACTIVITY` | Table | ~10,000 game session records |
| `RAW_CAMPAIGNS` | Table | 8 campaign definitions |
| `RAW_CAMPAIGN_RESPONSES` | Table | ~2,000 historical response records |
| `DT_PLAYER_FEATURES` | Dynamic Table | 16 behavioral features per player |
| `DT_PLAYER_VECTORS` | Dynamic Table | VECTOR(FLOAT,16) behavior embeddings |
| `V_CLASSIFICATION_TRAINING` | View | ML training dataset |
| `CAMPAIGN_RESPONSE_MODEL` | ML Model | CLASSIFICATION for response prediction |
| `FIND_SIMILAR_PLAYERS` | Procedure | Vector cosine similarity lookalike |
| `SCORE_CAMPAIGN_AUDIENCE` | Procedure | ML-based audience scoring |
| `GENERATE_CAMPAIGN_RECOMMENDATION` | Function | LLM campaign copy generator |
| `V_CAMPAIGN_RECOMMENDATIONS` | View | Audience profiles for LLM |
| `SV_CAMPAIGN_ENGINE_ANALYTICS` | Semantic View | In SEMANTIC_MODELS schema |
| `CAMPAIGN_ANALYTICS_AGENT` | Cortex Agent | Natural language analytics |
| `CAMPAIGN_ENGINE_DASHBOARD` | Streamlit | Interactive dashboard |

## Troubleshooting

| Issue | Solution |
|---|---|
| "API integration not found" | Ensure `deploy_all.sql` ran with ACCOUNTADMIN role |
| ML model training fails | Ensure Enterprise edition; check warehouse size |
| Dynamic Tables not refreshing | Check `SHOW DYNAMIC TABLES` for status |
| Streamlit not loading | Visit the app in Snowsight with the owning role |
