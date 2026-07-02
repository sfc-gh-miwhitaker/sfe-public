-- =============================================================================
-- 05_promote_rollback.sql — Promotion and rollback via alias + default
-- Pair-programmed by SE Community + Cortex Code
--
-- Promotion and rollback are the SAME operation done in different directions:
-- you repoint where traffic goes. Two levers:
--   * The "production" alias  — for callers that target versions/production:run
--   * DEFAULT_VERSION         — for unversioned agent:run callers
-- Callers never change; you move the pointer.
-- =============================================================================

USE SCHEMA AGENT_VERSIONING_DEMO.DEMO;
USE WAREHOUSE AGENT_VERSIONING_WH;

-- Assume 03 (or 04) has produced at least VERSION$2 (currently production) and
-- a newer VERSION$3 you now want to release. Confirm what exists first.
SHOW VERSIONS IN AGENT ORDERS_AGENT;

-- --- PROMOTE: move "production" to the new version ---------------------------
-- Reassigning an alias is atomic. Every caller hitting versions/production:run
-- immediately routes to VERSION$3 with no client-side change.
ALTER AGENT ORDERS_AGENT MODIFY VERSION VERSION$3 SET ALIAS = production;

-- Also move the default so unversioned agent:run callers follow along.
ALTER AGENT ORDERS_AGENT SET DEFAULT_VERSION = 'VERSION$3';

-- --- ROLLBACK: point everything back at the known-good version ---------------
-- Same commands, previous version. This is your incident lever.
-- ALTER AGENT ORDERS_AGENT MODIFY VERSION VERSION$2 SET ALIAS = production;
-- ALTER AGENT ORDERS_AGENT SET DEFAULT_VERSION = 'VERSION$2';

-- --- Auto-follow the newest release ------------------------------------------
-- Prefer that the default always tracks the latest commit? Use the LAST
-- shortcut instead of pinning a number. (There is no UNSET DEFAULT_VERSION.)
-- ALTER AGENT ORDERS_AGENT SET DEFAULT_VERSION = LAST;

-- --- Retire an old version (optional cleanup) --------------------------------
-- You can drop NAMED versions, but NOT: the default version, or a version that
-- is the base of the current LIVE. Change the default first if needed.
-- ALTER AGENT ORDERS_AGENT DROP VERSION VERSION$1;

SHOW VERSIONS IN AGENT ORDERS_AGENT;
