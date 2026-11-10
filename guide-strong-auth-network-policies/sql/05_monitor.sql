/*==============================================================================
  Strong Auth Network Policies | 05 Monitor after enforcement
  Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-09

  INSTRUCTIONS:
    Open Snowsight -> New Worksheet -> Paste this file -> Run All.
    Read-only. Run weekly, or schedule it as an alert (see the README).

  WHAT IT RETURNS:
    1. Sign-ins rejected in the last 7 days, grouped by user, IP, and error.
    2. Service users whose programmatic access tokens expire within 14 days.
       An expired token fails exactly like a blocked IP; rotate early.
    3. Service users still able to sign in with no network policy at all.

  PREREQUISITES:
    ACCOUNTADMIN, or a role granted SNOWFLAKE.SECURITY_VIEWER and
    SNOWFLAKE.GOVERNANCE_VIEWER.
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
-- 1. Rejected sign-ins. A new IP for a known job usually means its host or
--    vendor range changed: add the owner's range to that user's rule.
------------------------------------------------------------------------------
SELECT
    user_name,
    client_ip,
    error_code = 390422   AS blocked_by_network_policy,  -- INCOMING_REQUEST_BLOCKED
    reported_client_type,
    first_authentication_factor,
    error_code,
    error_message,
    COUNT(*)              AS attempts,
    MIN(event_timestamp)  AS first_attempt,
    MAX(event_timestamp)  AS last_attempt
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE event_timestamp >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND is_success = 'NO'
GROUP BY user_name, client_ip, reported_client_type, first_authentication_factor,
         error_code, error_message
ORDER BY blocked_by_network_policy DESC, attempts DESC;

------------------------------------------------------------------------------
-- 2. Tokens expiring soon.
------------------------------------------------------------------------------
SELECT
    user_name,
    name             AS token_name,
    status,
    expiration_date,
    DATEDIFF('day', CURRENT_TIMESTAMP(), expiration_date) AS days_left,
    last_used_on
FROM SNOWFLAKE.ACCOUNT_USAGE.CREDENTIALS
WHERE type = 'PAT'
  AND status = 'ACTIVE'
  AND expiration_date < DATEADD('day', 14, CURRENT_TIMESTAMP())
ORDER BY expiration_date;

------------------------------------------------------------------------------
-- 3. Service users with no user-level policy and no account policy.
------------------------------------------------------------------------------
SELECT u.name AS user_name, u.type, u.has_pat, u.has_rsa_public_key,
       u.has_workload_identity, u.last_success_login
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS AS u
WHERE u.deleted_on IS NULL
  AND u.type IN ('SERVICE', 'LEGACY_SERVICE')
  AND NOT EXISTS (
        SELECT 1 FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES AS p
        WHERE p.policy_kind = 'NETWORK_POLICY'
          AND (p.ref_entity_domain = 'ACCOUNT'
               OR (p.ref_entity_domain = 'USER' AND p.ref_entity_name = u.name)))
ORDER BY u.last_success_login DESC NULLS LAST;
