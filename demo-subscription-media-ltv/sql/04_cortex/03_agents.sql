/*==============================================================================
03_agents.sql - Subscription Media LTV demo
Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-16

MEMBER_VALUE_AGENT  grounded in the governed semantic view.
RAW_DATA_AGENT      the same data through the bare semantic view, with no
                    business definitions. Used only for the side-by-side contrast.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV;

CREATE OR REPLACE AGENT MEMBER_VALUE_AGENT
  COMMENT = 'DEMO: Governed member value, churn, and ad economics analyst. All data synthetic. (Expires: 2027-01-16)'
  PROFILE = '{"display_name": "Member Value Analyst", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  orchestration:
    budget:
      seconds: 120
      tokens: 32000

  instructions:
    response: >
      You are the member value analyst for a fictional subscription media
      publisher. All data is synthetic and current as of 2026-10-31. Lead with
      the answer in one sentence, then a short table. Always name the basis of
      any value figure (gross, net, contribution, or total value) and the window
      (12 or 24 months). Say that LTV, payback, and true ROAS use the mature
      cohort: members who signed up at least 24 months before the as-of date.
      When a chart helps, produce one. A headline total must equal the sum of
      the breakdown shown with it.
    orchestration: >
      Use the MemberValue tool for every question about members, LTV, CAC,
      payback, ROAS, churn risk, churn drivers, discounts, ad revenue, audience
      segments, or the free audience. LTV means 24-month net LTV unless the user
      asks otherwise. Compare reported ROAS with true ROAS only for paid
      channels. For a one-page summary request, combine total member value,
      LTV to CAC by source, payback by platform, churn revenue at risk, and the
      best discount tier.
    sample_questions:
      - question: "What is our 24-month net LTV and LTV to CAC by acquisition source?"
      - question: "Which payment platform pays back CAC fastest?"
      - question: "Compare reported ROAS to true ROAS for our paid channels"
      - question: "How many members are at high churn risk and how much net revenue is at risk?"
      - question: "What drives churn?"
      - question: "Do deeper first-year discounts pay off?"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "MemberValue"
        description: >
          Governed member economics: 12 and 24 month gross, net, contribution,
          and total member value; CAC, LTV to CAC, payback, reported versus true
          ROAS; Snowflake ML churn scores and drivers; discount tier economics;
          logged-in audience segment ad upside; free audience ad value.
    - tool_spec:
        type: "data_to_chart"
        name: "data_to_chart"
        description: "Generates visualizations from query results"

  tool_resources:
    MemberValue:
      semantic_view: "SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_SUBSCRIPTION_MEDIA_LTV_MEMBER_VALUE"
      execution_environment:
        type: "warehouse"
        warehouse: "SFE_SUBSCRIPTION_MEDIA_LTV_WH"
  $$;

CREATE OR REPLACE AGENT RAW_DATA_AGENT
  COMMENT = 'DEMO: Same data with no business context, for contrast only. All data synthetic. (Expires: 2027-01-16)'
  PROFILE = '{"display_name": "Raw Data Assistant (no business context)", "color": "gray"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  orchestration:
    budget:
      seconds: 120
      tokens: 32000

  instructions:
    response: "Answer questions about the data."

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "RawTables"
        description: "Members, subscription payments, and acquisition spend tables."
    - tool_spec:
        type: "data_to_chart"
        name: "data_to_chart"
        description: "Generates visualizations from query results"

  tool_resources:
    RawTables:
      semantic_view: "SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_SUBSCRIPTION_MEDIA_LTV_RAW"
      execution_environment:
        type: "warehouse"
        warehouse: "SFE_SUBSCRIPTION_MEDIA_LTV_WH"
  $$;
