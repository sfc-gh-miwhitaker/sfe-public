/*
 * Cross-cloud account replication: preflight (read-only)
 * Pair-programmed by SE Community + Cortex Code
 *
 * Run in the AWS SOURCE account as ACCOUNTADMIN.
 * Nothing here creates, grants, or changes anything.
 */

USE ROLE ACCOUNTADMIN;

-- 1. Where am I, and which edition? Account objects (users, roles, warehouses,
--    integrations) and failover need Business Critical or higher.
SELECT CURRENT_ORGANIZATION_NAME() AS org_name,
       CURRENT_ACCOUNT_NAME()      AS source_account,
       CURRENT_REGION()            AS source_region;

SHOW ORGANIZATION ACCOUNTS;  -- if this errors, use SHOW REPLICATION ACCOUNTS below

-- 2. Accounts already enabled for replication. Both source and target must be listed
--    before step 02 will work.
SHOW REPLICATION ACCOUNTS;

-- 3. Azure regions your organization can create accounts in.
SHOW REGIONS LIKE 'AZURE%';

-- 4. Existing groups: a database or account object type can belong to only one group.
SHOW FAILOVER GROUPS;
SHOW REPLICATION GROUPS;

-- 5. Generated ALLOWED_DATABASES list. Excludes imported (shared), personal, and
--    system databases, none of which can be added to a group.
SELECT LISTAGG('"' || REPLACE(database_name, '"', '""') || '"', ', ')
           WITHIN GROUP (ORDER BY database_name)
         AS allowed_databases_value
  FROM SNOWFLAKE.INFORMATION_SCHEMA.DATABASES
 WHERE type = 'STANDARD'
   AND CONTAINS(database_name, '$') = FALSE;

-- 6. Things that will NOT come across and need a plan (see README "What does not move").
SELECT table_catalog, table_schema, table_name,
       IFF(is_hybrid = 'YES', 'HYBRID TABLE', table_type) AS not_replicated
  FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES
 WHERE deleted IS NULL
   AND table_catalog <> 'SNOWFLAKE'
   AND (table_type IN ('EXTERNAL TABLE', 'EVENT TABLE', 'TEMPORARY TABLE') OR is_hybrid = 'YES')
ORDER BY not_replicated, table_catalog, table_schema, table_name;

-- 7. Integrations whose cloud-side trust must be redone in the Azure account.
SHOW INTEGRATIONS;
