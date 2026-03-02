# Demo Script: Casino Campaign Engine

Presenter playbook for the five-act AI-pair programming showcase.

**Total runtime:** ~27 minutes (5 + 5 + 7 + 5 + 5)

## Before You Start

1. Open Cursor (or Cortex Code in Snowsight) with this project
2. Have Snowsight open in a browser tab
3. Ensure `SNOWFLAKE_EXAMPLE` database exists (run `shared/sql/00_shared_setup.sql` if not)
4. Clear terminal history for a clean starting point

## Act 1: "Describe the Problem" (~5 min)

**Setup:** Show the blank project scaffold.

**Narrative:** "I'm a casino operator. I have player activity data -- slot sessions, table game visits, loyalty tiers. I need two things: identify which players to target for a campaign, and given a set of my best players, find 10 more just like them."

**What to show:**
- The English description generates a complete data model
- Four tables with correct column types and relationships
- A Mermaid ER diagram auto-generated from the description

**Talking points:**
- "Notice it chose the right data types -- BOOLEAN for responded, NUMBER for amounts"
- "The ER diagram came from the same description, not drawn separately"

## Act 2: "Build the Pipeline" (~5 min)

**Prompt:** "Create a feature engineering pipeline that computes 16 behavioral metrics per player and stores them as a VECTOR(FLOAT,16) for similarity search."

**What to show:**
- Dynamic Tables with TARGET_LAG for automatic refresh
- Min-max normalization math handled correctly
- VECTOR data type construction from ARRAY_CONSTRUCT

**Talking points:**
- "Dynamic Tables mean this pipeline re-runs automatically -- no scheduled tasks to manage"
- "The AI handled all the normalization math in one pass"

## Act 3: "Add Intelligence" (~7 min)

**Prompt:** "Add a lookalike finder that uses cosine similarity to find 10 players similar to a given set, and a campaign audience scorer using ML classification."

**What to show:**
- Python stored procedure for vector similarity search
- SNOWFLAKE.ML.CLASSIFICATION model training
- SNOWFLAKE.CORTEX.COMPLETE for campaign copy generation

**Talking points:**
- "Three distinct ML patterns from three sentences"
- "The Python proc uses Snowpark -- VECTOR types need Python, not SQL scripting"
- "Classification trains on historical campaign responses to predict future behavior"

## Act 4: "Build the Interface" (~5 min)

**Prompt:** "Create an interactive dashboard with campaign targeting and player lookalike tabs, plus a Cortex Intelligence Agent for natural-language queries."

**What to show:**
- Full Streamlit app with two functional tabs
- Semantic view with dimensions, facts, and metrics
- Intelligence Agent answering a natural-language question

**Talking points:**
- "A working UI from a one-line description"
- "The semantic view teaches the Agent about our data model"

## Act 5: "Extend It Live" (~5-7 min)

**Setup:** Ask the audience what feature to add.

**Fallback options if audience is quiet:**
1. **Campaign A/B Test Tracker** -- new table, Dynamic Table for metrics, Streamlit tab
2. **VIP Alert System** -- task-based monitoring for high-value player behavior changes
3. **Churn Prediction** -- second ML model using CLASSIFICATION on days_since_last_visit
4. **Campaign ROI Calculator** -- financial metrics and CORTEX.COMPLETE summary

**Talking points:**
- "This is live, unscripted -- the AI hasn't seen this request before"
- "Notice how AGENTS.md gives the AI context about our naming conventions and patterns"

## Closing (~2 min)

Show `git diff act-0-blank..act-4-interface` to display the full scope of what was built.

Key messages:
- "~1,200 lines of production-grade code from five prompts"
- "Every file has a header crediting the prompt that generated it"
- "AGENTS.md evolved from 5 lines to full project context -- the AI learned as we built"
- "You can take this project home, deploy it in your account, and extend it"
