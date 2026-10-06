/* Cross-platform AI spend consolidation — teardown
   Pair-programmed by SE Community + Cortex Code
   Expires: 2027-03-10

   Removes everything sql/01 through sql/09 created, in reverse dependency order.

   READ THIS BEFORE RUNNING:

   1. THE RAW LANDING TABLE IS NOT RECOVERABLE FROM THE VENDOR.
      Vendor admin APIs have short retention windows. Dropping AI_SPEND destroys
      history you cannot re-pull. If there is any chance you want it, clone first:

        CREATE DATABASE AI_SPEND_ARCHIVE CLONE AI_SPEND;

      Zero-copy, so it costs nothing until the original diverges.

   2. IDENTITY_MAP AND SEAT_ENTITLEMENT ARE HAND-CURATED.
      They are the two tables nobody wants to rebuild. Export them before dropping
      even if you are discarding everything else.

   3. THIS DOES NOT DELETE YOUR SECRETS' UNDERLYING CREDENTIALS.
      Dropping a Snowflake SECRET removes the stored value here. It does NOT revoke
      the token at the vendor. Revoke each token in the vendor console separately,
      or you leave live credentials that Snowflake no longer tracks. This is the
      step people skip.
*/

-- ---------------------------------------------------------------------------
-- Step 0: preserve the hand-curated tables
--
-- Run these and save the output before going further. Everything else in this
-- database can be rebuilt from an API; these two cannot.
-- ---------------------------------------------------------------------------

USE ROLE AI_SPEND_RL;
USE WAREHOUSE AI_SPEND_WH;

SELECT * FROM AI_SPEND.CONTROL.IDENTITY_MAP ORDER BY PLATFORM_KEY, SUBJECT_KEY;
SELECT * FROM AI_SPEND.CONTROL.SEAT_ENTITLEMENT ORDER BY PLATFORM_KEY, PERIOD_MONTH, PERSON_KEY;
SELECT * FROM AI_SPEND.CONTROL.PLATFORM_RATE ORDER BY PLATFORM_KEY, VALID_FROM;

-- ---------------------------------------------------------------------------
-- Step 1: stop the schedule first
--
-- Suspend before dropping. A task that fires mid-teardown fails against
-- half-removed objects and writes confusing rows into a log you are about to drop.
-- ---------------------------------------------------------------------------

ALTER TASK IF EXISTS AI_SPEND.CONTROL.TASK_PULL_GITHUB_COPILOT SUSPEND;

-- Uncomment if the optional alert in sql/09 was created.
-- ALTER ALERT IF EXISTS AI_SPEND.CONTROL.ALERT_PIPELINE_UNHEALTHY SUSPEND;

-- ---------------------------------------------------------------------------
-- Step 2: agent and semantic view
--
-- Before the tables they depend on. Dropping a base table under a live agent
-- leaves the agent in place and broken, answering with errors.
-- ---------------------------------------------------------------------------

DROP AGENT IF EXISTS AI_SPEND.GOLD.AI_SPEND_AGENT;
DROP SEMANTIC VIEW IF EXISTS AI_SPEND.GOLD.AI_SPEND_SV;

-- ---------------------------------------------------------------------------
-- Step 3: gold layer, leaves before intermediates
-- ---------------------------------------------------------------------------

DROP DYNAMIC TABLE IF EXISTS AI_SPEND.GOLD.AI_ADOPTION_TREND;
DROP DYNAMIC TABLE IF EXISTS AI_SPEND.GOLD.AI_SPEND_FORECAST;
DROP DYNAMIC TABLE IF EXISTS AI_SPEND.GOLD.AI_USAGE_ANOMALIES;
DROP DYNAMIC TABLE IF EXISTS AI_SPEND.GOLD.AI_ENGAGEMENT_TIERS;
DROP DYNAMIC TABLE IF EXISTS AI_SPEND.GOLD.AI_SPEND_BY_DEPARTMENT;
DROP DYNAMIC TABLE IF EXISTS AI_SPEND.GOLD.SEAT_UTILIZATION;
DROP DYNAMIC TABLE IF EXISTS AI_SPEND.GOLD.AI_SPEND_ALLOCATED;
DROP DYNAMIC TABLE IF EXISTS AI_SPEND.GOLD.PERSON_DAY_USAGE;

-- ---------------------------------------------------------------------------
-- Step 4: shaped layer
-- ---------------------------------------------------------------------------

DROP VIEW IF EXISTS AI_SPEND.SHAPED.V_IDENTITY_QUALITY;
DROP DYNAMIC TABLE IF EXISTS AI_SPEND.SHAPED.UNIFIED_AI_USAGE;

DROP VIEW IF EXISTS AI_SPEND.SHAPED.V_SHRED_GITHUB_COPILOT;
DROP VIEW IF EXISTS AI_SPEND.SHAPED.V_SHRED_CHATGPT_ENTERPRISE;
DROP VIEW IF EXISTS AI_SPEND.SHAPED.V_SHRED_M365_COPILOT;
DROP VIEW IF EXISTS AI_SPEND.SHAPED.V_SHRED_BOX_AI;

-- ---------------------------------------------------------------------------
-- Step 5: procedures, task, and the raw-layer view
-- ---------------------------------------------------------------------------

DROP TASK IF EXISTS AI_SPEND.CONTROL.TASK_PULL_GITHUB_COPILOT;
-- DROP ALERT IF EXISTS AI_SPEND.CONTROL.ALERT_PIPELINE_UNHEALTHY;

DROP VIEW IF EXISTS AI_SPEND.CONTROL.V_PIPELINE_HEALTH;
DROP VIEW IF EXISTS AI_SPEND.CONTROL.V_PERSON_DIRECTORY;
DROP VIEW IF EXISTS AI_SPEND.RAW.V_SNOWFLAKE_NATIVE_USAGE;

DROP PROCEDURE IF EXISTS AI_SPEND.CONTROL.PULL_GITHUB_COPILOT(VARCHAR, TIMESTAMP_TZ);
DROP PROCEDURE IF EXISTS AI_SPEND.CONTROL.PULL_GITHUB_ALL();
DROP PROCEDURE IF EXISTS AI_SPEND.CONTROL.PROJECT_GITHUB_SEATS(DATE, NUMBER, VARCHAR);
DROP PROCEDURE IF EXISTS AI_SPEND.CONTROL.SEED_SNOWFLAKE_IDENTITIES();

-- ---------------------------------------------------------------------------
-- Step 6: secrets, integration, and network rules
--
-- Order matters: a secret cannot be dropped while an integration still lists it in
-- ALLOWED_AUTHENTICATION_SECRETS, and a network rule cannot be dropped while an
-- integration references it. Integration first.
--
-- REMINDER: this removes the stored value from Snowflake. It does NOT revoke the
-- token at GitHub, OpenAI, Microsoft, or Box. Do that in each vendor console.
-- ---------------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

DROP INTEGRATION IF EXISTS AI_SPEND_EAI;

DROP SECRET IF EXISTS AI_SPEND.CONTROL.GITHUB_COPILOT_CREDENTIALS;
DROP SECRET IF EXISTS AI_SPEND.CONTROL.OPENAI_ADMIN_CREDENTIALS;
DROP SECRET IF EXISTS AI_SPEND.CONTROL.GRAPH_API_CREDENTIALS;
DROP SECRET IF EXISTS AI_SPEND.CONTROL.BOX_API_CREDENTIALS;

DROP NETWORK RULE IF EXISTS AI_SPEND.CONTROL.GITHUB_API_RULE;
DROP NETWORK RULE IF EXISTS AI_SPEND.CONTROL.OPENAI_API_RULE;
DROP NETWORK RULE IF EXISTS AI_SPEND.CONTROL.MICROSOFT_GRAPH_RULE;
DROP NETWORK RULE IF EXISTS AI_SPEND.CONTROL.BOX_API_RULE;

-- ---------------------------------------------------------------------------
-- Step 7: database, warehouse, role
--
-- Dropping the database removes the stage and every landed vendor payload with it.
-- Confirm step 0 is done.
-- ---------------------------------------------------------------------------

DROP DATABASE IF EXISTS AI_SPEND;
DROP WAREHOUSE IF EXISTS AI_SPEND_WH;
DROP ROLE IF EXISTS AI_SPEND_RL;

-- ---------------------------------------------------------------------------
-- Verify nothing is left behind
--
-- All four should return no rows. A surviving secret or integration is the
-- consequential leftover -- it means a credential is still stored.
-- ---------------------------------------------------------------------------

SHOW DATABASES LIKE 'AI_SPEND';
SHOW WAREHOUSES LIKE 'AI_SPEND_WH';
SHOW ROLES LIKE 'AI_SPEND_RL';
SHOW INTEGRATIONS LIKE 'AI_SPEND_EAI';

/* Finally, outside Snowflake: revoke the tokens in each vendor console.
   Nothing in this file can do that for you. */
