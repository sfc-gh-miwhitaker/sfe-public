-- =============================================================================
-- 02_create_agent.sql — Create the agent (this is where versioning begins)
-- Pair-programmed by SE Community + Cortex Code
--
-- KEY IDEA: When agent versioning is enabled, a single CREATE AGENT produces
-- TWO things at once:
--   * VERSION$1  — an immutable, committed snapshot
--   * LIVE       — a mutable working copy you edit during development
--
-- Prereq: agent versioning enabled for the account. If you get
--   "Unsupported feature 'AGENT VERSIONING'", ask your account admin to enable it.
-- =============================================================================

USE SCHEMA AGENT_VERSIONING_DEMO.DEMO;
USE WAREHOUSE AGENT_VERSIONING_WH;

-- --- Create the agent from an inline specification ---------------------------
-- orchestration: auto  -> let Snowflake pick an available model (portable across
-- regions). Pin a model name only if you have a specific reason to.
CREATE OR REPLACE AGENT ORDERS_AGENT
  COMMENT = 'Answers revenue questions over the ORDERS semantic view'
  PROFILE = '{"display_name": "Orders Analyst"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  instructions:
    response: "Answer concisely. Always state the region and the currency."
    orchestration: "Use the query_orders tool to look up figures before answering."
    sample_questions:
      - question: "What is total revenue by region?"
  tools:
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: query_orders
        description: "Query the ORDERS semantic view for revenue and counts."
  tool_resources:
    query_orders:
      semantic_view: AGENT_VERSIONING_DEMO.DEMO.ORDERS_SV
  $$;

-- --- Prove that dual-version creation happened -------------------------------
-- Expect two rows: VERSION$1 (committed) and LIVE (mutable).
SHOW VERSIONS IN AGENT ORDERS_AGENT;

-- DESCRIBE shows the resolved spec. With only VERSION$1 + LIVE, this is the
-- spec you just created.
DESCRIBE AGENT ORDERS_AGENT;
