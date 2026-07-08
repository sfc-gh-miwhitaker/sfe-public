-- ============================================================
-- AI_FUNCTIONS_USER RBAC — New BU Governance
-- ============================================================
-- This file covers the access control pattern for governing new business
-- units that need Cortex AI Functions but not the full Cortex surface.
--
-- Background:
--   CORTEX_USER (on PUBLIC by default) grants access to:
--     - All AI Functions (AI_COMPLETE, AI_CLASSIFY, AI_EXTRACT, etc.)
--     - Cortex Agents
--     - Cortex Analyst
--     - Cortex Search
--     - Snowflake CoWork
--
--   AI_FUNCTIONS_USER (GA April 2, 2026; NOT on PUBLIC by default) grants:
--     - Scalar AI Functions only (not AI_AGG or AI_SUMMARIZE_AGG)
--     - Does NOT grant Agents, Analyst, Search, Fine-tuning, or CoWork
--
-- Users need BOTH:
--   1. USE AI FUNCTIONS account-level privilege (on PUBLIC by default)
--   2. AI_FUNCTIONS_USER or CORTEX_USER database role
--
-- Required role: ACCOUNTADMIN
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ── STEP 1: AUDIT CURRENT STATE ──────────────────────────────────────────────
-- Run these BEFORE making any changes.
-- Understand who currently has CORTEX_USER (and therefore full Cortex access).

-- What database roles does PUBLIC currently have?
SHOW GRANTS TO ROLE PUBLIC;

-- Which roles have CORTEX_USER?
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.CORTEX_USER;

-- Which roles have AI_FUNCTIONS_USER?
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER;

-- What account-level privileges does PUBLIC have?
-- (Look for "USE AI FUNCTIONS" in the output)
SHOW GRANTS TO ROLE PUBLIC;

-- Check a specific role's full grant picture:
-- SHOW GRANTS TO ROLE <role_name>;


-- ── PATTERN A: MINIMAL — NEW BU GETS AI FUNCTIONS, EXISTING USERS UNCHANGED ──
-- Use this when CORTEX_USER is still on PUBLIC and you want to add a new BU
-- that has AI Functions access without changing anything for existing users.
-- Since USE AI FUNCTIONS is on PUBLIC, no account-level privilege change is needed.

-- Grant AI_FUNCTIONS_USER to the new BU's functional role:
GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE new_bu_role;

-- Verify:
SHOW GRANTS TO ROLE new_bu_role;


-- ── PATTERN B: FULL LOCKDOWN — REMOVE CORTEX_USER FROM PUBLIC ─────────────────
-- Use this when you want to control who has Cortex access on a per-role basis.
-- WARNING: This breaks access for any user whose only path to CORTEX_USER was PUBLIC.
-- Run the audit in Step 1 and evaluate the blast radius before proceeding.

-- Step B-1: Remove the broad default from PUBLIC
REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE PUBLIC;

-- NOTE: REVOKE IMPORTED PRIVILEGES on the SNOWFLAKE database from PUBLIC
-- removes access to ACCOUNT_USAGE views too. Only do this if that's intended.
-- If you only want to revoke AI capabilities, revoke the database role only.

-- Step B-2: Grant full Cortex access to roles that legitimately need it
-- (Agents, Analyst, Search, CoWork, full AI Functions including aggregate variants)
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE trusted_data_eng_role;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE cortex_agents_role;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE data_science_role;

-- Step B-3: Grant AI Functions-only access to the new BU role
GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE new_bu_role;
GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE analyst_role;

-- Step B-4: Verify the final state
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.CORTEX_USER;
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER;
SHOW GRANTS TO ROLE PUBLIC;


-- ── PATTERN C: PER-FUNCTION SURGICAL CONTROL (OPTIONAL) ──────────────────────
-- For cases where a BU should only access specific AI functions
-- (e.g., AI_COMPLETE and AI_CLASSIFY, but not AI_EXTRACT or AI_TRANSLATE).
-- The blanket USE AI FUNCTIONS privilege and the per-function privileges
-- have an OR relationship — a role with the blanket can call everything.
-- Use per-function ONLY if you're intentionally restricting to a subset.

-- Revoke blanket privilege from PUBLIC (if you haven't already):
REVOKE USE AI FUNCTIONS ON ACCOUNT FROM ROLE PUBLIC;

-- Grant only specific functions to the limited BU role:
GRANT USE AI FUNCTION AI_COMPLETE  ON ACCOUNT TO ROLE limited_bu_role;
GRANT USE AI FUNCTION AI_CLASSIFY  ON ACCOUNT TO ROLE limited_bu_role;

-- Still need the database role (AI_FUNCTIONS_USER or CORTEX_USER):
GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE limited_bu_role;

-- Restore blanket access to roles that should have all functions:
GRANT USE AI FUNCTIONS ON ACCOUNT TO ROLE trusted_data_eng_role;

-- View per-function grants:
SHOW GRANTS ON ACCOUNT;
-- Filter for privilege LIKE 'USE AI FUNCTION%' in the output.


-- ── PATTERN D: APPLYING AT SCALE — MULTIPLE ROLES AND BUs ─────────────────────
-- When you have many roles to update, use this approach to drive grants
-- from a governance table rather than ad-hoc SQL.

-- Create a governance table to track intended Cortex access by role:
CREATE TABLE IF NOT EXISTS your_db.your_schema.cortex_access_grants (
    role_name       VARCHAR   NOT NULL,
    cortex_level    VARCHAR   NOT NULL,  -- 'CORTEX_USER' or 'AI_FUNCTIONS_USER'
    granted_by      VARCHAR,
    granted_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    justification   VARCHAR,
    PRIMARY KEY (role_name)
);

-- Populate with your intended role-to-access mappings:
INSERT INTO your_db.your_schema.cortex_access_grants
    (role_name, cortex_level, justification)
VALUES
    ('data_eng_role',       'CORTEX_USER',         'Agents and Analyst needed'),
    ('analyst_role',        'AI_FUNCTIONS_USER',   'AI Functions only; no Agents'),
    ('reporting_role',      'AI_FUNCTIONS_USER',   'AI_CLASSIFY for content tagging'),
    ('new_bu_marketing',    'AI_FUNCTIONS_USER',   'Campaign classification use case'),
    ('new_bu_operations',   'AI_FUNCTIONS_USER',   'Invoice extraction use case');

-- Generate the GRANT statements from the table (review before executing):
SELECT
    CASE cortex_level
        WHEN 'CORTEX_USER'
            THEN 'GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE ' || role_name || ';'
        WHEN 'AI_FUNCTIONS_USER'
            THEN 'GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE ' || role_name || ';'
        ELSE '-- UNKNOWN LEVEL: ' || cortex_level || ' for role ' || role_name
    END AS grant_statement
FROM your_db.your_schema.cortex_access_grants
ORDER BY cortex_level, role_name;

-- After reviewing the output, copy and execute the GRANT statements.
-- (Snowflake does not support dynamic DDL execution in plain SQL outside of
--  stored procedures. Use a Snowpark or scripted deployment if you want
--  fully automated grant execution.)


-- ── STEP 2: VERIFICATION AFTER ANY CHANGE ────────────────────────────────────
-- Run these after applying changes to confirm the intended state.

-- Confirm AI_FUNCTIONS_USER assignments:
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER;

-- Confirm CORTEX_USER assignments:
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.CORTEX_USER;

-- Confirm PUBLIC no longer has CORTEX_USER (if lockdown applied):
SHOW GRANTS TO ROLE PUBLIC;

-- Test that a specific role can resolve grants (requires the role to exist):
-- SHOW GRANTS TO ROLE new_bu_role;

-- Test end-to-end: switch to the role and try an AI Function call
-- (requires appropriate warehouse and database access too):
-- USE ROLE new_bu_role;
-- SELECT AI_CLASSIFY('Test content', ['Category A', 'Category B']) AS classification;


-- ── REFERENCE: CORTEX DATABASE ROLE COMPARISON ────────────────────────────────
--
-- Role                  | AI Functions | Agents | Analyst | Search | Fine-tune | CoWork
-- ----------------------|--------------|--------|---------|--------|-----------|-------
-- CORTEX_USER           | YES (all)    | YES    | YES     | YES    | NO*       | YES
-- AI_FUNCTIONS_USER     | YES (scalar) | NO     | NO      | NO     | NO        | NO
-- CORTEX_EMBED_USER     | Embed only   | NO     | NO      | NO     | NO        | NO
--
-- *Fine-tuning requires CREATE MODEL privilege on a schema, not CORTEX_USER.
-- *AI_AGG and AI_SUMMARIZE_AGG require CORTEX_USER, not AI_FUNCTIONS_USER.
--
-- The USE AI FUNCTIONS account-level privilege is required in addition to
-- whichever database role the user has. It is on PUBLIC by default.
--
-- CORTEX_USER is on PUBLIC by default.
-- AI_FUNCTIONS_USER is NOT on PUBLIC by default — must be granted explicitly.
-- CORTEX_EMBED_USER is NOT on PUBLIC by default — must be granted explicitly.
