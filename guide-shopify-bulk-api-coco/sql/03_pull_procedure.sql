/* Shopify Bulk API + CoCo — deterministic pull procedure
   Pair-programmed by SE Community + Cortex Code
   Expires: 2026-12-03

   CoCo regenerates STORE_BINDINGS and SECRETS when stores change. Secret values
   remain inside Snowflake and are only available to this handler. */

USE ROLE SHOPIFY_PIPELINE_RL;
USE WAREHOUSE SHOPIFY_PIPELINE_WH;

CREATE OR REPLACE PROCEDURE SHOPIFY_NATIVE.CONTROL.PULL_STORE(
  STORE_KEY VARCHAR,
  OBJECT_NAME VARCHAR,
  SINCE_TS TIMESTAMP_TZ
)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python', 'requests')
HANDLER = 'pull_store'
EXTERNAL_ACCESS_INTEGRATIONS = (SHOPIFY_NATIVE_EAI)
SECRETS = (
  'store_001' = SHOPIFY_NATIVE.CONTROL.SHOPIFY_STORE_ALPHA_CREDENTIALS
)
EXECUTE AS CALLER
AS
$$
from __future__ import annotations

import json
import tempfile
import time
import uuid
from datetime import datetime, timezone

import _snowflake
import requests
from snowflake.snowpark import Session


API_VERSION = "2026-01"
POLL_SECONDS = 30
MAX_POLLS = 240
STORE_BINDINGS = {
    "STORE_ALPHA": {
        "domain": "store-alpha.myshopify.com",
        "binding_alias": "store_001",
    }
}

ORDER_QUERY = """
{
  orders(query: %FILTER%) {
    edges {
      node {
        id name createdAt updatedAt processedAt cancelledAt
        displayFinancialStatus displayFulfillmentStatus currencyCode test
        totalPriceSet { shopMoney { amount currencyCode } }
        totalDiscountsSet { shopMoney { amount currencyCode } }
        totalRefundedSet { shopMoney { amount currencyCode } }
        lineItems { edges { node { id title sku quantity currentQuantity vendor } } }
        fulfillments { id status createdAt updatedAt deliveredAt }
      }
    }
  }
}
"""

FULFILLMENT_ORDER_QUERY = """
{
  fulfillmentOrders(query: %FILTER%) {
    edges {
      node {
        id createdAt updatedAt status requestStatus fulfillAt fulfillBy
        order { id }
        assignedLocation { name location { id } }
        deliveryMethod { methodType }
      }
    }
  }
}
"""

START_MUTATION = """
mutation StartBulk($query: String!) {
  bulkOperationRunQuery(query: $query) {
    bulkOperation { id status }
    userErrors { field message }
  }
}
"""

STATUS_QUERY = """
query BulkStatus($id: ID!) {
  bulkOperation(id: $id) {
    id status errorCode objectCount url partialDataUrl completedAt
  }
}
"""


def graphql(http, endpoint, token, query, variables):
    response = http.post(
        endpoint,
        headers={"X-Shopify-Access-Token": token, "Content-Type": "application/json"},
        json={"query": query, "variables": variables},
        timeout=60,
    )
    response.raise_for_status()
    payload = response.json()
    if payload.get("errors"):
        raise RuntimeError(f"SHOPIFY_GRAPHQL: {payload['errors']}")
    return payload["data"]


def write_log(session, values):
    session.sql(
        """
        INSERT INTO SHOPIFY_NATIVE.CONTROL.PULL_RUN_LOG (
          RUN_ID, STORE_KEY, OBJECT_NAME, STARTED_AT, COMPLETED_AT, STATUS,
          BULK_OPERATION_ID, FILE_NAME, OBJECT_COUNT, ROWS_LOADED,
          WATERMARK_FROM, WATERMARK_TO, ERROR_CLASS, ERROR_MESSAGE, QUERY_ID
        ) SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, LAST_QUERY_ID()
        """,
        params=values,
    ).collect()


def pull_store(session: Session, store_key: str, object_name: str, since_ts):
    run_id = str(uuid.uuid4())
    started_at = datetime.now(timezone.utc)
    store_key = store_key.upper()
    object_name = object_name.upper()
    binding = STORE_BINDINGS.get(store_key)
    if binding is None:
        raise ValueError(f"CONFIG: no generated binding for {store_key}")
    queries = {"ORDERS": ORDER_QUERY, "FULFILLMENT_ORDERS": FULFILLMENT_ORDER_QUERY}
    if object_name not in queries:
        raise ValueError(f"CONFIG: unsupported object {object_name}; expected {sorted(queries)}")

    session.sql(
        f"ALTER SESSION SET QUERY_TAG = 'SHOPIFY_NATIVE:{store_key}:{object_name}'"
    ).collect()

    operation_id = None
    file_name = None
    watermark_to = datetime.now(timezone.utc)
    try:
        credentials = _snowflake.get_username_password(binding["binding_alias"])
        domain = binding["domain"]
        token_response = requests.post(
            f"https://{domain}/admin/oauth/access_token",
            data={
                "grant_type": "client_credentials",
                "client_id": credentials.username,
                "client_secret": credentials.password,
            },
            timeout=60,
        )
        token_response.raise_for_status()
        token = token_response.json()["access_token"]
        endpoint = f"https://{domain}/admin/api/{API_VERSION}/graphql.json"
        filter_text = '""'
        if since_ts is not None:
            iso_since = since_ts.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            filter_text = json.dumps(f"updated_at:>={iso_since}")
        bulk_query = queries[object_name].replace("%FILTER%", filter_text)

        with requests.Session() as http:
            started = graphql(http, endpoint, token, START_MUTATION, {"query": bulk_query})
            result = started["bulkOperationRunQuery"]
            if result["userErrors"]:
                raise RuntimeError(f"SHOPIFY_VALIDATION: {result['userErrors']}")
            operation_id = result["bulkOperation"]["id"]
            operation = None
            for _ in range(MAX_POLLS):
                operation = graphql(http, endpoint, token, STATUS_QUERY, {"id": operation_id})["bulkOperation"]
                if operation["status"] not in {"CREATED", "RUNNING", "CANCELING"}:
                    break
                time.sleep(POLL_SECONDS)
            if operation is None or operation["status"] != "COMPLETED":
                status = operation["status"] if operation else "UNKNOWN"
                code = operation.get("errorCode") if operation else None
                raise RuntimeError(f"SHOPIFY_BULK_{status}: {code or 'poll limit reached'}")
            result_url = operation["url"]
            if result_url:
                download = http.get(result_url, timeout=300, stream=True)
                download.raise_for_status()
                result_stream = tempfile.SpooledTemporaryFile(max_size=64 * 1024 * 1024)
                for chunk in download.iter_content(chunk_size=8 * 1024 * 1024):
                    if chunk:
                        result_stream.write(chunk)
                result_stream.seek(0)
            else:
                # Shopify returns a null URL for a valid zero-record operation.
                result_stream = None

        pulled_at = datetime.now(timezone.utc)
        path = f"{store_key.lower()}/{object_name.lower()}/{pulled_at:%Y/%m/%d}/{run_id}.jsonl"
        rows_loaded = 0
        if result_stream is not None:
            session.file.put_stream(
                result_stream,
                f"@SHOPIFY_NATIVE.LANDING.SHOPIFY_STAGE/{path}",
                auto_compress=False,
                overwrite=False,
            )
            file_name = path
            copy_result = session.sql(
                f"""
                COPY INTO SHOPIFY_NATIVE.LANDING.SHOPIFY_RAW (
                  STORE_KEY, OBJECT_NAME, PULLED_AT, SOURCE_FILE, SOURCE_ROW_NUMBER, RECORD
                )
                FROM (
                  SELECT ?, ?, ?::TIMESTAMP_TZ, METADATA$FILENAME,
                         METADATA$FILE_ROW_NUMBER, $1
                  FROM @SHOPIFY_NATIVE.LANDING.SHOPIFY_STAGE/{path}
                )
                FILE_FORMAT = (FORMAT_NAME = SHOPIFY_NATIVE.LANDING.JSONL_FORMAT)
                ON_ERROR = ABORT_STATEMENT
                """,
                params=[store_key, object_name, pulled_at],
            ).collect()
            rows_loaded = sum(
                int(row.as_dict().get("ROWS_LOADED", row.as_dict().get("rows_loaded", 0)))
                for row in copy_result
            )
        write_log(session, [
            run_id, store_key, object_name, started_at, pulled_at, "SUCCEEDED",
            operation_id, file_name, int(operation["objectCount"]), rows_loaded,
            since_ts, watermark_to, None, None,
        ])
        return {
            "run_id": run_id,
            "status": "SUCCEEDED",
            "store_key": store_key,
            "object_name": object_name,
            "rows_loaded": rows_loaded,
            "bulk_operation_id": operation_id,
            "file_name": file_name,
        }
    except Exception as exc:
        completed_at = datetime.now(timezone.utc)
        error_class = type(exc).__name__
        write_log(session, [
            run_id, store_key, object_name, started_at, completed_at, "FAILED",
            operation_id, file_name, None, None, since_ts, watermark_to,
            error_class, str(exc)[:16000],
        ])
        raise
$$;

CREATE OR REPLACE PROCEDURE SHOPIFY_NATIVE.CONTROL.PULL_ALL_STORES()
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  PULL_FAILURE EXCEPTION (-20001, 'One or more Shopify store/object pulls failed; inspect PULL_RUN_LOG');
  STORES RESULTSET;
  CURRENT_STORE VARCHAR;
  CURRENT_OBJECT VARCHAR;
  WATERMARK TIMESTAMP_TZ;
  RESULT VARIANT;
  SUCCEEDED NUMBER DEFAULT 0;
  FAILED NUMBER DEFAULT 0;
BEGIN
  STORES := (SELECT STORE_KEY FROM SHOPIFY_NATIVE.CONTROL.STORE_REGISTRY
             WHERE IS_ACTIVE ORDER BY STORE_KEY);
  FOR STORE IN STORES DO
    FOR OBJECT_ROW IN (SELECT COLUMN1 AS OBJECT_NAME FROM VALUES ('ORDERS'), ('FULFILLMENT_ORDERS')) DO
      CURRENT_STORE := STORE.STORE_KEY;
      CURRENT_OBJECT := OBJECT_ROW.OBJECT_NAME;
      WATERMARK := (
        SELECT MAX(WATERMARK_TO)
        FROM SHOPIFY_NATIVE.CONTROL.PULL_RUN_LOG
        WHERE STORE_KEY = :CURRENT_STORE
          AND OBJECT_NAME = :CURRENT_OBJECT
          AND STATUS = 'SUCCEEDED'
      );
      BEGIN
        CALL SHOPIFY_NATIVE.CONTROL.PULL_STORE(:CURRENT_STORE, :CURRENT_OBJECT, :WATERMARK) INTO :RESULT;
        SUCCEEDED := SUCCEEDED + 1;
      EXCEPTION
        WHEN OTHER THEN
          FAILED := FAILED + 1;
      END;
    END FOR;
  END FOR;
  IF (FAILED > 0) THEN
    RAISE PULL_FAILURE;
  END IF;
  RETURN OBJECT_CONSTRUCT('succeeded', SUCCEEDED, 'failed', FAILED);
END;
$$;

CREATE OR REPLACE PROCEDURE SHOPIFY_NATIVE.CONTROL.QUALIFY_STORE(
  STORE_KEY VARCHAR,
  BASELINE_SOURCE VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  PULL_RESULT VARIANT;
  QUALIFICATION_FILE VARCHAR;
  LOADED_ROWS NUMBER;
  GATES_FAILED NUMBER;
BEGIN
  DELETE FROM SHOPIFY_NATIVE.CONTROL.QUALIFICATION_RESULTS WHERE STORE_KEY = :STORE_KEY;

  INSERT INTO SHOPIFY_NATIVE.CONTROL.QUALIFICATION_RESULTS
  SELECT :STORE_KEY, 'REGISTRATION', COUNT(*) = 1,
         OBJECT_CONSTRUCT('registered_rows', COUNT(*)), CURRENT_TIMESTAMP()
  FROM SHOPIFY_NATIVE.CONTROL.STORE_REGISTRY WHERE STORE_KEY = :STORE_KEY;

  BEGIN
    CALL SHOPIFY_NATIVE.CONTROL.PULL_STORE(:STORE_KEY, 'ORDERS', DATEADD('day', -1, CURRENT_TIMESTAMP())) INTO :PULL_RESULT;
    LOADED_ROWS := PULL_RESULT:rows_loaded::NUMBER;
    QUALIFICATION_FILE := PULL_RESULT:file_name::VARCHAR;
    INSERT INTO SHOPIFY_NATIVE.CONTROL.QUALIFICATION_RESULTS
    SELECT :STORE_KEY, COLUMN1, TRUE, :PULL_RESULT, CURRENT_TIMESTAMP()
    FROM VALUES ('CONNECTIVITY'), ('EXTRACTION'), ('LANDING'), ('LOADING');
  EXCEPTION
    WHEN OTHER THEN
      INSERT INTO SHOPIFY_NATIVE.CONTROL.QUALIFICATION_RESULTS
      SELECT :STORE_KEY, 'PULL_EXECUTION', FALSE,
             OBJECT_CONSTRUCT('error', :SQLERRM), CURRENT_TIMESTAMP();
  END;

  INSERT INTO SHOPIFY_NATIVE.CONTROL.QUALIFICATION_RESULTS
  SELECT :STORE_KEY, 'DATA_CONTRACT', COUNT(*) > 0,
         OBJECT_CONSTRUCT('records_with_required_fields', COUNT(*)), CURRENT_TIMESTAMP()
  FROM SHOPIFY_NATIVE.LANDING.SHOPIFY_RAW
  WHERE STORE_KEY = :STORE_KEY AND OBJECT_NAME = 'ORDERS'
    AND SOURCE_FILE = :QUALIFICATION_FILE
    AND RECORD:id IS NOT NULL AND RECORD:updatedAt IS NOT NULL;

  INSERT INTO SHOPIFY_NATIVE.CONTROL.QUALIFICATION_RESULTS
  WITH ACTUAL AS (
    SELECT TO_DATE(TRY_TO_TIMESTAMP_TZ(RECORD:processedAt::VARCHAR)) AS ACTIVITY_DATE,
           RECORD:currencyCode::VARCHAR AS CURRENCY_CODE,
           COUNT_IF(RECORD:id::VARCHAR LIKE 'gid://shopify/Order/%') AS ORDER_COUNT,
           SUM(IFF(RECORD:id::VARCHAR LIKE 'gid://shopify/Order/%',
                   TRY_TO_DECIMAL(RECORD:totalPriceSet:shopMoney:amount::VARCHAR, 38, 4), 0)) AS GROSS_SALES
    FROM SHOPIFY_NATIVE.LANDING.SHOPIFY_RAW
    WHERE STORE_KEY = :STORE_KEY AND SOURCE_FILE = :QUALIFICATION_FILE
    GROUP BY ACTIVITY_DATE, CURRENCY_CODE
  ),
  COMPARISON AS (
    SELECT COUNT(*) AS COMPARED_DAYS,
           MAX(ABS(A.ORDER_COUNT - B.ORDER_COUNT)) AS MAX_ORDER_DELTA,
           MAX(ABS(A.GROSS_SALES - B.GROSS_SALES)) AS MAX_SALES_DELTA
    FROM ACTUAL A
    JOIN SHOPIFY_NATIVE.CONTROL.RECONCILIATION_BASELINE B
      ON B.STORE_KEY = :STORE_KEY
     AND B.SOURCE_NAME = :BASELINE_SOURCE
     AND B.ACTIVITY_DATE = A.ACTIVITY_DATE
     AND B.CURRENCY_CODE = A.CURRENCY_CODE
  )
  SELECT :STORE_KEY, 'RECONCILIATION',
         IFF(:BASELINE_SOURCE IS NULL, TRUE,
             COMPARED_DAYS > 0 AND COALESCE(MAX_ORDER_DELTA, 0) = 0
             AND COALESCE(MAX_SALES_DELTA, 0) <= 0.01),
         OBJECT_CONSTRUCT('baseline_source', :BASELINE_SOURCE,
                          'compared_days', COMPARED_DAYS,
                          'max_order_delta', MAX_ORDER_DELTA,
                          'max_sales_delta', MAX_SALES_DELTA), CURRENT_TIMESTAMP()
  FROM COMPARISON;

  GATES_FAILED := (SELECT COUNT(*) FROM SHOPIFY_NATIVE.CONTROL.QUALIFICATION_RESULTS
                   WHERE STORE_KEY = :STORE_KEY AND NOT PASSED);
  UPDATE SHOPIFY_NATIVE.CONTROL.STORE_REGISTRY
  SET QUALIFICATION_STATUS = IFF(:GATES_FAILED = 0, 'PASSED', 'FAILED'),
      LAST_QUALIFIED_AT = CURRENT_TIMESTAMP()
  WHERE STORE_KEY = :STORE_KEY;

  RETURN OBJECT_CONSTRUCT('store_key', :STORE_KEY, 'passed', :GATES_FAILED = 0,
                          'failed_gates', :GATES_FAILED, 'rows_loaded', :LOADED_ROWS);
END;
$$;
