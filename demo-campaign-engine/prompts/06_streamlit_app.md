# Prompt: Streamlit Dashboard

## The Prompt

"Create an interactive Streamlit dashboard with two tabs: Campaign Targeting (select campaign type, view ML-scored audience, generate recommendations via Cortex COMPLETE) and Player Lookalike (select seed players, find similar players with similarity scores)."

## What Was Generated

- `streamlit/streamlit_app.py` -- Full Streamlit application
- `sql/06_streamlit/01_create_dashboard.sql` -- Deployment script

## Key Decisions Made by AI

- Two-tab layout using st.tabs
- Campaign Targeting: dropdown for campaign type, data table of scored players, LLM recommendation
- Player Lookalike: multi-select for seed players, similarity results table
- All data from session.sql() queries (no hardcoded data)
- Page config with casino-themed icon and wide layout
