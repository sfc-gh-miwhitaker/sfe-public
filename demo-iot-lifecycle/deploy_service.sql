/*******************************************************************************
 * DEPLOY SERVICE -- Creates the SPCS service from your pushed container image
 *
 * Run this AFTER:
 *   1. deploy_all.sql completed (data + image repo + compute pool ready)
 *   2. ./build_and_push.sh completed (image pushed to registry)
 *
 * After this script finishes:
 *   - The SHOW ENDPOINTS output at the bottom gives you the dashboard URL
 *   - Open that URL in your browser (you'll authenticate with Snowflake)
 *   - The service takes ~60 seconds to become READY on first start
 ******************************************************************************/

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA IOT_LIFECYCLE;
USE WAREHOUSE SFE_IOT_LIFECYCLE_WH;

CREATE SERVICE IF NOT EXISTS FLEET_DASHBOARD_SERVICE
  IN COMPUTE POOL IOT_FLEET_POOL
  FROM SPECIFICATION $$
  spec:
    containers:
    - name: fleet-dashboard
      image: /snowflake_example/iot_lifecycle/iot_image_repo/fleet-dashboard:latest
      readinessProbe:
        port: 8000
        path: /api/vehicles
      resources:
        requests:
          memory: 512M
          cpu: 0.5
        limits:
          memory: 1G
          cpu: 1.0
    endpoints:
    - name: dashboard
      port: 8000
      public: true
  $$
  MIN_INSTANCES = 1
  MAX_INSTANCES = 1
  QUERY_WAREHOUSE = SFE_IOT_LIFECYCLE_WH
  COMMENT = 'DEMO: React fleet dashboard with deck.gl animated map (Expires: 2026-06-11)';

GRANT USAGE ON COMPUTE POOL IOT_FLEET_POOL TO ROLE PUBLIC;
GRANT SERVICE ROLE FLEET_DASHBOARD_SERVICE!all_endpoints_usage TO ROLE PUBLIC;

-- Wait a moment for service to register, then check status
SELECT SYSTEM$GET_SERVICE_STATUS('FLEET_DASHBOARD_SERVICE') AS service_status;

-- This shows your dashboard URL in the "ingress_url" column
SHOW ENDPOINTS IN SERVICE FLEET_DASHBOARD_SERVICE;
