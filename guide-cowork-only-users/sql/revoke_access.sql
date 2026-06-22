/*==============================================================================
  REVOKE ACCESS — guide-cowork-admin-setup
  Remove CoWork access for a single user or the entire role.
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-07-22
==============================================================================*/

USE ROLE ACCOUNTADMIN;

-- ─── Remove a single user's CoWork-only restriction ───────────────────────
-- Restores full interface access. Use this if the user should keep other
-- Snowflake access (e.g. moving from CoWork-only to a developer role).
ALTER USER alice SET ALLOWED_INTERFACES = (ALL);

-- Remove the CoWork role
REVOKE ROLE COWORK_USER FROM USER alice;

-- ─── Disable a user entirely ──────────────────────────────────────────────
-- Use when offboarding. The user object is preserved for audit history.
-- ALTER USER alice SET DISABLED = TRUE;

-- ─── Remove all CoWork-only users at once ─────────────────────────────────
-- Dropping the role revokes it from all members automatically.
-- Uncomment with caution — affects all users with this role.
-- DROP ROLE COWORK_USER;

-- ─── Remove an agent from the CoWork object ───────────────────────────────
-- Removes the agent from the curated list. Users with COWORK_USER role
-- can no longer see or interact with it.
-- ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
--   DROP AGENT <db>.<schema>.<agent_name>;
