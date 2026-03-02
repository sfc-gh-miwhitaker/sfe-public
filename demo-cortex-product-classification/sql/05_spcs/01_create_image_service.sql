/*==============================================================================
CLASSIFICATION APPROACH 4: SPCS Custom Vision Model (Infrastructure)
Creates the image repository, compute pool, service, and SQL function.

The service takes ~30-90s to start after creation. Populate results with
02_populate_vision.sql which waits for the service to become READY.

NOTE: Requires SPCS enabled + CREATE COMPUTE POOL privilege. If unavailable,
this step can be skipped — the comparison view shows NULL for vision results.

To build and push the image:
  cd spcs/
  docker build -t glaze-vision:latest .
  docker tag glaze-vision:latest <registry>/SNOWFLAKE_EXAMPLE/GLAZE_AND_CLASSIFY/GLAZE_IMAGE_REPO/glaze-vision:latest
  docker push <registry>/SNOWFLAKE_EXAMPLE/GLAZE_AND_CLASSIFY/GLAZE_IMAGE_REPO/glaze-vision:latest
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

CREATE IMAGE REPOSITORY IF NOT EXISTS GLAZE_IMAGE_REPO
  COMMENT = 'DEMO: Container images for Glaze & Classify vision service (Expires: 2026-05-01)';

USE ROLE SYSADMIN;
CREATE COMPUTE POOL IF NOT EXISTS SFE_GLAZE_VISION_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_SUSPEND_SECS = 300
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: Compute pool for bakery image classification (Expires: 2026-05-01)';

CREATE SERVICE IF NOT EXISTS SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.GLAZE_VISION_SERVICE
  IN COMPUTE POOL SFE_GLAZE_VISION_POOL
  FROM SPECIFICATION $$
  spec:
    containers:
      - name: vision-classifier
        image: /SNOWFLAKE_EXAMPLE/GLAZE_AND_CLASSIFY/GLAZE_IMAGE_REPO/glaze-vision:latest
        resources:
          requests:
            cpu: "0.5"
            memory: 256M
          limits:
            cpu: "1"
            memory: 512M
    endpoints:
      - name: classify
        port: 8080
  $$
  MIN_INSTANCES = 1
  MAX_INSTANCES = 1
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: Bakery image classification HTTP service (Expires: 2026-05-01)';

CREATE OR REPLACE FUNCTION CLASSIFY_IMAGE(image_url VARCHAR)
  RETURNS VARCHAR
  SERVICE = SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.GLAZE_VISION_SERVICE
  ENDPOINT = classify
  AS '/classify';
