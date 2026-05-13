/*******************************************************************************
 * DEPLOY SERVICE (Step 3 of 3)
 *
 * Creates the SPCS service from the container image you pushed in Step 2.
 *
 * Prerequisites (must be done BEFORE running this):
 *   Step 1: deploy_all.sql in Snowsight (creates data, agent, image repo, compute pool)
 *   Step 2: ./build_and_push.sh in terminal (builds React app, pushes image via Snow CLI)
 *
 * What happens when you Run All:
 *   - Creates the FLEET_DASHBOARD_SERVICE on the IOT_FLEET_POOL compute pool
 *   - Grants public access so anyone in your account can view the dashboard
 *   - The last query shows your dashboard URL in the "ingress_url" column
 *   - Open that URL in your browser -- Snowflake handles authentication
 *   - First start takes ~60 seconds while the container spins up
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
