/*==============================================================================
GOOGLE ADS DATA MANAGER — SNOWFLAKE SOURCE SETUP
Pair-programmed by SE Community + Cortex Code | Expires: 2026-11-28

WHAT THIS IS
  A copy/paste reference for exposing a Snowflake view to the Google Ads Data
  Manager native connector, with least-privilege access and PAT authentication.

  This is NOT an automated deploy script. CREATE ROLE and CREATE USER are
  account-level privileges (ACCOUNTADMIN by default). Read each section, adjust
  identifiers, and run deliberately.

PROVENANCE
  EXECUTED END TO END against a live Snowflake account (v10.30.102) on 2026-08-28,
  then torn down. Every statement below ran successfully, including the PAT with
  no network policy attached. The verification queries in Section 7 were run both
  positive and negative.

  Two defects were found and fixed by that run: Section 7 needs
  USE SECONDARY ROLES NONE (see the note there), and Section 5 needs
  DEFAULT_SECONDARY_ROLES = ().

WHAT GETS CREATED
  Role      GOOGLE_ADS_DM_ROLE
  Warehouse SFE_ADS_ACTIVATION_WH
  Schema    MARKETING.ACTIVATION
  View      V_GOOGLE_CUSTOMER_MATCH  (secure)
  User      GOOGLE_ADS_DM_SVC        (TYPE = SERVICE_AGENT)
  A Programmatic Access Token pinned to GOOGLE_ADS_DM_ROLE

PREREQUISITES
  ACCOUNTADMIN (or CREATE ROLE + CREATE USER + CREATE WAREHOUSE granted).

  A base table holding the customer PII you intend to activate. This file assumes
  MARKETING.CORE.CUSTOMER with columns email_address, phone_e164, first_name,
  last_name, country_code, postal_code, marketing_opt_in, last_activity_date.
  THIS IS THE ONE IDENTIFIER YOU MUST REPLACE with your own table and columns.

AFTER RUNNING
  1. Copy the PAT secret from the Section 5 output. It is shown ONCE.
  2. Copy the account identifier from Section 6.
  3. In Google Ads: Tools -> Data manager -> Connect a source -> Snowflake.
  4. Paste the PAT into the field labeled "password".
  5. Select warehouse, database, schema, and the VIEW (not the base table).
  6. Map columns, set the daily schedule, and run once manually.
==============================================================================*/

-- Identifiers are hardcoded to MARKETING.ACTIVATION throughout so the file is a
-- uniform find-and-replace. Do not reintroduce SET/IDENTIFIER indirection here:
-- only Section 2 could use it, which silently split the schema from the views.


/*==============================================================================
SECTION 1 — WAREHOUSE
  Small on purpose. This is a periodic extract, not analytics. The statement
  timeout is a guardrail against a runaway scan on a PII view.
==============================================================================*/
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS SFE_ADS_ACTIVATION_WH
    WAREHOUSE_SIZE               = 'XSMALL'
    AUTO_SUSPEND                 = 60
    AUTO_RESUME                  = TRUE
    INITIALLY_SUSPENDED          = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 900
    COMMENT = 'Google Ads Data Manager extracts only (Expires: 2026-11-28)';


/*==============================================================================
SECTION 2 — SCHEMA
  A dedicated activation schema keeps the outbound contract separate from the
  models that feed it. Nothing in here should be a base table.
==============================================================================*/
CREATE SCHEMA IF NOT EXISTS MARKETING.ACTIVATION
    COMMENT = 'Outbound ad-platform activation views (Expires: 2026-11-28)';


/*==============================================================================
SECTION 3 — THE CUSTOMER MATCH VIEW

  Google's expected headers contain spaces, so they require double-quoted
  identifiers in Snowflake. That is the main syntax gotcha in this file.

  Headers Google expects (exact, English):
    Email | Phone | First Name | Last Name | Country | Zip | Mobile Device ID

  Notes that change the shape of this view:
    - LET GOOGLE HASH. Data Manager normalizes and SHA-256 hex-hashes for you.
      Send cleartext unless policy forbids it. Section 3b is the opt-out.
    - Country and Zip must NEVER be hashed, in either variant.
    - Mobile Device ID must be the ONLY column if used, and must be unhashed.
    - Model this as the DESIRED CURRENT STATE. Google does not diff runs; the
      documented audience operations are replace / add / remove, so an
      append-only event log is the wrong shape here.
    - Emit ISO dates. Google reads 02/01/2026 as February 1, and a single
      unambiguous DD/MM/YYYY row fails the ENTIRE import by design.
    - Filters belong in Google (1 filter, up to 25 conditions per connection).
      Build one view per USE CASE, not one per audience variant.

  SECURE VIEW is deliberate: it blocks optimizer side channels and hides the
  definition from the consuming role. It also disables some optimizations, so
  a standard view is defensible when the base table is already tightly scoped.
==============================================================================*/
CREATE OR REPLACE SECURE VIEW MARKETING.ACTIVATION.V_GOOGLE_CUSTOMER_MATCH
    COMMENT = 'Google Ads Customer Match source, cleartext (Expires: 2026-11-28)'
AS
SELECT
    -- Normalization here is belt-and-braces; Google normalizes too. It costs
    -- almost nothing and makes the view self-documenting.
    LOWER(TRIM(c.email_address))                    AS "Email",
    c.phone_e164                                    AS "Phone",
    LOWER(TRIM(c.first_name))                       AS "First Name",
    LOWER(TRIM(c.last_name))                        AS "Last Name",
    UPPER(TRIM(c.country_code))                     AS "Country",
    TRIM(c.postal_code)                             AS "Zip"
FROM MARKETING.CORE.CUSTOMER AS c
WHERE c.email_address IS NOT NULL
  AND c.marketing_opt_in = TRUE
  -- Keep the outbound population bounded and current. Google caps membership
  -- at 540 days and needs >= 100 members added/updated in that window to keep
  -- a list eligible, so a rolling window is both cheaper and safer than "all".
  AND c.last_activity_date >= DATEADD('day', -540, CURRENT_DATE());


/*==============================================================================
SECTION 3b — PRE-HASHED VARIANT (only if policy forbids sending cleartext PII)

  Do not deploy both. Pick one.

  VERIFIED BY EXECUTION: SHA2(col, 256) returns a lowercase 64-character hex
  string, which is exactly what Data Manager expects.

  Encoding conflict, resolved: Google's legacy manual-upload page labels its
  examples "Base64 Encoded", but the Data Manager data-prep page specifies hex
  and the Data Manager API rejects anything else with INVALID_HEX_ENCODING.
  For this path, hex is correct. Do not "fix" this to BASE64_ENCODE.
==============================================================================*/
CREATE OR REPLACE SECURE VIEW MARKETING.ACTIVATION.V_GOOGLE_CUSTOMER_MATCH_HASHED
    COMMENT = 'Google Ads Customer Match source, hex SHA-256 (Expires: 2026-11-28)'
AS
WITH normalized AS (
    SELECT
        -- gmail.com / googlemail.com require stripping periods from the local
        -- part before hashing. Other domains must NOT be altered this way.
        CASE
            WHEN SPLIT_PART(LOWER(TRIM(c.email_address)), '@', 2)
                 IN ('gmail.com', 'googlemail.com')
            THEN REGEXP_REPLACE(
                     SPLIT_PART(LOWER(TRIM(c.email_address)), '@', 1), '\\.', '')
                 || '@'
                 || SPLIT_PART(LOWER(TRIM(c.email_address)), '@', 2)
            ELSE LOWER(TRIM(c.email_address))
        END                                          AS email_norm,
        c.phone_e164                                 AS phone_norm,
        LOWER(TRIM(c.first_name))                    AS first_name_norm,
        LOWER(TRIM(c.last_name))                     AS last_name_norm,
        UPPER(TRIM(c.country_code))                  AS country_code,
        TRIM(c.postal_code)                          AS postal_code
    FROM MARKETING.CORE.CUSTOMER AS c
    WHERE c.email_address IS NOT NULL
      AND c.marketing_opt_in = TRUE
      AND c.last_activity_date >= DATEADD('day', -540, CURRENT_DATE())
)
SELECT
    SHA2(n.email_norm, 256)      AS "Email",
    SHA2(n.phone_norm, 256)      AS "Phone",
    SHA2(n.first_name_norm, 256) AS "First Name",
    SHA2(n.last_name_norm, 256)  AS "Last Name",
    n.country_code               AS "Country",   -- never hashed
    n.postal_code                AS "Zip"        -- never hashed
FROM normalized AS n;


/*==============================================================================
SECTION 4 — LEAST-PRIVILEGE ROLE

  Grant SELECT on the SPECIFIC VIEW only. No SELECT ON ALL TABLES, and no
  future grants in this schema — a future grant here would silently expose the
  next object someone creates to an external ad platform.
==============================================================================*/
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS GOOGLE_ADS_DM_ROLE
    COMMENT = 'Google Ads Data Manager read-only source access (Expires: 2026-11-28)';

GRANT USAGE ON WAREHOUSE SFE_ADS_ACTIVATION_WH        TO ROLE GOOGLE_ADS_DM_ROLE;
GRANT USAGE ON DATABASE  MARKETING                    TO ROLE GOOGLE_ADS_DM_ROLE;
GRANT USAGE ON SCHEMA    MARKETING.ACTIVATION         TO ROLE GOOGLE_ADS_DM_ROLE;

GRANT SELECT ON VIEW MARKETING.ACTIVATION.V_GOOGLE_CUSTOMER_MATCH
    TO ROLE GOOGLE_ADS_DM_ROLE;

-- Needed so an operator can actually assume the role in Section 7a and verify
-- the grant chain before Google tries it. Without this, Section 7a silently
-- runs as ACCOUNTADMIN and proves nothing.
GRANT ROLE GOOGLE_ADS_DM_ROLE TO ROLE SYSADMIN;


/*==============================================================================
SECTION 5 — SERVICE USER AND PAT

  WHY TYPE = SERVICE_AGENT, and why this is the crux of the whole integration:

    Google states it reaches Snowflake from Google Cloud IP addresses, and that
    those ranges are "dynamic and subject to change"
    (https://www.gstatic.com/ipranges/cloud.json).

    Snowflake gates PAT auth on a network policy by default. With
    NETWORK_POLICY_EVALUATION = ENFORCED_REQUIRED, a TYPE = SERVICE user cannot
    generate or use a PAT unless it is subject to one.

    Static allowlist versus moving target. SERVICE_AGENT resolves it: this user
    type can generate and use a PAT without being subject to a network policy,
    without setting a bypass flag and without a self-updating firewall job.

  The higher-assurance alternative is a real network policy refreshed from
  Google's published ranges on a schedule. It breaks silently when Google adds
  a range before your job runs. Choose deliberately.

  ROLE_RESTRICTION is not optional here. Google's connector has NO role field,
  so without it the connection runs as the user's default role.

  DEFAULT_SECONDARY_ROLES = () is also not optional, and is easy to miss.
  VERIFIED BY EXECUTION: without it, Snowflake sets the user's secondary roles to
  [ALL], so the identity carries every role granted to it in addition to its
  primary role. On a service identity pointed at a PII view by an external ad
  platform, that silently widens reach beyond what ROLE_RESTRICTION implies.
  An empty list is accepted inline on CREATE USER for TYPE = SERVICE_AGENT.
==============================================================================*/
CREATE USER IF NOT EXISTS GOOGLE_ADS_DM_SVC
    TYPE                    = SERVICE_AGENT
    DEFAULT_ROLE            = GOOGLE_ADS_DM_ROLE
    DEFAULT_SECONDARY_ROLES = ()
    DEFAULT_WAREHOUSE       = SFE_ADS_ACTIVATION_WH
    DEFAULT_NAMESPACE       = MARKETING.ACTIVATION
    COMMENT = 'Google Ads Data Manager connector identity (Expires: 2026-11-28)';

GRANT ROLE GOOGLE_ADS_DM_ROLE TO USER GOOGLE_ADS_DM_SVC;

-- Belt-and-braces: keep PATs for this user off the admin roles entirely.
CREATE AUTHENTICATION POLICY IF NOT EXISTS
    MARKETING.ACTIVATION.GOOGLE_ADS_DM_AUTH_POLICY
    PAT_POLICY = (
        BLOCKED_ROLES_LIST = ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN')
    )
    COMMENT = 'Restrict PAT role reach for ad-platform connectors (Expires: 2026-11-28)';

ALTER USER GOOGLE_ADS_DM_SVC
    SET AUTHENTICATION POLICY MARKETING.ACTIVATION.GOOGLE_ADS_DM_AUTH_POLICY;

/*------------------------------------------------------------------------------
  Generate the PAT.

  OPERATIONAL WARNING: the secret is returned ONCE and cannot be retrieved
  again. Default expiry is 15 days; maximum is 365. Expiry CANNOT be changed
  after creation — you revoke and reissue. Maximum 15 PATs per user.

  DAYS_TO_EXPIRY = 90 below is a deliberate override of the 15-day default: it
  cuts reissue frequency to something a quarterly process can absorb while
  staying well under the 365 maximum. Set your renewal reminder from 90, not 15.

  An expired PAT presents exactly like a broken connector: no error in Google's
  UI beyond a failed run. Set a calendar reminder well inside the expiry window
  and monitor Section 7.
------------------------------------------------------------------------------*/
ALTER USER GOOGLE_ADS_DM_SVC
    ADD PROGRAMMATIC ACCESS TOKEN GOOGLE_ADS_DM_PAT
    ROLE_RESTRICTION = 'GOOGLE_ADS_DM_ROLE'
    DAYS_TO_EXPIRY   = 90
    COMMENT = 'Google Ads Data Manager connector token (Expires: 2026-11-28)';


/*==============================================================================
SECTION 6 — VALUES TO PASTE INTO GOOGLE

  Google asks for the identifier as orgname.account_name. If underscores are
  rejected in its form, replace them with hyphens.
==============================================================================*/
SELECT
    CURRENT_ORGANIZATION_NAME() || '.' || CURRENT_ACCOUNT_NAME()
                                          AS account_identifier,
    REPLACE(CURRENT_ORGANIZATION_NAME() || '.' || CURRENT_ACCOUNT_NAME(), '_', '-')
                                          AS account_identifier_hyphenated,
    'GOOGLE_ADS_DM_SVC'                   AS username,
    'SFE_ADS_ACTIVATION_WH'               AS warehouse,
    'MARKETING'                           AS database_name,
    'ACTIVATION'                          AS schema_name,
    'V_GOOGLE_CUSTOMER_MATCH'             AS object_name,
    'Paste the PAT secret into the field labeled "password"' AS auth_note;


/*==============================================================================
SECTION 7 — VERIFY AND AUDIT

  READ THIS BEFORE RUNNING 7a. `USE ROLE` alone is NOT enough to test least
  privilege, and this is the trap that makes most such tests worthless.

  VERIFIED BY EXECUTION: an interactive user typically has
  DEFAULT_SECONDARY_ROLES = ALL, so the session still carries ACCOUNTADMIN and
  ORGADMIN as SECONDARY roles even after USE ROLE GOOGLE_ADS_DM_ROLE. Under those
  conditions GET_DDL on the secure view SUCCEEDED — the test appeared to pass
  while proving nothing. With USE SECONDARY ROLES NONE it correctly failed with
  "Object does not exist, or operation cannot be performed."

  So: always drop secondary roles first. Check with
  SELECT CURRENT_SECONDARY_ROLES(); it must return an empty value.
==============================================================================*/

-- 7a. Confirm the role can read the view — and only the view.
USE SECONDARY ROLES NONE;   -- mandatory; see the note above
USE ROLE GOOGLE_ADS_DM_ROLE;
USE WAREHOUSE SFE_ADS_ACTIVATION_WH;

SELECT CURRENT_ROLE() AS primary_role, CURRENT_SECONDARY_ROLES() AS must_be_empty;

SELECT COUNT(*) AS activatable_rows
FROM MARKETING.ACTIVATION.V_GOOGLE_CUSTOMER_MATCH;

-- 7b. Row count against Google's documented minimums.
SELECT
    COUNT(*)                            AS row_count,
    COUNT(*) >= 100                     AS meets_100_record_minimum,
    COUNT(*) <= 100000000               AS under_100m_row_limit
FROM MARKETING.ACTIVATION.V_GOOGLE_CUSTOMER_MATCH;

/*------------------------------------------------------------------------------
  7b-i. NEGATIVE TESTS — the half people skip. All three MUST fail.
  VERIFIED BY EXECUTION: each raised the error shown.

    -- "Schema 'MARKETING.CORE' does not exist or not authorized."
    SELECT COUNT(*) FROM MARKETING.CORE.CUSTOMER;

    -- "Object '...V_GOOGLE_CUSTOMER_MATCH_HASHED' does not exist or not
    -- authorized."  (proves you granted the ONE view, not the schema)
    SELECT COUNT(*) FROM MARKETING.ACTIVATION.V_GOOGLE_CUSTOMER_MATCH_HASHED;

    -- "Object does not exist, or operation cannot be performed."
    -- (proves SECURE VIEW is hiding the definition and the base table name)
    SELECT GET_DDL('VIEW','MARKETING.ACTIVATION.V_GOOGLE_CUSTOMER_MATCH');

  If any of these SUCCEEDS, you have leftover secondary roles or an over-broad
  grant. Do not hand the PAT to Google until all three fail.
------------------------------------------------------------------------------*/

USE ROLE ACCOUNTADMIN;  -- 7c onward need account-level visibility again

-- 7c. Did the connector actually authenticate, and with what?
--     PROGRAMMATIC_ACCESS_TOKEN is the value to look for. Anything else means
--     something other than the connector is using this identity.
--     Note: this function covers only the last 7 days, and its own arguments
--     filter before any outer WHERE.
SELECT
    event_timestamp,
    first_authentication_factor,
    is_success,
    error_message,
    client_ip
FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.LOGIN_HISTORY_BY_USER(
    USER_NAME    => 'GOOGLE_ADS_DM_SVC',
    RESULT_LIMIT => 100))
ORDER BY event_timestamp DESC;

-- 7d. What did the connector read? Bounded to 7 days on purpose —
--     QUERY_HISTORY is large; tune the window rather than dropping the bound.
SELECT
    q.start_time,
    q.role_name,
    q.warehouse_name,
    q.execution_status,
    q.total_elapsed_time / 1000 AS elapsed_seconds,
    q.rows_produced,
    q.query_text
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY AS q
WHERE q.user_name  = 'GOOGLE_ADS_DM_SVC'
  AND q.start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY q.start_time DESC
LIMIT 100;

-- 7e. PAT inventory and expiry. Run this on a schedule — a silently expired
--     PAT is the most likely cause of "the connector stopped working".
--     Note the leading USER keyword; SHOW PROGRAMMATIC ACCESS TOKENS is a
--     syntax error.
--     Check mins_to_bypass_network_policy_requirement: on a SERVICE_AGENT it
--     reads None, which is the confirmation that no network policy was needed.
SHOW USER PROGRAMMATIC ACCESS TOKENS FOR USER GOOGLE_ADS_DM_SVC;

SELECT "name", "role_restriction", "expires_at", "status",
       "mins_to_bypass_network_policy_requirement"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));


/*==============================================================================
SECTION 8 — TEARDOWN
  Ordered so nothing is left orphaned. Does not touch the base table.
==============================================================================*/
-- USE ROLE ACCOUNTADMIN;
--
-- ALTER USER GOOGLE_ADS_DM_SVC
--     REMOVE PROGRAMMATIC ACCESS TOKEN GOOGLE_ADS_DM_PAT;
-- ALTER USER GOOGLE_ADS_DM_SVC UNSET AUTHENTICATION POLICY;
-- DROP AUTHENTICATION POLICY IF EXISTS
--     MARKETING.ACTIVATION.GOOGLE_ADS_DM_AUTH_POLICY;
-- DROP USER IF EXISTS GOOGLE_ADS_DM_SVC;
-- DROP VIEW IF EXISTS MARKETING.ACTIVATION.V_GOOGLE_CUSTOMER_MATCH;
-- DROP VIEW IF EXISTS MARKETING.ACTIVATION.V_GOOGLE_CUSTOMER_MATCH_HASHED;
-- REVOKE ROLE GOOGLE_ADS_DM_ROLE FROM ROLE SYSADMIN;
-- DROP ROLE IF EXISTS GOOGLE_ADS_DM_ROLE;
-- DROP WAREHOUSE IF EXISTS SFE_ADS_ACTIVATION_WH;
--
-- Drop the schema ONLY if no other activation views live in it.
-- DROP SCHEMA IF EXISTS MARKETING.ACTIVATION;
--
-- Remember to remove the connection in Google Ads as well. Dropping the
-- Snowflake side leaves a broken connection in the Data Manager UI.
