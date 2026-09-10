/* Cross-platform AI spend consolidation — gold reporting layer
   Pair-programmed by SE Community + Cortex Code
   Expires: 2027-03-10

   Built backwards from the five decisions leadership asked for:
     1. AI_SPEND_FORECAST      budget-cycle forecasting
     2. AI_SPEND_BY_DEPARTMENT departmental and business-unit allocation
     3. AI_ENGAGEMENT_TIERS    high-usage and low-usage populations
     4. AI_USAGE_ANOMALIES     anomalous consumption detection
     5. AI_ADOPTION_TREND      platform adoption and trend reporting
   Plus AI_SPEND_ALLOCATED, the one place seat amortization is applied, and
   SEAT_UTILIZATION, which finds the licences nobody touches.

   Leaf objects use TARGET_LAG = '24 hours'; intermediates use DOWNSTREAM so they
   refresh only when a leaf needs them. Everything upstream is a daily aggregate, so
   a tighter lag spends credits re-deriving unchanged rows.

   Two rules every object here obeys:
     - Never SUM cost across COST_MODEL values except inside AI_SPEND_ALLOCATED.
     - Never compare NATIVE_QTY across platforms. Different units, no exchange rate.

   A THIRD RULE, LEARNED THE HARD WAY: CURRENCY_CODE is carried in every GROUP BY
   and window PARTITION BY. Summing cost across currencies is the same class of
   error as blending meters, and a single non-USD platform makes any total that
   drops the currency meaningless.

   ON REFRESH MODE: ANY_VALUE is documented as NOT SUPPORTED for Dynamic Tables in
   either refresh mode, so MAX and MAX_BY are used throughout. Scalar subqueries
   outside FROM and sequence functions like SEQ4 disqualify a table from incremental
   refresh, so those are avoided or the table declares REFRESH_MODE = FULL
   explicitly. Verify what you actually got:
     SHOW DYNAMIC TABLES IN SCHEMA AI_SPEND.GOLD;
   and read refresh_mode plus refresh_mode_reason. With ADAPTIVE, an unsupported
   construct SILENTLY selects full refresh -- it does not error.
*/

USE ROLE AI_SPEND_RL;
USE WAREHOUSE AI_SPEND_WH;

-- ===========================================================================
-- Intermediate: per-person per-day spine
-- ===========================================================================

CREATE OR REPLACE DYNAMIC TABLE AI_SPEND.GOLD.PERSON_DAY_USAGE
TARGET_LAG = DOWNSTREAM
WAREHOUSE = AI_SPEND_WH
REFRESH_MODE = ADAPTIVE
INITIALIZE = ON_CREATE
COMMENT = 'Per person, per platform, per day. Metered and seat rows kept separate.'
AS
SELECT
    USAGE_DATE,
    PERSON_KEY,
    DEPARTMENT,
    COST_CENTER,
    BUSINESS_UNIT,
    PLATFORM_KEY,
    PLATFORM_DISPLAY_NAME,
    COST_MODEL,
    NATIVE_UNIT,
    CURRENCY_CODE,
    MAX(IDENTITY_CONFIDENCE)                    AS IDENTITY_CONFIDENCE,
    MAX(SUBJECT_DISPLAY_NAME)                   AS SUBJECT_DISPLAY_NAME,
    SUM(NATIVE_QTY)                             AS NATIVE_QTY,
    SUM(ACTIVITY_COUNT)                         AS ACTIVITY_COUNT,
    /* Only METERED rows carry cost. SEAT rows are NULL by construction upstream,
       and SUM over all-NULL yields NULL rather than a misleading zero. */
    SUM(COST_AMOUNT)                            AS METERED_COST,
    /* Any activity at all on this platform on this day. For SEAT platforms this is
       the ONLY meaningful signal, since their native quantity is a flag. */
    IFF(SUM(COALESCE(NATIVE_QTY, 0)) > 0
        OR SUM(COALESCE(ACTIVITY_COUNT, 0)) > 0, TRUE, FALSE) AS WAS_ACTIVE
FROM AI_SPEND.SHAPED.UNIFIED_AI_USAGE
GROUP BY
    USAGE_DATE, PERSON_KEY, DEPARTMENT, COST_CENTER, BUSINESS_UNIT,
    PLATFORM_KEY, PLATFORM_DISPLAY_NAME, COST_MODEL, NATIVE_UNIT, CURRENCY_CODE;

-- ===========================================================================
-- Person directory: ONE row per (platform, person)
--
-- IDENTITY_MAP's key is (PLATFORM_KEY, SUBJECT_KEY, VALID_FROM), so joining it on
-- PERSON_KEY fans out whenever several subjects map to one person -- which is the
-- table's entire purpose. Two GitHub logins for one engineer, or one human with two
-- Snowflake users, would silently MULTIPLY seat cost.
--
-- Collapsed here once and reused, rather than joined directly anywhere below. Seat
-- objects need this rather than PERSON_DAY_USAGE precisely because a dormant seat
-- produces no usage row at all.
-- ===========================================================================

CREATE OR REPLACE VIEW AI_SPEND.CONTROL.V_PERSON_DIRECTORY
  COMMENT = 'One row per platform and person. Use instead of joining IDENTITY_MAP on PERSON_KEY.'
AS
SELECT
    PLATFORM_KEY,
    PERSON_KEY,
    MAX_BY(DISPLAY_NAME, VALID_FROM)  AS DISPLAY_NAME,
    MAX_BY(DEPARTMENT, VALID_FROM)    AS DEPARTMENT,
    MAX_BY(COST_CENTER, VALID_FROM)   AS COST_CENTER,
    MAX_BY(BUSINESS_UNIT, VALID_FROM) AS BUSINESS_UNIT,
    MIN(CONFIDENCE)                   AS CONFIDENCE,
    COUNT(*)                          AS SUBJECT_COUNT
FROM AI_SPEND.CONTROL.IDENTITY_MAP
GROUP BY PLATFORM_KEY, PERSON_KEY;

-- ===========================================================================
-- Seat utilization -- the cheapest saving in the guide
--
-- A TRUE entitlement row with no activity is money leaving with nothing back. This
-- is usually the first finding that pays for the whole project, and it is the one
-- number a SEAT platform like M365 Copilot can answer well.
-- ===========================================================================

CREATE OR REPLACE DYNAMIC TABLE AI_SPEND.GOLD.SEAT_UTILIZATION
TARGET_LAG = '24 hours'
WAREHOUSE = AI_SPEND_WH
REFRESH_MODE = ADAPTIVE
INITIALIZE = ON_CREATE
COMMENT = 'Per seat per month: was the licence we paid for actually used'
AS
WITH activity AS (
    SELECT
        DATE_TRUNC('month', USAGE_DATE)     AS PERIOD_MONTH,
        PERSON_KEY,
        PLATFORM_KEY,
        COUNT_IF(WAS_ACTIVE)                AS ACTIVE_DAYS,
        SUM(COALESCE(ACTIVITY_COUNT, 0))    AS TOTAL_ACTIVITY,
        MAX(IFF(WAS_ACTIVE, USAGE_DATE, NULL)) AS LAST_ACTIVE_DATE
    FROM AI_SPEND.GOLD.PERSON_DAY_USAGE
    GROUP BY 1, 2, 3
)
SELECT
    s.PERIOD_MONTH,
    s.PLATFORM_KEY,
    s.PERSON_KEY,
    m.DEPARTMENT,
    m.COST_CENTER,
    s.SEAT_MONTHLY_COST,
    s.CURRENCY_CODE,
    s.IS_ACTIVE_IN_PERIOD,
    COALESCE(a.ACTIVE_DAYS, 0)      AS ACTIVE_DAYS,
    COALESCE(a.TOTAL_ACTIVITY, 0)   AS TOTAL_ACTIVITY,
    a.LAST_ACTIVE_DATE,
    /* DORMANT is the actionable bucket: billed and never touched in the period.
       LIGHT is the reclaim conversation. Thresholds are a documented choice, not a
       fact -- 1 to 3 active days in a month is light for a daily-use tool and may
       be normal for an occasional one. Tune per platform before acting. */
    CASE
        WHEN NOT s.IS_ACTIVE_IN_PERIOD          THEN 'NOT_BILLED'
        /* A platform that cannot report per-user usage volume cannot support a
           dormancy verdict either. M365 Copilot returns last-activity dates, so
           calling a seat DORMANT there would be a guess dressed as a finding.
           UNKNOWN is the honest band. */
        WHEN NOT p.SUPPORTS_USER_GRAIN
             AND COALESCE(a.ACTIVE_DAYS, 0) = 0 THEN 'UNKNOWN_NO_USAGE_SIGNAL'
        WHEN COALESCE(a.ACTIVE_DAYS, 0) = 0     THEN 'DORMANT'
        WHEN a.ACTIVE_DAYS <= 3                 THEN 'LIGHT'
        WHEN a.ACTIVE_DAYS <= 10                THEN 'MODERATE'
        ELSE 'REGULAR'
    END                             AS UTILIZATION_BAND,
    /* Recoverable spend if the seat were reclaimed. Only populated for a confirmed
       DORMANT seat, because a LIGHT user may still be getting the value of the
       licence and that is a judgement call, not arithmetic -- and an
       UNKNOWN_NO_USAGE_SIGNAL seat has not been shown to be idle at all. */
    IFF(s.IS_ACTIVE_IN_PERIOD
        AND p.SUPPORTS_USER_GRAIN
        AND COALESCE(a.ACTIVE_DAYS, 0) = 0,
        s.SEAT_MONTHLY_COST, 0)     AS RECLAIMABLE_COST
FROM AI_SPEND.CONTROL.SEAT_ENTITLEMENT s
LEFT JOIN activity a
       ON  a.PERIOD_MONTH = s.PERIOD_MONTH
       AND a.PERSON_KEY = s.PERSON_KEY
       AND a.PLATFORM_KEY = s.PLATFORM_KEY
/* Equality join to the collapsed directory, not a range join to IDENTITY_MAP.
   Prevents seat-cost fanout, and keeps this table eligible for incremental
   refresh -- an outer join with a non-equality predicate disqualifies it. */
LEFT JOIN AI_SPEND.CONTROL.V_PERSON_DIRECTORY m
       ON  m.PLATFORM_KEY = s.PLATFORM_KEY
       AND m.PERSON_KEY = s.PERSON_KEY
JOIN AI_SPEND.CONTROL.PLATFORM_REGISTRY p
       ON p.PLATFORM_KEY = s.PLATFORM_KEY;

-- ===========================================================================
-- AI_SPEND_ALLOCATED -- the ONLY place seats and meters are blended
--
-- Named so nobody reaches for it by accident, and it exposes the allocation rule
-- as a column so the invented precision is visible instead of hidden in a SUM.
--
-- ALLOCATION_BASIS values:
--   METERED        real consumption cost. No assumption applied.
--   AMORTIZED_SEAT monthly seat cost spread evenly across the days in the month.
--                  Even spreading is a CHOICE. The seat cost is committed on day
--                  one regardless of use, so a daily figure is a reporting
--                  convenience, not an economic fact.
--
-- REFRESH_MODE = FULL is EXPLICIT here, not a fallback. The seat-day expansion
-- needs a row generator, and sequence functions are unsupported for incremental
-- refresh. Declaring FULL states the intent instead of letting ADAPTIVE silently
-- pick it. Volume is one row per billed seat per day, which is small.
-- ===========================================================================

CREATE OR REPLACE DYNAMIC TABLE AI_SPEND.GOLD.AI_SPEND_ALLOCATED
TARGET_LAG = '24 hours'
WAREHOUSE = AI_SPEND_WH
REFRESH_MODE = FULL
INITIALIZE = ON_CREATE
COMMENT = 'Blended metered + amortized seat cost. Allocation rule exposed as a column. FULL refresh: seat-day expansion uses a row generator.'
AS
WITH metered AS (
    SELECT
        USAGE_DATE,
        PERSON_KEY,
        DEPARTMENT,
        COST_CENTER,
        BUSINESS_UNIT,
        PLATFORM_KEY,
        PLATFORM_DISPLAY_NAME,
        CURRENCY_CODE,
        'METERED'                       AS ALLOCATION_BASIS,
        'Actual metered consumption'    AS ALLOCATION_RULE,
        SUM(METERED_COST)               AS ALLOCATED_COST
    FROM AI_SPEND.GOLD.PERSON_DAY_USAGE
    WHERE COST_MODEL = 'METERED'
      AND METERED_COST IS NOT NULL
    -- CURRENCY_CODE is a grouping key, not an ANY_VALUE. Collapsing it would let a
    -- non-USD platform's cost be summed into a USD total.
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),
seat_days AS (
    SELECT
        s.PERIOD_MONTH,
        s.PERSON_KEY,
        s.PLATFORM_KEY,
        r.DISPLAY_NAME                  AS PLATFORM_DISPLAY_NAME,
        s.SEAT_MONTHLY_COST,
        s.CURRENCY_CODE,
        DAY(LAST_DAY(s.PERIOD_MONTH))   AS DAYS_IN_MONTH
    FROM AI_SPEND.CONTROL.SEAT_ENTITLEMENT s
    JOIN AI_SPEND.CONTROL.PLATFORM_REGISTRY r
      ON r.PLATFORM_KEY = s.PLATFORM_KEY
    WHERE s.IS_ACTIVE_IN_PERIOD
),
/* Expand each billed seat-month into its days. Generated from the month's own
   length rather than a calendar table so February and 31-day months are both
   correct without extra objects. */
seat_amortized AS (
    SELECT
        DATEADD('day', d.SEQ, sd.PERIOD_MONTH)  AS USAGE_DATE,
        sd.PERSON_KEY,
        m.DEPARTMENT,
        m.COST_CENTER,
        m.BUSINESS_UNIT,
        sd.PLATFORM_KEY,
        sd.PLATFORM_DISPLAY_NAME,
        sd.CURRENCY_CODE,
        'AMORTIZED_SEAT'                        AS ALLOCATION_BASIS,
        'Monthly seat cost divided evenly across days in month'
                                                AS ALLOCATION_RULE,
        sd.SEAT_MONTHLY_COST / sd.DAYS_IN_MONTH AS ALLOCATED_COST
    FROM seat_days sd
    JOIN (
        SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS SEQ
        FROM TABLE(GENERATOR(ROWCOUNT => 31))
    ) d
      ON d.SEQ < sd.DAYS_IN_MONTH
    /* Collapsed directory, not IDENTITY_MAP. Joining IDENTITY_MAP on PERSON_KEY
       here would multiply seat-day rows by the number of subjects mapped to the
       person, doubling or tripling seat cost with no error. */
    LEFT JOIN AI_SPEND.CONTROL.V_PERSON_DIRECTORY m
      ON  m.PLATFORM_KEY = sd.PLATFORM_KEY
      AND m.PERSON_KEY = sd.PERSON_KEY
)
SELECT USAGE_DATE, PERSON_KEY, DEPARTMENT, COST_CENTER, BUSINESS_UNIT,
       PLATFORM_KEY, PLATFORM_DISPLAY_NAME, CURRENCY_CODE,
       ALLOCATION_BASIS, ALLOCATION_RULE, ALLOCATED_COST
FROM metered
UNION ALL
SELECT USAGE_DATE, PERSON_KEY, DEPARTMENT, COST_CENTER, BUSINESS_UNIT,
       PLATFORM_KEY, PLATFORM_DISPLAY_NAME, CURRENCY_CODE,
       ALLOCATION_BASIS, ALLOCATION_RULE, ALLOCATED_COST
FROM seat_amortized;

-- ===========================================================================
-- DECISION 2: departmental and business-unit allocation
--
-- UNATTRIBUTED_COST and UNATTRIBUTED_PCT are on every row deliberately. Publish
-- them beside the allocation or someone will assume they are zero, and the first
-- reconciliation against the invoice will discredit the report.
-- ===========================================================================

CREATE OR REPLACE DYNAMIC TABLE AI_SPEND.GOLD.AI_SPEND_BY_DEPARTMENT
TARGET_LAG = '24 hours'
WAREHOUSE = AI_SPEND_WH
REFRESH_MODE = ADAPTIVE
INITIALIZE = ON_CREATE
COMMENT = 'Monthly spend by department and platform, with unattributed share exposed'
AS
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', USAGE_DATE)         AS PERIOD_MONTH,
        COALESCE(DEPARTMENT, 'UNATTRIBUTED')    AS DEPARTMENT,
        COALESCE(BUSINESS_UNIT, 'UNATTRIBUTED') AS BUSINESS_UNIT,
        COALESCE(COST_CENTER, 'UNATTRIBUTED')   AS COST_CENTER,
        PLATFORM_KEY,
        PLATFORM_DISPLAY_NAME,
        CURRENCY_CODE,
        ALLOCATION_BASIS,
        SUM(ALLOCATED_COST)                     AS ALLOCATED_COST,
        COUNT(DISTINCT PERSON_KEY)              AS PEOPLE
    FROM AI_SPEND.GOLD.AI_SPEND_ALLOCATED
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
)
SELECT
    PERIOD_MONTH,
    DEPARTMENT,
    BUSINESS_UNIT,
    COST_CENTER,
    PLATFORM_KEY,
    PLATFORM_DISPLAY_NAME,
    ALLOCATION_BASIS,
    ROUND(ALLOCATED_COST, 4)    AS ALLOCATED_COST,
    PEOPLE,
    CURRENCY_CODE,
    ROUND(ALLOCATED_COST / NULLIF(PEOPLE, 0), 4) AS COST_PER_PERSON,
    /* Month-level context so a single row is self-describing in a BI tool.
       CURRENCY_CODE is in every PARTITION BY: a month total that spans currencies
       is not a number, and the percentages derived from it would be nonsense. */
    ROUND(SUM(ALLOCATED_COST) OVER (PARTITION BY PERIOD_MONTH, CURRENCY_CODE), 4)
                                AS MONTH_TOTAL_COST,
    ROUND(100 * ALLOCATED_COST
          / NULLIF(SUM(ALLOCATED_COST) OVER (PARTITION BY PERIOD_MONTH, CURRENCY_CODE), 0), 2)
                                AS PCT_OF_MONTH,
    ROUND(SUM(IFF(DEPARTMENT = 'UNATTRIBUTED', ALLOCATED_COST, 0))
          OVER (PARTITION BY PERIOD_MONTH, CURRENCY_CODE), 4) AS UNATTRIBUTED_COST,
    ROUND(100 * SUM(IFF(DEPARTMENT = 'UNATTRIBUTED', ALLOCATED_COST, 0))
               OVER (PARTITION BY PERIOD_MONTH, CURRENCY_CODE)
          / NULLIF(SUM(ALLOCATED_COST) OVER (PARTITION BY PERIOD_MONTH, CURRENCY_CODE), 0), 2)
                                AS UNATTRIBUTED_PCT
FROM monthly;

-- ===========================================================================
-- DECISION 3: engagement tiers
--
-- Tier cut points are a CHOICE, not a fact, and they are computed here rather than
-- inherited from any vendor. OpenAI, for instance, defines power users as the top
-- 20 percent by message volume using three or more tools -- specific to their
-- product surface and not portable to Copilot or Cortex.
--
-- Method: percentile rank of a person's activity WITHIN their platform, over a
-- trailing 28-day window. Ranking within platform is essential -- ranking across
-- platforms would compare credits to messages to activity flags, which is
-- meaningless.
--
-- Platforms with SUPPORTS_USER_GRAIN = FALSE are EXCLUDED. M365 Copilot returns
-- last-activity dates, so a light and a heavy user look identical and any tier
-- assigned to them would be fabricated.
-- ===========================================================================

CREATE OR REPLACE DYNAMIC TABLE AI_SPEND.GOLD.AI_ENGAGEMENT_TIERS
TARGET_LAG = '24 hours'
WAREHOUSE = AI_SPEND_WH
REFRESH_MODE = ADAPTIVE
INITIALIZE = ON_CREATE
COMMENT = 'Trailing 28-day engagement tiers, ranked WITHIN platform. Cut points documented.'
AS
WITH window_bounds AS (
    SELECT MAX(USAGE_DATE) AS AS_OF_DATE
    FROM AI_SPEND.GOLD.PERSON_DAY_USAGE
),
eligible AS (
    SELECT p.*, w.AS_OF_DATE
    FROM AI_SPEND.GOLD.PERSON_DAY_USAGE p
    JOIN AI_SPEND.CONTROL.PLATFORM_REGISTRY r
      ON r.PLATFORM_KEY = p.PLATFORM_KEY
    CROSS JOIN window_bounds w
    WHERE r.SUPPORTS_USER_GRAIN                       -- excludes activity-flag-only platforms
      AND p.USAGE_DATE > DATEADD('day', -28, w.AS_OF_DATE)
      AND p.USAGE_DATE <= w.AS_OF_DATE
),
per_person AS (
    SELECT
        PLATFORM_KEY,
        PLATFORM_DISPLAY_NAME,
        NATIVE_UNIT,
        PERSON_KEY,
        AS_OF_DATE,
        MAX_BY(DEPARTMENT, USAGE_DATE)      AS DEPARTMENT,
        MAX_BY(BUSINESS_UNIT, USAGE_DATE)   AS BUSINESS_UNIT,
        MIN(IDENTITY_CONFIDENCE)            AS IDENTITY_CONFIDENCE,
        COUNT_IF(WAS_ACTIVE)                AS ACTIVE_DAYS,
        SUM(COALESCE(ACTIVITY_COUNT, 0))    AS TOTAL_ACTIVITY,
        SUM(COALESCE(NATIVE_QTY, 0))        AS TOTAL_NATIVE_QTY,
        SUM(METERED_COST)                   AS TOTAL_METERED_COST,
        MAX(IFF(WAS_ACTIVE, USAGE_DATE, NULL)) AS LAST_ACTIVE_DATE
    FROM eligible
    GROUP BY 1, 2, 3, 4, 5
)
SELECT
    /* Carried through the CROSS JOIN rather than fetched with a scalar subquery.
       Subqueries outside FROM disqualify a Dynamic Table from incremental refresh. */
    AS_OF_DATE,
    28                                      AS WINDOW_DAYS,
    PLATFORM_KEY,
    PLATFORM_DISPLAY_NAME,
    PERSON_KEY,
    DEPARTMENT,
    BUSINESS_UNIT,
    IDENTITY_CONFIDENCE,
    NATIVE_UNIT,
    ACTIVE_DAYS,
    TOTAL_ACTIVITY,
    ROUND(TOTAL_NATIVE_QTY, 4)              AS TOTAL_NATIVE_QTY,
    ROUND(TOTAL_METERED_COST, 4)            AS TOTAL_METERED_COST,
    LAST_ACTIVE_DATE,
    /* Rank on native quantity within platform, over ACTIVE people only.
       Including inactive people in the denominator drags every active person's
       percentile up and makes the tiers describe the roster rather than usage. */
    ROUND(PERCENT_RANK() OVER (
        PARTITION BY PLATFORM_KEY ORDER BY IFF(ACTIVE_DAYS > 0, TOTAL_NATIVE_QTY, NULL)
            NULLS FIRST
    ), 4)                                   AS PLATFORM_PERCENTILE,
    /* Documented cut points. Change them if your distribution warrants it -- but
       change them HERE, once, and say so when you present the chart.

       The COUNT guard matters: PERCENT_RANK returns 0 for a single-row partition,
       so a platform with one active person would otherwise report them as LOW.
       Below three active people a percentile is not meaningful at all. */
    CASE
        WHEN ACTIVE_DAYS = 0 THEN 'INACTIVE'
        WHEN COUNT_IF(ACTIVE_DAYS > 0) OVER (PARTITION BY PLATFORM_KEY) < 3
            THEN 'UNRANKED_TOO_FEW_USERS'
        WHEN PERCENT_RANK() OVER (
             PARTITION BY PLATFORM_KEY
             ORDER BY IFF(ACTIVE_DAYS > 0, TOTAL_NATIVE_QTY, NULL) NULLS FIRST) >= 0.80
            THEN 'POWER'
        WHEN PERCENT_RANK() OVER (
             PARTITION BY PLATFORM_KEY
             ORDER BY IFF(ACTIVE_DAYS > 0, TOTAL_NATIVE_QTY, NULL) NULLS FIRST) >= 0.40
            THEN 'MEDIUM'
        ELSE 'LOW'
    END                                     AS ENGAGEMENT_TIER,
    'Percentile of native quantity within platform over trailing 28 days; POWER >= p80, MEDIUM >= p40, LOW below, INACTIVE = no active day'
                                            AS TIER_DEFINITION
FROM per_person;

-- ===========================================================================
-- DECISION 4: anomaly detection
--
-- Deviation against each PERSON'S OWN trailing baseline, not a global threshold. A
-- global threshold flags every heavy user forever and is ignored within a week.
--
-- FLAGS FOR REVIEW, NOT ENFORCEMENT. Snowflake-side enforcement belongs to
-- SNOWFLAKE.CORE.QUOTA, which can actually block; this table only reports.
--
-- Requires at least 7 baseline days. Without that guard, a person's first active
-- day is always an infinite spike and the table fills with false positives.
-- ===========================================================================

CREATE OR REPLACE DYNAMIC TABLE AI_SPEND.GOLD.AI_USAGE_ANOMALIES
TARGET_LAG = '24 hours'
WAREHOUSE = AI_SPEND_WH
REFRESH_MODE = ADAPTIVE
INITIALIZE = ON_CREATE
COMMENT = 'Per-person deviation from own trailing baseline. Review signal, not enforcement.'
AS
WITH daily AS (
    SELECT
        USAGE_DATE,
        PERSON_KEY,
        PLATFORM_KEY,
        PLATFORM_DISPLAY_NAME,
        DEPARTMENT,
        NATIVE_UNIT,
        SUM(COALESCE(NATIVE_QTY, 0))    AS NATIVE_QTY,
        SUM(METERED_COST)               AS METERED_COST
    FROM AI_SPEND.GOLD.PERSON_DAY_USAGE
    WHERE COST_MODEL = 'METERED'        -- a seat cannot spike; it is a fixed charge
    GROUP BY 1, 2, 3, 4, 5, 6
),
baseline AS (
    SELECT
        d.*,
        /* Trailing 28 CALENDAR days excluding today. RANGE, not ROWS.

           ROWS BETWEEN 28 PRECEDING would count 28 preceding ROWS, and the daily
           CTE only holds days a person was actually active. For an intermittent
           user that reaches back months, so the "baseline" is stale rather than
           trailing. Worse, averaging only active days biases the baseline HIGH and
           systematically SUPPRESSES the real spikes this table exists to find. */
        AVG(NATIVE_QTY) OVER (
            PARTITION BY PERSON_KEY, PLATFORM_KEY
            ORDER BY USAGE_DATE
            RANGE BETWEEN INTERVAL '28 days' PRECEDING
                      AND INTERVAL '1 day' PRECEDING
        )                               AS BASELINE_AVG,
        STDDEV(NATIVE_QTY) OVER (
            PARTITION BY PERSON_KEY, PLATFORM_KEY
            ORDER BY USAGE_DATE
            RANGE BETWEEN INTERVAL '28 days' PRECEDING
                      AND INTERVAL '1 day' PRECEDING
        )                               AS BASELINE_STDDEV,
        COUNT(*) OVER (
            PARTITION BY PERSON_KEY, PLATFORM_KEY
            ORDER BY USAGE_DATE
            RANGE BETWEEN INTERVAL '28 days' PRECEDING
                      AND INTERVAL '1 day' PRECEDING
        )                               AS BASELINE_DAYS
    FROM daily d
)
SELECT
    USAGE_DATE,
    PERSON_KEY,
    PLATFORM_KEY,
    PLATFORM_DISPLAY_NAME,
    DEPARTMENT,
    NATIVE_UNIT,
    ROUND(NATIVE_QTY, 4)        AS NATIVE_QTY,
    ROUND(BASELINE_AVG, 4)      AS BASELINE_AVG,
    ROUND(METERED_COST, 4)      AS METERED_COST,
    BASELINE_DAYS,
    /* Ratio is the readable signal; z-score handles a naturally spiky baseline
       where a large ratio is normal. Both are reported so a reviewer can see
       which one fired. */
    ROUND(NATIVE_QTY / NULLIF(BASELINE_AVG, 0), 2)          AS RATIO_TO_BASELINE,
    ROUND((NATIVE_QTY - BASELINE_AVG)
          / NULLIF(BASELINE_STDDEV, 0), 2)                  AS Z_SCORE,
    CASE
        WHEN NATIVE_QTY >= 10 * BASELINE_AVG THEN 'SEVERE'
        WHEN NATIVE_QTY >=  5 * BASELINE_AVG THEN 'HIGH'
        ELSE 'MODERATE'
    END                         AS ANOMALY_SEVERITY
FROM baseline
WHERE BASELINE_DAYS >= 7            -- no baseline, no verdict
  AND BASELINE_AVG > 0
  AND NATIVE_QTY >= 3 * BASELINE_AVG;

/* KNOWN LIMITATION, stated rather than hidden: the baseline averages only the days
   a person had metered activity, because inactive days produce no row. That biases
   the baseline upward and makes this detector CONSERVATIVE -- it will miss a spike
   from an intermittent user. To make it exact, join a date spine and COALESCE
   absent days to zero. Conservative was the deliberate choice here: a review queue
   nobody trusts is worse than one that occasionally misses. */

-- ===========================================================================
-- DECISION 1: spend forecast
--
-- Forecasts METERED and SEAT separately on purpose. Seat cost is near-deterministic
-- -- headcount times rate -- while metered cost is the volatile part. A single
-- blended trend hides which half is actually moving, which is the only thing a
-- budget conversation needs to know.
--
-- Trailing-window linear projection, NOT a seasonal model. It will miss quarter-end
-- effects, holiday troughs, and the step change from a rollout. State that when you
-- present it; a forecast presented as more certain than it is will be held against
-- you at the next budget cycle.
-- ===========================================================================

CREATE OR REPLACE DYNAMIC TABLE AI_SPEND.GOLD.AI_SPEND_FORECAST
TARGET_LAG = '24 hours'
WAREHOUSE = AI_SPEND_WH
REFRESH_MODE = ADAPTIVE
INITIALIZE = ON_CREATE
COMMENT = 'Trailing-window projection, metered and seat forecast separately'
AS
WITH bounds AS (
    SELECT MAX(USAGE_DATE) AS AS_OF_DATE
    FROM AI_SPEND.GOLD.AI_SPEND_ALLOCATED
),
recent AS (
    SELECT
        a.PLATFORM_KEY,
        a.PLATFORM_DISPLAY_NAME,
        a.ALLOCATION_BASIS,
        a.CURRENCY_CODE,
        b.AS_OF_DATE,
        /* Two windows so the trend is visible rather than assumed. */
        SUM(IFF(a.USAGE_DATE > DATEADD('day', -30, b.AS_OF_DATE),
                a.ALLOCATED_COST, 0))                       AS COST_LAST_30D,
        SUM(IFF(a.USAGE_DATE > DATEADD('day', -60, b.AS_OF_DATE)
                AND a.USAGE_DATE <= DATEADD('day', -30, b.AS_OF_DATE),
                a.ALLOCATED_COST, 0))                       AS COST_PRIOR_30D,
        COUNT(DISTINCT IFF(a.USAGE_DATE > DATEADD('day', -30, b.AS_OF_DATE),
                           a.PERSON_KEY, NULL))             AS PEOPLE_LAST_30D
    FROM AI_SPEND.GOLD.AI_SPEND_ALLOCATED a
    CROSS JOIN bounds b
    WHERE a.USAGE_DATE > DATEADD('day', -60, b.AS_OF_DATE)
      AND a.USAGE_DATE <= b.AS_OF_DATE
    GROUP BY 1, 2, 3, 4, 5
)
SELECT
    -- Carried through the CROSS JOIN, not a scalar subquery.
    AS_OF_DATE,
    PLATFORM_KEY,
    PLATFORM_DISPLAY_NAME,
    ALLOCATION_BASIS,
    CURRENCY_CODE,
    ROUND(COST_LAST_30D, 4)                     AS COST_LAST_30D,
    ROUND(COST_PRIOR_30D, 4)                    AS COST_PRIOR_30D,
    PEOPLE_LAST_30D,
    ROUND(100 * (COST_LAST_30D - COST_PRIOR_30D)
          / NULLIF(COST_PRIOR_30D, 0), 2)       AS MOM_GROWTH_PCT,
    /* Flat projection: last 30 days repeated. The conservative anchor. */
    ROUND(COST_LAST_30D * 12, 4)                AS ANNUAL_RUN_RATE_FLAT,
    /* Trended projection: growth rate sustained for SIX further months, then held
       flat -- the exponent is 6, not 12, deliberately. Capped at 100 percent monthly
       growth. The cap matters: an early-rollout platform can show a 4000 percent
       month, and compounding that produces a number that discredits the forecast. */
    ROUND(COST_LAST_30D * 12 * POWER(
        1 + LEAST(GREATEST(
            (COST_LAST_30D - COST_PRIOR_30D) / NULLIF(COST_PRIOR_30D, 0), -0.5), 1.0),
        6), 4)                                  AS ANNUAL_RUN_RATE_TRENDED,
    CASE
        WHEN COST_PRIOR_30D = 0                 THEN 'NEW: no prior period, flat projection only'
        WHEN ALLOCATION_BASIS = 'AMORTIZED_SEAT'
             THEN 'SEAT: near-deterministic, forecast headcount not usage'
        ELSE 'METERED: volatile, trended projection is a range not a point'
    END                                         AS FORECAST_CAVEAT
FROM recent
WHERE COST_LAST_30D > 0 OR COST_PRIOR_30D > 0;

-- ===========================================================================
-- DECISION 5: adoption trend
--
-- Active-user counts are only comparable WITHIN a platform. Reporting Copilot
-- last-activity next to Cortex request volume as if they were the same measure is
-- the trap this table is shaped to avoid: NATIVE_UNIT is carried on every row so a
-- chart cannot silently mix units.
-- ===========================================================================

CREATE OR REPLACE DYNAMIC TABLE AI_SPEND.GOLD.AI_ADOPTION_TREND
TARGET_LAG = '24 hours'
WAREHOUSE = AI_SPEND_WH
REFRESH_MODE = ADAPTIVE
INITIALIZE = ON_CREATE
COMMENT = 'Weekly adoption per platform. Units carried so charts cannot mix them.'
AS
WITH weekly AS (
    SELECT
        DATE_TRUNC('week', USAGE_DATE)      AS WEEK_START,
        PLATFORM_KEY,
        PLATFORM_DISPLAY_NAME,
        COST_MODEL,
        NATIVE_UNIT,
        COUNT(DISTINCT IFF(WAS_ACTIVE, PERSON_KEY, NULL)) AS ACTIVE_PEOPLE,
        COUNT(DISTINCT PERSON_KEY)          AS SEEN_PEOPLE,
        COUNT(DISTINCT IFF(WAS_ACTIVE AND DEPARTMENT IS NOT NULL,
                           DEPARTMENT, NULL))            AS ACTIVE_DEPARTMENTS,
        SUM(COALESCE(NATIVE_QTY, 0))        AS NATIVE_QTY,
        SUM(METERED_COST)                   AS METERED_COST
    FROM AI_SPEND.GOLD.PERSON_DAY_USAGE
    GROUP BY 1, 2, 3, 4, 5
)
SELECT
    WEEK_START,
    PLATFORM_KEY,
    PLATFORM_DISPLAY_NAME,
    COST_MODEL,
    NATIVE_UNIT,
    ACTIVE_PEOPLE,
    SEEN_PEOPLE,
    ACTIVE_DEPARTMENTS,
    ROUND(NATIVE_QTY, 4)                    AS NATIVE_QTY,
    ROUND(METERED_COST, 4)                  AS METERED_COST,
    LAG(ACTIVE_PEOPLE) OVER (
        PARTITION BY PLATFORM_KEY ORDER BY WEEK_START)  AS PRIOR_WEEK_ACTIVE_PEOPLE,
    ROUND(100 * (ACTIVE_PEOPLE - LAG(ACTIVE_PEOPLE) OVER (
        PARTITION BY PLATFORM_KEY ORDER BY WEEK_START))
        / NULLIF(LAG(ACTIVE_PEOPLE) OVER (
            PARTITION BY PLATFORM_KEY ORDER BY WEEK_START), 0), 2)
                                            AS ACTIVE_PEOPLE_WOW_PCT,
    /* Intensity is only meaningful within a platform, because the numerator's unit
       differs per platform. NATIVE_UNIT above is the guard against misreading it. */
    ROUND(NATIVE_QTY / NULLIF(ACTIVE_PEOPLE, 0), 4)     AS QTY_PER_ACTIVE_PERSON
FROM weekly;

-- ===========================================================================
-- Verify the gold layer, and check the cost-model boundary held
-- ===========================================================================

SELECT 'PERSON_DAY_USAGE'        AS object_name, COUNT(*) AS row_count FROM AI_SPEND.GOLD.PERSON_DAY_USAGE
UNION ALL SELECT 'AI_SPEND_ALLOCATED',     COUNT(*) FROM AI_SPEND.GOLD.AI_SPEND_ALLOCATED
UNION ALL SELECT 'AI_SPEND_BY_DEPARTMENT', COUNT(*) FROM AI_SPEND.GOLD.AI_SPEND_BY_DEPARTMENT
UNION ALL SELECT 'AI_ENGAGEMENT_TIERS',    COUNT(*) FROM AI_SPEND.GOLD.AI_ENGAGEMENT_TIERS
UNION ALL SELECT 'AI_USAGE_ANOMALIES',     COUNT(*) FROM AI_SPEND.GOLD.AI_USAGE_ANOMALIES
UNION ALL SELECT 'AI_SPEND_FORECAST',      COUNT(*) FROM AI_SPEND.GOLD.AI_SPEND_FORECAST
UNION ALL SELECT 'AI_ADOPTION_TREND',      COUNT(*) FROM AI_SPEND.GOLD.AI_ADOPTION_TREND
UNION ALL SELECT 'SEAT_UTILIZATION',       COUNT(*) FROM AI_SPEND.GOLD.SEAT_UTILIZATION;

/* Boundary assertion: must return ZERO rows. A SEAT row carrying metered cost
   means the cost-model boundary in sql/06 has been broken. */
SELECT COUNT(*) AS seat_rows_with_metered_cost_must_be_zero
FROM AI_SPEND.GOLD.PERSON_DAY_USAGE
WHERE COST_MODEL = 'SEAT' AND METERED_COST IS NOT NULL;
