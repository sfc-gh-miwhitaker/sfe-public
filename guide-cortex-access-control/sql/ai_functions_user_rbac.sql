-- ============================================================
-- Cortex AI Access Control — RBAC Patterns
-- ============================================================
-- Pair-programmed by SE Community + Cortex Code
--
-- Companion SQL for guide-cortex-access-control/README.md.
-- Audit queries, narrowing patterns, full lockdown, per-function control,
-- the governance-table template, and verification.
--
-- Background:
--   CORTEX_USER (on PUBLIC by default) grants access to:
--     - All AI Functions (AI_COMPLETE, AI_CLASSIFY, AI_EXTRACT, etc.)
--     - Cortex Agents
--     - Cortex Analyst
--     - Cortex Search
--     - Snowflake CoWork
--     - Cortex Code (Desktop, CLI, Snowsight)
--
--   AI_FUNCTIONS_USER (GA April 2, 2026; NOT on PUBLIC by default) grants:
--     - Scalar AI Functions only (not AI_AGG or AI_SUMMARIZE_AGG)
--     - Does NOT grant Agents, Analyst, Search, Fine-tuning, CoWork, or CoCo
--
--   CORTEX_AGENT_USER (NOT on PUBLIC by default) grants Cortex Agents only.
--
-- Users need BOTH:
--   1. USE AI FUNCTIONS account-level privilege (on PUBLIC by default),
--      or a per-function USE AI FUNCTION <name> privilege
--   2. AI_FUNCTIONS_USER or CORTEX_USER database role
--
-- Model access is a THIRD, orthogonal plane — see the Model RBAC section of
-- the README. A role can hold both grants above and still be refused every
-- model.
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

-- IMPORTANT: this revoke alone is NOT sufficient. Two paths survive it:
--   1. Secondary roles — a user whose secondary roles include a role with
--      Cortex access still gets in. Verify with USE SECONDARY ROLES NONE.
--   2. IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE — a role holding it inherits
--      ALL database roles in that database, CORTEX_USER included.
--      Find the holders, then revoke per role:
--        SHOW GRANTS ON DATABASE SNOWFLAKE;
--        REVOKE IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE FROM ROLE <role_name>;
--
-- Revoking IMPORTED PRIVILEGES from PUBLIC account-wide is OPTIONAL per
-- Snowflake's docs, and it also removes PUBLIC's access to ACCOUNT_USAGE
-- views. Prefer fixing the specific over-inheriting roles.

-- Step B-2: Grant full Cortex access to roles that legitimately need it
-- (Agents, Analyst, Search, CoWork, full AI Functions including aggregate variants)
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE trusted_data_eng_role;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE cortex_agents_role;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE data_science_role;

-- Step B-3: Grant AI Functions-only access to the new BU role
GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE new_bu_role;
GRANT DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER TO ROLE analyst_role;

-- Step B-3b: Grant Agents-only access where that is the whole requirement
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_AGENT_USER TO ROLE business_cohort_role;

-- Step B-4: Verify the final state
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.CORTEX_USER;
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.AI_FUNCTIONS_USER;
SHOW GRANTS TO ROLE PUBLIC;


-- ── PATTERN C: PER-FUNCTION SURGICAL CONTROL (OPTIONAL) ──────────────────────
-- For cases where a BU should only access specific AI functions
-- (e.g., AI_COMPLETE and AI_CLASSIFY, but not AI_EXTRACT or AI_TRANSLATE).
-- The blanket USE AI FUNCTIONS privilege and the per-function privileges
-- have an OR relationship — a role with the blanket can call everything.
-- So revoking the blanket from every path the role inherits is a PREREQUISITE,
-- not an optional extra: until it is gone, per-function grants restrict nothing.

-- Revoke blanket privilege from PUBLIC (required for per-function to have effect):
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
    cortex_level    VARCHAR   NOT NULL,  -- 'CORTEX_USER' | 'AI_FUNCTIONS_USER' | 'CORTEX_AGENT_USER'
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
    role_name,
    cortex_level,
    'GRANT DATABASE ROLE SNOWFLAKE.' || cortex_level
        || ' TO ROLE ' || role_name || ';' AS grant_statement
FROM your_db.your_schema.cortex_access_grants
WHERE cortex_level IN ('CORTEX_USER', 'AI_FUNCTIONS_USER', 'CORTEX_AGENT_USER')
ORDER BY cortex_level, role_name;

-- Rows whose cortex_level is not one of the three supported values are
-- excluded above — list them separately so they are not silently dropped:
SELECT role_name, cortex_level
FROM your_db.your_schema.cortex_access_grants
WHERE cortex_level NOT IN ('CORTEX_USER', 'AI_FUNCTIONS_USER', 'CORTEX_AGENT_USER')
ORDER BY role_name;

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

-- Test end-to-end: switch to the role and try an AI Function call.
-- ALWAYS test as a non-ACCOUNTADMIN role with secondary roles disabled —
-- ACCOUNTADMIN reaches every Cortex service and every model regardless of
-- your grants, and an inherited secondary role masks a missing grant.
-- USE SECONDARY ROLES NONE;
-- USE ROLE new_bu_role;
-- SELECT AI_CLASSIFY('Test content', ['Category A', 'Category B']) AS classification;


-- ── REFERENCE: CORTEX DATABASE ROLE COMPARISON ────────────────────────────────
--
-- Role                  | AI Functions | Agents | Analyst | Search | Fine-tune | CoWork
-- ----------------------|--------------|--------|---------|--------|-----------|-------
-- CORTEX_USER           | YES (all)    | YES    | YES     | YES    | NO*       | YES
-- AI_FUNCTIONS_USER     | YES (scalar) | NO     | NO      | NO     | NO        | NO
-- CORTEX_AGENT_USER     | NO           | YES    | NO      | NO     | NO        | NO
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
-- CORTEX_AGENT_USER is NOT on PUBLIC by default — must be granted explicitly.
-- CORTEX_EMBED_USER is NOT on PUBLIC by default — must be granted explicitly.
--
-- Model access is a separate, orthogonal plane. CORTEX_MODELS_ALLOWLIST is
-- retired: it stopped authorizing anything with the 2026_07 bundle
-- (2026-09-08) and is fully retired 2026-11-18. Model application roles in
-- SNOWFLAKE.MODELS are the only mechanism, and they are enforced for embedding
-- models too. Removing the all-models bootstrap takes a stored procedure, not
-- a REVOKE:
--   SHOW GRANTS TO APPLICATION ROLE SNOWFLAKE.PUBLIC;
--   CALL SNOWFLAKE.LOCAL.REVOKE_FROM_PUBLIC_APPLICATION_ROLE(
--     'APP_ROLE', 'CORTEX-MODEL-ROLE-ALL');
--   CALL SNOWFLAKE.MODELS.CORTEX_BASE_MODELS_REFRESH();
