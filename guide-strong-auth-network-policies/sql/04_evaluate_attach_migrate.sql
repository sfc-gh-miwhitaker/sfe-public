/*==============================================================================
  Strong Auth Network Policies | 04 Dry run, attach, and migrate one user
  Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-09

  INSTRUCTIONS:
    Open Snowsight -> New Worksheet -> Paste this file.
    First time: run it as-is (Run All) against the practice user from
    script 00. For a real account, change the three SET lines below to the
    user, its job role, and the policy you created from script 03, then run
    ONE STEP AT A TIME and read each result before the next.

  ORDER MATTERS:
    A. Inspect      what the user is and what already applies to it
    B. Dry run      would the policy have blocked any real sign-in?
    C. Attach       user-level policy, while the old method still works
    D. Canary       watch for blocked sign-ins for one full job cycle
    E. Credential   PAT (needs the policy) or key pair (does not)
    F. Cut over     TYPE=SERVICE removes password sign-in for good
    G. Verify       the job now signs in with the new method
    Rollback statements for every step are at the end, commented out.

  PREREQUISITES:
    ACCOUNTADMIN, or SECURITYADMIN for policy steps plus OWNERSHIP or
    MODIFY PROGRAMMATIC AUTHENTICATION METHODS on the user for step E.
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

SET svc_user   = 'SFE_NETPOL_PRACTICE_SVC';                -- the service user
SET svc_role   = 'SFE_NETPOL_PRACTICE_ROLE';               -- the one role its job uses
SET svc_policy = 'SFE_NETPOL_PRACTICE_SVC_NETWORK_POLICY'; -- policy from script 03

------------------------------------------------------------------------------
-- A. Inspect. Note TYPE, HAS_PASSWORD, and any NETWORK_POLICY already set.
--    If a user policy exists, you are replacing it: merge its rules first.
------------------------------------------------------------------------------
DESCRIBE USER IDENTIFIER($svc_user);

SELECT "property", "value"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "property" IN ('TYPE', 'HAS_PASSWORD', 'HAS_RSA_PUBLIC_KEY', 'NETWORK_POLICY',
                     'DEFAULT_ROLE', 'DISABLED', 'HAS_PAT', 'HAS_WORKLOAD_IDENTITY');

DESCRIBE NETWORK POLICY IDENTIFIER($svc_policy);

------------------------------------------------------------------------------
-- B. Dry run against this user's real traffic. Every row with
--    IS_ALLOWED = 'NO' is a sign-in that would have failed. Resolve each one
--    (add the owner's range, or confirm it is not legitimate) before step C.
--    An empty result means no ingress was recorded for the user in the window
--    (expected for a brand-new practice user).
------------------------------------------------------------------------------
CALL SNOWFLAKE.NETWORK_SECURITY.EVALUATE_CANDIDATE_NETWORK_POLICY(
    POLICY_NAME   => $svc_policy,
    LOOKBACK_DAYS => 90,
    USER_NAME     => $svc_user);

------------------------------------------------------------------------------
-- C. Attach at the user level. This affects only this user; it overrides
--    the account policy for them. Password sign-in (if any) keeps working,
--    now only from allowlisted addresses.
------------------------------------------------------------------------------
ALTER USER IDENTIFIER($svc_user) SET NETWORK_POLICY = $svc_policy;

SHOW PARAMETERS LIKE 'NETWORK_POLICY' IN USER IDENTIFIER($svc_user);

------------------------------------------------------------------------------
-- D. Canary. Re-run this after each job cycle (LOGIN_HISTORY lags up to
--    2 hours). Any row here is a blocked or failed sign-in after attach.
------------------------------------------------------------------------------
SELECT event_timestamp, client_ip, reported_client_type,
       first_authentication_factor, error_code, error_message
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE user_name = $svc_user
  AND is_success = 'NO'
  AND event_timestamp >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY event_timestamp DESC;

------------------------------------------------------------------------------
-- E. New credential. Option 1, programmatic access token: requires the
--    policy from step C and a role restriction for service users. Copy
--    TOKEN_SECRET from the result now; it is never shown again. Store it in
--    the job's secret manager, not in code.
------------------------------------------------------------------------------
ALTER USER IDENTIFIER($svc_user) ADD PROGRAMMATIC ACCESS TOKEN IF NOT EXISTS SFE_MIGRATION_PAT
    ROLE_RESTRICTION = 'SFE_NETPOL_PRACTICE_ROLE'   -- change to your $svc_role value; this clause takes a literal
    DAYS_TO_EXPIRY   = 90
    COMMENT          = 'Replaces password sign-in. Rotate before expiry.';

-- Option 2, key pair (no network policy requirement; keep the policy anyway):
--   ALTER USER IDENTIFIER($svc_user) SET RSA_PUBLIC_KEY = 'MIIBIjANBgkqh...';
-- Option 3, workload identity federation for jobs running in AWS, Azure,
-- GCP, or with an OIDC issuer: ALTER USER ... SET WORKLOAD_IDENTITY = (...).

------------------------------------------------------------------------------
-- F. Cut over. Update the job to the new credential, confirm it runs, then
--    make the type permanent. TYPE=SERVICE cannot sign in with a password.
------------------------------------------------------------------------------
ALTER USER IDENTIFIER($svc_user) SET TYPE = SERVICE;
ALTER USER IDENTIFIER($svc_user) UNSET PASSWORD;

------------------------------------------------------------------------------
-- G. Verify. The newest successful sign-ins should show the new method
--    (for example PROGRAMMATIC_ACCESS_TOKEN or RSA_KEYPAIR), never PASSWORD.
------------------------------------------------------------------------------
SELECT event_timestamp, client_ip, reported_client_type, first_authentication_factor
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE user_name = $svc_user
  AND is_success = 'YES'
  AND event_timestamp >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY event_timestamp DESC
LIMIT 20;

SHOW USER PROGRAMMATIC ACCESS TOKENS FOR USER IDENTIFIER($svc_user);

/*----------------------------------------------------------------------------
  ROLLBACK (run only the line you need)
    C. ALTER USER IDENTIFIER($svc_user) UNSET NETWORK_POLICY;
       Falls back to the account policy, or to no restriction.
    E. ALTER USER IDENTIFIER($svc_user) REMOVE PROGRAMMATIC ACCESS TOKEN SFE_MIGRATION_PAT;
       By default a SERVICE user can generate and use a PAT only while a
       network policy (user-level or account-level) applies to it.
    F. There is no way back to a password for a SERVICE user, and once your
       account's strong authentication phase is enforced, LEGACY_SERVICE can
       no longer be set. Do not run step F until step G shows the new method.
----------------------------------------------------------------------------*/
