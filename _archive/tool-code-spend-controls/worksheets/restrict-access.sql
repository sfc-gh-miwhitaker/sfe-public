/*==============================================================================
  WORKSHEET: RBAC — Control Access to Cortex Code

  Purpose:    Grant, revoke, and audit Cortex Code access via CORTEX_USER
              database role. Also covers budget management role delegation.
  Requires:   ACCOUNTADMIN (for CORTEX_USER grants) or SECURITYADMIN
==============================================================================*/

/* ── SECTION 1: Audit — who currently has Cortex Code access? ─────────────
   Run this before making any changes.
   Expected: rows showing all roles granted CORTEX_USER.                     */

-- Roles with direct CORTEX_USER grant
SELECT GRANTEE_NAME,
       GRANTED_TO,
       CREATED_ON,
       GRANTED_BY
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE ROLE_NAME = 'CORTEX_USER'
  AND GRANTED_ON = 'DATABASE_ROLE'
  AND DELETED_ON IS NULL
ORDER BY CREATED_ON;

-- Users with direct CORTEX_USER grant
SELECT GRANTEE_NAME AS user_name, CREATED_ON, GRANTED_BY
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE ROLE = 'CORTEX_USER'
  AND DELETED_ON IS NULL
ORDER BY CREATED_ON;


/* ── SECTION 2: Grant Cortex Code access ────────────────────────────────── */

-- Grant to a role (all users with this role gain access)
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE developer;

-- Grant to a specific user
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO USER alice;

-- Recommended: use an intermediate role for team-level control
CREATE ROLE IF NOT EXISTS cortex_code_users
  COMMENT = 'Users with access to Cortex Code AI features';

GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE cortex_code_users;

-- Add users to the team role
GRANT ROLE cortex_code_users TO USER alice;
GRANT ROLE cortex_code_users TO USER bob;


/* ── SECTION 3: Revoke Cortex Code access ─────────────────────────────────
   Takes effect immediately — user's next Cortex Code request will fail.    */

REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE contractor_role;
REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM USER alice;

-- Remove from intermediate role (cleaner — leaves CORTEX_USER grant intact)
REVOKE ROLE cortex_code_users FROM USER alice;


/* ── SECTION 4: Network policy — restrict by IP ───────────────────────────
   WARNING: Network policies apply to ALL Snowflake access for that user,
   not just Cortex Code. Use only when full-session restriction is intended. */

-- Create a policy for corporate IP ranges
CREATE NETWORK POLICY IF NOT EXISTS corp_only_policy
  ALLOWED_IP_LIST = ('203.0.113.0/24', '10.0.0.0/8')
  COMMENT = 'Allow only corporate network access';

-- Apply to a user
ALTER USER contractor_alice SET NETWORK_POLICY = corp_only_policy;

-- Apply account-wide (blocks all users outside allowed IPs)
-- ALTER ACCOUNT SET NETWORK_POLICY = corp_only_policy;

-- Remove
ALTER USER contractor_alice UNSET NETWORK_POLICY;

-- List existing network policies
SHOW NETWORK POLICIES;


/* ── SECTION 5: Budget management role delegation ─────────────────────────
   Control who can view or manage budgets independently of ACCOUNTADMIN.    */

-- Let FinOps team view all budget spending
GRANT DATABASE ROLE SNOWFLAKE.BUDGET_VIEWER TO ROLE finops_role;

-- Let team leads create budgets in their own schemas
GRANT DATABASE ROLE SNOWFLAKE.BUDGET_CREATOR TO ROLE team_lead_role;

-- Full budget admin (create, modify, delete any budget)
GRANT DATABASE ROLE SNOWFLAKE.BUDGET_ADMIN TO ROLE finops_admin_role;

-- Delegate admin of a specific budget instance to a role
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!SET_ADMIN_ROLE(
    SYSTEM$ROLE_REFERENCE('team_lead_role')
);


/* ── SECTION 6: Audit — users who haven't used Cortex Code ────────────────
   Identify users with CORTEX_USER access who have zero requests in 30 days.
   Candidates for access revocation to reduce exposure.                     */

WITH active_users AS (
    SELECT DISTINCT USER_NAME
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    WHERE USAGE_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP)
    UNION
    SELECT DISTINCT USER_NAME
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
    WHERE USAGE_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP)
),
cortex_users AS (
    SELECT DISTINCT g.GRANTEE_NAME AS user_name
    FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS g
    WHERE g.ROLE = 'CORTEX_USER'
      AND g.DELETED_ON IS NULL
)
SELECT cu.user_name AS has_access_but_unused
FROM cortex_users cu
LEFT JOIN active_users au ON cu.user_name = au.USER_NAME
WHERE au.USER_NAME IS NULL
ORDER BY cu.user_name;
