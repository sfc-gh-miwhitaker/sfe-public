-- =============================================================================
-- 99_teardown.sql — Remove everything this example created
-- Pair-programmed by SE Community + Cortex Code
--
-- Safe to run repeatedly. Order matters: drop the agent and Git objects before
-- the schema/database that contain them.
-- =============================================================================

USE SCHEMA AGENT_VERSIONING_DEMO.DEMO;

-- Agent (drops all of its versions with it)
DROP AGENT IF EXISTS ORDERS_AGENT;
DROP AGENT IF EXISTS ORDERS_AGENT_FROM_GIT;

-- Git integration objects (created in 04; harmless if they were never made)
DROP GIT REPOSITORY IF EXISTS agent_repo;
DROP SECRET IF EXISTS github_pat;
DROP INTEGRATION IF EXISTS git_agent_api;

-- Data objects
DROP SEMANTIC VIEW IF EXISTS ORDERS_SV;
DROP TABLE IF EXISTS ORDERS;

-- Containers
DROP SCHEMA IF EXISTS AGENT_VERSIONING_DEMO.DEMO;
DROP DATABASE IF EXISTS AGENT_VERSIONING_DEMO;
DROP WAREHOUSE IF EXISTS AGENT_VERSIONING_WH;
