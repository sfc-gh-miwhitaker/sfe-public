/*==============================================================================
  Strong Auth Network Policies | 02 Inventory client IPs per user
  Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-09

  INSTRUCTIONS:
    Open Snowsight -> New Worksheet -> Paste this file -> Run All.
    Read-only. Runtime: under a minute on most accounts.
    The defaults cover every SERVICE and LEGACY_SERVICE user over 90 days.
    Optional: change lookback_days (max 365), user_filter (a LIKE pattern),
    or user_types. Needs only a running warehouse; creates nothing.

  WHAT IT RETURNS:
    1. One row per user and client IP with a REVIEW_FLAG for each address.
    2. IPv4 addresses rolled up to /24 so you can spot one network that
       shows up as many addresses (ask its owner for the real range).
    3. Failed sign-ins by IP. Review these; never allowlist them blindly.

  PREREQUISITES:
    ACCOUNTADMIN, or a role granted SNOWFLAKE.SECURITY_VIEWER.
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

SET lookback_days = 90;   -- Include at least one full cycle of your slowest job (monthly, quarterly).
SET user_filter   = '%';  -- LIKE pattern, for example 'ETL_%'.
SET user_types    = 'SERVICE,LEGACY_SERVICE';  -- Add ',NULL' to include users whose TYPE was never set.
                                               -- Use it for accounts flagged UNTYPED_LIKELY_SERVICE by script 01.

------------------------------------------------------------------------------
-- Base: successful and failed sign-ins for service users, with Snowflake
-- internal traffic removed. Snowsight worksheets and Snowpark Container
-- Services logins report INTERNAL_SNOWFLAKE_IP / 0.0.0.0; never allowlist it.
------------------------------------------------------------------------------
-- (Each query below repeats this base as a CTE so the script needs no
-- database context and creates no objects.)

------------------------------------------------------------------------------
-- 1. Per-user IP inventory with a review flag.
--    STABLE      seen on 3+ days, most recently in the last 30 days
--    STALE       not seen in 30 days; confirm the job still exists
--    ONE_OFF     seen on a single day; often a laptop or a test
--    FAILED_ONLY never succeeded; do not allowlist without an owner
------------------------------------------------------------------------------
WITH service_user_logins AS (
    SELECT
        l.user_name,
        u.type                                   AS user_type,
        l.event_timestamp,
        l.client_ip,
        CASE
            WHEN l.client_private_link_id IS NOT NULL THEN 'PRIVATELINK'
            WHEN CONTAINS(l.client_ip, ':')        THEN 'IPV6'
            ELSE 'IPV4'
        END                                      AS ip_family,
        l.client_private_link_id,
        l.reported_client_type,
        l.first_authentication_factor,
        l.is_success,
        l.error_code,
        l.error_message
    FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY AS l
    JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS AS u
      ON u.name = l.user_name AND u.deleted_on IS NULL
    WHERE l.event_timestamp >= DATEADD('day', -$lookback_days, CURRENT_TIMESTAMP())
      AND ARRAY_CONTAINS(COALESCE(u.type, 'NULL')::VARIANT, SPLIT($user_types, ','))
      AND l.user_name LIKE $user_filter
      AND l.client_ip NOT IN ('0.0.0.0', 'INTERNAL_SNOWFLAKE_IP', 'INTERNAL_SNOWFLAKE_IP/0.0.0.0')
)
SELECT
    user_name,
    user_type,
    client_ip,
    ip_family,
    client_private_link_id,
    COUNT_IF(is_success = 'YES')                         AS successful_logins,
    COUNT_IF(is_success = 'NO')                          AS failed_logins,
    COUNT(DISTINCT TO_DATE(event_timestamp))             AS days_seen,
    MIN(event_timestamp)                                 AS first_seen,
    MAX(event_timestamp)                                 AS last_seen,
    ARRAY_AGG(DISTINCT reported_client_type)             AS client_types,
    ARRAY_AGG(DISTINCT first_authentication_factor)      AS auth_methods,
    CASE
        WHEN COUNT_IF(is_success = 'YES') = 0                          THEN 'FAILED_ONLY'
        WHEN MAX(event_timestamp) < DATEADD('day', -30, CURRENT_TIMESTAMP()) THEN 'STALE'
        WHEN COUNT(DISTINCT TO_DATE(event_timestamp)) = 1              THEN 'ONE_OFF'
        WHEN COUNT(DISTINCT TO_DATE(event_timestamp)) >= 3             THEN 'STABLE'
        ELSE 'REVIEW'
    END                                                  AS review_flag
FROM service_user_logins
GROUP BY user_name, user_type, client_ip, ip_family, client_private_link_id
ORDER BY user_name, review_flag, successful_logins DESC;

------------------------------------------------------------------------------
-- 2. IPv4 /24 rollup. Many addresses inside one /24 usually means a cloud
--    NAT pool or vendor range: get the published CIDR from its owner rather
--    than allowlisting today's addresses one by one.
------------------------------------------------------------------------------
WITH service_user_logins AS (
    SELECT
        l.user_name,
        u.type                                   AS user_type,
        l.event_timestamp,
        l.client_ip,
        CASE
            WHEN l.client_private_link_id IS NOT NULL THEN 'PRIVATELINK'
            WHEN CONTAINS(l.client_ip, ':')        THEN 'IPV6'
            ELSE 'IPV4'
        END                                      AS ip_family,
        l.client_private_link_id,
        l.reported_client_type,
        l.first_authentication_factor,
        l.is_success,
        l.error_code,
        l.error_message
    FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY AS l
    JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS AS u
      ON u.name = l.user_name AND u.deleted_on IS NULL
    WHERE l.event_timestamp >= DATEADD('day', -$lookback_days, CURRENT_TIMESTAMP())
      AND ARRAY_CONTAINS(COALESCE(u.type, 'NULL')::VARIANT, SPLIT($user_types, ','))
      AND l.user_name LIKE $user_filter
      AND l.client_ip NOT IN ('0.0.0.0', 'INTERNAL_SNOWFLAKE_IP', 'INTERNAL_SNOWFLAKE_IP/0.0.0.0')
)
SELECT
    user_name,
    SPLIT_PART(client_ip, '.', 1) || '.' || SPLIT_PART(client_ip, '.', 2) || '.'
        || SPLIT_PART(client_ip, '.', 3) || '.0/24'      AS ipv4_slash_24,
    COUNT(DISTINCT client_ip)                            AS distinct_addresses,
    COUNT_IF(is_success = 'YES')                         AS successful_logins,
    MAX(event_timestamp)                                 AS last_seen
FROM service_user_logins
WHERE ip_family = 'IPV4'
GROUP BY user_name, ipv4_slash_24
HAVING COUNT(DISTINCT client_ip) > 1
ORDER BY distinct_addresses DESC;

------------------------------------------------------------------------------
-- 3. Failed sign-ins by IP and reason. Credential stuffing, a broken job,
--    and an old server all look alike here; each needs an owner's answer.
------------------------------------------------------------------------------
WITH service_user_logins AS (
    SELECT
        l.user_name,
        u.type                                   AS user_type,
        l.event_timestamp,
        l.client_ip,
        CASE
            WHEN l.client_private_link_id IS NOT NULL THEN 'PRIVATELINK'
            WHEN CONTAINS(l.client_ip, ':')        THEN 'IPV6'
            ELSE 'IPV4'
        END                                      AS ip_family,
        l.client_private_link_id,
        l.reported_client_type,
        l.first_authentication_factor,
        l.is_success,
        l.error_code,
        l.error_message
    FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY AS l
    JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS AS u
      ON u.name = l.user_name AND u.deleted_on IS NULL
    WHERE l.event_timestamp >= DATEADD('day', -$lookback_days, CURRENT_TIMESTAMP())
      AND ARRAY_CONTAINS(COALESCE(u.type, 'NULL')::VARIANT, SPLIT($user_types, ','))
      AND l.user_name LIKE $user_filter
      AND l.client_ip NOT IN ('0.0.0.0', 'INTERNAL_SNOWFLAKE_IP', 'INTERNAL_SNOWFLAKE_IP/0.0.0.0')
)
SELECT
    user_name,
    client_ip,
    error_code,
    error_message,
    COUNT(*)              AS attempts,
    MAX(event_timestamp)  AS last_attempt
FROM service_user_logins
WHERE is_success = 'NO'
GROUP BY user_name, client_ip, error_code, error_message
ORDER BY attempts DESC;
