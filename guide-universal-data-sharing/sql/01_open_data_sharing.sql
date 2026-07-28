/*=============================================================================
  Open Data Sharing — Share with Non-Snowflake Consumers

  Status: PUBLIC PREVIEW (July 2026)
  Docs:   https://docs.snowflake.com/en/user-guide/open-data-sharing

  What this does:
    Enables non-Snowflake consumers to access your shared data via standard
    Iceberg REST Catalog APIs. No Snowflake account needed on the consumer side.

  Prerequisites:
    - ACCOUNTADMIN role (or role with CREATE EXTERNAL CONSUMER, CREATE SHARE,
      CREATE EXTERNAL LISTING privileges)
    - Iceberg table to share (Snowflake-managed or external volume)
=============================================================================*/

USE ROLE ACCOUNTADMIN;

-------------------------------------------------------------------------------
-- Step 1: Create an external consumer
--   This represents the non-Snowflake party accessing your data.
--   External consumers are restricted users bound to a specific region.
-------------------------------------------------------------------------------

CREATE EXTERNAL CONSUMER partner_analytics_consumer;

SHOW EXTERNAL CONSUMERS LIKE '%partner_analytics%';

-------------------------------------------------------------------------------
-- Step 2: Add a Programmatic Access Token (PAT)
--   IMPORTANT: Save the returned secret immediately. You cannot retrieve it later.
--   During Preview, PATs are the only supported auth method.
-------------------------------------------------------------------------------

ALTER EXTERNAL CONSUMER partner_analytics_consumer ADD PAT partner_pat;

-- The output contains the PAT secret. Provide this + catalog URL to your partner.

-------------------------------------------------------------------------------
-- Step 3: Create the data to share (Iceberg table)
--   Using Snowflake-managed storage for simplicity.
--   You can also use an external volume — see docs for that path.
-------------------------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS sharing_demo_db;
CREATE SCHEMA IF NOT EXISTS sharing_demo_db.open_sharing;

CREATE OR REPLACE ICEBERG TABLE sharing_demo_db.open_sharing.partner_metrics (
    region        STRING,
    quarter       STRING,
    revenue       NUMBER(12,2),
    customer_count INT
)
  EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
  CATALOG = 'SNOWFLAKE';

INSERT INTO sharing_demo_db.open_sharing.partner_metrics VALUES
    ('AMER', '2026-Q1', 4250000.00, 1200),
    ('AMER', '2026-Q2', 4780000.00, 1350),
    ('EMEA', '2026-Q1', 3100000.00, 890),
    ('EMEA', '2026-Q2', 3450000.00, 960),
    ('APAC', '2026-Q1', 2200000.00, 650),
    ('APAC', '2026-Q2', 2580000.00, 720);

-------------------------------------------------------------------------------
-- Step 4: Create a share and grant access
-------------------------------------------------------------------------------

CREATE SHARE partner_metrics_share;

GRANT USAGE ON DATABASE sharing_demo_db TO SHARE partner_metrics_share;
GRANT USAGE ON SCHEMA sharing_demo_db.open_sharing TO SHARE partner_metrics_share;
GRANT SELECT ON TABLE sharing_demo_db.open_sharing.partner_metrics
    TO SHARE partner_metrics_share;

-------------------------------------------------------------------------------
-- Step 5: Create an external listing
--   This links the share to the external consumer identity.
-------------------------------------------------------------------------------

CREATE EXTERNAL LISTING partner_metrics_listing SHARE partner_metrics_share AS
$$
title: "Partner Revenue Metrics"
description: "Quarterly revenue and customer metrics by region"
listing_terms:
  type: "OFFLINE"
external_targets:
  access:
    - external_consumers: [PARTNER_ANALYTICS_CONSUMER]
$$;

-- Verify
SHOW LISTINGS LIKE 'PARTNER_METRICS_LISTING';
DESC LISTING partner_metrics_listing;

-------------------------------------------------------------------------------
-- Step 6: Get the catalog URL for the external consumer
--   Provide this URL + the PAT to your partner.
--   They connect with any IRC-compatible client (Spark, Trino, PyIceberg, etc.)
-------------------------------------------------------------------------------

CALL SYSTEM$GET_LISTING_URL_FOR_EXTERNAL_CONSUMER('PARTNER_METRICS_LISTING');

-- Output contains:
--   catalog: <catalog_type>
--   catalog_uri: https://<region>.snowflakecomputing.com/polaris/api/catalog/...
--
-- Partner uses: catalog_uri + PAT + standard Iceberg REST Catalog client

-------------------------------------------------------------------------------
-- Cleanup (when done testing)
-------------------------------------------------------------------------------
-- DROP LISTING partner_metrics_listing;
-- DROP SHARE partner_metrics_share;
-- DROP EXTERNAL CONSUMER partner_analytics_consumer;
-- DROP TABLE sharing_demo_db.open_sharing.partner_metrics;
