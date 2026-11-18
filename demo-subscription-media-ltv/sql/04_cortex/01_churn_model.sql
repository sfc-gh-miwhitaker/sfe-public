/*==============================================================================
01_churn_model.sql - Subscription Media LTV demo
Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-16

Snowflake ML classification for 90-day churn.
  Train:  members active on 2026-07-31, label = cancelled in the next 90 days.
  Score:  members active on the 2026-10-31 as-of date.
Features use only data on or before each snapshot date, so the training label
never leaks into the inputs. Training takes a few minutes on an XS warehouse.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV;

CREATE OR REPLACE VIEW CHURN_FEATURES
  COMMENT = 'DEMO: Churn features per member at the training and scoring snapshots (Expires: 2027-01-16)'
AS
WITH snapshots AS (
    SELECT '2026-07-31'::DATE AS snapshot_date, 'TRAIN' AS snapshot_role
    UNION ALL
    SELECT '2026-10-31'::DATE, 'SCORE'
),
active AS (
    SELECT
        s.snapshot_date,
        s.snapshot_role,
        m.member_id,
        m.acquisition_source,
        m.payment_platform,
        m.plan_type,
        m.first_year_discount_pct,
        m.age_band,
        m.state,
        m.signup_season,
        m.cancel_date,
        DATEDIFF('month', m.signup_date, s.snapshot_date) AS tenure_months
    FROM MEMBERS m
    JOIN snapshots s
      ON m.signup_date <= s.snapshot_date
     AND (m.cancel_date IS NULL OR m.cancel_date > s.snapshot_date)
),
viewing AS (
    SELECT
        a.snapshot_date,
        a.member_id,
        v.viewing_minutes,
        ROW_NUMBER() OVER (PARTITION BY a.snapshot_date, a.member_id
                           ORDER BY v.months_since_signup DESC) AS months_back
    FROM active a
    JOIN VIEWING_MONTHLY v
      ON v.member_id = a.member_id
     AND v.activity_month_start <= a.snapshot_date
),
viewing_summary AS (
    SELECT
        snapshot_date,
        member_id,
        MAX(IFF(months_back = 1, viewing_minutes, NULL))                   AS recent_viewing_minutes,
        AVG(IFF(months_back BETWEEN 2 AND 4, viewing_minutes, NULL))       AS prior_viewing_minutes
    FROM viewing
    WHERE months_back <= 4
    GROUP BY snapshot_date, member_id
)
SELECT
    a.snapshot_date,
    a.snapshot_role,
    a.member_id,
    a.acquisition_source,
    a.payment_platform,
    a.plan_type,
    a.first_year_discount_pct::VARCHAR                                     AS first_year_discount,
    a.age_band,
    a.state,
    a.signup_season,
    a.tenure_months,
    IFF(a.plan_type = 'Annual', 12 - MOD(a.tenure_months, 12), 1)          AS months_to_renewal,
    COALESCE(vs.recent_viewing_minutes, 0)                                 AS recent_viewing_minutes,
    ROUND(COALESCE(vs.recent_viewing_minutes / NULLIF(vs.prior_viewing_minutes, 0), 1), 3) AS viewing_trend,
    a.cancel_date IS NOT NULL
        AND a.cancel_date <= DATEADD('day', 90, a.snapshot_date)           AS churned_next_90d
FROM active a
LEFT JOIN viewing_summary vs
  ON vs.snapshot_date = a.snapshot_date
 AND vs.member_id = a.member_id;

CREATE OR REPLACE VIEW CHURN_TRAINING_DATA
  COMMENT = 'DEMO: Labeled churn training rows, 2026-07-31 snapshot (Expires: 2027-01-16)'
AS
SELECT
    acquisition_source,
    payment_platform,
    plan_type,
    first_year_discount,
    age_band,
    signup_season,
    tenure_months,
    months_to_renewal,
    recent_viewing_minutes,
    viewing_trend,
    churned_next_90d
FROM CHURN_FEATURES
WHERE snapshot_role = 'TRAIN';

CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION CHURN_MODEL(
    INPUT_DATA     => SYSTEM$REFERENCE('VIEW', 'CHURN_TRAINING_DATA'),
    TARGET_COLNAME => 'CHURNED_NEXT_90D',
    CONFIG_OBJECT  => {'evaluate': TRUE, 'on_error': 'skip'}
)
COMMENT = 'DEMO: 90-day churn classifier (Expires: 2027-01-16)';

CALL CHURN_MODEL!SHOW_FEATURE_IMPORTANCE();

CREATE OR REPLACE TABLE CHURN_FEATURE_IMPORTANCE
  COMMENT = 'DEMO: Churn model feature importance (Expires: 2027-01-16)'
AS
SELECT
    "RANK"::NUMBER         AS importance_rank,
    "FEATURE"::VARCHAR     AS feature_name,
    ROUND("SCORE"::FLOAT, 4) AS importance_score
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

CALL CHURN_MODEL!SHOW_GLOBAL_EVALUATION_METRICS();

CREATE OR REPLACE TABLE CHURN_MODEL_METRICS
  COMMENT = 'DEMO: Churn model held-out evaluation metrics (Expires: 2027-01-16)'
AS
SELECT
    "ERROR_METRIC"::VARCHAR            AS metric_name,
    "AVERAGE_TYPE"::VARCHAR            AS average_type,
    ROUND("METRIC_VALUE"::FLOAT, 4)    AS metric_value
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

CREATE OR REPLACE TABLE CHURN_SCORES (
    MEMBER_ID                    NUMBER(10,0) NOT NULL,
    SCORED_AS_OF                 DATE NOT NULL,
    CHURN_PROBABILITY_90D        NUMBER(6,4) NOT NULL,
    RISK_BAND                    VARCHAR NOT NULL,
    MONTHS_TO_RENEWAL            NUMBER(4,0) NOT NULL,
    RECENT_VIEWING_MINUTES       NUMBER(8,0) NOT NULL,
    VIEWING_TREND                NUMBER(8,3) NOT NULL,
    NET_REVENUE_NEXT_90D_USD     NUMBER(10,2) NOT NULL,
    NET_REVENUE_AT_RISK_USD      NUMBER(10,2) NOT NULL,
    PRIMARY KEY (MEMBER_ID)
) COMMENT = 'DEMO: 90-day churn scores for active members as of 2026-10-31 (Expires: 2027-01-16)';

INSERT INTO CHURN_SCORES
WITH scored AS (
    SELECT
        f.member_id,
        f.snapshot_date,
        f.plan_type,
        f.months_to_renewal,
        f.recent_viewing_minutes,
        f.viewing_trend,
        p.fee_rate,
        CHURN_MODEL!PREDICT(INPUT_DATA => {
            'ACQUISITION_SOURCE':     f.acquisition_source,
            'PAYMENT_PLATFORM':       f.payment_platform,
            'PLAN_TYPE':              f.plan_type,
            'FIRST_YEAR_DISCOUNT':    f.first_year_discount,
            'AGE_BAND':               f.age_band,
            'SIGNUP_SEASON':          f.signup_season,
            'TENURE_MONTHS':          f.tenure_months,
            'MONTHS_TO_RENEWAL':      f.months_to_renewal,
            'RECENT_VIEWING_MINUTES': f.recent_viewing_minutes,
            'VIEWING_TREND':          f.viewing_trend
        }) AS prediction
    FROM CHURN_FEATURES f
    JOIN PAYMENT_PLATFORMS p
      ON p.payment_platform = f.payment_platform
    WHERE f.snapshot_role = 'SCORE'
),
valued AS (
    SELECT
        member_id,
        snapshot_date,
        months_to_renewal,
        recent_viewing_minutes,
        viewing_trend,
        ROUND(prediction:probability:"True"::FLOAT, 4) AS churn_probability_90d,
        ROUND(CASE
                  WHEN plan_type = 'Monthly' THEN 3 * 14.00 * (1 - fee_rate)
                  WHEN months_to_renewal <= 3 THEN 120.00 * (1 - fee_rate)
                  ELSE 0
              END, 2) AS net_revenue_next_90d_usd
    FROM scored
)
SELECT
    member_id,
    snapshot_date,
    churn_probability_90d,
    CASE WHEN churn_probability_90d >= 0.30 THEN 'High'
         WHEN churn_probability_90d >= 0.10 THEN 'Medium'
         ELSE 'Low' END,
    months_to_renewal,
    recent_viewing_minutes,
    viewing_trend,
    net_revenue_next_90d_usd,
    ROUND(churn_probability_90d * net_revenue_next_90d_usd, 2)
FROM valued;
