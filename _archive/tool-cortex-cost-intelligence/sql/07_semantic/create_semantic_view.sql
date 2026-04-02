USE ROLE ACCOUNTADMIN;
USE SCHEMA SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE;

CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
    'SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE.SV_CORTEX_COST_INTELLIGENCE',
    $$
name: cortex_cost_intelligence
description: >
  Cortex Cost Intelligence semantic view for natural-language cost analysis
  across all Snowflake Cortex AI services.

tables:
  - name: cortex_costs
    description: >
      Unified Cortex AI cost data. Each row represents usage from a single
      service on a given day, optionally attributed to a user, model, and function.
    base_table:
      database: SNOWFLAKE_EXAMPLE
      schema: CORTEX_COST_INTELLIGENCE
      table: V_COST_INTELLIGENCE_FLAT
    dimensions:
      - name: service_type
        synonyms: ["service", "cortex service", "AI service", "product"]
        description: "The Cortex AI service (Cortex Analyst, AI Functions, Agent, Intelligence, Search, etc.)"
        expr: service_type
        data_type: VARCHAR
        is_enum: true
      - name: user_name
        synonyms: ["user", "username", "who", "person"]
        description: "The Snowflake user who incurred the cost. SYSTEM for non-user-attributed usage."
        expr: user_name
        data_type: VARCHAR
      - name: model_name
        synonyms: ["model", "LLM", "AI model"]
        description: "The AI model used (e.g. llama3.3-70b, claude-4-sonnet, mistral-large2)."
        expr: model_name
        data_type: VARCHAR
      - name: function_name
        synonyms: ["function", "operation", "agent name", "service name"]
        description: "The specific function, agent, or service instance name."
        expr: function_name
        data_type: VARCHAR
      - name: role_name
        synonyms: ["role"]
        description: "The Snowflake role used. Only populated for Cortex AI Functions."
        expr: role_name
        data_type: VARCHAR
      - name: billing_type
        synonyms: ["billing model", "pricing model", "charge type"]
        description: "How this service is billed. CREDITS for most services; USD for Cortex REST API (token-based pricing from Consumption Table 6c)."
        expr: billing_type
        data_type: VARCHAR
        is_enum: true
      - name: day_of_week
        synonyms: ["weekday", "day name"]
        description: "Day of the week (Mon, Tue, etc.)"
        expr: day_of_week
        data_type: VARCHAR
        is_enum: true
    time_dimensions:
      - name: usage_date
        synonyms: ["date", "day", "when"]
        description: "Calendar date of the usage."
        expr: usage_date
        data_type: DATE
      - name: usage_week
        synonyms: ["week", "weekly"]
        description: "Start of the ISO week for the usage."
        expr: usage_week
        data_type: DATE
      - name: usage_month
        synonyms: ["month", "monthly"]
        description: "First day of the month for the usage."
        expr: usage_month
        data_type: DATE
    facts:
      - name: credits
        synonyms: ["credit usage", "credit consumption"]
        description: "Snowflake credits consumed. NULL for Cortex REST API (billed in USD per token, not credits)."
        expr: credits
        data_type: NUMBER
      - name: operations
        synonyms: ["requests", "calls", "queries", "invocations"]
        description: "Number of operations."
        expr: operations
        data_type: NUMBER
      - name: tokens_total
        synonyms: ["tokens", "token count"]
        description: "Total tokens processed."
        expr: tokens_total
        data_type: NUMBER
      - name: cost_usd
        synonyms: ["cost", "dollars", "spend", "USD", "money"]
        description: "Estimated USD cost. Most services: credits × credit_cost_usd. REST API: token counts × per-model USD rates (Consumption Table 6c)."
        expr: cost_usd
        data_type: NUMBER
      - name: mtd_credits
        description: "Month-to-date cumulative credits for the service type."
        expr: mtd_credits
        data_type: NUMBER
      - name: mtd_cost_usd
        synonyms: ["month to date cost", "MTD spend"]
        description: "Month-to-date cumulative USD cost for the service type."
        expr: mtd_cost_usd
        data_type: NUMBER
    metrics:
      - name: total_credits
        synonyms: ["total credit usage", "total consumption"]
        description: "Sum of all credits consumed."
        expr: SUM(credits)
      - name: total_cost_usd
        synonyms: ["total cost", "total spend", "total dollars"]
        description: "Sum of all estimated USD costs."
        expr: SUM(cost_usd)
      - name: total_operations
        synonyms: ["total requests", "total calls"]
        description: "Total operations across all services."
        expr: SUM(operations)
      - name: total_tokens
        synonyms: ["total token usage"]
        description: "Total tokens processed."
        expr: SUM(tokens_total)
      - name: unique_users
        synonyms: ["number of users", "user count", "active users"]
        description: "Count of distinct users."
        expr: COUNT(DISTINCT user_name)
      - name: avg_credits_per_operation
        synonyms: ["cost per request", "unit cost"]
        description: "Average credits per operation."
        expr: "CASE WHEN SUM(operations) > 0 THEN SUM(credits) / SUM(operations) ELSE 0 END"
      - name: avg_cost_per_user
        synonyms: ["cost per user", "spend per user"]
        description: "Average USD cost per unique user."
        expr: "CASE WHEN COUNT(DISTINCT user_name) > 0 THEN SUM(cost_usd) / COUNT(DISTINCT user_name) ELSE 0 END"
    filters:
      - name: last_7_days
        description: "Last 7 days of usage."
        expr: "usage_date >= DATEADD('day', -7, CURRENT_DATE())"
      - name: last_30_days
        description: "Last 30 days of usage."
        expr: "usage_date >= DATEADD('day', -30, CURRENT_DATE())"
      - name: current_month
        description: "Current calendar month."
        expr: "usage_month = DATE_TRUNC('month', CURRENT_DATE())"
      - name: previous_month
        description: "Previous calendar month."
        expr: "usage_month = DATE_TRUNC('month', DATEADD('month', -1, CURRENT_DATE()))"
      - name: non_system_users
        description: "Exclude SYSTEM rows."
        expr: "user_name != 'SYSTEM'"

verified_queries:
  - name: total_spend_last_month
    question: "What was our total Cortex spend last month?"
    use_as_onboarding_question: true
    sql: |
      SELECT SUM(cost_usd) AS total_cost_usd, SUM(credits) AS total_credits
      FROM cortex_cost_intelligence
      WHERE usage_month = DATE_TRUNC('month', DATEADD('month', -1, CURRENT_DATE()))
  - name: top_spenders_this_month
    question: "Who are the top 10 spenders this month?"
    use_as_onboarding_question: true
    sql: |
      SELECT user_name, SUM(cost_usd) AS total_cost_usd, SUM(credits) AS total_credits, SUM(operations) AS total_operations
      FROM cortex_cost_intelligence
      WHERE usage_month = DATE_TRUNC('month', CURRENT_DATE()) AND user_name != 'SYSTEM'
      GROUP BY user_name ORDER BY total_cost_usd DESC LIMIT 10
  - name: cost_by_service
    question: "How much does each Cortex service cost?"
    use_as_onboarding_question: true
    sql: |
      SELECT service_type, SUM(cost_usd) AS total_cost_usd, SUM(credits) AS total_credits, COUNT(DISTINCT user_name) AS unique_users
      FROM cortex_cost_intelligence
      WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
      GROUP BY service_type ORDER BY total_cost_usd DESC
  - name: daily_agent_cost
    question: "Show me daily Cortex Agent costs for the last 30 days"
    sql: |
      SELECT usage_date, SUM(cost_usd) AS daily_cost_usd, SUM(credits) AS daily_credits
      FROM cortex_cost_intelligence
      WHERE service_type = 'Cortex Agent' AND usage_date >= DATEADD('day', -30, CURRENT_DATE())
      GROUP BY usage_date ORDER BY usage_date
  - name: cheapest_model
    question: "What is the cheapest model for COMPLETE?"
    use_as_onboarding_question: true
    sql: |
      SELECT model_name, SUM(credits) AS total_credits, SUM(operations) AS total_ops,
        CASE WHEN SUM(operations) > 0 THEN SUM(credits)/SUM(operations) ELSE 0 END AS credits_per_op
      FROM cortex_cost_intelligence
      WHERE function_name = 'COMPLETE' AND model_name IS NOT NULL AND usage_date >= DATEADD('day', -30, CURRENT_DATE())
      GROUP BY model_name ORDER BY credits_per_op ASC
  - name: weekly_trend
    question: "What is the weekly spend trend for the last 3 months?"
    use_as_onboarding_question: true
    sql: |
      SELECT usage_week, service_type, SUM(credits) AS weekly_credits, SUM(cost_usd) AS weekly_cost_usd
      FROM cortex_cost_intelligence
      WHERE usage_date >= DATEADD('month', -3, CURRENT_DATE())
      GROUP BY usage_week, service_type ORDER BY usage_week, service_type
    $$,
    TRUE
);

GRANT SELECT ON SEMANTIC VIEW SNOWFLAKE_EXAMPLE.CORTEX_COST_INTELLIGENCE.SV_CORTEX_COST_INTELLIGENCE TO ROLE PUBLIC;
