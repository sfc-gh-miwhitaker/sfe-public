/*==============================================================================
01_reference_tables.sql - Subscription Media LTV demo
Pair-programmed by SE Community + Cortex Code | Expires: 2027-01-16
Small lookup tables. Every value is a fictional assumption for the demo.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.SUBSCRIPTION_MEDIA_LTV;

-- Acquisition sources: blended CAC per acquired member and the 30-day ROAS
-- each ad platform reports about itself. Unpaid sources have no reported ROAS.
CREATE OR REPLACE TABLE ACQUISITION_SOURCES (
    ACQUISITION_SOURCE  VARCHAR NOT NULL,
    IS_PAID_CHANNEL     BOOLEAN NOT NULL,
    CAC_USD             NUMBER(10,2) NOT NULL,
    REPORTED_ROAS_30D   NUMBER(6,2),
    CHURN_MULTIPLIER    NUMBER(6,3) NOT NULL,
    OFF_PLATFORM_SHARE  NUMBER(6,3) NOT NULL,
    PRIMARY KEY (ACQUISITION_SOURCE)
) COMMENT = 'DEMO: Acquisition source economics, synthetic (Expires: 2027-01-16)';

INSERT INTO ACQUISITION_SOURCES
    (ACQUISITION_SOURCE, IS_PAID_CHANNEL, CAC_USD, REPORTED_ROAS_30D, CHURN_MULTIPLIER, OFF_PLATFORM_SHARE)
VALUES
    ('Organic',            FALSE,  10.00, NULL, 0.800, 0.30),
    ('Referral',           FALSE,  25.00, NULL, 0.700, 0.30),
    ('Podcast host reads', TRUE,   45.00, 1.40, 0.750, 0.55),
    ('YouTube',            TRUE,   70.00, 2.30, 1.000, 0.40),
    ('Search',             TRUE,   85.00, 2.90, 1.200, 0.20),
    ('Paid social',        TRUE,  110.00, 3.40, 1.450, 0.15);

-- Payment platforms: the share of each charge kept by the platform.
CREATE OR REPLACE TABLE PAYMENT_PLATFORMS (
    PAYMENT_PLATFORM  VARCHAR NOT NULL,
    FEE_RATE          NUMBER(6,4) NOT NULL,
    CHURN_MULTIPLIER  NUMBER(6,3) NOT NULL,
    PRIMARY KEY (PAYMENT_PLATFORM)
) COMMENT = 'DEMO: Payment platform fee rates, synthetic (Expires: 2027-01-16)';

INSERT INTO PAYMENT_PLATFORMS (PAYMENT_PLATFORM, FEE_RATE, CHURN_MULTIPLIER)
VALUES
    ('Web (card)',  0.0400, 0.950),
    ('Amazon',      0.1500, 1.000),
    ('Google Play', 0.1500, 1.050),
    ('Apple',       0.1500, 1.150);

-- Offer page funnel: signups per 1,000 visitors at each first-year discount.
CREATE OR REPLACE TABLE OFFER_FUNNEL (
    DISCOUNT_PCT              NUMBER(4,0) NOT NULL,
    SIGNUPS_PER_1000_VISITORS NUMBER(6,1) NOT NULL,
    PRIMARY KEY (DISCOUNT_PCT)
) COMMENT = 'DEMO: Offer page conversion by first-year discount, synthetic (Expires: 2027-01-16)';

INSERT INTO OFFER_FUNNEL (DISCOUNT_PCT, SIGNUPS_PER_1000_VISITORS)
VALUES (0, 18.0), (20, 27.0), (30, 31.0), (40, 35.0), (50, 40.0);

-- Free (non-paying) audience that hears ads on outside podcast and video apps.
CREATE OR REPLACE TABLE FREE_AUDIENCE (
    LISTENER_TIER          VARCHAR NOT NULL,
    LISTENERS              NUMBER(12,0) NOT NULL,
    MONTHLY_AD_VALUE_USD   NUMBER(8,2) NOT NULL,
    PRIMARY KEY (LISTENER_TIER)
) COMMENT = 'DEMO: Free audience size and ad value per listener, synthetic (Expires: 2027-01-16)';

INSERT INTO FREE_AUDIENCE (LISTENER_TIER, LISTENERS, MONTHLY_AD_VALUE_USD)
VALUES
    ('Light listener', 3200000, 0.33),
    ('Heavy listener',  800000, 1.50);

-- Logged-in audience segments that a data clean room could make sellable.
CREATE OR REPLACE TABLE AD_SEGMENTS (
    AUDIENCE_SEGMENT              VARCHAR NOT NULL,
    ANNUAL_LOGGED_IN_IMPRESSIONS  NUMBER(14,0) NOT NULL,
    RUN_OF_NETWORK_CPM            NUMBER(8,2) NOT NULL,
    TARGETED_CPM                  NUMBER(8,2) NOT NULL,
    PRIMARY KEY (AUDIENCE_SEGMENT)
) COMMENT = 'DEMO: Logged-in audience segments and CPM assumptions, synthetic (Expires: 2027-01-16)';

INSERT INTO AD_SEGMENTS (AUDIENCE_SEGMENT, ANNUAL_LOGGED_IN_IMPRESSIONS, RUN_OF_NETWORK_CPM, TARGETED_CPM)
VALUES
    ('Personal finance and investing', 50000000, 34.00, 55.00),
    ('Small business owners',          62000000, 29.00, 43.00),
    ('Retirement and wealth',          54000000, 26.00, 38.00),
    ('Home and auto',                  58000000, 29.00, 37.00),
    ('Young families',                 41000000, 34.00, 46.00),
    ('Fitness and outdoors',           36000000, 28.00, 36.00),
    ('Faith and family',               38000000, 26.00, 31.00);
