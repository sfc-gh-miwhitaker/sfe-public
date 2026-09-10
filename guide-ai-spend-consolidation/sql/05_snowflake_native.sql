/* Cross-platform AI spend consolidation — Snowflake native adapter
   Pair-programmed by SE Community + Cortex Code
   Expires: 2027-03-10

   The Snowflake side of the model. NO CREDENTIALS, NO API, NO NETWORK RULE --
   ACCOUNT_USAGE is already there. Run this immediately after sql/01 and you have a
   working end-to-end model with real data, which is the cheapest way to prove the
   design and the reports before negotiating access to any vendor admin API.

   Unions four ACCOUNT_USAGE views into a shape matching the adapter contract.
   Because it reads views rather than an external API, it skips the stage-and-COPY
   path and writes SHAPED-compatible rows directly. That is the one sanctioned
   deviation from the contract, and it is safe for the same reason it is a
   deviation: ACCOUNT_USAGE is already immutable and already retained.

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
     - COCO exposes a first-class INTERFACE column; Agent and CoWork carry the
       equivalent inside METADATA. Do not look for INTERFACE on the others.
*/

USE ROLE AI_SPEND_RL;
USE WAREHOUSE AI_SPEND_WH;

-- ---------------------------------------------------------------------------
-- Shredded view over the four Cortex usage views
--
-- A view rather than a table: ACCOUNT_USAGE is already the durable copy, so
-- materializing here would duplicate storage and add a staleness window for no
-- benefit. The SHAPED Dynamic Table in sql/06 does the materialization.
--
-- ACCOUNT_USAGE views carry latency measured in hours. That is why
-- EXPECTED_LAG_HOURS for this platform is 24 in the registry, not 1.
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
           ON u.USER_ID = f.USER_ID
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
        c.METADATA:interaction_interface::VARCHAR AS INTERACTION_INTERFACE,
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
    SUBJECT_KEY,
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
    COUNT(*)                          AS REQUEST_COUNT,
    COUNT(DISTINCT ENTITY_NAME)       AS DISTINCT_ENTITIES,
    MAX(ROLE_NAME)                    AS ROLE_NAME,
    MAX(INTERACTION_INTERFACE)        AS INTERACTION_INTERFACE,
    MAX_BY(USER_TAGS, USAGE_TS)       AS USER_TAGS,
    MAX(USAGE_TS)                     AS LAST_SEEN_TS
FROM combined
WHERE SUBJECT_KEY IS NOT NULL
  /* USER_ID 0 is a Snowflake-internal subject, not a person. Verified on the
     created date: it appears with no ACCOUNT_USAGE.USERS entry and, in a busy
     account, tens of thousands of requests and thousands of credits per day.
     Left in, it becomes the top "user" in every engagement and allocation chart
     and it will never resolve to a department. Excluded here rather than in the
     gold layer so it cannot leak into any downstream aggregate.

     Its credits are real account spend, so if your platform total must reconcile
     to the invoice, report it separately as non-attributable system usage --
     do not silently drop it from the total. */
  AND SUBJECT_KEY <> '0'
GROUP BY
    SERVICE_TYPE,
    TO_DATE(USAGE_TS),
    SUBJECT_KEY;

-- ---------------------------------------------------------------------------
-- Seed IDENTITY_MAP from Snowflake's own user directory
--
-- Snowflake is the one platform whose subject key maps to a person with no
-- guessing, because EMAIL is in the directory. Confidence is VERIFIED where an
-- email exists and HEURISTIC where it does not and we fall back to the login name.
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
      COALESCE(LOWER(u.EMAIL), LOWER(u.NAME))  AS PERSON_KEY,
      COALESCE(u.DISPLAY_NAME, u.NAME)         AS DISPLAY_NAME,
      IFF(u.EMAIL IS NOT NULL, 'VERIFIED', 'HEURISTIC') AS CONFIDENCE
    FROM SNOWFLAKE.ACCOUNT_USAGE.USERS u
    WHERE u.DELETED_ON IS NULL
      AND u.USER_ID IS NOT NULL
      -- Exclude service accounts: no person, no department, and they would
      -- dominate any engagement-tier ranking.
      AND COALESCE(u.TYPE, 'PERSON') NOT IN ('SERVICE', 'LEGACY_SERVICE')
  ) AS src
  ON  tgt.PLATFORM_KEY = src.PLATFORM_KEY
  AND tgt.SUBJECT_KEY = src.SUBJECT_KEY
  AND tgt.VALID_FROM = '1900-01-01'
  WHEN MATCHED THEN UPDATE SET
    -- DEPARTMENT, COST_CENTER, and BUSINESS_UNIT are NOT touched. If an HR feed
    -- has already enriched this row, re-seeding must not blank that out.
    tgt.PERSON_KEY = src.PERSON_KEY,
    tgt.DISPLAY_NAME = src.DISPLAY_NAME,
    tgt.CONFIDENCE = src.CONFIDENCE,
    tgt.UPDATED_AT = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN INSERT (
    PLATFORM_KEY, SUBJECT_KEY, PERSON_KEY, DISPLAY_NAME, CONFIDENCE
  ) VALUES (
    src.PLATFORM_KEY, src.SUBJECT_KEY, src.PERSON_KEY, src.DISPLAY_NAME,
    src.CONFIDENCE
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
-- unmapped_subjects count means SEED_SNOWFLAKE_IDENTITIES has not run or the
-- users have since been dropped.
--
-- The validity predicate on the join is NOT optional: without it a subject with
-- more than one dated mapping row multiplies the row count and inflates the credit
-- total, so a validation query would report numbers higher than reality.
SELECT
    v.SERVICE_TYPE,
    COUNT(*)                            AS user_day_rows,
    COUNT(DISTINCT v.SUBJECT_KEY)       AS distinct_users,
    ROUND(SUM(v.CREDITS), 4)            AS total_credits,
    COUNT(DISTINCT IFF(m.PERSON_KEY IS NULL, v.SUBJECT_KEY, NULL))
                                        AS unmapped_subjects,
    MAX(v.USAGE_DATE)                   AS latest_date
FROM AI_SPEND.RAW.V_SNOWFLAKE_NATIVE_USAGE v
LEFT JOIN AI_SPEND.CONTROL.IDENTITY_MAP m
       ON m.PLATFORM_KEY = v.PLATFORM_KEY
      AND m.SUBJECT_KEY = v.SUBJECT_KEY
      AND v.USAGE_DATE BETWEEN m.VALID_FROM AND m.VALID_TO
WHERE v.USAGE_DATE >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY v.SERVICE_TYPE
ORDER BY total_credits DESC NULLS LAST;
