/*==============================================================================
  04_cortex/02_create_agent.sql
  Media Campaign Analytics — Cortex Agent
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-12

  Creates the Intelligence agent. Demo UI:
  Snowsight → AI & ML → Agents → MEDIA_CAMPAIGN_AGENT
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_MEDIA_CAMPAIGN_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS;

CREATE OR REPLACE AGENT MEDIA_CAMPAIGN_AGENT
  COMMENT = 'DEMO: Media campaign performance analytics agent — natural language over paid media KPIs. Expires: 2026-08-12'
  PROFILE = '{"display_name": "Campaign Analytics", "avatar": "chart-bar", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-4-sonnet

  orchestration:
    budget:
      seconds: 45
      tokens: 32000

  instructions:
    response: |
      You are a media analytics assistant helping agency teams understand paid media performance.
      Always show numbers in context — pair a metric with a comparison (vs last period, vs benchmark, vs budget).
      Format currency as $X,XXX. Format percentages to 1 decimal place.
      When a channel is Connected TV, note that CTR and CVR metrics are not applicable (impression-only medium).
      Keep responses concise — lead with the key number, follow with context.
    orchestration: |
      Use the CampaignAnalytics tool for all questions about campaign performance, spend, ROAS, CTR, conversions, budgets, and channel comparisons.
      Use the data_to_chart tool whenever the user asks for a chart, trend, comparison across more than 3 items, or when the result is a ranking.
    sample_questions:
      - question: "Which channel has the highest ROAS this year?"
      - question: "Which active campaigns are pacing over budget?"
      - question: "Compare click-through rates across channels this year"
      - question: "What is total spend by channel for the last 30 days?"
      - question: "Which clients have the highest ROAS this quarter?"
      - question: "How has Connected TV spend trended by quarter?"
      - question: "Break down total spend by campaign objective this year"
      - question: "Show the bottom 5 campaigns by conversion rate"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "CampaignAnalytics"
        description: |
          Converts natural language questions about paid media performance into SQL and returns results.
          Use for: spend, ROAS, CTR, CPM, CPC, CVR, conversions, impressions, budget pacing, channel comparisons,
          client rankings, campaign performance, time-period comparisons (YoY, QoQ, MoM), and any KPI trending.
          The data covers 20 clients across 5 channels (Paid Search, Social Media, Display, Connected TV,
          Streaming Audio) from January 2025 through June 2026.
    - tool_spec:
        type: "data_to_chart"
        name: "data_to_chart"
        description: "Generates bar charts, line charts, and tables from query results. Use for trends, rankings, and multi-item comparisons."

  tool_resources:
    CampaignAnalytics:
      semantic_view: "SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_MEDIA_CAMPAIGN_ANALYTICS"
      execution_environment:
        type: warehouse
        warehouse: "SFE_MEDIA_CAMPAIGN_WH"
  $$;
