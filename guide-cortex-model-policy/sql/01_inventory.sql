-- Pair-programmed by SE Community + Cortex Code
-- Read-only inventory and command generation. Run sections in order in Snowsight.
-- Use ACCOUNTADMIN for complete visibility; choose it in the worksheet role picker.
-- Save each result privately. Generated SQL is text, not executed by this script.
-- No inference, grants, revokes, account changes, or persistent objects are run here.

-- 1. Account context, transition state, and routing. No settings are changed.
SELECT CURRENT_ACCOUNT() AS account_locator,
       CURRENT_ROLE() AS active_role,
       CURRENT_SECONDARY_ROLES() AS secondary_roles,
       SYSTEM$BEHAVIOR_CHANGE_BUNDLE_STATUS('2026_07') AS model_rbac_bundle_status;
SHOW PARAMETERS LIKE 'CORTEX_MODELS_ALLOWLIST' IN ACCOUNT;
SHOW PARAMETERS LIKE 'CORTEX_ENABLED_CROSS_REGION' IN ACCOUNT;

-- 2. Both PUBLIC paths, plus direct recipients of the all-model role.
SHOW GRANTS TO APPLICATION ROLE SNOWFLAKE.PUBLIC;
SHOW GRANTS TO ROLE PUBLIC;
SHOW GRANTS OF APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-ALL";

-- 3. Catalog and synthetic test text. Existence is not approval or invocability.
-- Save approved and excluded AI_COMPLETE model tests before removing access.
-- Do not execute TEST_SQL for embedding/special-purpose models or the whole catalog.
SHOW CORTEX BASE MODELS IN SCHEMA SNOWFLAKE.MODELS
->> SELECT "name" AS model_name,
           "lifecycle_status" AS lifecycle_status,
           "in_region_availability" AS in_region_availability,
           "cross_region_availability" AS cross_region_availability,
           "legacy_date" AS legacy_date,
           "eol_date" AS eol_date,
           'SELECT AI_COMPLETE(model => ' || CHR(39)
               || REPLACE(LOWER("name"), CHR(39), CHR(39) || CHR(39))
               || CHR(39) || ', prompt => ' || CHR(39) || 'Reply OK.' || CHR(39)
               || ', model_parameters => {' || CHR(39) || 'max_tokens' || CHR(39)
               || ': 16}, return_error_details => TRUE) AS access_test;' AS test_sql
    FROM $1
    ORDER BY model_name;

-- 4. Copy only the approved GRANT_SQL rows. PUBLIC is the shared baseline,
-- not a ceiling on other roles. For team policies use actual execution roles.
SHOW APPLICATION ROLES LIKE 'CORTEX-MODEL-ROLE-%' IN APPLICATION SNOWFLAKE
->> SELECT SUBSTR("name", LENGTH('CORTEX-MODEL-ROLE-') + 1) AS model_name,
           'GRANT APPLICATION ROLE SNOWFLAKE."' || REPLACE("name", '"', '""')
               || '" TO ROLE PUBLIC;' AS grant_sql,
           'SHOW GRANTS OF APPLICATION ROLE SNOWFLAKE."' || REPLACE("name", '"', '""')
               || '";' AS inspect_sql
    FROM $1
    WHERE "name" <> 'CORTEX-MODEL-ROLE-ALL'
    ORDER BY model_name;

-- 5. Direct account-role grants only. Save RESTORE_SQL; execute reviewed revokes
-- separately, AFTER approved replacement grants. The bootstrap needs its procedure.
SHOW GRANTS OF APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-ALL"
->> SELECT "grantee_name" AS account_role,
           'REVOKE APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-ALL" FROM ROLE "'
               || REPLACE("grantee_name", '"', '""') || '";' AS revoke_sql,
           'GRANT APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-ALL" TO ROLE "'
               || REPLACE("grantee_name", '"', '""') || '";' AS restore_sql
    FROM $1
    WHERE "granted_to" = 'ROLE' AND "grantee_name" <> 'ACCOUNTADMIN'
    ORDER BY account_role;

-- 6. Optional team-specific recipients. Select existing roles, not all output rows.
SHOW ROLES
->> SELECT "name" AS account_role,
           '"' || REPLACE("name", '"', '""') || '"' AS quoted_role_identifier
    FROM $1
    WHERE "name" <> 'ACCOUNTADMIN'
    ORDER BY account_role;
