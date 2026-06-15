/*******************************************************************************
 * UPDATE SERVICE (in-place image upgrade)
 *
 * Re-applies the SPCS service spec to pull the latest container image and
 * roll the containers in place. The dashboard URL stays the same.
 *
 * When to use:
 *   After ./build_and_push.sh has pushed a new :latest image and you want the
 *   running FLEET_DASHBOARD_SERVICE to pick it up without dropping/recreating.
 *
 * Prerequisites:
 *   - Service was already created via deploy_service.sql
 *   - You just pushed a new image with ./build_and_push.sh
 *
 * What happens:
 *   - ALTER SERVICE re-resolves the :latest tag in the image repository
 *   - Snowflake rolls the containers (~30-60s)
 *   - Service URL, endpoints, and grants are unchanged
 *
 * Expires: 2026-06-11
 ******************************************************************************/

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA IOT_LIFECYCLE;
USE WAREHOUSE SFE_IOT_LIFECYCLE_WH;

ALTER SERVICE FLEET_DASHBOARD_SERVICE
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
  $$;

-- Confirm the rollout is in progress / complete
SELECT SYSTEM$GET_SERVICE_STATUS('FLEET_DASHBOARD_SERVICE') AS service_status;

-- Dashboard URL (unchanged) for convenience
SHOW ENDPOINTS IN SERVICE FLEET_DASHBOARD_SERVICE;
