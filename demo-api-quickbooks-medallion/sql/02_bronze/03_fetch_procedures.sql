/*==============================================================================
02_BRONZE / 03_FETCH_PROCEDURES
Generic Python stored procedure that calls the QuickBooks Online REST API.
Handles OAuth 2.0 token refresh, pagination, and CDC via LastUpdatedTime.
Author: SE Community | Expires: 2026-03-29
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.QB_API;

-------------------------------------------------------------------------------
-- Watermark table: tracks the last successful fetch per entity for CDC
-------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS _QBO_FETCH_WATERMARK (
    entity_name   VARCHAR   PRIMARY KEY,
    last_fetched  TIMESTAMP_NTZ,
    rows_fetched  NUMBER,
    updated_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'DEMO: CDC watermark for QBO incremental fetches (Expires: 2026-03-29)';

-------------------------------------------------------------------------------
-- FETCH_QBO_ENTITY: one procedure handles all 7 entities
--
-- entity_name: Customer | Vendor | Item | Account | Invoice | Payment | Bill
-- realm_id:    Your QBO Company ID (visible in QBO URL or API Explorer)
-- full_reload: TRUE to ignore watermark and fetch everything
-------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE FETCH_QBO_ENTITY(
    entity_name VARCHAR,
    realm_id    VARCHAR,
    full_reload BOOLEAN DEFAULT FALSE
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'requests')
HANDLER = 'run'
EXTERNAL_ACCESS_INTEGRATIONS = (SFE_QBO_API_INTEGRATION)
SECRETS = ('qbo_cred' = SFE_QBO_OAUTH_SECRET)
COMMENT = 'DEMO: Fetch a single QBO entity with pagination + CDC (Expires: 2026-03-29)'
AS
$$
import _snowflake
import requests
import json
from datetime import datetime, timezone

BASE_URL = "https://sandbox-quickbooks.api.intuit.com"
PAGE_SIZE = 1000

def run(session, entity_name: str, realm_id: str, full_reload: bool = False) -> str:
    token = _snowflake.get_oauth_access_token('qbo_cred')
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }

    target_table = f"RAW_{entity_name.upper()}"
    fetch_start = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    watermark = None
    if not full_reload:
        wm_rows = session.sql(
            f"SELECT last_fetched FROM _QBO_FETCH_WATERMARK "
            f"WHERE entity_name = '{entity_name}'"
        ).collect()
        if wm_rows:
            watermark = wm_rows[0]["LAST_FETCHED"]

    where_clause = ""
    if watermark:
        wm_str = watermark.strftime("%Y-%m-%dT%H:%M:%S")
        where_clause = f" WHERE MetaData.LastUpdatedTime > '{wm_str}'"

    total_inserted = 0
    start_position = 1

    while True:
        query = (
            f"SELECT * FROM {entity_name}{where_clause} "
            f"STARTPOSITION {start_position} MAXRESULTS {PAGE_SIZE}"
        )
        url = f"{BASE_URL}/v3/company/{realm_id}/query"
        resp = requests.get(
            url,
            headers=headers,
            params={"query": query, "minorversion": "75"},
        )
        resp.raise_for_status()
        data = resp.json()

        query_response = data.get("QueryResponse", {})
        entities = query_response.get(entity_name, [])

        if not entities:
            break

        rows = []
        for entity in entities:
            rows.append({
                "qbo_id": str(entity.get("Id", "")),
                "raw_payload": json.dumps(entity),
                "api_endpoint": f"/v3/company/{realm_id}/query?query={entity_name}",
            })

        df = session.create_dataframe(rows)
        df.write.mode("append").save_as_table(target_table)
        total_inserted += len(entities)

        if len(entities) < PAGE_SIZE:
            break
        start_position += PAGE_SIZE

    session.sql(
        f"""
        MERGE INTO _QBO_FETCH_WATERMARK t
        USING (SELECT '{entity_name}' AS entity_name) s
        ON t.entity_name = s.entity_name
        WHEN MATCHED THEN UPDATE SET
            last_fetched = '{fetch_start}'::TIMESTAMP_NTZ,
            rows_fetched = {total_inserted},
            updated_at   = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN INSERT (entity_name, last_fetched, rows_fetched)
            VALUES ('{entity_name}', '{fetch_start}'::TIMESTAMP_NTZ, {total_inserted})
        """
    ).collect()

    return f"OK: {total_inserted} {entity_name} records loaded into {target_table}"
$$;

-------------------------------------------------------------------------------
-- Convenience wrapper: fetch all 7 entities in one call
-------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE FETCH_ALL_QBO_ENTITIES(
    realm_id    VARCHAR,
    full_reload BOOLEAN DEFAULT FALSE
)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'DEMO: Fetch all 7 QBO entities sequentially (Expires: 2026-03-29)'
AS
DECLARE
    result VARCHAR DEFAULT '';
    entities ARRAY DEFAULT ARRAY_CONSTRUCT(
        'Customer', 'Vendor', 'Item', 'Account',
        'Invoice', 'Payment', 'Bill'
    );
    i NUMBER DEFAULT 0;
    entity_result VARCHAR;
BEGIN
    FOR i IN 0 TO 6 DO
        CALL FETCH_QBO_ENTITY(:entities[i]::VARCHAR, :realm_id, :full_reload);
        result := result || '\n' || entity_result;
    END FOR;
    RETURN result;
END;
