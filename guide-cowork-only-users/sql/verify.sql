/*==============================================================================
  VERIFICATION — guide-cowork-admin-setup
  Run these after provisioning to confirm the setup is correct.
  Pair-programmed by SE Community + Cortex Code | Expires: 2027-02-04
==============================================================================*/

USE ROLE ACCOUNTADMIN;

-- ─── Role grants ──────────────────────────────────────────────────────────
-- Expected: CORTEX_AGENT_USER database role, USAGE on SNOWFLAKE INTELLIGENCE,
--           USAGE on each agent
SHOW GRANTS TO ROLE COWORK_USER;

-- ─── CoWork object ────────────────────────────────────────────────────────
-- Expected: returns one row (SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT)
SHOW SNOWFLAKE INTELLIGENCES;

-- Expected: lists all agents added to the object
DESCRIBE SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- ─── CoWork object grant ──────────────────────────────────────────────────
-- Expected: USAGE granted to COWORK_USER
SHOW GRANTS ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- ─── Single user spot check (replace 'alice' with actual username) ────────
DESCRIBE USER alice;
-- Expected: DEFAULT_ROLE = COWORK_USER
--           ALLOWED_INTERFACES = SNOWFLAKE_INTELLIGENCE
--           DEFAULT_WAREHOUSE  = <your_warehouse>

SHOW GRANTS TO USER alice;
-- Expected: COWORK_USER appears in the list

-- ─── Bulk verification ────────────────────────────────────────────────────
-- List all users who have been granted the COWORK_USER role
SHOW GRANTS OF ROLE COWORK_USER;
-- Returns all users and roles that have been granted this role
