/*==============================================================================
02_semantic_views.sql - Subscription Media LTV demo
Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-16

Two semantic views over the same synthetic data:

  SV_SUBSCRIPTION_MEDIA_LTV_MEMBER_VALUE  governed: business definitions,
      mature-cohort rules, synonyms, SQL generation guidance, verified queries.
  SV_SUBSCRIPTION_MEDIA_LTV_RAW           bare: the raw tables and their column
      names, nothing else. This is what "point an AI at the warehouse" gets.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS;

CREATE OR REPLACE SEMANTIC VIEW SV_SUBSCRIPTION_MEDIA_LTV_MEMBER_VALUE

  TABLES (
    members AS SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.MEMBER_VALUE
      PRIMARY KEY (member_id)
      WITH SYNONYMS ('subscribers', 'paying members', 'customers')
      COMMENT = 'One row per paying member with governed 12 and 24 month value, cash basis',
    sources AS SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.ACQUISITION_SOURCES
      PRIMARY KEY (acquisition_source)
      WITH SYNONYMS ('channels', 'marketing channels')
      COMMENT = 'Acquisition source with CAC and the ROAS each ad platform reports about itself',
    churn AS SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.CHURN_SCORES
      PRIMARY KEY (member_id)
      WITH SYNONYMS ('churn risk', 'cancellation risk')
      COMMENT = 'Snowflake ML 90-day churn probability for members active on 2026-10-31',
    churn_drivers AS SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.CHURN_FEATURE_IMPORTANCE
      PRIMARY KEY (feature_name)
      WITH SYNONYMS ('what drives churn', 'churn factors')
      COMMENT = 'Feature importance from the churn model, one row per feature',
    discounts AS SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.DISCOUNT_ECONOMICS
      PRIMARY KEY (first_year_discount_pct)
      WITH SYNONYMS ('promo tiers', 'offers')
      COMMENT = 'Annual-plan first-year discount tiers: conversion, first renewal, value per 1,000 visitors',
    ad_segments AS SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.AD_SEGMENT_ECONOMICS
      PRIMARY KEY (audience_segment)
      WITH SYNONYMS ('audience segments', 'first-party audiences')
      COMMENT = 'Logged-in audience segments, ad revenue today and targeted CPM upside',
    free_audience AS SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.FREE_AUDIENCE
      PRIMARY KEY (listener_tier)
      WITH SYNONYMS ('free listeners', 'non-paying audience')
      COMMENT = 'Free audience on outside podcast and video apps and their ad value'
  )

  RELATIONSHIPS (
    members_to_sources AS members (acquisition_source) REFERENCES sources,
    churn_to_members AS churn (member_id) REFERENCES members
  )

  FACTS (
    members.cac AS cac_usd
      COMMENT = 'Acquisition cost of this member',
    members.active_flag AS IFF(is_active, 1, 0),
    members.mature_gross_24m AS IFF(is_mature_24m, gross_revenue_24m_usd, NULL),
    members.mature_discounts_24m AS IFF(is_mature_24m, discounts_24m_usd, NULL),
    members.mature_fees_24m AS IFF(is_mature_24m, platform_fees_24m_usd, NULL),
    members.mature_net_24m AS IFF(is_mature_24m, net_revenue_24m_usd, NULL),
    members.mature_delivery_24m AS IFF(is_mature_24m, delivery_cost_24m_usd, NULL),
    members.mature_contribution_24m AS IFF(is_mature_24m, contribution_24m_usd, NULL),
    members.mature_ad_value_24m AS IFF(is_mature_24m, off_platform_ad_value_24m_usd, NULL),
    members.mature_total_value_24m AS IFF(is_mature_24m, total_value_24m_usd, NULL),
    members.mature_cac_24m AS IFF(is_mature_24m, cac_usd, NULL),
    members.mature_paid_contribution_24m AS IFF(is_mature_24m AND is_paid_channel, contribution_24m_usd, NULL),
    members.mature_paid_cac_24m AS IFF(is_mature_24m AND is_paid_channel, cac_usd, NULL),
    members.mature_net_12m AS IFF(is_mature_12m, net_revenue_12m_usd, NULL),
    members.mature_contribution_12m AS IFF(is_mature_12m, contribution_12m_usd, NULL),
    members.active_monthly_net AS IFF(is_active, monthly_net_revenue_usd, NULL),
    sources.reported_roas AS reported_roas_30d,
    churn.probability AS churn_probability_90d,
    churn.revenue_at_risk AS net_revenue_at_risk_usd,
    churn.high_flag AS IFF(risk_band = 'High', 1, 0),
    churn.medium_flag AS IFF(risk_band = 'Medium', 1, 0),
    churn_drivers.score AS importance_score,
    discounts.signups AS signups_per_1000_visitors,
    discounts.renewal_rate AS first_renewal_rate,
    discounts.contribution AS avg_contribution_24m_usd,
    discounts.value_per_1000 AS value_per_1000_visitors_usd,
    ad_segments.revenue_today AS ad_revenue_today_usd,
    ad_segments.upside AS targeted_upside_usd,
    ad_segments.ron_cpm AS run_of_network_cpm,
    ad_segments.tgt_cpm AS targeted_cpm,
    free_audience.listener_count AS listeners,
    free_audience.ad_value_per_listener AS monthly_ad_value_usd
  )

  DIMENSIONS (
    members.acquisition_source AS acquisition_source
      WITH SYNONYMS ('channel', 'source', 'marketing channel')
      COMMENT = 'Where the member came from',
    members.payment_platform AS payment_platform
      WITH SYNONYMS ('billing platform', 'app store', 'platform')
      COMMENT = 'Web (card), Apple, Google Play, or Amazon',
    members.plan_type AS plan_type
      WITH SYNONYMS ('plan', 'billing plan')
      COMMENT = 'Monthly or Annual',
    members.first_year_discount_pct AS first_year_discount_pct
      WITH SYNONYMS ('discount', 'promo')
      COMMENT = 'Percent off the first annual payment; renewals bill at full price',
    members.age_band AS age_band,
    members.state AS state,
    members.signup_season AS signup_season
      COMMENT = 'Black Friday or Rest of year',
    members.signup_month AS signup_month
      COMMENT = 'Month the member signed up',
    members.is_active AS is_active
      COMMENT = 'TRUE if the member had not cancelled as of 2026-10-31',
    members.listens_off_platform AS listens_off_platform
      COMMENT = 'TRUE if the member also listens on outside apps and hears ads there',
    sources.source_name AS acquisition_source,
    sources.is_paid_channel AS is_paid_channel
      COMMENT = 'TRUE for paid channels; Organic and Referral are unpaid',
    churn.risk_band AS risk_band
      COMMENT = 'High (30 percent or more), Medium (10 to 30 percent), Low',
    churn_drivers.feature_name AS feature_name,
    churn_drivers.importance_rank AS importance_rank,
    discounts.discount_tier AS first_year_discount_pct,
    ad_segments.audience_segment AS audience_segment,
    free_audience.listener_tier AS listener_tier
  )

  METRICS (
    members.member_count AS COUNT(members.member_id)
      COMMENT = 'Members ever acquired',
    members.active_members AS SUM(members.active_flag)
      WITH SYNONYMS ('active subscribers', 'current members')
      COMMENT = 'Members not cancelled as of 2026-10-31',
    members.avg_gross_ltv_24m AS AVG(members.mature_gross_24m)
      WITH SYNONYMS ('gross LTV')
      COMMENT = '24-month list-price revenue per member, mature cohort only',
    members.avg_discounts_24m AS AVG(members.mature_discounts_24m),
    members.avg_platform_fees_24m AS AVG(members.mature_fees_24m),
    members.avg_net_ltv_24m AS AVG(members.mature_net_24m)
      WITH SYNONYMS ('LTV', 'net LTV', 'lifetime value', 'member lifetime value')
      COMMENT = '24-month amount charged minus platform fees per member, mature cohort only. Default LTV.',
    members.avg_delivery_cost_24m AS AVG(members.mature_delivery_24m),
    members.avg_contribution_ltv_24m AS AVG(members.mature_contribution_24m)
      WITH SYNONYMS ('contribution LTV', 'contribution')
      COMMENT = '24-month net revenue minus delivery cost per member, mature cohort only',
    members.avg_off_platform_ad_value_24m AS AVG(members.mature_ad_value_24m)
      COMMENT = '24-month ad value from members listening on outside apps, mature cohort only',
    members.avg_total_member_value_24m AS AVG(members.mature_total_value_24m)
      WITH SYNONYMS ('total member value', 'subscription plus ads value')
      COMMENT = '24-month contribution plus off-platform ad value per member, mature cohort only',
    members.avg_net_ltv_12m AS AVG(members.mature_net_12m)
      COMMENT = '12-month net LTV, members with at least 12 months of tenure possible',
    members.avg_contribution_ltv_12m AS AVG(members.mature_contribution_12m),
    members.avg_cac AS AVG(members.cac)
      WITH SYNONYMS ('CAC', 'acquisition cost', 'cost per acquisition')
      COMMENT = 'Average acquisition cost per member',
    members.ltv_to_cac_24m AS SUM(members.mature_contribution_24m) / NULLIF(SUM(members.mature_cac_24m), 0)
      WITH SYNONYMS ('LTV to CAC', 'LTV:CAC')
      COMMENT = '24-month contribution divided by CAC, same mature cohort for both',
    members.cac_payback_months AS SUM(members.mature_cac_24m) / NULLIF(SUM(members.mature_contribution_24m) / 24, 0)
      WITH SYNONYMS ('payback', 'payback period', 'CAC payback')
      COMMENT = 'Months of average contribution needed to earn back CAC, mature cohort',
    members.true_roas_24m AS SUM(members.mature_paid_contribution_24m) / NULLIF(SUM(members.mature_paid_cac_24m), 0)
      WITH SYNONYMS ('true ROAS', 'real return on ad spend', 'actual ROAS')
      COMMENT = 'Paid channels only: 24-month contribution returned per dollar of acquisition spend',
    members.avg_monthly_net_revenue_active AS AVG(members.active_monthly_net)
      COMMENT = 'Monthly net subscription revenue per active member',
    sources.avg_reported_roas_30d AS AVG(sources.reported_roas)
      WITH SYNONYMS ('reported ROAS', 'platform ROAS')
      COMMENT = 'The 30-day ROAS each ad platform reports about itself',
    churn.scored_members AS COUNT(churn.member_id),
    churn.high_risk_members AS SUM(churn.high_flag)
      WITH SYNONYMS ('high churn risk', 'at-risk members'),
    churn.medium_risk_members AS SUM(churn.medium_flag),
    churn.avg_churn_probability AS AVG(churn.probability),
    churn.net_revenue_at_risk AS SUM(churn.revenue_at_risk)
      WITH SYNONYMS ('revenue at risk')
      COMMENT = 'Expected net subscription revenue lost in the next 90 days: probability x next-90-day net revenue',
    churn_drivers.driver_importance AS AVG(churn_drivers.score)
      COMMENT = 'Share of model importance; one row per feature',
    discounts.tier_signups_per_1000_visitors AS AVG(discounts.signups),
    discounts.tier_first_renewal_rate AS AVG(discounts.renewal_rate)
      COMMENT = 'Share of annual members who renew at full price after year one',
    discounts.contribution_24m_per_member AS AVG(discounts.contribution),
    discounts.tier_value_per_1000_visitors AS AVG(discounts.value_per_1000)
      COMMENT = 'Signups per 1,000 visitors x (24-month contribution minus CAC)',
    ad_segments.ad_revenue_today AS SUM(ad_segments.revenue_today),
    ad_segments.targeted_upside AS SUM(ad_segments.upside)
      COMMENT = 'Annual upside if half of logged-in impressions sell at targeted CPM',
    ad_segments.avg_run_of_network_cpm AS AVG(ad_segments.ron_cpm),
    ad_segments.avg_targeted_cpm AS AVG(ad_segments.tgt_cpm),
    free_audience.total_listeners AS SUM(free_audience.listener_count),
    free_audience.monthly_ad_value_per_listener AS AVG(free_audience.ad_value_per_listener)
  )

  COMMENT = 'DEMO: Governed member value, churn, and ad economics for a fictional subscription publisher (Expires: 2027-01-16)'

  AI_SQL_GENERATION 'All data is synthetic and pinned to an as-of date of 2026-10-31. LTV means 24-month net LTV (avg_net_ltv_24m) unless the user asks for gross, contribution, 12-month, or total value; always state which basis you used. Use mature-cohort metrics for any LTV, LTV to CAC, payback, or true ROAS question; never average raw revenue over all members, because young members have not had time to pay. Compare true ROAS with reported ROAS only for paid channels. Revenue at risk comes from the churn table. A headline total must equal the sum of the breakdown it is shown with.'

  AI_VERIFIED_QUERIES (
    ltv_by_source AS (
      QUESTION 'What is our 24-month net LTV and LTV to CAC by acquisition source?'
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = SE Community)'
      SQL 'SELECT acquisition_source, COUNT(mature_cac_24m) AS mature_members, ROUND(AVG(mature_net_24m), 2) AS avg_net_ltv_24m, ROUND(AVG(mature_contribution_24m), 2) AS avg_contribution_ltv_24m, ROUND(AVG(mature_cac_24m), 2) AS avg_cac, ROUND(SUM(mature_contribution_24m) / NULLIF(SUM(mature_cac_24m), 0), 2) AS ltv_to_cac_24m FROM members GROUP BY acquisition_source ORDER BY ltv_to_cac_24m DESC'
    ),
    payback_by_platform AS (
      QUESTION 'Which payment platform pays back CAC fastest?'
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = SE Community)'
      SQL 'SELECT payment_platform, ROUND(AVG(mature_net_24m), 2) AS avg_net_ltv_24m, ROUND(AVG(mature_fees_24m), 2) AS avg_platform_fees_24m, ROUND(AVG(mature_cac_24m), 2) AS avg_cac, ROUND(SUM(mature_cac_24m) / NULLIF(SUM(mature_contribution_24m) / 24, 0), 1) AS cac_payback_months FROM members GROUP BY payment_platform ORDER BY cac_payback_months'
    ),
    reported_vs_true_roas AS (
      QUESTION 'Compare reported ROAS to true ROAS for our paid channels'
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = SE Community)'
      SQL 'SELECT s.acquisition_source, AVG(s.reported_roas) AS reported_roas_30d, ROUND(SUM(m.mature_paid_contribution_24m) / NULLIF(SUM(m.mature_paid_cac_24m), 0), 2) AS true_roas_24m FROM members AS m JOIN sources AS s ON s.acquisition_source = m.acquisition_source WHERE s.is_paid_channel GROUP BY s.acquisition_source ORDER BY true_roas_24m DESC'
    ),
    churn_risk_summary AS (
      QUESTION 'How many members are at high churn risk and how much net revenue is at risk?'
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = SE Community)'
      SQL 'SELECT risk_band, COUNT(member_id) AS members, ROUND(AVG(probability), 4) AS avg_churn_probability, ROUND(SUM(revenue_at_risk), 2) AS net_revenue_at_risk FROM churn GROUP BY risk_band ORDER BY avg_churn_probability DESC'
    ),
    churn_drivers_ranked AS (
      QUESTION 'What drives churn?'
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = SE Community)'
      SQL 'SELECT importance_rank, feature_name, AVG(score) AS importance_score FROM churn_drivers GROUP BY importance_rank, feature_name ORDER BY importance_rank'
    ),
    discount_payoff AS (
      QUESTION 'Do deeper first-year discounts pay off?'
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = SE Community)'
      SQL 'SELECT first_year_discount_pct, AVG(signups) AS signups_per_1000_visitors, AVG(renewal_rate) AS first_renewal_rate, AVG(contribution) AS avg_contribution_24m_usd, AVG(value_per_1000) AS value_per_1000_visitors_usd FROM discounts GROUP BY first_year_discount_pct ORDER BY first_year_discount_pct'
    ),
    total_value_by_source AS (
      QUESTION 'What is total member value including off-platform ad revenue by acquisition source?'
      VERIFIED_BY '(STEWARD = SE Community)'
      SQL 'SELECT acquisition_source, ROUND(AVG(mature_contribution_24m), 2) AS avg_contribution_ltv_24m, ROUND(AVG(mature_ad_value_24m), 2) AS avg_off_platform_ad_value_24m, ROUND(AVG(mature_total_value_24m), 2) AS avg_total_member_value_24m FROM members GROUP BY acquisition_source ORDER BY avg_total_member_value_24m DESC'
    ),
    segment_upside AS (
      QUESTION 'Which audience segments have the biggest targeted ad upside?'
      VERIFIED_BY '(STEWARD = SE Community)'
      SQL 'SELECT audience_segment, AVG(ron_cpm) AS run_of_network_cpm, AVG(tgt_cpm) AS targeted_cpm, SUM(revenue_today) AS ad_revenue_today_usd, SUM(upside) AS targeted_upside_usd FROM ad_segments GROUP BY audience_segment ORDER BY targeted_upside_usd DESC'
    )
  );

CREATE OR REPLACE SEMANTIC VIEW SV_SUBSCRIPTION_MEDIA_LTV_RAW

  TABLES (
    members AS SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.MEMBERS
      PRIMARY KEY (member_id),
    payments AS SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.SUBSCRIPTION_PAYMENTS
      PRIMARY KEY (payment_id),
    spend AS SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV.ACQUISITION_SPEND
      PRIMARY KEY (spend_month, acquisition_source)
  )

  RELATIONSHIPS (
    payments_to_members AS payments (member_id) REFERENCES members
  )

  FACTS (
    payments.amount_charged AS amount_charged_usd,
    payments.list_price AS list_price_usd,
    spend.spend AS spend_usd
  )

  DIMENSIONS (
    members.acquisition_source AS acquisition_source,
    members.payment_platform AS payment_platform,
    members.plan_type AS plan_type,
    members.first_year_discount_pct AS first_year_discount_pct,
    members.age_band AS age_band,
    members.state AS state,
    members.signup_date AS signup_date,
    members.cancel_date AS cancel_date,
    payments.payment_date AS payment_date,
    spend.spend_source AS acquisition_source,
    spend.spend_month AS spend_month
  )

  METRICS (
    members.member_count AS COUNT(members.member_id),
    payments.total_amount_charged AS SUM(payments.amount_charged),
    payments.total_list_price AS SUM(payments.list_price),
    spend.total_spend AS SUM(spend.spend)
  )

  COMMENT = 'DEMO: Raw tables with no business context, contrast only (Expires: 2027-01-16)';
