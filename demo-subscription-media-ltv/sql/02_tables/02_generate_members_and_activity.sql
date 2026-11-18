/*==============================================================================
02_generate_members_and_activity.sql - Subscription Media LTV demo
Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-16

Deterministic synthetic data. Every random draw is HASH(member_id, salt), and
the data is pinned to an as-of date of 2026-10-31, so a redeploy reproduces the
same rows and the same answers.

Shape:
  30,000 members who signed up 2023-11-01 .. 2026-10-31.
  Monthly members can cancel any month. Annual members can only leave at a
  renewal (month 12, 24, 36), and a deeper first-year discount means fewer
  survive the first full-price renewal.
  Viewing minutes fall off in the three months before a member cancels, which
  is the signal the churn model learns.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV;

-- 1. Member attributes ---------------------------------------------------------
CREATE OR REPLACE TEMPORARY TABLE TMP_MEMBER_DRAWS AS
WITH ids AS (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS member_id
    FROM TABLE(GENERATOR(ROWCOUNT => 30000))
)
SELECT
    member_id,
    (ABS(HASH(member_id, 'bf'))    % 1000000) / 1000000.0 AS u_bf,
    (ABS(HASH(member_id, 'year'))  % 1000000) / 1000000.0 AS u_year,
    (ABS(HASH(member_id, 'day'))   % 1000000) / 1000000.0 AS u_day,
    (ABS(HASH(member_id, 'src'))   % 1000000) / 1000000.0 AS u_src,
    (ABS(HASH(member_id, 'plat'))  % 1000000) / 1000000.0 AS u_plat,
    (ABS(HASH(member_id, 'plan'))  % 1000000) / 1000000.0 AS u_plan,
    (ABS(HASH(member_id, 'disc'))  % 1000000) / 1000000.0 AS u_disc,
    (ABS(HASH(member_id, 'age'))   % 1000000) / 1000000.0 AS u_age,
    (ABS(HASH(member_id, 'state')) % 1000000) / 1000000.0 AS u_state,
    (ABS(HASH(member_id, 'eng'))   % 1000000) / 1000000.0 AS u_eng,
    (ABS(HASH(member_id, 'off'))   % 1000000) / 1000000.0 AS u_off,
    (ABS(HASH(member_id, 'adv'))   % 1000000) / 1000000.0 AS u_adv
FROM ids;

CREATE OR REPLACE TABLE MEMBERS (
    MEMBER_ID                         NUMBER(10,0) NOT NULL,
    SIGNUP_DATE                       DATE NOT NULL,
    ACQUISITION_SOURCE                VARCHAR NOT NULL,
    PAYMENT_PLATFORM                  VARCHAR NOT NULL,
    PLAN_TYPE                         VARCHAR NOT NULL,
    FIRST_YEAR_DISCOUNT_PCT           NUMBER(4,0) NOT NULL,
    AGE_BAND                          VARCHAR NOT NULL,
    STATE                             VARCHAR NOT NULL,
    SIGNUP_SEASON                     VARCHAR NOT NULL,
    LISTENS_OFF_PLATFORM              BOOLEAN NOT NULL,
    MONTHLY_OFF_PLATFORM_AD_VALUE_USD NUMBER(8,2) NOT NULL,
    CANCEL_DATE                       DATE,
    PRIMARY KEY (MEMBER_ID)
) COMMENT = 'DEMO: Synthetic subscription members, one row per member (Expires: 2027-01-16)';

INSERT INTO MEMBERS
WITH attrs AS (
    SELECT
        d.member_id,
        d.u_bf < 0.08 AS is_black_friday,
        CASE
            WHEN d.u_bf < 0.08 THEN
                DATEADD('day', FLOOR(d.u_day * 8)::INT,
                    CASE WHEN d.u_year < 0.33 THEN '2023-11-24'::DATE
                         WHEN d.u_year < 0.66 THEN '2024-11-24'::DATE
                         ELSE '2025-11-24'::DATE END)
            ELSE DATEADD('day', FLOOR(d.u_day * 1096)::INT, '2023-11-01'::DATE)
        END AS signup_date,
        CASE WHEN d.u_src < 0.25 THEN 'Organic'
             WHEN d.u_src < 0.45 THEN 'Podcast host reads'
             WHEN d.u_src < 0.60 THEN 'YouTube'
             WHEN d.u_src < 0.75 THEN 'Search'
             WHEN d.u_src < 0.90 THEN 'Paid social'
             ELSE 'Referral' END AS acquisition_source,
        CASE WHEN d.u_plat < 0.55 THEN 'Web (card)'
             WHEN d.u_plat < 0.73 THEN 'Apple'
             WHEN d.u_plat < 0.87 THEN 'Google Play'
             ELSE 'Amazon' END AS payment_platform,
        IFF(d.u_plan < 0.60, 'Annual', 'Monthly') AS plan_type,
        CASE
            WHEN d.u_plan >= 0.60 THEN 0
            WHEN d.u_bf < 0.08 THEN
                CASE WHEN d.u_disc < 0.60 THEN 50 WHEN d.u_disc < 0.85 THEN 40 ELSE 30 END
            ELSE
                CASE WHEN d.u_disc < 0.40 THEN 0  WHEN d.u_disc < 0.60 THEN 20
                     WHEN d.u_disc < 0.80 THEN 30 WHEN d.u_disc < 0.92 THEN 40 ELSE 50 END
        END AS first_year_discount_pct,
        CASE WHEN d.u_age < 0.08 THEN '18-24' WHEN d.u_age < 0.28 THEN '25-34'
             WHEN d.u_age < 0.52 THEN '35-44' WHEN d.u_age < 0.72 THEN '45-54'
             WHEN d.u_age < 0.88 THEN '55-64' ELSE '65+' END AS age_band,
        CASE WHEN d.u_state < 0.14 THEN 'TX' WHEN d.u_state < 0.26 THEN 'FL'
             WHEN d.u_state < 0.34 THEN 'TN' WHEN d.u_state < 0.42 THEN 'OH'
             WHEN d.u_state < 0.50 THEN 'GA' WHEN d.u_state < 0.58 THEN 'NC'
             WHEN d.u_state < 0.66 THEN 'AZ' WHEN d.u_state < 0.74 THEN 'PA'
             WHEN d.u_state < 0.84 THEN 'CA' ELSE 'Other' END AS state,
        d.u_eng,
        d.u_off,
        d.u_adv
    FROM TMP_MEMBER_DRAWS d
)
SELECT
    a.member_id,
    a.signup_date,
    a.acquisition_source,
    a.payment_platform,
    a.plan_type,
    a.first_year_discount_pct,
    a.age_band,
    a.state,
    IFF(a.is_black_friday, 'Black Friday', 'Rest of year'),
    a.u_off < s.off_platform_share,
    IFF(a.u_off < s.off_platform_share, ROUND(0.40 + 1.60 * a.u_adv, 2), 0),
    NULL
FROM attrs a
JOIN ACQUISITION_SOURCES s
  ON s.acquisition_source = a.acquisition_source;

-- 2. Lifecycle: the first month a member does not renew -----------------------
-- Held in a temporary table so the future (post as-of) cancellations that
-- shape viewing behavior are never exposed as a queryable object.
CREATE OR REPLACE TEMPORARY TABLE TMP_MEMBER_LIFECYCLE AS
WITH months AS (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS month_index
    FROM TABLE(GENERATOR(ROWCOUNT => 36))
),
grid AS (
    SELECT
        m.member_id,
        mo.month_index,
        (ABS(HASH(m.member_id, mo.month_index, 'renew')) % 1000000) / 1000000.0 AS u_renew,
        CASE
            WHEN m.plan_type = 'Monthly' THEN
                LEAST(0.50, 0.055 * s.churn_multiplier * p.churn_multiplier * (1.8 - 1.4 * d.u_eng))
            WHEN mo.month_index = 12 THEN
                LEAST(0.95, (0.24 + 0.0075 * m.first_year_discount_pct)
                            * SQRT(s.churn_multiplier) * SQRT(p.churn_multiplier) * (1.6 - 1.2 * d.u_eng))
            WHEN mo.month_index IN (24, 36) THEN
                LEAST(0.95, 0.22 * SQRT(s.churn_multiplier) * (1.6 - 1.2 * d.u_eng))
            ELSE 0
        END AS hazard
    FROM MEMBERS m
    JOIN TMP_MEMBER_DRAWS d    ON d.member_id = m.member_id
    JOIN ACQUISITION_SOURCES s ON s.acquisition_source = m.acquisition_source
    JOIN PAYMENT_PLATFORMS p   ON p.payment_platform = m.payment_platform
    CROSS JOIN months mo
)
SELECT
    m.member_id,
    MIN(IFF(g.u_renew < g.hazard, g.month_index, NULL)) AS cancel_month_index
FROM MEMBERS m
LEFT JOIN grid g
  ON g.member_id = m.member_id
GROUP BY m.member_id;

-- Only cancellations on or before the as-of date are visible in the data.
UPDATE MEMBERS m
SET CANCEL_DATE = DATEADD('day', -1, DATEADD('month', l.cancel_month_index, m.signup_date))
FROM TMP_MEMBER_LIFECYCLE l
WHERE l.member_id = m.member_id
  AND l.cancel_month_index IS NOT NULL
  AND DATEADD('month', l.cancel_month_index, m.signup_date) <= '2026-10-31'::DATE;

-- 3. Payments --------------------------------------------------------------------
CREATE OR REPLACE TABLE SUBSCRIPTION_PAYMENTS (
    PAYMENT_ID           NUMBER(14,0) NOT NULL,
    MEMBER_ID            NUMBER(10,0) NOT NULL,
    PAYMENT_DATE         DATE NOT NULL,
    MONTHS_SINCE_SIGNUP  NUMBER(4,0) NOT NULL,
    LIST_PRICE_USD       NUMBER(10,2) NOT NULL,
    AMOUNT_CHARGED_USD   NUMBER(10,2) NOT NULL,
    PRIMARY KEY (PAYMENT_ID)
) COMMENT = 'DEMO: Synthetic subscription charges, one row per charge (Expires: 2027-01-16)';

INSERT INTO SUBSCRIPTION_PAYMENTS
WITH k AS (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS month_index
    FROM TABLE(GENERATOR(ROWCOUNT => 37))
)
SELECT
    m.member_id * 100 + k.month_index,
    m.member_id,
    DATEADD('month', k.month_index, m.signup_date),
    k.month_index,
    IFF(m.plan_type = 'Annual', 120.00, 14.00),
    CASE
        WHEN m.plan_type = 'Annual' AND k.month_index = 0
            THEN ROUND(120.00 * (1 - m.first_year_discount_pct / 100), 2)
        WHEN m.plan_type = 'Annual' THEN 120.00
        ELSE 14.00
    END
FROM MEMBERS m
JOIN TMP_MEMBER_LIFECYCLE l ON l.member_id = m.member_id
CROSS JOIN k
WHERE DATEADD('month', k.month_index, m.signup_date) <= '2026-10-31'::DATE
  AND (l.cancel_month_index IS NULL OR k.month_index < l.cancel_month_index)
  AND (m.plan_type = 'Monthly' OR k.month_index IN (0, 12, 24, 36));

-- 4. Viewing minutes per member month --------------------------------------------
CREATE OR REPLACE TABLE VIEWING_MONTHLY (
    MEMBER_ID            NUMBER(10,0) NOT NULL,
    MONTHS_SINCE_SIGNUP  NUMBER(4,0) NOT NULL,
    ACTIVITY_MONTH_START DATE NOT NULL,
    VIEWING_MINUTES      NUMBER(8,0) NOT NULL,
    PRIMARY KEY (MEMBER_ID, MONTHS_SINCE_SIGNUP)
) COMMENT = 'DEMO: Synthetic in-app viewing minutes per member month (Expires: 2027-01-16)';

INSERT INTO VIEWING_MONTHLY
WITH k AS (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS month_index
    FROM TABLE(GENERATOR(ROWCOUNT => 37))
)
SELECT
    m.member_id,
    k.month_index,
    DATEADD('month', k.month_index, m.signup_date),
    ROUND(
        (40 + 560 * POWER(d.u_eng, 1.2))
        * (0.85 + 0.30 * (ABS(HASH(m.member_id, k.month_index, 'view')) % 1000000) / 1000000.0)
        * CASE l.cancel_month_index - k.month_index
              WHEN 1 THEN 0.30
              WHEN 2 THEN 0.55
              WHEN 3 THEN 0.80
              ELSE 1.0
          END
        * IFF((ABS(HASH(m.member_id, 'dip')) % 100) < 8 AND MOD(k.month_index, 7) = 3, 0.60, 1.0)
    )
FROM MEMBERS m
JOIN TMP_MEMBER_DRAWS d     ON d.member_id = m.member_id
JOIN TMP_MEMBER_LIFECYCLE l ON l.member_id = m.member_id
CROSS JOIN k
WHERE DATEADD('month', k.month_index, m.signup_date) <= '2026-10-31'::DATE
  AND (l.cancel_month_index IS NULL OR k.month_index < l.cancel_month_index);

-- 5. Paid acquisition spend by month ----------------------------------------------
CREATE OR REPLACE TABLE ACQUISITION_SPEND (
    SPEND_MONTH         DATE NOT NULL,
    ACQUISITION_SOURCE  VARCHAR NOT NULL,
    SPEND_USD           NUMBER(12,2) NOT NULL,
    PRIMARY KEY (SPEND_MONTH, ACQUISITION_SOURCE)
) COMMENT = 'DEMO: Synthetic paid acquisition spend by month and source (Expires: 2027-01-16)';

INSERT INTO ACQUISITION_SPEND
SELECT
    DATE_TRUNC('month', m.signup_date),
    m.acquisition_source,
    ROUND(COUNT(m.member_id) * s.cac_usd, 2)
FROM MEMBERS m
JOIN ACQUISITION_SOURCES s
  ON s.acquisition_source = m.acquisition_source
WHERE s.is_paid_channel
GROUP BY DATE_TRUNC('month', m.signup_date), m.acquisition_source, s.cac_usd;

DROP TABLE IF EXISTS TMP_MEMBER_LIFECYCLE;
DROP TABLE IF EXISTS TMP_MEMBER_DRAWS;
