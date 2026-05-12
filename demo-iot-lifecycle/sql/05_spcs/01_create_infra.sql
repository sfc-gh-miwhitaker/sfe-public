USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA IOT_LIFECYCLE;
USE WAREHOUSE SFE_IOT_LIFECYCLE_WH;

CREATE IMAGE REPOSITORY IF NOT EXISTS IOT_IMAGE_REPO
  COMMENT = 'DEMO: Container images for IoT fleet dashboard (Expires: 2026-06-11)';

CREATE COMPUTE POOL IF NOT EXISTS IOT_FLEET_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_SUSPEND_SECS = 300
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: Compute pool for fleet dashboard SPCS service (Expires: 2026-06-11)';

SHOW IMAGE REPOSITORIES LIKE 'IOT_IMAGE_REPO';

SELECT
    'Image repo and compute pool ready.' AS status,
    'Next: Build and push image, then run deploy_service.sql' AS next_step;
