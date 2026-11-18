/*==============================================================================
01_member_value_views.sql - Subscription Media LTV demo
Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-16

The governed business definitions live here, once, so every consumer (the
semantic view, the agent, a dashboard) gets the same arithmetic.

  Gross revenue     = list price of every charge in the window
  Discounts         = list price minus amount actually charged
  Platform fees     = amount charged x payment platform fee rate
  Net revenue       = amount charged minus platform fees
  Delivery cost     = 0.40 USD per active member month
  Contribution      = net revenue minus delivery cost
  Off-platform ads  = ad value from members listening on outside apps
  Total value       = contribution plus off-platform ad value
  Windows           = first 12 or 24 months after signup, cash basis
  Mature cohort     = members who signed up at least N months before the
                      2026-10-31 as-of date; N-month LTV uses only these
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV;

CREATE OR REPLACE VIEW MEMBER_VALUE
  COMMENT = 'DEMO: Governed member value per member, 12 and 24 month windows, cash basis (Expires: 2027-01-16)'
AS
WITH pay AS (
    SELECT
        p.member_id,
        SUM(IFF(p.months_since_signup < 12, p.list_price_usd, 0))                         AS gross_12m,
        SUM(IFF(p.months_since_signup < 12, p.list_price_usd - p.amount_charged_usd, 0))  AS discounts_12m,
        SUM(IFF(p.months_since_signup < 12, p.amount_charged_usd, 0))                     AS charged_12m,
        SUM(IFF(p.months_since_signup < 24, p.list_price_usd, 0))                         AS gross_24m,
        SUM(IFF(p.months_since_signup < 24, p.list_price_usd - p.amount_charged_usd, 0))  AS discounts_24m,
        SUM(IFF(p.months_since_signup < 24, p.amount_charged_usd, 0))                     AS charged_24m,
        SUM(p.amount_charged_usd)                                                         AS charged_lifetime
    FROM SUBSCRIPTION_PAYMENTS p
    GROUP BY p.member_id
),
base AS (
    SELECT
        m.member_id,
        m.signup_date,
        DATE_TRUNC('month', m.signup_date)                                   AS signup_month,
        m.acquisition_source,
        s.is_paid_channel,
        m.payment_platform,
        m.plan_type,
        m.first_year_discount_pct,
        m.age_band,
        m.state,
        m.signup_season,
        m.listens_off_platform,
        m.cancel_date,
        m.cancel_date IS NULL                                                AS is_active,
        s.cac_usd,
        f.fee_rate,
        m.monthly_off_platform_ad_value_usd,
        DATEDIFF('month', m.signup_date,
                 COALESCE(DATEADD('day', 1, m.cancel_date), '2026-11-01'::DATE)) AS active_months,
        m.signup_date <= '2025-10-31'::DATE                                  AS is_mature_12m,
        m.signup_date <= '2024-10-31'::DATE                                  AS is_mature_24m,
        COALESCE(p.gross_12m, 0)        AS gross_12m,
        COALESCE(p.discounts_12m, 0)    AS discounts_12m,
        COALESCE(p.charged_12m, 0)      AS charged_12m,
        COALESCE(p.gross_24m, 0)        AS gross_24m,
        COALESCE(p.discounts_24m, 0)    AS discounts_24m,
        COALESCE(p.charged_24m, 0)      AS charged_24m,
        COALESCE(p.charged_lifetime, 0) AS charged_lifetime
    FROM MEMBERS m
    JOIN ACQUISITION_SOURCES s ON s.acquisition_source = m.acquisition_source
    JOIN PAYMENT_PLATFORMS f   ON f.payment_platform = m.payment_platform
    LEFT JOIN pay p            ON p.member_id = m.member_id
)
SELECT
    member_id,
    signup_date,
    signup_month,
    acquisition_source,
    is_paid_channel,
    payment_platform,
    plan_type,
    first_year_discount_pct,
    age_band,
    state,
    signup_season,
    listens_off_platform,
    cancel_date,
    is_active,
    cac_usd,
    active_months,
    is_mature_12m,
    is_mature_24m,
    gross_12m                                                        AS gross_revenue_12m_usd,
    discounts_12m                                                    AS discounts_12m_usd,
    ROUND(charged_12m * fee_rate, 2)                                 AS platform_fees_12m_usd,
    ROUND(charged_12m * (1 - fee_rate), 2)                           AS net_revenue_12m_usd,
    ROUND(0.40 * LEAST(active_months, 12), 2)                        AS delivery_cost_12m_usd,
    ROUND(charged_12m * (1 - fee_rate) - 0.40 * LEAST(active_months, 12), 2) AS contribution_12m_usd,
    gross_24m                                                        AS gross_revenue_24m_usd,
    discounts_24m                                                    AS discounts_24m_usd,
    ROUND(charged_24m * fee_rate, 2)                                 AS platform_fees_24m_usd,
    ROUND(charged_24m * (1 - fee_rate), 2)                           AS net_revenue_24m_usd,
    ROUND(0.40 * LEAST(active_months, 24), 2)                        AS delivery_cost_24m_usd,
    ROUND(charged_24m * (1 - fee_rate) - 0.40 * LEAST(active_months, 24), 2) AS contribution_24m_usd,
    ROUND(monthly_off_platform_ad_value_usd * LEAST(active_months, 24), 2)    AS off_platform_ad_value_24m_usd,
    ROUND(charged_24m * (1 - fee_rate) - 0.40 * LEAST(active_months, 24)
          + monthly_off_platform_ad_value_usd * LEAST(active_months, 24), 2)  AS total_value_24m_usd,
    ROUND(IFF(plan_type = 'Annual', 120.00, 14.00 * 12) * (1 - fee_rate) / 12, 2) AS monthly_net_revenue_usd
FROM base;

-- Which first-year discount makes the most money per 1,000 offer page visitors.
CREATE OR REPLACE VIEW DISCOUNT_ECONOMICS
  COMMENT = 'DEMO: Annual-plan discount tiers, first renewal survival and value per 1,000 visitors (Expires: 2027-01-16)'
AS
WITH renewal AS (
    SELECT
        first_year_discount_pct,
        COUNT(member_id)                                                    AS members_reached_renewal,
        COUNT_IF(cancel_date IS NULL OR cancel_date >= DATEADD('month', 12, signup_date)) AS members_renewed
    FROM MEMBER_VALUE
    WHERE plan_type = 'Annual'
      AND signup_date <= '2025-09-30'::DATE
    GROUP BY first_year_discount_pct
),
value AS (
    SELECT
        first_year_discount_pct,
        AVG(contribution_24m_usd) AS avg_contribution_24m_usd,
        AVG(cac_usd)              AS avg_cac_usd
    FROM MEMBER_VALUE
    WHERE plan_type = 'Annual'
      AND is_mature_24m
    GROUP BY first_year_discount_pct
)
SELECT
    o.discount_pct                                                            AS first_year_discount_pct,
    o.signups_per_1000_visitors,
    r.members_reached_renewal,
    ROUND(r.members_renewed / NULLIF(r.members_reached_renewal, 0), 4)        AS first_renewal_rate,
    ROUND(v.avg_contribution_24m_usd, 2)                                      AS avg_contribution_24m_usd,
    ROUND(v.avg_cac_usd, 2)                                                   AS avg_cac_usd,
    ROUND(o.signups_per_1000_visitors * (v.avg_contribution_24m_usd - v.avg_cac_usd), 2) AS value_per_1000_visitors_usd
FROM OFFER_FUNNEL o
JOIN renewal r ON r.first_year_discount_pct = o.discount_pct
JOIN value v   ON v.first_year_discount_pct = o.discount_pct;

-- Targeted-segment upside if half of logged-in impressions sell at targeted CPM.
CREATE OR REPLACE VIEW AD_SEGMENT_ECONOMICS
  COMMENT = 'DEMO: Logged-in audience segments, ad revenue today and targeted upside (Expires: 2027-01-16)'
AS
SELECT
    audience_segment,
    annual_logged_in_impressions,
    run_of_network_cpm,
    targeted_cpm,
    ROUND(annual_logged_in_impressions * run_of_network_cpm / 1000, 2)                            AS ad_revenue_today_usd,
    ROUND(annual_logged_in_impressions * 0.5 * (targeted_cpm - run_of_network_cpm) / 1000, 2)     AS targeted_upside_usd
FROM AD_SEGMENTS;
