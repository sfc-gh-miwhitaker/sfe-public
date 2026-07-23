# Pattern 1: Filter-Based UBAC

**The recommended pattern for most Cortex Search access control scenarios.**

The core idea: tag each indexed document with an ARRAY of identifiers authorized to see it. At query time, the calling application injects the current user's identifier as a `@contains` filter. The service returns only rows where the caller's identifier appears in that array.

This works for any external identifier — CRM account IDs, Salesforce Account IDs, workspace IDs, tenant IDs, user emails, employee IDs. The pattern is identical regardless of what the identifier looks like.

> **Security contract.** The service still indexes all documents. A query issued without the filter exposes the full index to whoever has USAGE on the service. The calling application is the enforcement point. See [Hardening the Pattern](#hardening-the-pattern) to eliminate that risk with a stored procedure wrapper.

---

## Step 1: Add an ARRAY Attribute Column to Your Source Table

The filter-based approach requires an ARRAY-typed column that holds the list of identifiers authorized to access each row. Add it to your source table (or view) and populate it.

```sql
-- Add the column
ALTER TABLE db.schema.content_documents
  ADD COLUMN authorized_ids ARRAY
  COMMENT 'Access control list: array of external account identifiers authorized to see this document';

-- Populate for a document visible to two accounts
UPDATE db.schema.content_documents
  SET authorized_ids = ['acct-001', 'acct-002']::ARRAY
WHERE doc_id = 'doc-abc123';

-- Populate for a document visible to one account
UPDATE db.schema.content_documents
  SET authorized_ids = ['acct-042']::ARRAY
WHERE doc_id = 'doc-xyz789';

-- Verify
SELECT doc_id, title, authorized_ids
FROM db.schema.content_documents
LIMIT 5;
```

### Identifier format

The identifier stored in `authorized_ids` must match exactly what the calling application injects at query time. Common patterns:

| Source system | Example identifier |
|---|---|
| Salesforce Account | `'0015e000003AbCdAAF'` |
| Internal tenant ID | `'tenant-acme-corp'` |
| Workspace ID | `'ws-4f2a9b'` |
| User email | `'alice@example.com'` |
| UUID | `'a3f8c2d1-...'` |

Pick one and be consistent. The filter is a string equality check — casing matters.

---

## Step 2: Create the Cortex Search Service with ATTRIBUTES

Declare `authorized_ids` in the `ATTRIBUTES` clause. Attribute columns must also appear in the source query.

```sql
CREATE OR REPLACE CORTEX SEARCH SERVICE db.schema.docs_search_svc
  ON content_text                    -- the column to search
  ATTRIBUTES authorized_ids          -- columns available for filtering
  WAREHOUSE = my_search_wh
  TARGET_LAG = '1 hour'
  COMMENT = 'Document search with per-account access control (Expires: 2026-10-21)'
AS
  SELECT
    content_text,       -- the searchable column (must match ON clause)
    authorized_ids,     -- MUST be in SELECT for ATTRIBUTES to work
    doc_id,
    title,
    doc_type
  FROM db.schema.content_documents;
```

**Common mistake:** declaring a column in `ATTRIBUTES` but omitting it from the `SELECT`. The service creation will fail or the column will not be filterable.

---

## Step 3: Inject the Filter at Query Time

The `@contains` operator checks whether the ARRAY column contains a given value. Pass it as a filter JSON object.

### REST API

```bash
curl --location \
  'https://<ACCOUNT_URL>/api/v2/databases/db/schemas/schema/cortex-search-services/docs_search_svc:query' \
  --header 'Content-Type: application/json' \
  --header 'Authorization: Bearer <PAT>' \
  --data '{
    "query": "quarterly results",
    "columns": ["doc_id", "title", "content_text"],
    "filter": { "@contains": { "authorized_ids": "acct-001" } },
    "limit": 10
  }'
```

### Python API

```python
from snowflake.core import Root
from snowflake.snowpark import Session

session = Session.builder.configs(connection_params).create()
root = Root(session)

search_svc = (
    root
    .databases["db"]
    .schemas["schema"]
    .cortex_search_services["docs_search_svc"]
)

# caller_account_id resolved from session context or app layer
resp = search_svc.search(
    query="quarterly results",
    columns=["doc_id", "title", "content_text"],
    filter={"@contains": {"authorized_ids": caller_account_id}},
    limit=10,
)
print(resp.to_json())
```

### SQL (testing / validation only — not for production)

```sql
-- SEARCH_PREVIEW is for interactive testing only, not production apps
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'db.schema.docs_search_svc',
    '{
      "query": "quarterly results",
      "columns": ["doc_id", "title", "content_text"],
      "filter": { "@contains": { "authorized_ids": "acct-001" } },
      "limit": 10
    }'
  )
)['results'] AS results;
```

> `SEARCH_PREVIEW` is intended for interactive validation in worksheets and notebooks — it has higher latency than the REST and Python APIs and is not intended for production search traffic.

---

## Step 4: Resolve the Caller's Identifier

The calling application is responsible for resolving the current user's external identifier before issuing the search query. Three common approaches:

### Option A: User-to-account mapping table in Snowflake

Maintain a mapping table and look it up at query time.

```sql
CREATE OR REPLACE TABLE db.schema.user_account_map (
  snowflake_user   VARCHAR NOT NULL,
  account_id       VARCHAR NOT NULL,
  CONSTRAINT pk_uam PRIMARY KEY (snowflake_user, account_id)
);
```

```sql
-- Look up the caller's account ID in a query or stored procedure
SELECT account_id
FROM db.schema.user_account_map
WHERE snowflake_user = CURRENT_USER();
```

### Option B: JWT / OAuth token claim

Extract the external account ID from the caller's token at the application layer before constructing the search request. The identifier never flows through Snowflake session context.

### Option C: Session context tag

If your Snowflake SSO integration populates custom session tags, read them via `SYSTEM$GET_TAG` or a custom session parameter set at login.

---

## Hardening the Pattern

The default setup grants USAGE on the service directly to callers. A caller who bypasses the application can query the service without a filter and see all indexed documents.

To eliminate this risk: wrap the search call in a stored procedure that resolves the filter from an internal mapping table. Grant callers USAGE on the procedure only — not on the service.

> **Note on `SEARCH_PREVIEW` inside a stored procedure.** Within Snowflake SQL, `SEARCH_PREVIEW` is the only way to call a Cortex Search Service. The latency warning elsewhere in this guide applies to routing end-user traffic directly through `SEARCH_PREVIEW` from a worksheet or notebook. Wrapping it in an `EXECUTE AS OWNER` procedure is a legitimate Snowflake-native pattern for enforcing the filter — the security guarantee (filter bypass is impossible) is the point, not bypassing the latency advisory. For applications that call Snowflake from outside (a web backend, a Streamlit-in-Snowflake app calling the REST API), use the REST or Python API directly rather than routing through this procedure.

```sql
CREATE OR REPLACE PROCEDURE db.schema.search_my_docs(
  query       VARCHAR,
  result_cols VARCHAR  -- columns to return as a JSON array string, e.g. '["doc_id", "title"]'
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS
BEGIN
  -- Resolve caller identity from the mapping table
  LET account_id VARCHAR := (
    SELECT account_id
    FROM db.schema.user_account_map
    WHERE snowflake_user = CURRENT_USER()
    LIMIT 1
  );

  IF (account_id IS NULL) THEN
    RETURN PARSE_JSON('{"error": "Caller has no account mapping. Contact your administrator."}');
  END IF;

  -- Issue the search with the injected filter; caller cannot bypass this
  RETURN (
    SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
      'db.schema.docs_search_svc',
      OBJECT_CONSTRUCT(
        'query',   :query,
        'columns', PARSE_JSON(:result_cols),
        'filter',  OBJECT_CONSTRUCT('@contains', OBJECT_CONSTRUCT('authorized_ids', :account_id)),
        'limit',   10
      )::VARCHAR
    )
  );
END;

-- Grant callers EXECUTE on the procedure only
GRANT EXECUTE ON PROCEDURE db.schema.search_my_docs(VARCHAR, VARCHAR)
  TO ROLE analyst_role;

-- Do NOT grant USAGE on the service to analyst_role
-- REVOKE USAGE ON CORTEX SEARCH SERVICE db.schema.docs_search_svc FROM ROLE analyst_role;
```

This pattern eliminates the filter-bypass risk: the procedure always injects the caller's account ID from the mapping table, and the caller has no path to the service directly.

---

## Multi-Identifier Support

A user may be authorized to access content from multiple accounts (e.g., a team member who serves several clients, or a document licensed to a group of organizations).

Use `@or` to match any of the user's identifiers:

```json
{
  "@or": [
    { "@contains": { "authorized_ids": "acct-001" } },
    { "@contains": { "authorized_ids": "acct-002" } }
  ]
}
```

Python:

```python
resp = search_svc.search(
    query="quarterly results",
    columns=["doc_id", "title", "content_text"],
    filter={
        "@or": [
            {"@contains": {"authorized_ids": acct_id}}
            for acct_id in caller_account_ids   # list resolved from mapping table
        ]
    },
    limit=10,
)
```

For very large identifier lists (dozens of IDs), consider whether [Pattern 2 — separate services](separate-services.md) is a cleaner fit.

---

## Combining Access Control with Other Filters

Access control filters compose with other filters using `@and`:

```json
{
  "@and": [
    { "@contains": { "authorized_ids": "acct-001" } },
    { "@eq": { "doc_type": "report" } }
  ]
}
```

The access control predicate should always be the outermost or first condition to make it visually obvious that it is present.

---

## Tradeoffs and Gotchas

| Consideration | Detail |
|---|---|
| **Data model change required** | You must add the `authorized_ids` ARRAY column to your source table. For existing tables with complex ownership logic, this may require a migration. |
| **Filter injection is the enforcement point** | If the application layer omits the filter, the full index is exposed. Use the stored procedure wrapper to prevent this. |
| **No partial attribute exposure** | If a column is in the ATTRIBUTES clause, any caller with USAGE on the service can filter on it. Do not put sensitive values in ATTRIBUTES columns themselves. |
| **ARRAY element type must be VARIANT-compatible** | Snowflake stores ARRAY elements as VARIANT. String identifiers work reliably. Avoid typed arrays with non-standard types. |
| **Column name casing in filters** | Cortex Search filter attribute names are case-sensitive in the JSON object. Match the column name exactly as declared in the source query. |
| **SEARCH_PREVIEW is for testing only** | Do not route production traffic through `SNOWFLAKE.CORTEX.SEARCH_PREVIEW`. Use the REST or Python APIs. |
| **Row-level masking is NOT inherited** | Masking policies on the source table do not apply to Cortex Search results. The ARRAY filter is your only access control mechanism. |

---

## When to Switch to Pattern 2

Consider [Pattern 2 — separate services](separate-services.md) instead of this pattern when:

- Access boundaries are static, well-defined groups (fewer than ~20)
- Zero tolerance for leakage — you cannot trust the application layer to always inject the filter
- You do not want to modify the source table schema

---

*[Back to README](README.md)*
