-- =============================================================================
-- 03_iterate_commit_promote.sql — The Snowflake-driven lifecycle
-- Pair-programmed by SE Community + Cortex Code
--
-- This is the "develop in Snowflake" model: edit LIVE, commit it to an
-- immutable VERSION$N, alias it, and set it as the default.
--
-- THE #1 GOTCHA:  ALTER AGENT ... COMMIT DESTROYS the LIVE version.
-- After a commit there is NO live version until you explicitly recreate one
-- with ADD LIVE VERSION ... FROM LAST.  Scripts that "commit then keep editing
-- LIVE" fail for exactly this reason.
-- =============================================================================

USE SCHEMA AGENT_VERSIONING_DEMO.DEMO;
USE WAREHOUSE AGENT_VERSIONING_WH;

-- --- 1. Edit the LIVE version -------------------------------------------------
-- The new spec REPLACES the old one entirely — omitted fields are removed.
-- Here we tighten the response style and add an orchestration budget.
ALTER AGENT ORDERS_AGENT MODIFY LIVE VERSION SET SPECIFICATION =
  $$
  models:
    orchestration: auto
  orchestration:
    budget:
      seconds: 30
      tokens: 16000
  instructions:
    response: "Answer in one sentence. Lead with the number, then the region."
    orchestration: "Always call query_orders before answering. Never guess."
    sample_questions:
      - question: "What is total revenue by region?"
      - question: "Which region had the highest revenue?"
  tools:
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: query_orders
        description: "Query the ORDERS semantic view for revenue and counts."
  tool_resources:
    query_orders:
      semantic_view: AGENT_VERSIONING_DEMO.DEMO.ORDERS_SV
  $$;

-- --- 2. Commit LIVE -> new immutable VERSION$2 (LIVE is now GONE) ------------
ALTER AGENT ORDERS_AGENT COMMIT
  COMMENT = 'v2: one-sentence answers + orchestration budget';

-- Confirm: you should see VERSION$1 and VERSION$2, and NO LIVE row.
SHOW VERSIONS IN AGENT ORDERS_AGENT;

-- --- 3. Name the release: alias VERSION$2 as "production" --------------------
-- Aliases are version-level (MODIFY VERSION), not agent-level. Unquoted alias
-- names are stored uppercase; double-quote to preserve case.
ALTER AGENT ORDERS_AGENT MODIFY VERSION VERSION$2 SET ALIAS = production;

-- --- 4. Point unversioned traffic at it --------------------------------------
-- IMPORTANT: DEFAULT_VERSION accepts a system id (VERSION$N) or a shortcut
-- (FIRST / LAST) — it does NOT accept user aliases like 'production'.
ALTER AGENT ORDERS_AGENT SET DEFAULT_VERSION = 'VERSION$2';

-- Behavior change to remember: once committed versions exist, the unversioned
-- agent:run endpoint and DESCRIBE AGENT resolve to DEFAULT, not LIVE.

-- --- 5. Resume development: recreate a LIVE version --------------------------
-- Without this you cannot edit the agent again. FROM LAST bases the new LIVE on
-- the most recent committed version.
ALTER AGENT ORDERS_AGENT ADD LIVE VERSION dev FROM LAST
  COMMENT = 'Resume development from v2';

-- Final state: VERSION$1, VERSION$2 (alias production, default), LIVE (alias DEV).
SHOW VERSIONS IN AGENT ORDERS_AGENT;
