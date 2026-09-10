/* Cross-platform AI spend consolidation — landing layer
   Pair-programmed by SE Community + Cortex Code
   Expires: 2027-03-10

   Creates the role, database, four schemas, warehouse, stage, and the four control
   tables. Run this first. It creates no external connectivity and pulls no data.

   The four schemas map to the four jobs:
     CONTROL  registry, run log, identity spine, seat entitlement
     RAW      immutable vendor payloads exactly as returned
     SHAPED   the unified fact, one row per person per platform per day
     GOLD     the reporting layer the agent and dashboards read
*/

USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS AI_SPEND_RL
  COMMENT = 'Owns the cross-platform AI usage and cost consolidation pipeline';
GRANT ROLE AI_SPEND_RL TO ROLE SYSADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE AI_SPEND_RL;

/* The Snowflake-native adapter reads SNOWFLAKE.ACCOUNT_USAGE. This grant is what makes
   sql/05_snowflake_native.sql work with no external credential at all. */
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE AI_SPEND_RL;

CREATE DATABASE IF NOT EXISTS AI_SPEND
  COMMENT = 'Cross-platform AI usage and cost consolidation';
CREATE SCHEMA IF NOT EXISTS AI_SPEND.CONTROL;
CREATE SCHEMA IF NOT EXISTS AI_SPEND.RAW;
CREATE SCHEMA IF NOT EXISTS AI_SPEND.SHAPED;
CREATE SCHEMA IF NOT EXISTS AI_SPEND.GOLD;

CREATE WAREHOUSE IF NOT EXISTS AI_SPEND_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 3600
  COMMENT = 'Vendor admin API pulls, normalization, and Dynamic Table refresh';

GRANT USAGE, OPERATE ON WAREHOUSE AI_SPEND_WH TO ROLE AI_SPEND_RL;

GRANT OWNERSHIP ON DATABASE AI_SPEND TO ROLE AI_SPEND_RL COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SCHEMA AI_SPEND.CONTROL TO ROLE AI_SPEND_RL COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SCHEMA AI_SPEND.RAW TO ROLE AI_SPEND_RL COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SCHEMA AI_SPEND.SHAPED TO ROLE AI_SPEND_RL COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SCHEMA AI_SPEND.GOLD TO ROLE AI_SPEND_RL COPY CURRENT GRANTS;

USE ROLE AI_SPEND_RL;
USE WAREHOUSE AI_SPEND_WH;

-- ---------------------------------------------------------------------------
-- Stage and file format
-- ---------------------------------------------------------------------------

CREATE STAGE IF NOT EXISTS AI_SPEND.RAW.AI_USAGE_STAGE
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Immutable vendor admin API responses, partitioned platform/report/date';

CREATE FILE FORMAT IF NOT EXISTS AI_SPEND.RAW.JSONL_FORMAT
  TYPE = JSON
  STRIP_OUTER_ARRAY = FALSE
  COMMENT = 'NDJSON: one vendor record per line';

-- ---------------------------------------------------------------------------
-- CONTROL 1: platform registry
--
-- Declares each platform once: how it bills, what unit it reports, what kind of
-- subject key it uses, and — honestly — what grain it can actually deliver.
-- The capability flags are consumed by the monitoring layer so a report can say
-- "this platform cannot answer that" instead of rendering an empty panel.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS AI_SPEND.CONTROL.PLATFORM_REGISTRY (
  PLATFORM_KEY          VARCHAR(64)  NOT NULL,
  DISPLAY_NAME          VARCHAR(128) NOT NULL,
  -- Which contract and meter this platform's rows bill against. ChatGPT Enterprise
  -- and the OpenAI API Platform are separate contexts and must never be summed.
  BILLING_CONTEXT       VARCHAR(64)  NOT NULL,
  -- METERED: cost varies with consumption. SEAT: fixed per licensed person.
  -- Never sum cost_amount across these two without going through GOLD.AI_SPEND_ALLOCATED.
  --
  -- THIS DESCRIBES THE USAGE ROWS, NOT THE WHOLE CONTRACT. Several platforms here are
  -- both: a seat fee plus metered consumption. Those register as METERED, because that
  -- is what their usage rows measure, and their seat fee goes in SEAT_ENTITLEMENT.
  -- GitHub Copilot, Cursor, and Anthropic Claude Enterprise are all in this shape.
  COST_MODEL            VARCHAR(16)  NOT NULL,
  -- The vendor's own unit, preserved rather than converted: CREDITS, TOKENS,
  -- MESSAGES, AI_UNITS, INTERACTIONS, ACTIVE_DAYS, FEATURE_EVENTS, IDE_INTERACTIONS.
  -- Box's AI_UNIT is a vendor-proprietary composite and means nothing outside Box --
  -- which is exactly why native units are never converted into each other.
  NATIVE_UNIT           VARCHAR(32)  NOT NULL,
  -- What the vendor calls a person: SNOWFLAKE_USER_ID, GITHUB_LOGIN, EMAIL,
  -- WORKSPACE_MEMBER_ID, PSEUDONYMIZED_UPN, API_KEY_ID, PROJECT_LABEL.
  --
  -- API_KEY_ID and PROJECT_LABEL are not people. They are recorded honestly so the
  -- monitoring layer can say a platform has no user grain rather than implying one.
  SUBJECT_KEY_KIND      VARCHAR(32)  NOT NULL,
  CREDENTIAL_OBJECT_FQN VARCHAR(255),
  -- Honest capability declaration. FALSE here is a feature, not a gap to hide.
  SUPPORTS_USER_GRAIN   BOOLEAN      NOT NULL DEFAULT FALSE,
  SUPPORTS_USER_COST    BOOLEAN      NOT NULL DEFAULT FALSE,
  -- Expected freshness. Drives the staleness check in V_PIPELINE_HEALTH.
  EXPECTED_LAG_HOURS    NUMBER       NOT NULL DEFAULT 48,
  IS_ACTIVE             BOOLEAN      NOT NULL DEFAULT FALSE,
  NOTES                 VARCHAR,
  CREATED_AT            TIMESTAMP_TZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  CONSTRAINT PK_PLATFORM_REGISTRY PRIMARY KEY (PLATFORM_KEY),
  CONSTRAINT CK_COST_MODEL CHECK (COST_MODEL IN ('METERED', 'SEAT'))
);

-- ---------------------------------------------------------------------------
-- CONTROL 2: pull run log
--
-- Watermark source and failure record. Adapters write here on BOTH the success and
-- the exception path -- without failure rows you cannot distinguish "no usage
-- yesterday" from "this adapter has been dead for a week".
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS AI_SPEND.CONTROL.PULL_RUN_LOG (
  RUN_ID          VARCHAR(36) NOT NULL,
  PLATFORM_KEY    VARCHAR(64) NOT NULL,
  REPORT_NAME     VARCHAR(64) NOT NULL,
  STARTED_AT      TIMESTAMP_TZ NOT NULL,
  COMPLETED_AT    TIMESTAMP_TZ,
  STATUS          VARCHAR(32) NOT NULL,
  FILE_NAME       VARCHAR,
  RECORDS_FETCHED NUMBER,
  ROWS_LOADED     NUMBER,
  WATERMARK_FROM  TIMESTAMP_TZ,
  WATERMARK_TO    TIMESTAMP_TZ,
  -- Python exception class name. Makes credential failures, rate limits, and schema
  -- drift separable in a GROUP BY rather than buried in a message string.
  ERROR_CLASS     VARCHAR,
  ERROR_MESSAGE   VARCHAR,
  QUERY_ID        VARCHAR
);

-- ---------------------------------------------------------------------------
-- CONTROL 3: identity map -- the spine
--
-- Seeded from your IdP or HR system, NEVER from an AI vendor. One row per
-- (platform, subject_key). PERSON_KEY is the stable cross-platform identifier;
-- corporate email is the usual choice.
--
-- CONFIDENCE is not decoration. A department allocation built on heuristic matches
-- should be visibly built on heuristic matches.
--   VERIFIED   provisioned from IdP/SCIM or an authoritative export
--   ASSERTED   admin-maintained mapping, plausible but unprovisioned
--   HEURISTIC  inferred, e.g. email local-part matched to a GitHub login
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS AI_SPEND.CONTROL.IDENTITY_MAP (
  PLATFORM_KEY   VARCHAR(64)  NOT NULL,
  SUBJECT_KEY    VARCHAR(255) NOT NULL,
  PERSON_KEY     VARCHAR(255) NOT NULL,
  DISPLAY_NAME   VARCHAR(255),
  DEPARTMENT     VARCHAR(128),
  COST_CENTER    VARCHAR(64),
  BUSINESS_UNIT  VARCHAR(128),
  MANAGER_KEY    VARCHAR(255),
  CONFIDENCE     VARCHAR(16)  NOT NULL DEFAULT 'ASSERTED',
  VALID_FROM     DATE         NOT NULL DEFAULT '1900-01-01',
  VALID_TO       DATE         NOT NULL DEFAULT '9999-12-31',
  UPDATED_AT     TIMESTAMP_TZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  CONSTRAINT PK_IDENTITY_MAP PRIMARY KEY (PLATFORM_KEY, SUBJECT_KEY, VALID_FROM),
  CONSTRAINT CK_CONFIDENCE CHECK (CONFIDENCE IN ('VERIFIED', 'ASSERTED', 'HEURISTIC'))
);

-- ---------------------------------------------------------------------------
-- CONTROL 4: seat entitlement
--
-- Where SEAT cost lives, deliberately outside the usage fact. A seat costs the same
-- whether the person used it 400 times or zero times, so it is an attribute of the
-- month and the person, not of an activity row.
--
-- This table is what answers the highest-value question in the whole project:
-- which licenses are we paying for that nobody touches.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS AI_SPEND.CONTROL.SEAT_ENTITLEMENT (
  PLATFORM_KEY      VARCHAR(64)  NOT NULL,
  PERSON_KEY        VARCHAR(255) NOT NULL,
  PERIOD_MONTH      DATE         NOT NULL,   -- first day of the month
  SEAT_MONTHLY_COST NUMBER(38,4) NOT NULL,
  CURRENCY_CODE     VARCHAR(3)   NOT NULL DEFAULT 'USD',
  ASSIGNED_AT       TIMESTAMP_TZ,
  -- Sourced from the vendor's licensing API, which is usually a DIFFERENT endpoint
  -- from its usage API. GitHub is the clearest example of that split.
  IS_ACTIVE_IN_PERIOD BOOLEAN    NOT NULL DEFAULT TRUE,
  SOURCE_NAME       VARCHAR(64),
  CAPTURED_AT       TIMESTAMP_TZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  CONSTRAINT PK_SEAT_ENTITLEMENT PRIMARY KEY (PLATFORM_KEY, PERSON_KEY, PERIOD_MONTH)
);

-- ---------------------------------------------------------------------------
-- CONTROL 5: platform rate
--
-- Converts a vendor's native quantity into currency. Kept as a dated table rather
-- than a constant because rates are contractual, discounted off list, and change
-- at renewal -- and because a historical report must use the rate that applied on
-- the day, not today's rate.
--
-- This is the ONLY place native-unit-to-currency conversion happens. Adapters must
-- not do it (see docs/adapter-contract.md), or you end up with two rates in two
-- places and no way to tell which produced a given number.
--
-- No default rows are seeded. A missing rate makes COST_AMOUNT fall back to the raw
-- native quantity, which is visibly wrong in a currency column and prompts someone
-- to enter the real rate. A plausible list-price default would instead produce a
-- confidently wrong forecast that nobody questions.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS AI_SPEND.CONTROL.PLATFORM_RATE (
  PLATFORM_KEY  VARCHAR(64)  NOT NULL,
  -- Currency per one NATIVE_UNIT, e.g. dollars per Snowflake credit or per
  -- GitHub AI credit. Your negotiated rate, not list price.
  UNIT_COST     NUMBER(38,10) NOT NULL,
  CURRENCY_CODE VARCHAR(3)   NOT NULL DEFAULT 'USD',
  VALID_FROM    DATE         NOT NULL DEFAULT '1900-01-01',
  VALID_TO      DATE         NOT NULL DEFAULT '9999-12-31',
  SOURCE_NOTE   VARCHAR,
  UPDATED_AT    TIMESTAMP_TZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  CONSTRAINT PK_PLATFORM_RATE PRIMARY KEY (PLATFORM_KEY, VALID_FROM)
);

/* Populate with your actual contracted rates before presenting any currency
   figure. Example shape only -- these numbers are placeholders.

   CRITICAL WHEN A RATE CHANGES: close the prior row's VALID_TO in the SAME
   statement. VALID_TO defaults to 9999-12-31, so simply inserting a second row
   leaves TWO rows matching every later date. sql/06 resolves that to the latest
   row rather than fanning out, but leaving overlaps in place makes the table
   misleading to read and one careless direct join doubles every cost.

     -- First rate
     INSERT INTO AI_SPEND.CONTROL.PLATFORM_RATE
       (PLATFORM_KEY, UNIT_COST, CURRENCY_CODE, VALID_FROM, SOURCE_NOTE)
     VALUES
       ('SNOWFLAKE_CORTEX', 0.0000, 'USD', '2026-01-01', 'Effective credit rate'),
       ('GITHUB_COPILOT',   0.0000, 'USD', '2026-01-01', 'Per AI credit, contracted');

     -- Rate change at renewal: close the old row FIRST, then insert the new one.
     UPDATE AI_SPEND.CONTROL.PLATFORM_RATE
        SET VALID_TO = '2026-06-30', UPDATED_AT = CURRENT_TIMESTAMP()
      WHERE PLATFORM_KEY = 'GITHUB_COPILOT' AND VALID_TO = '9999-12-31';

     INSERT INTO AI_SPEND.CONTROL.PLATFORM_RATE
       (PLATFORM_KEY, UNIT_COST, CURRENCY_CODE, VALID_FROM, SOURCE_NOTE)
     VALUES
       ('GITHUB_COPILOT', 0.0000, 'USD', '2026-07-01', 'Renewal rate');

   The same discipline applies to IDENTITY_MAP when a person changes department.
*/

-- ---------------------------------------------------------------------------
-- RAW: the landing table
--
-- RECORD holds the vendor payload with NO transformation. Not renamed, not cast,
-- not pruned. That is what lets a shredding bug be fixed with CREATE OR REPLACE
-- instead of a re-pull from an API with short retention.
--
-- CHANGE_TRACKING is on because the SHAPED layer is an incremental Dynamic Table.
--
-- DELIBERATELY NO CHECK CONSTRAINTS ON THIS TABLE. Snowflake enforces CHECK
-- constraints on INSERT/UPDATE/MERGE/CTAS, but COPY INTO a table that has one
-- FAILS outright -- and every adapter loads here via COPY INTO. Validation for
-- this table belongs in the adapter's shape assertion and in the SHAPED layer.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS AI_SPEND.RAW.LANDING_AI_USAGE (
  PLATFORM_KEY      VARCHAR(64)  NOT NULL,
  REPORT_NAME       VARCHAR(64)  NOT NULL,
  BILLING_CONTEXT   VARCHAR(64)  NOT NULL,
  PULLED_AT         TIMESTAMP_TZ NOT NULL,
  SOURCE_FILE       VARCHAR      NOT NULL,
  SOURCE_ROW_NUMBER NUMBER       NOT NULL,
  RECORD            VARIANT      NOT NULL,
  LOADED_AT         TIMESTAMP_TZ NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
CHANGE_TRACKING = TRUE
COMMENT = 'Immutable vendor admin API records, one row per vendor record';

-- ---------------------------------------------------------------------------
-- Seed the registry
--
-- Every row ships IS_ACTIVE = FALSE. Nothing pulls until someone turns it on, so a
-- half-configured adapter cannot start writing.
--
-- The capability flags below are the honest answers as of the expiry date on this
-- file. Re-verify them -- these are exactly the facts vendors change.
-- ---------------------------------------------------------------------------

MERGE INTO AI_SPEND.CONTROL.PLATFORM_REGISTRY AS tgt
USING (
  SELECT * FROM VALUES
    ('SNOWFLAKE_CORTEX', 'Snowflake Cortex', 'SNOWFLAKE_ACCOUNT', 'METERED',
     'CREDITS', 'SNOWFLAKE_USER_ID', NULL, TRUE, TRUE, 24,
     'ACCOUNT_USAGE only, no external credential. Four views with inconsistent columns: Cortex Code reports USAGE_TIME not START_TIME and carries no USER_NAME.'),
    ('GITHUB_COPILOT', 'GitHub Copilot', 'GITHUB_ENTERPRISE', 'METERED',
     'AI_CREDITS', 'GITHUB_LOGIN', 'AI_SPEND.CONTROL.GITHUB_COPILOT_CREDENTIALS', TRUE, TRUE, 48,
     'User-level NDJSON usage report includes per-user AI credits. Seats come from the separate user-management API. Legacy metrics API retired April 2026.'),
    ('CHATGPT_ENTERPRISE', 'ChatGPT Enterprise', 'CHATGPT_WORKSPACE', 'METERED',
     'CREDITS', 'WORKSPACE_MEMBER_ID', 'AI_SPEND.CONTROL.OPENAI_ADMIN_CREDENTIALS', TRUE, TRUE, 48,
     'Analytics endpoints for adoption, Cost API for credits by user/product/model. Separate billing context from the OpenAI API Platform -- never sum the two.'),
    ('OPENAI_API_PLATFORM', 'OpenAI API Platform', 'OPENAI_API_ORG', 'METERED',
     'TOKENS', 'API_KEY_OWNER', 'AI_SPEND.CONTROL.OPENAI_ADMIN_CREDENTIALS', FALSE, FALSE, 48,
     'Distinct product and contract from ChatGPT Enterprise. Registered separately so the two can never be blended by accident. Cost is attributable to an API key, not to a person -- so SUPPORTS_USER_COST is FALSE, the same shape as the Anthropic Console row. An API key owner is a plausible proxy for a person and not the same thing as one.'),
    ('M365_COPILOT', 'Microsoft 365 Copilot', 'MICROSOFT_TENANT', 'SEAT',
     'ACTIVE_DAYS', 'PSEUDONYMIZED_UPN', 'AI_SPEND.CONTROL.GRAPH_API_CREDENTIALS', FALSE, FALSE, 72,
     'Graph usage detail pseudonymizes UPN and display name unless the tenant disables report concealment. Returns last-activity dates, not volume. Cannot support engagement tiers or per-user cost.'),
    ('BOX_AI', 'Box AI', 'BOX_ENTERPRISE', 'METERED',
     'AI_UNITS', 'EMAIL', 'AI_SPEND.CONTROL.BOX_API_CREDENTIALS', TRUE, TRUE, 72,
     'Metered in AI Units since 2025-10-20 -- NOT a bundled seat cost. Per-user and per-agent AI Units come from the AI Units Admin Report (console export, can auto-deliver to a Box folder); the Enterprise Events API gives event granularity but retains only 2 weeks streaming / 1 year admin_logs.'),
    ('ANTHROPIC_CLAUDE_ENTERPRISE', 'Anthropic Claude Enterprise', 'CLAUDE_ENTERPRISE', 'METERED',
     'TOKENS', 'EMAIL', 'AI_SPEND.CONTROL.ANTHROPIC_ANALYTICS_CREDENTIALS', TRUE, TRUE, 24,
     'The seat includes NO usage on current Enterprise plans -- every token bills separately at API rates, so this platform carries BOTH a seat fee and metered cost. Enterprise Analytics API returns per-user cost with both effective and list amounts. Two hard limits: no data before 2026-01-01, and a value for a given date can be REVISED for up to 30 days, so loads must restate rather than append.'),
    ('ANTHROPIC_API_CONSOLE', 'Anthropic Claude Console (API)', 'ANTHROPIC_API_ORG', 'METERED',
     'TOKENS', 'API_KEY_ID', 'AI_SPEND.CONTROL.ANTHROPIC_ADMIN_CREDENTIALS', FALSE, FALSE, 24,
     'Distinct product, contract, and admin key from Claude Enterprise -- registered separately so the two can never be blended. The Admin usage and cost endpoints have NO user dimension at all: grain is API key, workspace, and model. Needed anyway, because the per-user Enterprise endpoints exclude direct API-key and automation traffic and cannot reconcile to invoice alone.'),
    ('CURSOR', 'Cursor', 'CURSOR_TEAM', 'METERED',
     'TOKENS', 'EMAIL', 'AI_SPEND.CONTROL.CURSOR_ADMIN_CREDENTIALS', TRUE, TRUE, 24,
     'Seat includes a per-user usage pool, then bills on-demand in arrears -- so seat and metered cost overlap and must not be added. Use spendCents (on-demand only), never overallSpendCents, alongside SEAT_ENTITLEMENT. Cost arrives already in cents: do NOT seed PLATFORM_RATE for this platform. Activity and cost are two different endpoints; the 30-day per-request range cap sets the backfill shape.'),
    ('GOOGLE_WORKSPACE_GEMINI', 'Gemini in Google Workspace', 'GOOGLE_WORKSPACE', 'SEAT',
     'FEATURE_EVENTS', 'EMAIL', 'AI_SPEND.CONTROL.GOOGLE_SA_CREDENTIALS', TRUE, FALSE, 72,
     'Baseline Gemini is bundled into the Workspace plan price and has NO separable per-user cost. There is no Gemini userUsageReport -- per-user data is audit events (gemini_in_workspace_apps / feature_utilization), which carry an actor and an action but no tokens and no cost. Retention 180 days rolling with nothing before 2025-06-20, so a Snowflake-side accumulator is mandatory. The only legitimate per-user cost is the AI Expanded Access / AI Ultra Access add-on seat, which goes in SEAT_ENTITLEMENT.'),
    ('GOOGLE_CODE_ASSIST', 'Gemini Code Assist', 'GOOGLE_CLOUD', 'SEAT',
     'IDE_INTERACTIONS', 'EMAIL', 'AI_SPEND.CONTROL.GOOGLE_SA_CREDENTIALS', TRUE, FALSE, 24,
     'The best per-user signal Google offers: Cloud Logging entries carry labels.user_id as a plain email, giving per-user code and chat exposure and acceptance. Cloud Monitoring metrics for the same product are aggregate-only -- do not use them for user grain. Cost is a seat, so per-user cost is allocation from SEAT_ENTITLEMENT, not measurement. Records IDE interactions only.'),
    ('GOOGLE_VERTEX_AI', 'Gemini Enterprise Agent Platform (Vertex AI)', 'GOOGLE_CLOUD_BILLING', 'METERED',
     'TOKENS', 'PROJECT_LABEL', 'AI_SPEND.CONTROL.GOOGLE_SA_CREDENTIALS', FALSE, FALSE, 48,
     'Genuinely cannot do per-user cost. Cloud Billing attribution stops at project, service, and SKU; the only request-level mechanism is labels, and Google both warns against putting PII in them and caps a label key at 1000 distinct values for the life of the billing account. Renamed from Vertex AI in 2026 but the aiplatform.googleapis.com endpoint is unchanged. Per-user USAGE is available from Data Access audit logs (principalEmail); per-user COST is not.')
  AS s(PLATFORM_KEY, DISPLAY_NAME, BILLING_CONTEXT, COST_MODEL, NATIVE_UNIT,
       SUBJECT_KEY_KIND, CREDENTIAL_OBJECT_FQN, SUPPORTS_USER_GRAIN,
       SUPPORTS_USER_COST, EXPECTED_LAG_HOURS, NOTES)
) AS src
ON tgt.PLATFORM_KEY = src.PLATFORM_KEY
WHEN NOT MATCHED THEN INSERT (
  PLATFORM_KEY, DISPLAY_NAME, BILLING_CONTEXT, COST_MODEL, NATIVE_UNIT,
  SUBJECT_KEY_KIND, CREDENTIAL_OBJECT_FQN, SUPPORTS_USER_GRAIN,
  SUPPORTS_USER_COST, EXPECTED_LAG_HOURS, IS_ACTIVE, NOTES
) VALUES (
  src.PLATFORM_KEY, src.DISPLAY_NAME, src.BILLING_CONTEXT, src.COST_MODEL, src.NATIVE_UNIT,
  src.SUBJECT_KEY_KIND, src.CREDENTIAL_OBJECT_FQN, src.SUPPORTS_USER_GRAIN,
  src.SUPPORTS_USER_COST, src.EXPECTED_LAG_HOURS, FALSE, src.NOTES
);

-- ---------------------------------------------------------------------------
-- Confirm and show what each platform can honestly deliver
-- ---------------------------------------------------------------------------

SELECT
    PLATFORM_KEY,
    COST_MODEL,
    NATIVE_UNIT,
    SUPPORTS_USER_GRAIN,
    SUPPORTS_USER_COST,
    IS_ACTIVE
FROM AI_SPEND.CONTROL.PLATFORM_REGISTRY
ORDER BY COST_MODEL, PLATFORM_KEY;
