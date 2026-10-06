/* Cross-platform AI spend consolidation — normalization
   Pair-programmed by SE Community + Cortex Code
   Expires: 2027-03-10

   Builds SHAPED.UNIFIED_AI_USAGE: one row per person, per platform, per report,
   per day. This is where the two design decisions from the README become physical.

   DECISION 1 -- DO NOT BLEND METERS.
   COST_MODEL comes from PLATFORM_REGISTRY, so it is declared once per platform
   rather than asserted per row. COST_AMOUNT is NULL on every SEAT row, on purpose,
   because a seat's cost is an attribute of the month and not of an activity.
   Anything that needs one blended number goes through GOLD.AI_SPEND_ALLOCATED in
   sql/07, which applies amortization in one labelled place and exposes the rule.

   DECISION 2 -- IDENTITY IS THE ACTUAL PROJECT.
   Every platform names people differently and none of the names join. IDENTITY_MAP
   is the spine. Unmatched rows are NOT dropped -- they get PERSON_KEY
   'UNRESOLVED:<platform>:<subject>' and IDENTITY_CONFIDENCE 'NONE', so unattributed
   spend stays in the total. Dropping them makes the platform total disagree with the
   invoice, which destroys trust in the report on first contact with finance.

   That exact string format is load-bearing: sql/03 builds the same prefix for seat
   rows, and if the two drift apart seats never join to usage and every unresolved
   seat falsely reads as DORMANT.

   NATIVE_QTY and NATIVE_UNIT are preserved rather than converted. Credits, tokens,
   messages, and interactions have no defensible exchange rate. Compare platforms on
   currency cost or on user counts, never on raw quantity.
*/

USE ROLE AI_SPEND_RL;
USE WAREHOUSE AI_SPEND_WH;

-- ---------------------------------------------------------------------------
-- Per-platform shredding views
--
-- One view per platform, each producing the same columns. A new platform is a new
-- view plus one UNION ALL branch below -- it never changes the fact table's shape.
-- All extraction is TRY_TO_* so a malformed record degrades one row instead of
-- failing a Dynamic Table refresh for everyone.
-- ---------------------------------------------------------------------------

/* GitHub Copilot -- user usage. The only external platform fully worked in this
   guide, so this view is also the template for the others.

   Field names below match the illustrative response shape in sql/03. VERIFY them
   against your first landed records before trusting the output -- a renamed field
   read through TRY_TO_* yields NULL and a chart that looks fine. */
CREATE OR REPLACE VIEW AI_SPEND.SHAPED.V_SHRED_GITHUB_COPILOT
  COMMENT = 'GitHub Copilot user-level usage shredded to the unified grain'
AS
SELECT
    PLATFORM_KEY,
    REPORT_NAME,
    BILLING_CONTEXT,
    TRY_TO_DATE(RECORD:date::VARCHAR)                       AS USAGE_DATE,
    RECORD:user_login::VARCHAR                              AS SUBJECT_KEY,
    RECORD:user_login::VARCHAR                              AS SUBJECT_DISPLAY_NAME,
    /* Per-user AI credits: metered premium-request spend, distinct from the seat
       licence. This is the field that makes GitHub the useful worked example --
       it exercises both cost models within one platform. */
    TRY_TO_DECIMAL(RECORD:ai_credits_used::VARCHAR, 38, 6)   AS NATIVE_QTY,
    TRY_TO_NUMBER(RECORD:code_acceptance_activity_count::VARCHAR) AS ACTIVITY_COUNT,
    /* Engagement phase as GitHub computes it. Carried for reference only --
       sql/07 computes portable tiers, because every vendor defines this
       differently and inheriting one vendor's definition makes cross-platform
       tiers incomparable. */
    RECORD:phase::VARCHAR                                   AS VENDOR_ENGAGEMENT_LABEL,
    PULLED_AT,
    SOURCE_FILE,
    SOURCE_ROW_NUMBER,
    LOADED_AT
FROM AI_SPEND.RAW.LANDING_AI_USAGE
WHERE PLATFORM_KEY = 'GITHUB_COPILOT'
  AND REPORT_NAME = 'USER_USAGE'
  AND RECORD:user_login IS NOT NULL;

/* Stub shredding views for the platforms in sql/04.
   Deliberately return zero rows until an adapter lands data and the field names
   below are corrected against reality. Present so the UNION ALL and every
   downstream object are structurally complete from day one -- adding a platform
   then changes one view body, not the fact table. */

CREATE OR REPLACE VIEW AI_SPEND.SHAPED.V_SHRED_CHATGPT_ENTERPRISE
  COMMENT = 'STUB: correct field names against OpenAI docs before activating'
AS
SELECT
    PLATFORM_KEY,
    REPORT_NAME,
    BILLING_CONTEXT,
    TRY_TO_DATE(RECORD:date::VARCHAR)                       AS USAGE_DATE,
    RECORD:user_id::VARCHAR                                 AS SUBJECT_KEY,
    RECORD:email::VARCHAR                                   AS SUBJECT_DISPLAY_NAME,
    TRY_TO_DECIMAL(RECORD:credits::VARCHAR, 38, 6)          AS NATIVE_QTY,
    TRY_TO_NUMBER(RECORD:messages::VARCHAR)                 AS ACTIVITY_COUNT,
    NULL::VARCHAR                                           AS VENDOR_ENGAGEMENT_LABEL,
    PULLED_AT,
    SOURCE_FILE,
    SOURCE_ROW_NUMBER,
    LOADED_AT
FROM AI_SPEND.RAW.LANDING_AI_USAGE
WHERE PLATFORM_KEY = 'CHATGPT_ENTERPRISE'
  /* ONE credit-bearing report only. Admitting both USER_ACTIVITY and CREDIT_USAGE
     while reading RECORD:credits from each would double-count credits the moment
     this platform is activated. */
  AND REPORT_NAME = 'CREDIT_USAGE';

/* M365 Copilot. NATIVE_QTY is intentionally an activity FLAG, not a volume,
   because the API returns last-activity dates and nothing else. A light user and
   a power user are indistinguishable. Presenting this as a usage quantity would be
   a fabricated metric.

   TWO SUBTLETIES THAT MAKE THE DIFFERENCE BETWEEN USEFUL AND WORTHLESS:

   1. USAGE_DATE comes from lastActivityDate, NOT reportRefreshDate. The refresh
      date is identical for every row in a pull, so using it would make every
      licensed person look active on the pull date forever.
   2. The flag is time-bounded against the refresh date. A bare
      "lastActivityDate IS NOT NULL" means "has EVER been active", so someone who
      last opened Copilot a year ago would read as active and DORMANT would become
      unreachable -- destroying the one question this platform answers well. */
CREATE OR REPLACE VIEW AI_SPEND.SHAPED.V_SHRED_M365_COPILOT
  COMMENT = 'STUB: last-activity signal only. Cannot support engagement tiers.'
AS
SELECT
    PLATFORM_KEY,
    REPORT_NAME,
    BILLING_CONTEXT,
    TRY_TO_DATE(RECORD:lastActivityDate::VARCHAR)           AS USAGE_DATE,
    /* Hashed unless the tenant disabled report concealment. Stable, so it trends
       an anonymous individual -- but it will not join to a department. The
       identity join below assigns it NONE confidence and it lands in UNRESOLVED,
       which is the correct visible outcome rather than a silent gap. */
    RECORD:userPrincipalName::VARCHAR                       AS SUBJECT_KEY,
    RECORD:displayName::VARCHAR                             AS SUBJECT_DISPLAY_NAME,
    IFF(TRY_TO_DATE(RECORD:lastActivityDate::VARCHAR)
        >= DATEADD('day', -30, TRY_TO_DATE(RECORD:reportRefreshDate::VARCHAR)),
        1, 0)::NUMBER(38,6)                                 AS NATIVE_QTY,
    NULL::NUMBER                                            AS ACTIVITY_COUNT,
    NULL::VARCHAR                                           AS VENDOR_ENGAGEMENT_LABEL,
    PULLED_AT,
    SOURCE_FILE,
    SOURCE_ROW_NUMBER,
    LOADED_AT
FROM AI_SPEND.RAW.LANDING_AI_USAGE
WHERE PLATFORM_KEY = 'M365_COPILOT'
  AND REPORT_NAME = 'USAGE_USER_DETAIL';

/* Box AI. METERED in AI Units since 2025-10-20 -- not a bundled seat cost.

   TWO reports, and only ONE carries the chargeable unit:

     AI_UNITS_MONTHLY  from the AI Units Admin Report, which Box delivers as a file
                       into a Box folder. Per user and per agent. COST-BEARING.
     AI_EVENTS         from the Enterprise Events API. Event granularity and agent
                       attribution, but NOT the chargeable unit.

   AI_EVENTS lands with NATIVE_QTY = NULL on purpose. Counting events as if they
   were AI Units would double count against the report -- a Box AI interaction can
   consume many units or few, so an event count is activity, not spend. */
CREATE OR REPLACE VIEW AI_SPEND.SHAPED.V_SHRED_BOX_AI
  COMMENT = 'STUB: AI Units report is cost-bearing; events are activity only. Verify field names.'
AS
SELECT
    PLATFORM_KEY,
    REPORT_NAME,
    BILLING_CONTEXT,
    COALESCE(
        TRY_TO_DATE(RECORD:period_start::VARCHAR),      -- AI_UNITS_MONTHLY
        TRY_TO_DATE(RECORD:created_at::VARCHAR)         -- AI_EVENTS
    )                                                       AS USAGE_DATE,
    /* Box identifies people by login, which is normally the corporate email --
       the one platform in this guide whose subject key joins to IDENTITY_MAP with
       no mapping step. Confirm on your tenant; some use an internal user ID. */
    COALESCE(
        RECORD:user_login::VARCHAR,
        RECORD:created_by:login::VARCHAR
    )                                                       AS SUBJECT_KEY,
    COALESCE(
        RECORD:user_name::VARCHAR,
        RECORD:created_by:name::VARCHAR
    )                                                       AS SUBJECT_DISPLAY_NAME,
    -- NULL for AI_EVENTS by design. See the note above.
    IFF(REPORT_NAME = 'AI_UNITS_MONTHLY',
        TRY_TO_DECIMAL(RECORD:ai_units::VARCHAR, 38, 6),
        NULL)                                               AS NATIVE_QTY,
    IFF(REPORT_NAME = 'AI_EVENTS', 1, NULL)::NUMBER          AS ACTIVITY_COUNT,
    NULL::VARCHAR                                           AS VENDOR_ENGAGEMENT_LABEL,
    PULLED_AT,
    SOURCE_FILE,
    SOURCE_ROW_NUMBER,
    LOADED_AT
FROM AI_SPEND.RAW.LANDING_AI_USAGE
WHERE PLATFORM_KEY = 'BOX_AI'
  AND REPORT_NAME IN ('AI_UNITS_MONTHLY', 'AI_EVENTS');

-- ---------------------------------------------------------------------------
-- SHAPED.UNIFIED_AI_USAGE -- the fact
--
-- Dynamic Table so it refreshes incrementally from CHANGE_TRACKING on the landing
-- table and from ACCOUNT_USAGE for the native branch.
--
-- TARGET_LAG is 12 hours because every upstream source is a daily aggregate with
-- multi-hour publication latency. A shorter lag burns credits re-deriving rows
-- that have not changed.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE DYNAMIC TABLE AI_SPEND.SHAPED.UNIFIED_AI_USAGE (
    USAGE_DATE              COMMENT 'Activity date as the vendor reported it',
    PLATFORM_KEY            COMMENT 'Registry key of the source platform',
    PLATFORM_DISPLAY_NAME   COMMENT 'Human-readable platform name',
    REPORT_NAME             COMMENT 'Which vendor report this row came from',
    BILLING_CONTEXT         COMMENT 'Contract and meter. Never sum across contexts.',
    COST_MODEL              COMMENT 'METERED or SEAT. Never sum cost across these.',
    SUBJECT_KEY             COMMENT 'The vendor own identifier for the person',
    SUBJECT_DISPLAY_NAME    COMMENT 'Vendor-supplied display name, may be hashed',
    PERSON_KEY              COMMENT 'Resolved person, or UNRESOLVED:<platform>:<subject>',
    IDENTITY_CONFIDENCE     COMMENT 'VERIFIED, ASSERTED, HEURISTIC, or NONE',
    DEPARTMENT              COMMENT 'From IDENTITY_MAP. NULL when unresolved.',
    COST_CENTER             COMMENT 'From IDENTITY_MAP. NULL when unresolved.',
    BUSINESS_UNIT           COMMENT 'From IDENTITY_MAP. NULL when unresolved.',
    NATIVE_QTY              COMMENT 'Vendor quantity in its own unit. Do not convert.',
    NATIVE_UNIT             COMMENT 'CREDITS, TOKENS, MESSAGES, INTERACTIONS, ACTIVE_DAYS',
    ACTIVITY_COUNT          COMMENT 'Comparable-ish interaction count where reported',
    COST_AMOUNT             COMMENT 'Metered cost. NULL when COST_MODEL = SEAT.',
    CURRENCY_CODE           COMMENT 'Currency of COST_AMOUNT',
    VENDOR_ENGAGEMENT_LABEL COMMENT 'Vendor own tier label. Reference only.',
    SUPPORTS_USER_COST      COMMENT 'Whether this platform can report per-user cost',
    LAST_LOADED_AT          COMMENT 'When this row last landed'
)
TARGET_LAG = '12 hours'
WAREHOUSE = AI_SPEND_WH
REFRESH_MODE = ADAPTIVE
INITIALIZE = ON_CREATE
COMMENT = 'One row per person per platform per report per day. Cost-model aware.'
AS
WITH external_usage AS (
    SELECT PLATFORM_KEY, REPORT_NAME, BILLING_CONTEXT, USAGE_DATE, SUBJECT_KEY,
           SUBJECT_DISPLAY_NAME, NATIVE_QTY, ACTIVITY_COUNT,
           VENDOR_ENGAGEMENT_LABEL, PULLED_AT, SOURCE_FILE, SOURCE_ROW_NUMBER,
           LOADED_AT
    FROM AI_SPEND.SHAPED.V_SHRED_GITHUB_COPILOT
    UNION ALL
    SELECT PLATFORM_KEY, REPORT_NAME, BILLING_CONTEXT, USAGE_DATE, SUBJECT_KEY,
           SUBJECT_DISPLAY_NAME, NATIVE_QTY, ACTIVITY_COUNT,
           VENDOR_ENGAGEMENT_LABEL, PULLED_AT, SOURCE_FILE, SOURCE_ROW_NUMBER,
           LOADED_AT
    FROM AI_SPEND.SHAPED.V_SHRED_CHATGPT_ENTERPRISE
    UNION ALL
    SELECT PLATFORM_KEY, REPORT_NAME, BILLING_CONTEXT, USAGE_DATE, SUBJECT_KEY,
           SUBJECT_DISPLAY_NAME, NATIVE_QTY, ACTIVITY_COUNT,
           VENDOR_ENGAGEMENT_LABEL, PULLED_AT, SOURCE_FILE, SOURCE_ROW_NUMBER,
           LOADED_AT
    FROM AI_SPEND.SHAPED.V_SHRED_M365_COPILOT
    UNION ALL
    SELECT PLATFORM_KEY, REPORT_NAME, BILLING_CONTEXT, USAGE_DATE, SUBJECT_KEY,
           SUBJECT_DISPLAY_NAME, NATIVE_QTY, ACTIVITY_COUNT,
           VENDOR_ENGAGEMENT_LABEL, PULLED_AT, SOURCE_FILE, SOURCE_ROW_NUMBER,
           LOADED_AT
    FROM AI_SPEND.SHAPED.V_SHRED_BOX_AI
),
/* Deduplicate restatements. Adapters overlap their pull window on purpose --
   vendor daily aggregates get restated for a day or two after publication -- so
   the same (platform, report, date, subject) legitimately lands more than once.
   Keep the most recently pulled version. Without this, an overlapping window
   double counts and every total silently inflates. */
external_deduped AS (
    SELECT
        PLATFORM_KEY, REPORT_NAME, BILLING_CONTEXT, USAGE_DATE, SUBJECT_KEY,
        SUBJECT_DISPLAY_NAME, NATIVE_QTY, ACTIVITY_COUNT,
        VENDOR_ENGAGEMENT_LABEL, LOADED_AT
    FROM external_usage
    /* Rows with an unparseable date or a missing subject are EXCLUDED here, which
       is the one place this pipeline deliberately loses data. That is a real
       tradeoff: a renamed vendor date field makes TRY_TO_DATE return NULL and the
       rows vanish. CONTROL.V_PIPELINE_HEALTH counts them as UNSHREDDABLE_ROWS and
       raises SHAPE_DRIFT, so the loss is visible rather than silent -- do not
       remove that check thinking it is redundant. */
    WHERE USAGE_DATE IS NOT NULL
      AND SUBJECT_KEY IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY PLATFORM_KEY, REPORT_NAME, USAGE_DATE, SUBJECT_KEY
        ORDER BY PULLED_AT DESC, LOADED_AT DESC, SOURCE_ROW_NUMBER DESC
    ) = 1
),
/* The Snowflake-native branch. Already aggregated to the unified grain in sql/05
   and already deduplicated by construction, so it bypasses the QUALIFY above. */
native_usage AS (
    SELECT
        PLATFORM_KEY, REPORT_NAME, BILLING_CONTEXT, USAGE_DATE, SUBJECT_KEY,
        SUBJECT_DISPLAY_NAME,
        CREDITS::NUMBER(38,6)   AS NATIVE_QTY,
        REQUEST_COUNT           AS ACTIVITY_COUNT,
        NULL::VARCHAR           AS VENDOR_ENGAGEMENT_LABEL,
        LAST_SEEN_TS::TIMESTAMP_TZ AS LOADED_AT
    FROM AI_SPEND.RAW.V_SNOWFLAKE_NATIVE_USAGE
),
all_usage AS (
    SELECT * FROM external_deduped
    UNION ALL
    SELECT * FROM native_usage
),
/* Collapse IDENTITY_MAP to ONE row per (platform, subject).

   Neither IDENTITY_MAP nor PLATFORM_RATE has a constraint preventing overlapping
   validity ranges, and VALID_TO defaults to 9999-12-31. Range-joining them
   directly means a second open-ended row silently DUPLICATES every matching fact
   row and doubles COST_AMOUNT. Picking the latest applicable row makes an
   overlap a resolution choice rather than a fanout.

   Deliberately joined on the fact's date range rather than filtered to "today",
   so a historical report still uses the mapping that applied on the day. */
identity_resolved AS (
    SELECT
        u.PLATFORM_KEY,
        u.SUBJECT_KEY,
        u.USAGE_DATE,
        m.PERSON_KEY,
        m.CONFIDENCE,
        m.DEPARTMENT,
        m.COST_CENTER,
        m.BUSINESS_UNIT
    FROM (SELECT DISTINCT PLATFORM_KEY, SUBJECT_KEY, USAGE_DATE FROM all_usage) u
    JOIN AI_SPEND.CONTROL.IDENTITY_MAP m
      ON  m.PLATFORM_KEY = u.PLATFORM_KEY
     AND m.SUBJECT_KEY = u.SUBJECT_KEY
     AND u.USAGE_DATE BETWEEN m.VALID_FROM AND m.VALID_TO
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY u.PLATFORM_KEY, u.SUBJECT_KEY, u.USAGE_DATE
        ORDER BY m.VALID_FROM DESC, m.UPDATED_AT DESC
    ) = 1
),
-- Same treatment for rates. A rate change at renewal is the common way a second
-- open-ended row appears, so this is not a hypothetical.
rate_resolved AS (
    SELECT
        u.PLATFORM_KEY,
        u.USAGE_DATE,
        r.UNIT_COST,
        r.CURRENCY_CODE
    FROM (SELECT DISTINCT PLATFORM_KEY, USAGE_DATE FROM all_usage) u
    JOIN AI_SPEND.CONTROL.PLATFORM_RATE r
      ON  r.PLATFORM_KEY = u.PLATFORM_KEY
     AND u.USAGE_DATE BETWEEN r.VALID_FROM AND r.VALID_TO
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY u.PLATFORM_KEY, u.USAGE_DATE
        ORDER BY r.VALID_FROM DESC, r.UPDATED_AT DESC
    ) = 1
)
SELECT
    u.USAGE_DATE,
    u.PLATFORM_KEY,
    r.DISPLAY_NAME                          AS PLATFORM_DISPLAY_NAME,
    u.REPORT_NAME,
    u.BILLING_CONTEXT,
    /* Declared once per platform in the registry, not asserted per row. */
    r.COST_MODEL,
    u.SUBJECT_KEY,
    u.SUBJECT_DISPLAY_NAME,
    /* Unresolved subjects are KEPT, prefixed so they are impossible to mistake for
       a real person and impossible to silently exclude from a total. */
    COALESCE(m.PERSON_KEY, 'UNRESOLVED:' || u.PLATFORM_KEY || ':' || u.SUBJECT_KEY)
                                            AS PERSON_KEY,
    COALESCE(m.CONFIDENCE, 'NONE')          AS IDENTITY_CONFIDENCE,
    m.DEPARTMENT,
    m.COST_CENTER,
    m.BUSINESS_UNIT,
    u.NATIVE_QTY,
    r.NATIVE_UNIT,
    u.ACTIVITY_COUNT,
    /* THE COST-MODEL BOUNDARY, ENFORCED HERE.
       SEAT platforms get NULL cost: their spend is a monthly licence held in
       CONTROL.SEAT_ENTITLEMENT, not a property of an activity row. A platform
       that cannot report per-user cost also gets NULL rather than a fabricated
       share. Blending happens once, visibly, in GOLD.AI_SPEND_ALLOCATED. */
    CASE
        WHEN r.COST_MODEL = 'SEAT' THEN NULL
        WHEN NOT r.SUPPORTS_USER_COST THEN NULL
        ELSE u.NATIVE_QTY * COALESCE(r_rate.UNIT_COST, 1)
    END::NUMBER(38,6)                       AS COST_AMOUNT,
    COALESCE(r_rate.CURRENCY_CODE, 'USD')   AS CURRENCY_CODE,
    u.VENDOR_ENGAGEMENT_LABEL,
    r.SUPPORTS_USER_COST,
    u.LOADED_AT                             AS LAST_LOADED_AT
FROM all_usage u
JOIN AI_SPEND.CONTROL.PLATFORM_REGISTRY r
  ON r.PLATFORM_KEY = u.PLATFORM_KEY
/* Equality joins onto the pre-resolved one-row-per-key CTEs. Equality matters for
   more than correctness: outer joins with non-equality predicates disqualify a
   Dynamic Table from incremental refresh entirely. */
LEFT JOIN identity_resolved m
  ON  m.PLATFORM_KEY = u.PLATFORM_KEY
  AND m.SUBJECT_KEY = u.SUBJECT_KEY
  AND m.USAGE_DATE = u.USAGE_DATE
LEFT JOIN rate_resolved r_rate
  ON  r_rate.PLATFORM_KEY = u.PLATFORM_KEY
  AND r_rate.USAGE_DATE = u.USAGE_DATE;

-- ---------------------------------------------------------------------------
-- Identity quality view
--
-- Publish this NEXT TO every department allocation. If you do not, someone will
-- assume the unresolved rate is zero, and the first time finance reconciles a
-- department total against the invoice the whole report loses credibility.
--
-- A platform at 100 percent unresolved is the signature of a newly activated
-- adapter whose subject keys were never seeded into IDENTITY_MAP.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW AI_SPEND.SHAPED.V_IDENTITY_QUALITY
  COMMENT = 'Per-platform identity resolution rates. Publish beside any allocation.'
AS
SELECT
    PLATFORM_KEY,
    PLATFORM_DISPLAY_NAME,
    COUNT(*)                                         AS total_rows,
    COUNT(DISTINCT PERSON_KEY)                       AS distinct_people,
    COUNT_IF(IDENTITY_CONFIDENCE = 'VERIFIED')       AS verified_rows,
    COUNT_IF(IDENTITY_CONFIDENCE = 'ASSERTED')       AS asserted_rows,
    COUNT_IF(IDENTITY_CONFIDENCE = 'HEURISTIC')      AS heuristic_rows,
    COUNT_IF(IDENTITY_CONFIDENCE = 'NONE')           AS unresolved_rows,
    ROUND(100 * COUNT_IF(IDENTITY_CONFIDENCE = 'NONE')
          / NULLIF(COUNT(*), 0), 2)                  AS unresolved_pct,
    ROUND(100 * COUNT_IF(DEPARTMENT IS NULL)
          / NULLIF(COUNT(*), 0), 2)                  AS no_department_pct,
    /* Unattributable metered spend. This is the number to put in front of anyone
       who asks why a department total does not tie to the invoice. */
    ROUND(SUM(IFF(IDENTITY_CONFIDENCE = 'NONE', COST_AMOUNT, 0)), 4)
                                                     AS unresolved_cost_amount
FROM AI_SPEND.SHAPED.UNIFIED_AI_USAGE
GROUP BY PLATFORM_KEY, PLATFORM_DISPLAY_NAME
ORDER BY unresolved_pct DESC;

-- Verify. Snowflake Cortex should already be populated from sql/05; external
-- platforms stay at zero until their adapters run.
SELECT
    PLATFORM_KEY,
    COST_MODEL,
    NATIVE_UNIT,
    COUNT(*)                        AS rows_in_fact,
    COUNT(DISTINCT PERSON_KEY)      AS people,
    ROUND(SUM(NATIVE_QTY), 4)       AS total_native_qty,
    ROUND(SUM(COST_AMOUNT), 4)      AS total_cost_amount,
    MAX(USAGE_DATE)                 AS latest_date
FROM AI_SPEND.SHAPED.UNIFIED_AI_USAGE
GROUP BY PLATFORM_KEY, COST_MODEL, NATIVE_UNIT
ORDER BY PLATFORM_KEY;
