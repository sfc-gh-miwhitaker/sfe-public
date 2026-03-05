# Build It Yourself: AI-Pair Programming Workshop

Learn AI-pair programming by building a production-grade campaign recommendation engine from scratch -- one prompt at a time.

**Time:** ~90 minutes | **Steps:** 7 | **Result:** ~1,200 lines of working code

## Who This Is For

SEs, developers, and anyone who wants to learn AI-pair programming by doing, not watching. You don't need prior ML experience. You do need a Snowflake account and an AI coding tool.

## What You'll Build

A casino campaign recommendation engine with ML audience targeting, vector-based player lookalike matching, an interactive Streamlit dashboard, and a Cortex Intelligence Agent for natural language analytics. The same project described in the [README](README.md) -- but you'll construct it from scratch.

## What You'll Learn

Each step teaches one AI-pair programming technique. By the end you'll have a toolkit of prompting patterns that transfer to any project.

| Step | What You Build | AI-Pair Technique |
|---|---|---|
| [1](prompts/01_data_model.md) | 4 tables + ER diagram | **Describe the problem, not the solution** |
| [2](prompts/02_sample_data.md) | 500 players, 10K activities | **Specify constraints, not code** |
| [3](prompts/03_feature_pipeline.md) | Dynamic Tables + VECTOR | **Name the Snowflake feature** |
| [4](prompts/04_vector_engine.md) | Cosine similarity procedure | **Decompose into steps** |
| [5](prompts/05_ml_classifier.md) | ML CLASSIFICATION + scoring | **Chain multiple ML patterns** |
| [6](prompts/06_streamlit_app.md) | Interactive dashboard | **Describe the UX, not the code** |
| [7](prompts/07_cortex_agent.md) | Semantic view + Intelligence Agent | **Teach the AI about your data** |

## Prerequisites

> [!IMPORTANT]
> - Snowflake account with **Enterprise** edition (required for ML CLASSIFICATION and Dynamic Tables)
> - `SYSADMIN` and `ACCOUNTADMIN` role access

- **Cortex Code CLI** ([install guide](https://docs.snowflake.com/en/user-guide/snowflake-cli/cortex-code/cortex-code-overview)) -- the primary tool for this Hands-on Lab
- Also works with: Cursor, Claude Code, or Cortex Code in Snowsight

### New to AI Pair-Programming?

> [!TIP]
> If this is your first time using an AI coding tool, complete the [Cortex Code Setup Guide](../guide-coco-setup/README.md) first (~45 minutes). It teaches the context management concepts this workshop assumes:
>
> - **How your AI tool finds its instructions** -- the guidance hierarchy, always-on context (AGENTS.md) vs on-demand skills, and why this matters
> - **What to do when the AI forgets your conventions** -- context compaction happens in long sessions and silently drops your AGENTS.md content. The setup guide teaches you to recognize and recover from it.
> - **Your first custom skill** -- a team-standards template that prevents common drift patterns (naming conventions, SQL quality rules) before they compound across steps

This workshop teaches *prompting techniques* (one per step). The setup guide teaches *context management* -- how to keep the AI aligned across a multi-step build. Both skills are essential; the setup guide is where the second one is taught.

## Before You Start

> [!WARNING]
> **Don't skip this.** Two setup tasks before Step 1.

### 1. Create the Snowflake Schema

Run this in Snowsight:

```sql
USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;
CREATE WAREHOUSE IF NOT EXISTS SFE_CAMPAIGN_ENGINE_WH
  WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;
USE SCHEMA SNOWFLAKE_EXAMPLE.CAMPAIGN_ENGINE;
USE WAREHOUSE SFE_CAMPAIGN_ENGINE_WH;
```

### 2. Create AGENTS.md

Create an `AGENTS.md` file in your project root with this content. This is your project context file -- your AI tool reads it automatically. It must exist **before** you open your first AI conversation.

```markdown
# Casino Campaign Recommendation Engine

Campaign recommendation engine for casino operators.

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: CAMPAIGN_ENGINE
- Warehouse: SFE_CAMPAIGN_ENGINE_WH

## Development Standards
- Naming: RAW_ prefix for staging tables (e.g. RAW_PLAYERS, RAW_PLAYER_ACTIVITY)
- IDs: INTEGER primary keys (Step 2 uses GENERATOR/UNIFORM for synthetic data)
- Objects: COMMENT = 'DEMO: <description> (Expires: 2026-05-01)' on all objects
- Constraints: PRIMARY KEY on every table, FOREIGN KEY where applicable
```

This is deliberately minimal -- environment plus naming standards. You'll add patterns and conventions as you build (see [The AGENTS.md Story](#the-agentsmd-story)).

## How This Works

Each step follows the same rhythm:

1. **Read** the step guide in `prompts/`
2. **Paste** the prompt into your AI tool
3. **Review** what the AI generates -- don't blindly accept
4. **Run** the SQL in Snowsight
5. **Validate** with the provided check queries
6. **Update AGENTS.md** when the step tells you to (this is how the AI learns your project over time)
7. **Move on** to the next step

### The One Anti-Pattern That Ruins Everything

> [!CAUTION]
> **"Build me a complete casino campaign engine with ML, vectors, Streamlit, and a Cortex Agent."**
>
> This mega-prompt approach fails for three reasons: the AI loses coherence across 1,200 lines, naming conventions drift between components, and you can't validate intermediate states. The whole point of this workshop is learning that 7 focused prompts with progressive context (AGENTS.md) beats one wall of text.

## The 7 Steps

### Step 1: Data Model
**Technique:** Describe the problem, not the solution

Tell the AI about your business domain -- casino players, game types, campaigns, responses -- and let it infer the right schema. You'll see how describing *use cases* (ML targeting, vector similarity) causes the AI to include columns you'd have forgotten.

Go to: [prompts/01_data_model.md](prompts/01_data_model.md)

### Step 2: Sample Data
**Technique:** Specify constraints, not code

Give the AI statistical requirements -- tier distributions, wager ranges, response rates -- and let it write the GENERATOR() logic. The distributions you specify here directly affect ML model quality in Step 5.

Go to: [prompts/02_sample_data.md](prompts/02_sample_data.md)

### Step 3: Feature Pipeline
**Technique:** Name the Snowflake feature

Explicitly say "Dynamic Tables with TARGET_LAG" and "VECTOR(FLOAT,16)". Without naming these features, the AI defaults to regular views and arrays. This is where you learn that platform-specific vocabulary in prompts is not optional.

Go to: [prompts/03_feature_pipeline.md](prompts/03_feature_pipeline.md)

### Step 4: Vector Similarity Engine
**Technique:** Decompose into steps

Break the problem into a pipeline: seed players -> average vector -> cosine similarity -> ranked results. This is also where you hit the VECTOR-in-SQL-scripting gotcha and learn why stating platform constraints saves debugging time.

Go to: [prompts/04_vector_engine.md](prompts/04_vector_engine.md)

### Step 5: ML Campaign Classifier
**Technique:** Chain multiple ML patterns

One prompt produces a training view, a CLASSIFICATION model, and a scoring procedure. This step is the payoff for maintaining AGENTS.md -- the AI reuses your exact table names, vector widths, and naming conventions without you repeating them.

Go to: [prompts/05_ml_classifier.md](prompts/05_ml_classifier.md)

### Step 6: Streamlit Dashboard
**Technique:** Describe the UX, not the code

Tell the AI what tabs, dropdowns, and charts you want. Don't specify st.tabs() or st.selectbox() -- let it choose the right widgets. The AI already knows your schema from AGENTS.md, so it wires up the queries correctly.

Go to: [prompts/06_streamlit_app.md](prompts/06_streamlit_app.md)

### Step 7: Cortex Intelligence Agent
**Technique:** Teach the AI about your data

The semantic view requires rich COMMENT metadata and correct clause ordering (FACTS before DIMENSIONS). This step teaches you that AI tools produce better Cortex artifacts when AGENTS.md includes platform-specific syntax rules.

Go to: [prompts/07_cortex_agent.md](prompts/07_cortex_agent.md)

## After the Build

### Compare Your Version

Your AI-generated code won't be identical to the reference implementation in `sql/`. That's expected -- the point is that it *works*, not that it matches character-for-character. Each step's prompt guide links to its specific reference file(s) -- compare only against those files, not the entire directory. Some directories contain files from multiple steps (e.g., `sql/04_engine/` has Step 4's lookalike procedure *and* Step 5's classifier).

```
sql/02_data/01_create_tables.sql        -- Step 1 reference
sql/02_data/02_load_sample_data.sql     -- Step 2 reference
sql/03_features/01_player_features.sql  -- Step 3 reference
sql/03_features/02_player_vectors.sql   -- Step 3 reference
sql/04_engine/01_lookalike_procedure.sql -- Step 4 reference
sql/04_engine/02_campaign_classifier.sql -- Step 5 reference
sql/04_engine/03_campaign_recommendations.sql -- Step 5 reference
```

### Deploy From Git

Once you're satisfied, the `deploy_all.sql` script deploys the reference implementation from this Git repo. See [docs/01-DEPLOYMENT.md](docs/01-DEPLOYMENT.md).

### Extend It (Act 5)

Pick a feature the AI hasn't seen and build it live. Ideas:

1. **Campaign A/B Test Tracker** -- new table, Dynamic Table for metrics, Streamlit tab
2. **VIP Alert System** -- task-based monitoring for high-value player behavior changes
3. **Churn Prediction** -- second ML model using CLASSIFICATION on days_since_last_visit
4. **Campaign ROI Calculator** -- financial metrics and CORTEX.COMPLETE summary

This is the real test of whether your AGENTS.md is complete enough for the AI to extend the project without guidance.

## The AGENTS.md Story

> [!TIP]
> The hidden curriculum of this workshop is AGENTS.md. You create it before Step 1, then update it at Steps 3, 5, and 7 as the project grows. By the end you'll have a complete project context file that any AI tool can use.

See [prompts/00_agents_evolution.md](prompts/00_agents_evolution.md) for the full evolution story.

| When | AGENTS.md Version | What the AI Now Knows |
|---|---|---|
| Before Step 1 | v1 | Project name, environment, naming conventions (RAW_ prefix, integer PKs) |
| After Step 3 | v2 | + Dynamic Tables, VECTOR(FLOAT,16), normalization patterns |
| After Step 5 | v3 | + ML CLASSIFICATION, VECTOR_COSINE_SIMILARITY, Python procs, CORTEX.COMPLETE |
| After Step 7 | v4 | + Semantic view clause order, CREATE AGENT YAML syntax, Streamlit deployment |
