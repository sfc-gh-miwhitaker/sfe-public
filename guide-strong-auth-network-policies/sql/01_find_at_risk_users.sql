/*==============================================================================
  Strong Auth Network Policies | 01 Find at-risk users
  Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-09

  INSTRUCTIONS:
    Open Snowsight -> New Worksheet -> Paste this file -> Run All.
    Read-only. Runtime: under a minute. No values to edit.

  WHAT IT RETURNS (one result grid per query):
    1. Every active user that still needs a strong-authentication decision,
       with the action this guide recommends.
    2. Password sign-ins in the last 90 days, by user and client, so you can
       see which tools still depend on a password.
    3. Where network policies are already active (account and users).

  PREREQUISITES:
    ACCOUNTADMIN, or a role granted SNOWFLAKE.SECURITY_VIEWER and
    SNOWFLAKE.GOVERNANCE_VIEWER. ACCOUNT_USAGE views lag up to 2 hours.
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

------------------------------------------------------------------------------
-- 1. Users that need a decision before strong authentication is enforced.
--    TYPE NULL is treated as PERSON. SERVICE users already cannot use a
--    password; they appear here only when no network policy covers them,
--    because a programmatic access token (PAT) needs one by default.
------------------------------------------------------------------------------
WITH user_policies AS (
    SELECT ref_entity_name AS user_name, policy_name
    FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES
    WHERE policy_kind = 'NETWORK_POLICY'
      AND ref_entity_domain = 'USER'
),
account_policy AS (
    SELECT MAX(policy_name) AS policy_name
    FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES
    WHERE policy_kind = 'NETWORK_POLICY'
      AND ref_entity_domain = 'ACCOUNT'
),
classified AS (
SELECT
    u.name                                   AS user_name,
    COALESCE(u.type, 'PERSON (unset)')       AS user_type,
    u.has_password,
    u.has_mfa,
    u.has_rsa_public_key,
    u.has_pat,
    u.has_workload_identity,
    u.last_success_login,
    up.policy_name                           AS user_network_policy,
    ap.policy_name                           AS account_network_policy,
    CASE
        WHEN u.type = 'LEGACY_SERVICE'
            THEN '1. Migrate to TYPE=SERVICE with key pair, workload identity, or PAT plus network policy'
        WHEN u.type = 'SERVICE' AND up.policy_name IS NULL AND ap.policy_name IS NULL
             AND u.has_rsa_public_key IS DISTINCT FROM TRUE AND u.has_workload_identity IS DISTINCT FROM TRUE
            THEN '2. SERVICE user with no credential and no network policy: PAT is blocked until a policy covers it'
        WHEN COALESCE(u.type, 'PERSON') = 'PERSON' AND u.has_password AND NOT u.has_mfa
            THEN '3. Human password user without MFA: enroll in MFA or move to SSO'
        ELSE 'OK'
    END AS recommended_action
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS AS u
LEFT JOIN user_policies AS up ON up.user_name = u.name
CROSS JOIN account_policy AS ap
WHERE u.deleted_on IS NULL
  AND COALESCE(u.disabled::BOOLEAN, FALSE) = FALSE
  AND COALESCE(u.type, 'PERSON') IN ('PERSON', 'LEGACY_SERVICE', 'SERVICE')
)
SELECT user_name, user_type, has_password, has_mfa, has_rsa_public_key, has_pat,
       has_workload_identity, last_success_login, user_network_policy,
       account_network_policy, recommended_action
FROM classified
WHERE recommended_action <> 'OK'
ORDER BY recommended_action, user_name;

------------------------------------------------------------------------------
-- 2. Password sign-ins in the last 90 days. These users and clients break
--    on enforcement day unless they move off single-factor passwords.
------------------------------------------------------------------------------
SELECT
    l.user_name,
    COALESCE(u.type, 'PERSON (unset)')       AS user_type,
    l.reported_client_type,
    l.second_authentication_factor,
    COUNT(*)                                 AS password_logins,
    COUNT(DISTINCT l.client_ip)              AS distinct_ips,
    MIN(l.event_timestamp)                   AS first_seen,
    MAX(l.event_timestamp)                   AS last_seen
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY AS l
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS AS u
       ON u.name = l.user_name AND u.deleted_on IS NULL
WHERE l.event_timestamp >= DATEADD('day', -90, CURRENT_TIMESTAMP())
  AND l.is_success = 'YES'
  AND l.first_authentication_factor = 'PASSWORD'
GROUP BY l.user_name, user_type, l.reported_client_type, l.second_authentication_factor
ORDER BY (l.second_authentication_factor IS NULL) DESC, password_logins DESC;

------------------------------------------------------------------------------
-- 2b. Users whose TYPE was never set but who sign in only from drivers or
--     connectors, never from Snowsight. These are usually service accounts
--     that Snowflake treats as people, so enforcement will demand MFA from
--     them. Set TYPE first; that decides which path they take.
------------------------------------------------------------------------------
SELECT
    l.user_name                              AS untyped_likely_service,
    ARRAY_AGG(DISTINCT l.reported_client_type) AS client_types,
    ARRAY_AGG(DISTINCT l.first_authentication_factor) AS auth_methods,
    COUNT(*)                                 AS logins_90d,
    MAX(l.event_timestamp)                   AS last_seen
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY AS l
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS AS u
  ON u.name = l.user_name AND u.deleted_on IS NULL
WHERE l.event_timestamp >= DATEADD('day', -90, CURRENT_TIMESTAMP())
  AND l.is_success = 'YES'
  AND u.type IS NULL
GROUP BY l.user_name
HAVING COUNT_IF(l.reported_client_type = 'SNOWFLAKE_UI') = 0
ORDER BY logins_90d DESC;

------------------------------------------------------------------------------
-- 3. Network policies already active. A user-level policy REPLACES the
--    account policy for that user; it does not add to it.
------------------------------------------------------------------------------
SELECT
    ref_entity_domain AS applied_to,
    ref_entity_name   AS entity,
    policy_db,
    policy_schema,
    policy_name,
    policy_status
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES
WHERE policy_kind = 'NETWORK_POLICY'
ORDER BY applied_to, entity;
