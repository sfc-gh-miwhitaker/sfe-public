/*==============================================================================
CLASSIFICATION APPROACH 4: Populate Vision Results
Waits for the SPCS service to become READY, then classifies all products
with image URLs and writes results to STG_CLASSIFIED_VISION.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

DECLARE
  service_status VARCHAR;
  attempts       NUMBER DEFAULT 0;
  max_attempts   NUMBER DEFAULT 18;   -- 18 × 10s = 3 min max wait
  svc_not_ready  EXCEPTION (-20002, 'SPCS service did not reach READY within timeout');
BEGIN
  -- Poll until the service container is READY
  WHILE (attempts < max_attempts) DO
    SELECT PARSE_JSON(SYSTEM$GET_SERVICE_STATUS(
             'SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.GLAZE_VISION_SERVICE'
           ))[0]['status']::VARCHAR
      INTO service_status;

    IF (service_status = 'READY') THEN
      BREAK;
    END IF;

    SYSTEM$LOG_INFO('Waiting for GLAZE_VISION_SERVICE… status=' || service_status
                    || ' attempt=' || attempts);
    CALL SYSTEM$WAIT(10, 'SECONDS');
    attempts := attempts + 1;
  END WHILE;

  IF (service_status != 'READY') THEN
    RAISE svc_not_ready;
  END IF;

  -- Service is healthy — populate results
  TRUNCATE TABLE IF EXISTS STG_CLASSIFIED_VISION;

  INSERT INTO STG_CLASSIFIED_VISION
    (product_id, predicted_category, predicted_subcategory, confidence_score, raw_response)
  WITH classified AS (
      SELECT
          p.product_id,
          CLASSIFY_IMAGE(p.image_url) AS raw_response
      FROM RAW_PRODUCTS p
      WHERE p.image_url IS NOT NULL
  )
  SELECT
      product_id,
      TRY_PARSE_JSON(raw_response):category::VARCHAR       AS predicted_category,
      TRY_PARSE_JSON(raw_response):subcategory::VARCHAR    AS predicted_subcategory,
      TRY_PARSE_JSON(raw_response):confidence::NUMBER(5,4) AS confidence_score,
      raw_response
  FROM classified;

  SYSTEM$LOG_INFO('Vision classification complete — '
                  || (SELECT COUNT(*) FROM STG_CLASSIFIED_VISION) || ' products classified');
END;
