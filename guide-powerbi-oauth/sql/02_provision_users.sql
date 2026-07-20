/*==============================================================================
  GUIDE: Power BI + Snowflake OAuth
  Existing User Audit & Fix
  Pair-programmed by SE Community + Cortex Code | Expires: 2026-08-19

  Run these queries BEFORE Step 2 (Entra SCIM setup) if your Power BI users
  already have Snowflake accounts. See README.md Path B and Path C.
==============================================================================*/

USE ROLE SECURITYADMIN;

-- ============================================================
-- AUDIT: Find users whose LOGIN_NAME is NOT an email address
-- These users will fail Power BI OAuth until fixed.
-- ============================================================
SHOW USERS;
SELECT "name", "login_name", "email"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "login_name" NOT ILIKE '%@%'
ORDER BY "name";

-- If this returns no rows: all existing users are correctly configured. Continue to Step 2.
-- If this returns rows: pick Fix 1 or Fix 2 below for each affected user.


-- ============================================================
-- FIX 1: Update LOGIN_NAME directly (best for a small number of users)
-- Repeat for each user returned by the audit above.
-- ============================================================
-- ALTER USER <snowflake_username> SET LOGIN_NAME = 'user@company.com';


-- ============================================================
-- FIX 2: Transfer ownership to the SCIM provisioner
-- Use this if you want Entra to manage this user going forward.
-- Entra will overwrite the user's LOGIN_NAME at the next sync.
-- Make sure the user's email in Entra is correct first.
-- ============================================================
-- USE ROLE ACCOUNTADMIN;
-- GRANT OWNERSHIP ON USER <snowflake_username> TO ROLE AAD_PROVISIONER;


-- ============================================================
-- CONFIRM: After fixes, verify no users remain with non-email LOGIN_NAME
-- ============================================================
SHOW USERS;
SELECT "name", "login_name", "email", "default_role", "default_warehouse", "disabled"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "login_name" NOT ILIKE '%@%'
   OR "default_role" IS NULL
   OR "disabled" = 'true'
ORDER BY "name";

-- This query should return zero rows before you move to Step 2.
