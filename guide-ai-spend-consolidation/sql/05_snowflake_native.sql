/* Cross-platform AI spend consolidation — Snowflake native adapter
   Pair-programmed by SE Community + Cortex Code
   Expires: 2026-11-09

   The Snowflake side of the model. NO CREDENTIALS, NO API, NO NETWORK RULE --
   ACCOUNT_USAGE is already there. Run this immediately after sql/01 and you have a
   working end-to-end model with real data, which is the cheapest way to prove the
   design and the reports before negotiating access to any vendor admin API.

   Unions four ACCOUNT_USAGE views into a shape matching the adapter contract.
   Because it reads views rather than an external API, it skips the stage-and-COPY
   path and writes SHAPED-compatible rows directly. That is the one sanctioned
   deviation from the contract, and it is safe for the same reason it is a
   deviation: this reference intentionally reports only the retained source window.
   ACCOUNT_USAGE is neither an immutable archive nor unlimited history (typically
   365 days for these views). Archive qualified source partitions in owned tables
   before expiry when longer history is required; a Dynamic Table is not an archive.
   These four views are a scoped subset, not every Snowflake AI billing service.

   COLUMN QUIRKS -- verified against ACCOUNT_USAGE on the created date. These are
   real, they are inconsistent between the four views, and every one of them will
   silently produce NULLs if you assume uniformity:

     view                              time column   user_name?  credit column
     CORTEX_AI_FUNCTIONS_USAGE_HISTORY START_TIME     NO          CREDITS
     CORTEX_AGENT_USAGE_HISTORY        START_TIME     yes         TOKEN_CREDITS
     SNOWFLAKE_COWORK_USAGE_HISTORY    START_TIME     yes         TOKEN_CREDITS
     SNOWFLAKE_COCO_USAGE_HISTORY      USAGE_TIME     yes         TOKEN_CREDITS

   Two further traps:
     - CORTEX_AI_FUNCTIONS_USAGE_HISTORY has NO USER_NAME. It must be joined to
       ACCOUNT_USAGE.USERS on USER_ID.
     - COCO's USAGE_TIME is TIMESTAMP_TZ while the other three are TIMESTAMP_LTZ.
       Cast explicitly or the UNION resolves types in a way you did not choose.
     - COCO exposes a first-class INTERFACE column; Agent carries
       interaction_interface inside METADATA. CoWork does not document that key.
     - SNOWFLAKE_COCO_USAGE_HISTORY is the UNIFIED CoCo view and already covers
       every billable surface -- cli, desktop, and snowsight -- so no enumeration
       of surfaces is needed here. If you ever swap to the per-interface views or
       filter a SERVICE_TYPE list, match on LIKE 'CORTEX_CODE%' rather than
       hand-listing surfaces. Hand-written lists routinely omit
       CORTEX_CODE_DESKTOP, which is a first-class billable surface with its own
       usage view and credit-limit parameter, and the omission silently
       under-reports CoCo spend instead of failing.
*/

USE ROLE AI_SPEND_RL;
USE WAREHOUSE AI_SPEND_WH;

-- ---------------------------------------------------------------------------
-- Shredded view over the four Cortex usage views
--
-- This view follows ACCOUNT_USAGE retention and source corrections. Older rows
-- age out of downstream Dynamic Tables. Use an owned historical accumulator for
-- reporting beyond source retention; neither this view nor gold preserves it.
--
-- ACCOUNT_USAGE latency varies by view -- commonly ~45 minutes to 3 hours, and
-- some views up to 24 hours -- so check the documented latency for each view
-- rather than assuming one number. The four read here are each documented at up
-- to 1 hour, except CORTEX_AI_FUNCTIONS_USAGE_HISTORY, whose running-query
-- updates have a documented five-minute SLA. EXPECTED_LAG_HOURS is 24 in the
-- registry: it is
-- a tolerance that must hold for every source, not a claim about the fastest one.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW AI_SPEND.RAW.V_SNOWFLAKE_NATIVE_USAGE
  COMMENT = 'Snowflake Cortex AI usage in adapter-contract shape, per user per day'
AS
WITH ai_functions AS (
    SELECT
        f.USER_ID::VARCHAR                       AS SUBJECT_KEY,
        u.NAME                                   AS SUBJECT_DISPLAY_NAME,
        f.START_TIME::TIMESTAMP_LTZ              AS USAGE_TS,
        f.CREDITS                                AS CREDITS,
        NULL::NUMBER                             AS TOKENS,
        'AI_FUNCTION'                            AS SERVICE_TYPE,
        f.FUNCTION_NAME || ' (' || COALESCE(f.MODEL_NAME, 'default') || ')'
                                                 AS ENTITY_NAME,
        f.ROLE_NAMES[0]::VARCHAR                 AS ROLE_NAME,
        NULL::VARCHAR                            AS INTERACTION_INTERFACE,
        NULL::ARRAY                              AS USER_TAGS,
        f.QUERY_ID                               AS REQUEST_ID
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY f
    -- Required: this view carries no USER_NAME of its own.
    LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u
           ON u.USER_ID::VARCHAR = f.USER_ID::VARCHAR
),
agents AS (
    SELECT
        a.USER_ID::VARCHAR                       AS SUBJECT_KEY,
        a.USER_NAME                              AS SUBJECT_DISPLAY_NAME,
        a.START_TIME::TIMESTAMP_LTZ              AS USAGE_TS,
        a.TOKEN_CREDITS                          AS CREDITS,
        a.TOKENS                                 AS TOKENS,
        'CORTEX_AGENT'                           AS SERVICE_TYPE,
        a.AGENT_NAME                             AS ENTITY_NAME,
        a.METADATA:role_name::VARCHAR            AS ROLE_NAME,
        a.METADATA:interaction_interface::VARCHAR AS INTERACTION_INTERFACE,
        a.USER_TAGS                              AS USER_TAGS,
        a.REQUEST_ID                             AS REQUEST_ID
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY a
),
cowork AS (
    SELECT
        c.USER_ID::VARCHAR                       AS SUBJECT_KEY,
        c.USER_NAME                              AS SUBJECT_DISPLAY_NAME,
        c.START_TIME::TIMESTAMP_LTZ              AS USAGE_TS,
        c.TOKEN_CREDITS                          AS CREDITS,
        c.TOKENS                                 AS TOKENS,
        'SNOWFLAKE_COWORK'                       AS SERVICE_TYPE,
        c.SNOWFLAKE_COWORK_NAME                  AS ENTITY_NAME,
        c.METADATA:role_name::VARCHAR            AS ROLE_NAME,
        NULL::VARCHAR                           AS INTERACTION_INTERFACE,
        c.USER_TAGS                              AS USER_TAGS,
        c.REQUEST_ID                             AS REQUEST_ID
    FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COWORK_USAGE_HISTORY c
),
coco AS (
    SELECT
        cc.USER_ID::VARCHAR                      AS SUBJECT_KEY,
        cc.USER_NAME                             AS SUBJECT_DISPLAY_NAME,
        -- USAGE_TIME, not START_TIME. And TIMESTAMP_TZ, not TIMESTAMP_LTZ --
        -- cast explicitly so the UNION does not resolve the type for us.
        cc.USAGE_TIME::TIMESTAMP_LTZ             AS USAGE_TS,
        cc.TOKEN_CREDITS                         AS CREDITS,
        cc.TOKENS                                AS TOKENS,
        'CORTEX_CODE'                            AS SERVICE_TYPE,
        'Cortex Code'                            AS ENTITY_NAME,
        cc.METADATA:role_name::VARCHAR           AS ROLE_NAME,
        -- First-class column here; the other views bury it in METADATA.
        cc.INTERFACE                             AS INTERACTION_INTERFACE,
        cc.USER_TAGS                             AS USER_TAGS,
        cc.REQUEST_ID                            AS REQUEST_ID
    FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COCO_USAGE_HISTORY cc
),
combined AS (
    SELECT SUBJECT_KEY, SUBJECT_DISPLAY_NAME, USAGE_TS, CREDITS, TOKENS,
           SERVICE_TYPE, ENTITY_NAME, ROLE_NAME, INTERACTION_INTERFACE,
           USER_TAGS, REQUEST_ID
    FROM ai_functions
    UNION ALL
    SELECT SUBJECT_KEY, SUBJECT_DISPLAY_NAME, USAGE_TS, CREDITS, TOKENS,
           SERVICE_TYPE, ENTITY_NAME, ROLE_NAME, INTERACTION_INTERFACE,
           USER_TAGS, REQUEST_ID
    FROM agents
    UNION ALL
    SELECT SUBJECT_KEY, SUBJECT_DISPLAY_NAME, USAGE_TS, CREDITS, TOKENS,
           SERVICE_TYPE, ENTITY_NAME, ROLE_NAME, INTERACTION_INTERFACE,
           USER_TAGS, REQUEST_ID
    FROM cowork
    UNION ALL
    SELECT SUBJECT_KEY, SUBJECT_DISPLAY_NAME, USAGE_TS, CREDITS, TOKENS,
           SERVICE_TYPE, ENTITY_NAME, ROLE_NAME, INTERACTION_INTERFACE,
           USER_TAGS, REQUEST_ID
    FROM coco
)
SELECT
    'SNOWFLAKE_CORTEX'                AS PLATFORM_KEY,
    SERVICE_TYPE                      AS REPORT_NAME,
    'SNOWFLAKE_ACCOUNT'               AS BILLING_CONTEXT,
    TO_DATE(USAGE_TS)                 AS USAGE_DATE,
    COALESCE(c.SUBJECT_KEY, 'UNKNOWN_USER') AS SUBJECT_KEY,
    CASE WHEN c.SUBJECT_KEY = '0' THEN 'SYSTEM'
         WHEN u.TYPE IN ('SERVICE', 'LEGACY_SERVICE') THEN 'SERVICE'
         WHEN u.USER_ID IS NULL THEN 'UNKNOWN'
         ELSE 'PERSON' END AS ENTITY_KIND,
    /* MAX rather than ANY_VALUE throughout. ANY_VALUE is non-deterministic and is
       documented as NOT SUPPORTED for Dynamic Tables in EITHER refresh mode -- so
       using it here would make the downstream SHAPED.UNIFIED_AI_USAGE Dynamic Table
       fail to create, not merely fall back to full refresh. MAX and MAX_BY are
       supported in both modes. */
    MAX(SUBJECT_DISPLAY_NAME)         AS SUBJECT_DISPLAY_NAME,
    SERVICE_TYPE,
    /* Aggregated to per-user per-day per-service to match the grain every other
       platform reports at. Vendor admin APIs publish daily aggregates; keeping
       Snowflake at request grain would make it the only platform whose row counts
       mean something different, and every cross-platform comparison would be
       quietly wrong. Request-level detail stays available in ACCOUNT_USAGE. */
    SUM(CREDITS)                      AS CREDITS,
    SUM(TOKENS)                       AS TOKENS,
    COUNT(DISTINCT REQUEST_ID)        AS REQUEST_COUNT,
    COUNT(*)                          AS METERING_RECORD_COUNT,
    COUNT(DISTINCT ENTITY_NAME)       AS DISTINCT_ENTITIES,
    MAX(ROLE_NAME)                    AS ROLE_NAME,
    MAX(INTERACTION_INTERFACE)        AS INTERACTION_INTERFACE,
    MAX_BY(USER_TAGS, USAGE_TS)       AS USER_TAGS,
    MAX(USAGE_TS)                     AS LAST_SEEN_TS
FROM combined c
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON u.USER_ID::VARCHAR = c.SUBJECT_KEY
GROUP BY SERVICE_TYPE, TO_DATE(USAGE_TS), c.SUBJECT_KEY,
         CASE WHEN c.SUBJECT_KEY = '0' THEN 'SYSTEM'
              WHEN u.TYPE IN ('SERVICE', 'LEGACY_SERVICE') THEN 'SERVICE'
              WHEN u.USER_ID IS NULL THEN 'UNKNOWN' ELSE 'PERSON' END;
-- REQUEST_COUNT counts distinct query IDs for AI functions, not individual AI
-- function calls or input rows. METERING_RECORD_COUNT is a separate meter count.
-- NULL user IDs remain in totals as UNKNOWN_USER/UNKNOWN, never a human rank.
-- Dates use the refresh session timezone; qualify a consistent reporting timezone.
-- USER type/name comes from the current directory, not historical user-type data.
-- References: https://docs.snowflake.com/en/sql-reference/account-usage/cortex_ai_functions_usage_history
-- https://docs.snowflake.com/en/sql-reference/account-usage/snowflake_coco_usage_history

-- ---------------------------------------------------------------------------
-- Seed IDENTITY_MAP from Snowflake's own user directory
--
-- Bootstrap unseen human subjects from today's directory, effective today only.
-- An email is an ASSERTED mapping, not proof of historical employment or an IdP
-- attestation. Blank email falls back to the login name with HEURISTIC confidence.
-- Never update an existing mapping: a directory refresh must not rewrite history
-- or reopen a closed interval. Maintain later changes through a dated HR feed.
--
-- DEPARTMENT and COST_CENTER are deliberately left NULL. They do not exist in
-- ACCOUNT_USAGE.USERS. Populate them from your IdP or HR export -- inventing them
-- here would put fabricated allocation data at the base of the model.
--
-- Service accounts are excluded. They have no department and no person behind
-- them, and letting them into an engagement-tier calculation produces a
-- non-existent "power user" at the top of every chart.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE AI_SPEND.CONTROL.SEED_SNOWFLAKE_IDENTITIES()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  ROWS_MERGED NUMBER;
BEGIN
  MERGE INTO AI_SPEND.CONTROL.IDENTITY_MAP AS tgt
  USING (
    SELECT
      'SNOWFLAKE_CORTEX'                       AS PLATFORM_KEY,
      u.USER_ID::VARCHAR                       AS SUBJECT_KEY,
      'PERSON' AS ENTITY_KIND,
      COALESCE(LOWER(NULLIF(TRIM(u.EMAIL), '')), LOWER(u.NAME)) AS PERSON_KEY,
      COALESCE(u.DISPLAY_NAME, u.NAME)         AS DISPLAY_NAME,
      IFF(NULLIF(TRIM(u.EMAIL), '') IS NOT NULL, 'ASSERTED', 'HEURISTIC') AS CONFIDENCE
    FROM SNOWFLAKE.ACCOUNT_USAGE.USERS u
    WHERE u.DELETED_ON IS NULL
      AND u.USER_ID IS NOT NULL AND u.USER_ID::VARCHAR <> '0'
      -- Exclude service accounts: no person, no department, and they would
      -- dominate any engagement-tier ranking.
      AND COALESCE(u.TYPE, 'PERSON') NOT IN ('SERVICE', 'LEGACY_SERVICE')
  ) AS src
  ON  tgt.PLATFORM_KEY = src.PLATFORM_KEY
  AND tgt.SUBJECT_KEY = src.SUBJECT_KEY
  WHEN NOT MATCHED THEN INSERT (
    PLATFORM_KEY, SUBJECT_KEY, PERSON_KEY, DISPLAY_NAME, CONFIDENCE, ENTITY_KIND, VALID_FROM
  ) VALUES (
    src.PLATFORM_KEY, src.SUBJECT_KEY, src.PERSON_KEY, src.DISPLAY_NAME,
    src.CONFIDENCE, src.ENTITY_KIND, CURRENT_DATE()
  );

  ROWS_MERGED := SQLROWCOUNT;
  RETURN 'Snowflake identities seeded: ' || :ROWS_MERGED::VARCHAR
         || '. DEPARTMENT and COST_CENTER still require an IdP or HR feed.';
END;
$$;

-- ---------------------------------------------------------------------------
-- Activate and verify
--
-- This platform needs no credential, so it can be activated immediately.
-- ---------------------------------------------------------------------------

CALL AI_SPEND.CONTROL.SEED_SNOWFLAKE_IDENTITIES();

UPDATE AI_SPEND.CONTROL.PLATFORM_REGISTRY
   SET IS_ACTIVE = TRUE
 WHERE PLATFORM_KEY = 'SNOWFLAKE_CORTEX';

-- Confirm data is flowing and identity resolution is working. A high
-- unmapped_subjects can reflect history predating the bootstrap, missing mappings,
-- dropped users, or non-person subjects. Qualify historical mappings separately.
--
-- The validity predicate on the join is NOT optional: without it a subject with
-- more than one dated mapping row multiplies the row count and inflates the credit
-- total, so a validation query would report numbers higher than reality.
WITH resolved AS (
    SELECT v.PLATFORM_KEY, v.REPORT_NAME, v.USAGE_DATE, v.SUBJECT_KEY,
           v.SERVICE_TYPE, v.CREDITS, m.PERSON_KEY
    FROM AI_SPEND.RAW.V_SNOWFLAKE_NATIVE_USAGE v
    LEFT JOIN AI_SPEND.CONTROL.IDENTITY_MAP m
      ON m.PLATFORM_KEY = v.PLATFORM_KEY AND m.SUBJECT_KEY = v.SUBJECT_KEY
     AND v.USAGE_DATE BETWEEN m.VALID_FROM AND m.VALID_TO
    WHERE v.USAGE_DATE >= DATEADD('day', -30, CURRENT_DATE())
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY v.PLATFORM_KEY, v.REPORT_NAME, v.USAGE_DATE, v.SUBJECT_KEY
      ORDER BY m.VALID_FROM DESC NULLS LAST, m.UPDATED_AT DESC NULLS LAST, m.PERSON_KEY
    ) = 1
)
SELECT
    v.SERVICE_TYPE,
    COUNT(*)                            AS user_day_rows,
    COUNT(DISTINCT v.SUBJECT_KEY)       AS distinct_users,
    ROUND(SUM(v.CREDITS), 4)            AS total_credits,
    COUNT(DISTINCT IFF(v.PERSON_KEY IS NULL, v.SUBJECT_KEY, NULL))
                                        AS unmapped_subjects,
    MAX(v.USAGE_DATE)                   AS latest_date
FROM resolved v
GROUP BY v.SERVICE_TYPE
ORDER BY total_credits DESC NULLS LAST;
