/*==============================================================================
  04_cortex/02_create_agent.sql
  Media Campaign Analytics — Cortex Agent
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-12

  Creates the Intelligence agent with two tools:
    - CampaignAnalytics (structured KPIs via semantic view)
    - CampaignDocs (unstructured documents via Cortex Search)

  Demo UI: Snowsight → AI & ML → Agents → MEDIA_CAMPAIGN_AGENT
==============================================================================*/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_MEDIA_CAMPAIGN_WH;
USE SCHEMA SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS;

CREATE OR REPLACE AGENT MEDIA_CAMPAIGN_AGENT
  COMMENT = 'DEMO: Media campaign analytics — structured KPIs + document search in one agent. Expires: 2026-08-12'
  PROFILE = '{"display_name": "Campaign Analytics", "avatar": "chart-bar", "color": "blue"}'
  FROM SPECIFICATION
  $$

  orchestration:
    budget:
      seconds: 60
      tokens: 40000

  instructions:
    response: |
      You are a media analytics assistant helping agency teams understand paid media performance
      and campaign strategy. You have access to both quantitative data (spend, ROAS, CTR, etc.)
      and qualitative documents (campaign briefs, creative copy, channel strategies, client notes).

      For numbers: always show context — pair a metric with a comparison (vs last period, vs benchmark, vs budget).
      Format currency as $X,XXX. Format percentages to 1 decimal place.
      When a channel is Connected TV, note that CTR and CVR metrics are not applicable (impression-only medium).

      For documents: cite the document title and relevant excerpt. Summarize key points rather than dumping full text.

      For hybrid questions (e.g., "ROAS dropped — what does the brief say about the strategy?"):
      use both tools and synthesize the quantitative finding with the qualitative context.

      Keep responses concise — lead with the answer, follow with supporting detail.
    orchestration: |
      Route questions to the right tool:
      - Quantitative (spend, ROAS, CTR, impressions, conversions, budgets, rankings, trends) → CampaignAnalytics
      - Qualitative (strategy, briefs, creative copy, client context, "why", relationships, preferences) → CampaignDocs
      - Mixed ("ROAS dropped — what does the brief say?") → use BOTH tools and synthesize
      Use data_to_chart when the user asks for a chart, trend visualization, or when comparing 3+ items.
    sample_questions:
      - question: "Which channel has the highest ROAS this year?"
      - question: "What was the creative strategy for Client Alpha's social campaigns?"
      - question: "Which active campaigns are pacing over budget?"
      - question: "Show me the ad copy for Client Echo's streaming audio campaign"
      - question: "Client Bravo's ROAS dropped — what does their brief say about target audience?"
      - question: "What is total spend by channel for the last 30 days?"
      - question: "Why did we choose Connected TV for Client Charlie?"
      - question: "How has Connected TV spend trended by quarter?"

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
        type: "cortex_search"
        name: "CampaignDocs"
        description: |
          Searches campaign documents including briefs, creative copy, channel strategy rationale,
          and client relationship notes. Use for questions about WHY a campaign exists, WHAT the
          creative looks like, WHO the client is, and HOW channel decisions were made.
          Document types: Campaign Brief, Creative Copy, Channel Strategy, Client Notes.
          Covers all 20 clients with varying depth — Enterprise clients have more documentation.
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
    CampaignDocs:
      name: "SNOWFLAKE_EXAMPLE.MEDIA_CAMPAIGN_ANALYTICS.CAMPAIGN_DOCS_SEARCH"
      max_results: "5"
      title_column: "TITLE"
      id_column: "DOC_ID"
      columns_and_descriptions:
        content:
          description: "Full document text — campaign briefs, creative copy, strategy rationale, client relationship context. Rich marketing content with specific details about audiences, KPIs, messaging, and channel selection reasoning."
          type: "string"
          searchable: true
          filterable: false
        doc_type:
          description: "Document category. Valid values: Campaign Brief, Creative Copy, Channel Strategy, Client Notes"
          type: "string"
          searchable: false
          filterable: true
        client_name:
          description: "Client name the document relates to. Values: Client Alpha through Client Tango (20 clients)"
          type: "string"
          searchable: false
          filterable: true
        channel_name:
          description: "Media channel the document relates to. Valid values: Paid Search, Social Media, Display, Connected TV, Streaming Audio, N/A"
          type: "string"
          searchable: false
          filterable: true
        campaign_name:
          description: "Campaign the document is tied to, or N/A for account-level documents"
          type: "string"
          searchable: false
          filterable: true
  $$;
