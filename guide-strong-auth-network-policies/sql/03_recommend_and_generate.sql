/*==============================================================================
  Strong Auth Network Policies | 03 Recommend and generate draft policies
  Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-09

  INSTRUCTIONS:
    Open Snowsight -> New Worksheet -> Paste this file -> Run All.
    Read-only: this script creates nothing in your account. It returns SQL
    text for you to review. Runtime: one to two minutes.

  WHAT IT RETURNS:
    1. Draft DDL, one row per statement, for one network rule (IPv4, plus
       IPv6 when seen) and one network policy per service user, built only
       from addresses flagged STABLE or REVIEW in script 02. Copy the
       STATEMENT column into a new worksheet, edit, then run it.
    2. Users whose draft needs a human decision (PrivateLink, no usable IPs).
    3. Ready-to-run CALL statements for the native Network Policy Advisor
       and the dry run, one per user, so you can compare its CIDR blocks
       with the exact addresses above.

  OPTIONAL SETTINGS (defaults work as-is):
    rule_schema  where generated rules live; created by the draft if missing
    lookback_days, user_filter, user_types as in script 02

  PREREQUISITES:
    ACCOUNTADMIN, or SECURITYADMIN plus SNOWFLAKE.SECURITY_VIEWER.
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

SET lookback_days = 90;
SET user_filter   = '%';
SET user_types    = 'SERVICE,LEGACY_SERVICE';
SET rule_schema   = 'SECURITY.NETWORK_RULES';  -- database.schema for your rules

------------------------------------------------------------------------------
-- Same base as script 02, so this file runs on its own.
------------------------------------------------------------------------------
-- (Each query below repeats this base as a CTE so the script needs no
-- database context and creates no objects.)

------------------------------------------------------------------------------
-- 1. Draft DDL. Never emits an empty rule: a network policy whose allowed
--    list holds no IPv4 identifiers blocks every IPv4 address.
------------------------------------------------------------------------------
WITH service_user_ips AS (
    SELECT
        l.user_name,
        REGEXP_REPLACE(UPPER(l.user_name), '[^A-Z0-9_]', '_') AS object_stem,
        l.client_ip,
        CASE
            WHEN l.client_private_link_id IS NOT NULL THEN 'PRIVATELINK'
            WHEN CONTAINS(l.client_ip, ':')        THEN 'IPV6'
            ELSE 'IPV4'
        END                                                 AS ip_family,
        COUNT_IF(l.is_success = 'YES')                      AS successful_logins,
        COUNT(DISTINCT TO_DATE(l.event_timestamp))          AS days_seen,
        MAX(l.event_timestamp)                              AS last_seen,
        CASE
            WHEN COUNT_IF(l.is_success = 'YES') = 0                              THEN 'FAILED_ONLY'
            WHEN MAX(l.event_timestamp) < DATEADD('day', -30, CURRENT_TIMESTAMP()) THEN 'STALE'
            WHEN COUNT(DISTINCT TO_DATE(l.event_timestamp)) = 1                  THEN 'ONE_OFF'
            WHEN COUNT(DISTINCT TO_DATE(l.event_timestamp)) >= 3                 THEN 'STABLE'
            ELSE 'REVIEW'
        END                                                 AS review_flag
    FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY AS l
    JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS AS u
      ON u.name = l.user_name AND u.deleted_on IS NULL
    WHERE l.event_timestamp >= DATEADD('day', -$lookback_days, CURRENT_TIMESTAMP())
      AND ARRAY_CONTAINS(COALESCE(u.type, 'NULL')::VARIANT, SPLIT($user_types, ','))
      AND l.user_name LIKE $user_filter
      AND l.client_ip NOT IN ('0.0.0.0', 'INTERNAL_SNOWFLAKE_IP', 'INTERNAL_SNOWFLAKE_IP/0.0.0.0')
    GROUP BY l.user_name, l.client_ip, ip_family
),
kept AS (
    SELECT user_name, object_stem, ip_family,
           LISTAGG('''' || client_ip || '''', ', ') WITHIN GROUP (ORDER BY client_ip) AS value_list,
           COUNT(*) AS address_count
    FROM service_user_ips
    WHERE review_flag IN ('STABLE', 'REVIEW')
      AND ip_family IN ('IPV4', 'IPV6')
    GROUP BY user_name, object_stem, ip_family
),
per_user AS (
    SELECT user_name, object_stem,
           LISTAGG('''' || $rule_schema || '.' || object_stem || '_' || ip_family || '''', ', ')
               WITHIN GROUP (ORDER BY ip_family) AS rule_refs
    FROM kept
    GROUP BY user_name, object_stem
),
statements AS (
    SELECT '(setup)' AS user_sort, 1 AS step,
           'CREATE DATABASE IF NOT EXISTS ' || SPLIT_PART($rule_schema, '.', 1) || ';' AS statement
    UNION ALL
    SELECT '(setup)', 2, 'CREATE SCHEMA IF NOT EXISTS ' || $rule_schema || ';'
    UNION ALL
    SELECT user_name, 10,
           'CREATE NETWORK RULE IF NOT EXISTS ' || $rule_schema || '.' || object_stem || '_' || ip_family
           || ' MODE = INGRESS TYPE = ' || ip_family
           || ' VALUE_LIST = (' || value_list || ')'
           || ' COMMENT = ''' || address_count || ' address(es) observed for ' || REPLACE(user_name, '''', '')
           || ' over ' || $lookback_days || ' days, generated ' || CURRENT_DATE() || ''';'
    FROM kept
    UNION ALL
    SELECT user_name, 20,
           'CREATE NETWORK POLICY IF NOT EXISTS ' || object_stem || '_NETWORK_POLICY'
           || ' ALLOWED_NETWORK_RULE_LIST = (' || rule_refs || ')'
           || ' COMMENT = ''Per-user ingress policy for ' || REPLACE(user_name, '''', '') || ''';'
    FROM per_user
)
SELECT user_sort AS user_name, step, statement
FROM statements
ORDER BY user_sort, step;

------------------------------------------------------------------------------
-- 2. Users that need a human decision before any policy is drafted.
------------------------------------------------------------------------------
WITH service_user_ips AS (
    SELECT
        l.user_name,
        REGEXP_REPLACE(UPPER(l.user_name), '[^A-Z0-9_]', '_') AS object_stem,
        l.client_ip,
        CASE
            WHEN l.client_private_link_id IS NOT NULL THEN 'PRIVATELINK'
            WHEN CONTAINS(l.client_ip, ':')        THEN 'IPV6'
            ELSE 'IPV4'
        END                                                 AS ip_family,
        COUNT_IF(l.is_success = 'YES')                      AS successful_logins,
        COUNT(DISTINCT TO_DATE(l.event_timestamp))          AS days_seen,
        MAX(l.event_timestamp)                              AS last_seen,
        CASE
            WHEN COUNT_IF(l.is_success = 'YES') = 0                              THEN 'FAILED_ONLY'
            WHEN MAX(l.event_timestamp) < DATEADD('day', -30, CURRENT_TIMESTAMP()) THEN 'STALE'
            WHEN COUNT(DISTINCT TO_DATE(l.event_timestamp)) = 1                  THEN 'ONE_OFF'
            WHEN COUNT(DISTINCT TO_DATE(l.event_timestamp)) >= 3                 THEN 'STABLE'
            ELSE 'REVIEW'
        END                                                 AS review_flag
    FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY AS l
    JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS AS u
      ON u.name = l.user_name AND u.deleted_on IS NULL
    WHERE l.event_timestamp >= DATEADD('day', -$lookback_days, CURRENT_TIMESTAMP())
      AND ARRAY_CONTAINS(COALESCE(u.type, 'NULL')::VARIANT, SPLIT($user_types, ','))
      AND l.user_name LIKE $user_filter
      AND l.client_ip NOT IN ('0.0.0.0', 'INTERNAL_SNOWFLAKE_IP', 'INTERNAL_SNOWFLAKE_IP/0.0.0.0')
    GROUP BY l.user_name, l.client_ip, ip_family
)
SELECT
    user_name,
    COUNT_IF(review_flag IN ('STABLE', 'REVIEW') AND ip_family IN ('IPV4', 'IPV6')) AS usable_addresses,
    COUNT_IF(ip_family = 'PRIVATELINK')                                             AS privatelink_rows,
    ARRAY_AGG(DISTINCT review_flag)                                                 AS flags_seen,
    CASE
        WHEN COUNT_IF(ip_family = 'PRIVATELINK') > 0
            THEN 'Signs in over private connectivity: add an AWSVPCEID or AZURELINKID rule; it overrides IPv4 rules'
        WHEN COUNT_IF(review_flag IN ('STABLE', 'REVIEW') AND ip_family IN ('IPV4', 'IPV6')) = 0
            THEN 'No stable address: confirm the job owner and source network, or use key pair / workload identity'
    END AS decision_needed
FROM service_user_ips
GROUP BY user_name
HAVING decision_needed IS NOT NULL
ORDER BY user_name;

------------------------------------------------------------------------------
-- 3. Native advisor and dry run, one CALL per user. The advisor reads
--    successful ingress (not only logins), merges addresses into CIDR
--    blocks, returns IPv4 only, and stops at 1,000 blocks.
------------------------------------------------------------------------------
WITH service_user_ips AS (
    SELECT
        l.user_name,
        REGEXP_REPLACE(UPPER(l.user_name), '[^A-Z0-9_]', '_') AS object_stem,
        l.client_ip,
        CASE
            WHEN l.client_private_link_id IS NOT NULL THEN 'PRIVATELINK'
            WHEN CONTAINS(l.client_ip, ':')        THEN 'IPV6'
            ELSE 'IPV4'
        END                                                 AS ip_family,
        COUNT_IF(l.is_success = 'YES')                      AS successful_logins,
        COUNT(DISTINCT TO_DATE(l.event_timestamp))          AS days_seen,
        MAX(l.event_timestamp)                              AS last_seen,
        CASE
            WHEN COUNT_IF(l.is_success = 'YES') = 0                              THEN 'FAILED_ONLY'
            WHEN MAX(l.event_timestamp) < DATEADD('day', -30, CURRENT_TIMESTAMP()) THEN 'STALE'
            WHEN COUNT(DISTINCT TO_DATE(l.event_timestamp)) = 1                  THEN 'ONE_OFF'
            WHEN COUNT(DISTINCT TO_DATE(l.event_timestamp)) >= 3                 THEN 'STABLE'
            ELSE 'REVIEW'
        END                                                 AS review_flag
    FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY AS l
    JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS AS u
      ON u.name = l.user_name AND u.deleted_on IS NULL
    WHERE l.event_timestamp >= DATEADD('day', -$lookback_days, CURRENT_TIMESTAMP())
      AND ARRAY_CONTAINS(COALESCE(u.type, 'NULL')::VARIANT, SPLIT($user_types, ','))
      AND l.user_name LIKE $user_filter
      AND l.client_ip NOT IN ('0.0.0.0', 'INTERNAL_SNOWFLAKE_IP', 'INTERNAL_SNOWFLAKE_IP/0.0.0.0')
    GROUP BY l.user_name, l.client_ip, ip_family
)
SELECT DISTINCT
    user_name,
    'CALL SNOWFLAKE.NETWORK_SECURITY.RECOMMEND_NETWORK_POLICY(LOOKBACK_DAYS => ' || $lookback_days
        || ', USER_NAME => ''' || REPLACE(user_name, '''', '''''') || ''');'              AS advisor_call,
    'CALL SNOWFLAKE.NETWORK_SECURITY.EVALUATE_CANDIDATE_NETWORK_POLICY(POLICY_NAME => '''
        || object_stem || '_NETWORK_POLICY'', LOOKBACK_DAYS => ' || $lookback_days
        || ', USER_NAME => ''' || REPLACE(user_name, '''', '''''') || ''');'              AS dry_run_call
FROM service_user_ips
ORDER BY user_name;
