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
  EXTERNAL_ACCESS_INTEGRATIONS = (OSM_TILES_ACCESS)
  MIN_INSTANCES = 1
  MAX_INSTANCES = 1
  QUERY_WAREHOUSE = SFE_IOT_LIFECYCLE_WH
  COMMENT = 'DEMO: React fleet dashboard with deck.gl animated map (Expires: 2026-06-11)';

GRANT USAGE ON COMPUTE POOL IOT_FLEET_POOL TO ROLE PUBLIC;
GRANT SERVICE ROLE FLEET_DASHBOARD_SERVICE!all_endpoints_usage TO ROLE PUBLIC;

SELECT SYSTEM$GET_SERVICE_STATUS('FLEET_DASHBOARD_SERVICE') AS service_status;
SHOW ENDPOINTS IN SERVICE FLEET_DASHBOARD_SERVICE;
