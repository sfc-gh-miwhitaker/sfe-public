/*=============================================================================
  Open Table Format Sharing — Iceberg/Delta Across Clouds

  Status: GA (late 2025)
  Docs:   https://docs.snowflake.com/en/collaboration/use-auto-fulfillment-with-open-table-formats
  Blog:   https://www.snowflake.com/en/blog/data-sharing-open-table-formats/

  What this does:
    Share Apache Iceberg and Delta Lake tables across regions and clouds using
    Cross-Cloud Auto-Fulfillment. Consumer must have a Snowflake account.
    (For non-Snowflake consumers, see 01_open_data_sharing.sql)

  Key benefits:
    - No ETL pipelines
    - No per-query egress charges (Egress Cost Optimizer)
    - Full Horizon governance policies enforced on shared data
    - Works with Snowflake-managed AND externally-managed Iceberg
=============================================================================*/

USE ROLE ACCOUNTADMIN;

-------------------------------------------------------------------------------
-- Option A: Share Snowflake-managed Iceberg table
--   Simplest path — Snowflake manages the storage and catalog.
-------------------------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS otf_sharing_db;
CREATE SCHEMA IF NOT EXISTS otf_sharing_db.shared_data;

-- Create Iceberg table with Snowflake-managed storage
CREATE OR REPLACE ICEBERG TABLE otf_sharing_db.shared_data.product_catalog (
    product_id     STRING,
    product_name   STRING,
    category       STRING,
    price          NUMBER(10,2),
    last_updated   TIMESTAMP_NTZ
)
  EXTERNAL_VOLUME = 'SNOWFLAKE_MANAGED'
  CATALOG = 'SNOWFLAKE';

INSERT INTO otf_sharing_db.shared_data.product_catalog VALUES
    ('P001', 'Widget Pro', 'Hardware', 29.99, CURRENT_TIMESTAMP()),
    ('P002', 'DataSync', 'Software', 149.00, CURRENT_TIMESTAMP()),
    ('P003', 'CloudBridge', 'Services', 499.00, CURRENT_TIMESTAMP());

-------------------------------------------------------------------------------
-- Option B: Share externally-managed Iceberg table
--   Data lives in your S3/Azure/GCS bucket, managed by external catalog.
--   Requires an external volume + catalog integration.
-------------------------------------------------------------------------------

-- Example: External volume pointing to S3
-- CREATE OR REPLACE EXTERNAL VOLUME partner_exvol
--   STORAGE_LOCATIONS = (
--     (
--       NAME = 'partner-s3-west'
--       STORAGE_PROVIDER = 'S3'
--       STORAGE_BASE_URL = 's3://your-bucket/iceberg/'
--       STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789012:role/your-role'
--     )
--   );
--
-- CREATE OR REPLACE ICEBERG TABLE otf_sharing_db.shared_data.external_table (...)
--   EXTERNAL_VOLUME = 'partner_exvol'
--   CATALOG = 'SNOWFLAKE'
--   BASE_LOCATION = 'external_table/';

-------------------------------------------------------------------------------
-- Apply governance policies BEFORE sharing
--   These policies travel with the data across clouds/regions.
-------------------------------------------------------------------------------

-- Example: Mask revenue for non-privileged roles
-- CREATE OR REPLACE MASKING POLICY revenue_mask AS (val NUMBER)
--   RETURNS NUMBER ->
--   CASE
--     WHEN CURRENT_ROLE() IN ('FINANCE_ADMIN') THEN val
--     ELSE NULL
--   END;
--
-- ALTER TABLE otf_sharing_db.shared_data.product_catalog
--   MODIFY COLUMN price SET MASKING POLICY revenue_mask;

-------------------------------------------------------------------------------
-- Create a listing with Cross-Cloud Auto-Fulfillment
--   Use Snowsight UI: Data Products → Provider Studio → +Listing
--   Select "Only Specified Customers" for private listings.
--
--   Cross-Cloud Auto-Fulfillment handles:
--     - Automatic replication to consumer's region
--     - Egress Cost Optimizer for predictable costs
--     - Delivery to commercial, VPS, and government clouds
--
--   Full UI walkthrough:
--   https://docs.snowflake.com/collaboration/provider-listings-creating-publishing
-------------------------------------------------------------------------------

-- Verify existing listings
SHOW LISTINGS;

-------------------------------------------------------------------------------
-- Cleanup
-------------------------------------------------------------------------------
-- DROP TABLE otf_sharing_db.shared_data.product_catalog;
-- DROP SCHEMA otf_sharing_db.shared_data;
-- DROP DATABASE otf_sharing_db;
