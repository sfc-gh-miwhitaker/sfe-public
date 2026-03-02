/*==============================================================================
Create Cortex Agent via DDL
teams-agent-uni | Expires: 2026-05-01

Creates: JOKE_ASSISTANT agent with custom_tool linked to GENERATE_SAFE_JOKE UDF
Depends: 01_create_demo_objects.sql, 02_create_joke_function.sql

Reference: https://docs.snowflake.com/en/sql-reference/sql/create-agent
==============================================================================*/

USE ROLE ACCOUNTADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA TEAMS_AGENT_UNI;

-- ============================================================================
-- CREATE AGENT (SQL DDL)
-- ============================================================================

CREATE OR REPLACE AGENT JOKE_ASSISTANT
    COMMENT = 'DEMO: teams-agent-uni - AI joke bot powered by Cortex Agent (Expires: 2026-05-01)'
    PROFILE = '{"display_name": "Joke Assistant", "color": "blue"}'
    FROM SPECIFICATION
    $$
    models:
      orchestration: auto

    orchestration:
      budget:
        seconds: 30
        tokens: 8000

    instructions:
      system: >
        You are a friendly, enthusiastic AI comedian specializing in tech humor.
        When users ask for a joke, always use the joke_generator tool with their
        requested subject. Keep responses brief and professional. If no subject is
        specified, ask the user what topic they would like a joke about.
      response: >
        When delivering jokes, keep it brief: just the joke followed by an
        invitation to try a different topic. If the tool returns a safety
        filter message, politely suggest a different topic.
      orchestration: >
        Extract the subject from the user message and call the joke_generator
        tool. If the user asks for multiple jokes, generate them one at a time.
      sample_questions:
        - question: "Tell me a joke about data engineers"
        - question: "Give me a joke about SQL databases"
        - question: "Make me laugh about cloud computing"
        - question: "Tell me something funny about Snowflake"

    tools:
      - tool_spec:
          type: "custom_tool"
          name: "joke_generator"
          description: >
            Generates safe, workplace-appropriate jokes about any subject using
            Snowflake Cortex AI with content safety guardrails. Pass the desired
            joke topic as the subject parameter.

    tool_resources:
      joke_generator:
        type: "function"
        identifier: "SNOWFLAKE_EXAMPLE.TEAMS_AGENT_UNI.GENERATE_SAFE_JOKE"
        execution_environment:
          type: "warehouse"
          warehouse: "SFE_TEAMS_AGENT_UNI_WH"
    $$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SHOW AGENTS IN SCHEMA TEAMS_AGENT_UNI;
DESCRIBE AGENT JOKE_ASSISTANT;

-- ============================================================================
-- PRODUCTION TEMPLATE: Cortex Analyst Agent with Semantic View
-- ============================================================================

/*
 * Use this pattern when your customer has a semantic view and wants to expose
 * it through Teams. Replace placeholders with actual values.
 *
 * CREATE OR REPLACE AGENT SALES_ANALYST
 *     COMMENT = 'Sales call activity analyst for Teams'
 *     PROFILE = '{"display_name": "Sales Analyst", "color": "green"}'
 *     FROM SPECIFICATION
 *     $$
 *     models:
 *       orchestration: auto
 *
 *     orchestration:
 *       budget:
 *         seconds: 60
 *         tokens: 16000
 *
 *     instructions:
 *       system: >
 *         You are a revenue operations analyst. Answer questions about sales
 *         call activity using the configured semantic view. Respect RBAC and
 *         disclose data freshness timestamps when available.
 *       response: >
 *         Lead with the requested metric, then provide supporting context.
 *         Cite the semantic view name in a Sources section.
 *       sample_questions:
 *         - question: "Show quarterly call volume by manufacturer for 2024"
 *         - question: "Which distributors declined in call activity YoY?"
 *
 *     tools:
 *       - tool_spec:
 *           type: "cortex_analyst_text_to_sql"
 *           name: "sales_analyst"
 *           description: "Structured analytics over the sales call activity semantic view"
 *
 *     tool_resources:
 *       sales_analyst:
 *         semantic_view: "<DB>.<SCHEMA>.VW_CORTEX_ANALYST_SALES_CALL_ACTIVITY"
 *     $$;
 *
 * GRANT USAGE ON AGENT <DB>.<SCHEMA>.SALES_ANALYST TO ROLE <ROLE>;
 */
