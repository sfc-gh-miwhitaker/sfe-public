# Step 6: Streamlit Dashboard

## AI-Pair Technique: Describe the UX, Not the Code

Don't tell the AI "use st.tabs() and st.selectbox()." Describe what the user should experience -- tabs, dropdowns, charts, data tables -- and let the AI pick the right Streamlit widgets. The AI already knows your schema from AGENTS.md, so it wires up the queries without you specifying table names or columns.

## Before You Start

- [ ] Step 5 complete: `SCORE_CAMPAIGN_AUDIENCE` procedure works, ML model is trained
- [ ] `FIND_SIMILAR_PLAYERS` procedure works (from Step 4)
- [ ] *(Optional)* `GENERATE_CAMPAIGN_RECOMMENDATION` function exists (from Step 5)
- [ ] AGENTS.md is updated to v3

## The Prompt

Paste this into your AI tool:

> "Create an interactive Streamlit dashboard with two tabs: Campaign Targeting (select campaign type, view ML-scored audience, generate recommendations via Cortex COMPLETE) and Player Lookalike (select seed players, find similar players with similarity scores)."

## Validate Your Work

Deploy the Streamlit app to Snowflake and test both tabs:

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;

-- If deploying from a Git repo stage:
CREATE OR REPLACE STREAMLIT CAMPAIGN_ENGINE_DASHBOARD
  FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_CAMPAIGN_ENGINE_REPO/branches/main/demo-campaign-engine/streamlit'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = SFE_CAMPAIGN_ENGINE_WH
  TITLE = 'Casino Campaign Engine';
ALTER STREAMLIT CAMPAIGN_ENGINE_DASHBOARD ADD LIVE VERSION FROM LAST;

-- If testing locally with the AI tool, you can also validate
-- the underlying queries directly:

-- Campaign Targeting query (should return scored players)
CALL SCORE_CAMPAIGN_AUDIENCE('RETENTION');

-- Lookalike query (should return 10 similar players)
CALL FIND_SIMILAR_PLAYERS(PARSE_JSON('[1, 5, 12]'));
```

Open the Streamlit app in Snowsight. Test:
1. **Campaign Targeting tab** -- Select a campaign type, click Score Audience, verify results appear
2. **Player Lookalike tab** -- Select 2-3 seed players, click Find Similar Players, verify 10 results with similarity scores

## Common Mistake

**The over-specified prompt:** "Create a Streamlit app using st.tabs for two tabs, st.selectbox for campaign type dropdown with options RETENTION, ACQUISITION, UPSELL, REACTIVATION, st.dataframe for results..."

What goes wrong: Nothing breaks -- but you're doing the AI's job. When you specify widget names, you lock the AI into your choices and prevent it from using better patterns you might not know about (like `st.status()` for progress feedback, or `st.metric()` for KPI cards). You also make the prompt three times longer for no quality improvement.

The worse version of this mistake is specifying SQL queries in the prompt. The AI already knows your table names, procedure signatures, and column names from AGENTS.md. Repeating them in the prompt risks a mismatch if you have a typo.

The fix: Describe what the *user* should experience: "select a campaign type, view scored players, generate a recommendation." Let the AI choose the implementation. You'll review the code anyway before deploying.

## What Just Happened

From a two-sentence description, the AI produced:

- **Two-tab layout** using `st.tabs()` -- Campaign Targeting and Player Lookalike
- **Pipeline visualizations** -- horizontal step indicators showing the data flow (Raw Data -> Features -> ML Score -> Rank -> LLM Copy)
- **Interactive controls** -- campaign type dropdown, multi-select for seed players, action buttons
- **Progress indicators** -- `st.status()` blocks showing what's happening during ML scoring and vector search
- **Metric cards** -- `st.metric()` for audience size, average probability, similarity scores
- **Charts** -- probability distribution histogram, loyalty tier breakdown, similarity score bar chart
- **Data tables** -- `st.dataframe()` with renamed columns for readability

Key patterns to notice:

- **Inline SQL queries** -- The app builds SQL strings with format parameters rather than calling stored procedures. This is a valid pattern for Streamlit apps that need more control over the result set.
- **Session object** -- `from snowflake.snowpark.context import get_active_session` gives the app a Snowpark session without credentials.
- **Error handling** -- try/except blocks with `st.error()` for graceful failure.

## If Something Went Wrong

**App won't deploy?** Check that the Streamlit file is named `streamlit_app.py` and lives in a `streamlit/` directory. The deployment script references this path.

**"Object does not exist" errors in the app?** The SQL queries in the Streamlit app may use unqualified table names. Ensure they include the schema prefix: `CAMPAIGN_ENGINE.DT_PLAYER_FEATURES` instead of just `DT_PLAYER_FEATURES`.

**Charts are empty?** The ML model or lookalike procedure may not be returning data. Test the underlying queries directly in Snowsight (see the Validate section) before debugging the Streamlit code.

## What Was Generated

- `streamlit/streamlit_app.py` -- Full Streamlit application with two tabs
- `streamlit/environment.yml` -- Python dependencies
- Deployment SQL for CREATE STREAMLIT

## Reference Implementation

Compare your AI's output to:
- [streamlit/streamlit_app.py](../streamlit/streamlit_app.py)
- [sql/06_streamlit/01_create_dashboard.sql](../sql/06_streamlit/01_create_dashboard.sql)
