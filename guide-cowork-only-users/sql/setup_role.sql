/*==============================================================================
  COWORK ROLE SETUP — guide-cowork-admin-setup
  Run as ACCOUNTADMIN. One-time per account.
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-07-22
==============================================================================*/

USE ROLE ACCOUNTADMIN;

-- ─── 1. CoWork object (one per account) ────────────────────────────────────
-- Creates the curated agent list. Once this object exists, ONLY agents
-- explicitly added to it appear in CoWork for any user.
CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- Add the agent(s) your users will interact with.
-- Repeat this line for each agent.
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
  ADD AGENT <db>.<schema>.<agent_name>;   -- replace with actual agent path

-- ─── 2. CoWork-only role ───────────────────────────────────────────────────
CREATE ROLE IF NOT EXISTS COWORK_USER
  COMMENT = 'CoWork-only users: Cortex Agents API via Snowflake CoWork (Expires: 2026-07-22)';

-- Core privilege: Cortex Agents API only (not full Cortex feature set).
-- CORTEX_AGENT_USER ≠ CORTEX_USER — do not substitute.
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_AGENT_USER TO ROLE COWORK_USER;

-- CoWork object: lets users see the curated agent list
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
  TO ROLE COWORK_USER;

-- Agent access: all three grants are required per agent
-- Users' default role must have USAGE on the database and schema, not just the agent object
GRANT USAGE ON DATABASE <db> TO ROLE COWORK_USER;
GRANT USAGE ON SCHEMA <db>.<schema> TO ROLE COWORK_USER;
GRANT USAGE ON AGENT <db>.<schema>.<agent_name> TO ROLE COWORK_USER;   -- replace with actual agent path

-- ─── 3. Optional: tighten Cortex access account-wide ─────────────────────
-- By default CORTEX_USER is on PUBLIC, giving all users full Cortex access.
-- All three statements are needed to fully revoke. Test in non-prod first.
-- REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE PUBLIC;
-- REVOKE IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE FROM ROLE PUBLIC;
-- REVOKE USE AI FUNCTIONS ON ACCOUNT FROM ROLE PUBLIC;

-- ─── 4. Verify ────────────────────────────────────────────────────────────
SHOW GRANTS TO ROLE COWORK_USER;
SHOW SNOWFLAKE INTELLIGENCES;
