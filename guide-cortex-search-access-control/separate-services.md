# Pattern 2: Separate Services per Data Boundary

**The recommended pattern when access boundaries are static, well-defined groups.**

The core idea: build one Cortex Search Service per access boundary, where each service's source query filters to only the documents that boundary should see. Grant USAGE on each service only to the role that maps to that boundary. Data from one boundary never enters another service.

> **Zero leakage by design.** Unlike [Pattern 1](filter-attribute-ubac.md), this pattern cannot accidentally expose data if the calling application omits a filter — the data simply isn't in the wrong service.

---

## When to Use This Pattern

Use Pattern 2 when:

- Boundaries are **static and known at index time** (regional, tier-based, department-based)
- You have **fewer than ~20 distinct groups** — beyond that, the per-service overhead compounds
- **Zero tolerance for leakage** — you cannot rely on the application layer to inject a filter correctly
- You prefer **not to modify the source table schema** (no ARRAY attribute column needed)
- Each group's content is already clearly partitioned by an existing column

Use [Pattern 1 — Filter UBAC](filter-attribute-ubac.md) instead when:
- Boundaries are per-user, per-account, or otherwise dynamic
- You have many distinct identities (dozens to thousands)
- A user can belong to multiple groups simultaneously

---

## Step 1: Identify Your Boundary Column

Pick the column in your source table that defines the access boundary. This is typically a partition or classification column already in your data model.

Common examples:

| Data model | Boundary column | Values |
|---|---|---|
| Multi-tenant SaaS | `tenant_tier` | `'enterprise'`, `'standard'`, `'trial'` |
| Regional compliance | `data_region` | `'EMEA'`, `'AMER'`, `'APAC'` |
| Department content | `owning_department` | `'legal'`, `'finance'`, `'engineering'` |
| Product line | `product_line` | `'platform'`, `'analytics'`, `'security'` |

The column must have a value in every row, and the values must be stable. If rows move between groups frequently, Pattern 2 will require frequent service recreations.

---

## Step 2: Create One Service per Boundary

Each service uses a `WHERE` clause in its source query to scope the indexed content.

```sql
-- EMEA service: indexes only EMEA documents
CREATE OR REPLACE CORTEX SEARCH SERVICE db.schema.docs_search_emea
  ON content_text
  WAREHOUSE = my_search_wh
  TARGET_LAG = '1 hour'
  COMMENT = 'Document search — EMEA region only (Expires: 2026-10-21)'
AS
  SELECT
    content_text,
    doc_id,
    title,
    doc_type,
    data_region
  FROM db.schema.content_documents
  WHERE data_region = 'EMEA';

-- AMER service: indexes only AMER documents
CREATE OR REPLACE CORTEX SEARCH SERVICE db.schema.docs_search_amer
  ON content_text
  WAREHOUSE = my_search_wh
  TARGET_LAG = '1 hour'
  COMMENT = 'Document search — AMER region only (Expires: 2026-10-21)'
AS
  SELECT
    content_text,
    doc_id,
    title,
    doc_type,
    data_region
  FROM db.schema.content_documents
  WHERE data_region = 'AMER';

-- APAC service: indexes only APAC documents
CREATE OR REPLACE CORTEX SEARCH SERVICE db.schema.docs_search_apac
  ON content_text
  WAREHOUSE = my_search_wh
  TARGET_LAG = '1 hour'
  COMMENT = 'Document search — APAC region only (Expires: 2026-10-21)'
AS
  SELECT
    content_text,
    doc_id,
    title,
    doc_type,
    data_region
  FROM db.schema.content_documents
  WHERE data_region = 'APAC';
```

---

## Step 3: Grant USAGE to the Matching Role

Grant each role USAGE on only its own service. Do not grant cross-service access.

```sql
-- EMEA analysts can only query the EMEA service
GRANT USAGE ON CORTEX SEARCH SERVICE db.schema.docs_search_emea
  TO ROLE emea_analyst_role;

-- AMER analysts can only query the AMER service
GRANT USAGE ON CORTEX SEARCH SERVICE db.schema.docs_search_amer
  TO ROLE amer_analyst_role;

-- APAC analysts can only query the APAC service
GRANT USAGE ON CORTEX SEARCH SERVICE db.schema.docs_search_apac
  TO ROLE apac_analyst_role;

-- Grant USAGE on the parent database and schema too
GRANT USAGE ON DATABASE db TO ROLE emea_analyst_role;
GRANT USAGE ON SCHEMA db.schema TO ROLE emea_analyst_role;
-- (repeat for other roles)
```

---

## Step 4: Route Queries to the Correct Service

The calling application resolves which service to call based on the user's role or session context. No filter injection is needed — the right service naturally returns only the right data.

### Python API

```python
from snowflake.core import Root
from snowflake.snowpark import Session

session = Session.builder.configs(connection_params).create()
root = Root(session)

# Resolve which service to use from the user's session role or a mapping table
service_map = {
    "emea_analyst_role": "docs_search_emea",
    "amer_analyst_role": "docs_search_amer",
    "apac_analyst_role": "docs_search_apac",
}

current_role = session.get_current_role().strip('"')
service_name = service_map.get(current_role)

if service_name is None:
    raise PermissionError(f"Role {current_role} has no search service assigned.")

search_svc = (
    root
    .databases["db"]
    .schemas["schema"]
    .cortex_search_services[service_name]
)

resp = search_svc.search(
    query="quarterly results",
    columns=["doc_id", "title", "content_text"],
    limit=10,
)
print(resp.to_json())
```

### REST API

```bash
# Caller uses the endpoint for their region's service
# No filter needed — the service only contains their data

curl --location \
  'https://<ACCOUNT_URL>/api/v2/databases/db/schemas/schema/cortex-search-services/docs_search_emea:query' \
  --header 'Content-Type: application/json' \
  --header 'Authorization: Bearer <PAT>' \
  --data '{
    "query": "quarterly results",
    "columns": ["doc_id", "title", "content_text"],
    "limit": 10
  }'
```

---

## Operational Considerations

### Adding a new boundary group

When your data has a new value for the boundary column, create a new service and grant access:

```sql
-- New product line added
CREATE OR REPLACE CORTEX SEARCH SERVICE db.schema.docs_search_security
  ON content_text
  WAREHOUSE = my_search_wh
  TARGET_LAG = '1 hour'
  COMMENT = 'Document search — Security product line (Expires: 2026-10-21)'
AS
  SELECT content_text, doc_id, title, doc_type, product_line
  FROM db.schema.content_documents
  WHERE product_line = 'security';

GRANT USAGE ON CORTEX SEARCH SERVICE db.schema.docs_search_security
  TO ROLE security_analyst_role;
GRANT USAGE ON DATABASE db TO ROLE security_analyst_role;
GRANT USAGE ON SCHEMA db.schema TO ROLE security_analyst_role;
```

### Warehouse cost

Each service refresh consumes warehouse credits. With many services sharing a warehouse, refreshes compete for compute. Options:
- **Shared warehouse, staggered lag:** use the same warehouse but accept that refreshes queue
- **Dedicated warehouse per service:** cleanest isolation; higher cost
- **Shared warehouse, larger size:** faster individual refreshes; same contention

### When a document moves between boundaries

If a row's boundary column value changes (e.g., a document is reclassified from AMER to EMEA), the next refresh of the affected services will pick up the change automatically (incremental refresh mode). The document will appear in the new service and disappear from the old one within one TARGET_LAG period.

---

## Tradeoffs vs. Pattern 1

| Consideration | Pattern 2 (separate services) | Pattern 1 (filter UBAC) |
|---|---|---|
| **Leakage if app omits filter** | None — data not in service | Yes — full index exposed |
| **Source table schema change** | None required | Must add ARRAY column |
| **Number of services to manage** | One per group | One total |
| **Works for individual-level access** | No (impractical at scale) | Yes |
| **Dynamic group membership** | Requires service recreation | Update array column |
| **Cost at scale** | Grows linearly with group count | Fixed |

---

## When to Switch to Pattern 1

Consider [Pattern 1 — Filter UBAC](filter-attribute-ubac.md) instead of this pattern when:

- You have more than ~20 distinct boundaries
- Boundaries are dynamic or per-user
- A user legitimately belongs to multiple groups and needs a unified search result
- You want a single service to maintain and monitor

---

*[Back to README](README.md)*
