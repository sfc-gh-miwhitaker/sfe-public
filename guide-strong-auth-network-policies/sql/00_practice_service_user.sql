/*==============================================================================
  Strong Auth Network Policies | 00 Practice service user (optional)
  Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-09

  INSTRUCTIONS:
    Open Snowsight -> New Worksheet -> Paste this file -> Run All.
    Runtime: under a minute. No values to edit. Re-runnable.
    Then run script 04 unchanged: its defaults point at these objects, so you
    can rehearse the migration before touching a real service account.

  WHAT GETS CREATED:
    Role            SFE_NETPOL_PRACTICE_ROLE (no privileges)
    User            SFE_NETPOL_PRACTICE_SVC  (TYPE=SERVICE, no password)
    Schema          SNOWFLAKE_EXAMPLE.SFE_NETPOL_PRACTICE
    Network rule    SFE_NETPOL_PRACTICE.SFE_NETPOL_PRACTICE_SVC_INGRESS
                    (only the IP address you are connected from right now)
    Network policy  SFE_NETPOL_PRACTICE_SVC_NETWORK_POLICY (created, NOT attached)

  PREREQUISITES:
    ACCOUNTADMIN (creates a user and a role). Nothing is applied to your
    account or to any existing user. Remove everything with 99_teardown.sql.
==============================================================================*/

SELECT
    '2027-01-09'::DATE AS expiration_date,
    CURRENT_DATE()     AS current_date,
    DATEDIFF('day', CURRENT_DATE(), '2027-01-09'::DATE) AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), '2027-01-09'::DATE) < 0  THEN 'EXPIRED - Check the guide for a newer version.'
        WHEN DATEDIFF('day', CURRENT_DATE(), '2027-01-09'::DATE) <= 7 THEN 'EXPIRING SOON - Verify syntax against current documentation.'
        ELSE 'ACTIVE - Safe to run.'
    END AS guide_status;

USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS SFE_NETPOL_PRACTICE_ROLE
    COMMENT = 'Practice role for the strong auth network policy guide. Safe to drop.';

CREATE USER IF NOT EXISTS SFE_NETPOL_PRACTICE_SVC
    TYPE = SERVICE
    DEFAULT_ROLE = SFE_NETPOL_PRACTICE_ROLE
    COMMENT = 'Practice service user for the strong auth network policy guide. Safe to drop.';

GRANT ROLE SFE_NETPOL_PRACTICE_ROLE TO USER SFE_NETPOL_PRACTICE_SVC;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'Shared database for SE Community examples';
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.SFE_NETPOL_PRACTICE
    COMMENT = 'Practice network rules for the strong auth network policy guide';

-- VALUE_LIST takes literals, so build the rule from the caller's address.
-- A rule referenced by a policy cannot be replaced (098509), so create it
-- once and update its list in place on every re-run.
SET practice_rule = 'SNOWFLAKE_EXAMPLE.SFE_NETPOL_PRACTICE.SFE_NETPOL_PRACTICE_SVC_INGRESS';
SET practice_rule_ddl =
    'CREATE NETWORK RULE IF NOT EXISTS ' || $practice_rule
    || ' MODE = INGRESS TYPE = ' || IFF(CONTAINS(CURRENT_IP_ADDRESS(), ':'), 'IPV6', 'IPV4')
    || ' VALUE_LIST = (''' || CURRENT_IP_ADDRESS() || ''')';
EXECUTE IMMEDIATE $practice_rule_ddl;
SET practice_rule_update =
    'ALTER NETWORK RULE ' || $practice_rule
    || ' SET VALUE_LIST = (''' || CURRENT_IP_ADDRESS() || ''')'
    || ' COMMENT = ''Practice: the address the admin connected from on ' || CURRENT_DATE() || '''';
EXECUTE IMMEDIATE $practice_rule_update;

CREATE NETWORK POLICY IF NOT EXISTS SFE_NETPOL_PRACTICE_SVC_NETWORK_POLICY
    ALLOWED_NETWORK_RULE_LIST = ('SNOWFLAKE_EXAMPLE.SFE_NETPOL_PRACTICE.SFE_NETPOL_PRACTICE_SVC_INGRESS')
    COMMENT = 'Practice per-user policy. Not attached by this script.';

SELECT
    'SFE_NETPOL_PRACTICE_SVC'      AS practice_user,
    CURRENT_IP_ADDRESS()           AS allowlisted_address,
    'Run sql/04_evaluate_attach_migrate.sql with its defaults' AS next_step;
