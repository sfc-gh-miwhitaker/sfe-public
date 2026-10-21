/*
 * Cross-cloud account replication: source side (AWS)
 * Pair-programmed by SE Community + Cortex Code
 *
 * Run in the AWS SOURCE account as ACCOUNTADMIN, after 02_create_target.sql.
 * Creates: one failover group (everything replicable) + one client-redirect connection.
 * Change the three SET values only if you chose different names in step 02.
 */

USE ROLE ACCOUNTADMIN;

SET TARGET_ACCOUNT_NAME = 'AZURE_DR';   -- account created in 02_create_target.sql
SET GROUP_NAME          = 'ACCOUNT_FG';
SET CONNECTION_NAME     = 'PRIMARY_CONN'; -- becomes <org>-primary_conn.snowflakecomputing.com

-- One group, every replicable object type, every eligible database, 10-minute refresh.
-- The database list is read from the account at run time, so nothing is typed by hand.
EXECUTE IMMEDIATE $$
DECLARE
  db_list STRING;
  stmt    STRING;
BEGIN
  SELECT LISTAGG('"' || REPLACE(database_name, '"', '""') || '"', ', ')
           WITHIN GROUP (ORDER BY database_name)
    INTO :db_list
    FROM SNOWFLAKE.INFORMATION_SCHEMA.DATABASES
   WHERE type = 'STANDARD'
     AND CONTAINS(database_name, '$') = FALSE;

  stmt := 'CREATE FAILOVER GROUP IF NOT EXISTS ' || $GROUP_NAME ||
          ' OBJECT_TYPES = USERS, ROLES, WAREHOUSES, RESOURCE MONITORS, DATABASES,' ||
          ' INTEGRATIONS, NETWORK POLICIES, ACCOUNT PARAMETERS' ||
          ' ALLOWED_DATABASES = ' || :db_list ||
          ' ALLOWED_INTEGRATION_TYPES = SECURITY INTEGRATIONS, API INTEGRATIONS,' ||
          ' STORAGE INTEGRATIONS, EXTERNAL ACCESS INTEGRATIONS, NOTIFICATION INTEGRATIONS' ||
          ' ALLOWED_ACCOUNTS = ' || CURRENT_ORGANIZATION_NAME() || '.' || $TARGET_ACCOUNT_NAME ||
          ' REPLICATION_SCHEDULE = ''10 MINUTE''';
  EXECUTE IMMEDIATE :stmt;
  RETURN stmt;
END;
$$;

-- Client redirect: one URL that follows whichever account is primary.
CREATE CONNECTION IF NOT EXISTS IDENTIFIER($CONNECTION_NAME);

EXECUTE IMMEDIATE $$
BEGIN
  EXECUTE IMMEDIATE 'ALTER CONNECTION ' || $CONNECTION_NAME ||
    ' ENABLE FAILOVER TO ACCOUNTS ' || CURRENT_ORGANIZATION_NAME() || '.' || $TARGET_ACCOUNT_NAME;
  RETURN 'Connection failover enabled';
END;
$$;

-- Hand these two values to the person running 04 in the Azure account.
SELECT CURRENT_ORGANIZATION_NAME() || '.' || CURRENT_ACCOUNT_NAME() || '.' || $GROUP_NAME      AS failover_group_primary,
       CURRENT_ORGANIZATION_NAME() || '.' || CURRENT_ACCOUNT_NAME() || '.' || $CONNECTION_NAME AS connection_primary,
       LOWER(CURRENT_ORGANIZATION_NAME() || '-' || $CONNECTION_NAME) || '.snowflakecomputing.com' AS connection_url;
