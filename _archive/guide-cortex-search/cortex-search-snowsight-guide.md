# Creating a Cortex Search Service via Snowsight

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Role | Must have `SNOWFLAKE.CORTEX_USER` database role granted |
| Warehouse | Active warehouse for service creation/refresh |
| Source Data | Table with text column to search |

---

## Step 1: Navigate to AI & ML Studio

1. Sign in to **Snowsight**
2. Select **AI & ML → Studio** from the navigation menu
3. Locate the **Create a Cortex Search Service** box
4. Click **+ Create**

---

## Step 2: Configure Service Settings

| Setting | Action |
|---------|--------|
| Role | Select role with `SNOWFLAKE.CORTEX_USER` privilege |
| Warehouse | Choose warehouse for indexing operations |
| Database | Select target database |
| Schema | Select target schema |
| Service Name | Enter a unique name |

Click **Let's go** to proceed.

---

## Step 3: Select Source Data

1. Choose the **table** containing your searchable content
2. Select the **text column** to index (the column users will search against)
3. Click **Next**

---

## Step 4: Configure Attributes (Optional)

Select columns to enable **filtering** on search results:

- Choose columns like `region`, `category`, `date`, etc.
- These become filterable attributes in queries
- Click **Next** or **Skip this option** if no filters needed

---

## Step 5: Set Target Lag

Configure refresh frequency:

| Target Lag | Use Case |
|------------|----------|
| 1 minute | Near real-time, higher compute cost |
| 1 hour | Balanced (recommended) |
| 1 day | Batch updates, lower cost |

Click **Create search service**.

---

## Step 6: Verify Service Creation

The confirmation screen displays:
- Service name (double-quoted identifier)
- Data source reference

---

## Testing the Service

Use `SEARCH_PREVIEW` to validate:

```sql
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'DATABASE.SCHEMA."Service_Name"',
    '{
      "query": "your search term",
      "columns": ["text_column", "attribute_column"],
      "limit": 5
    }'
  )
)['results'] AS results;
```

### With Filtering

```sql
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'DATABASE.SCHEMA."Service_Name"',
    '{
      "query": "your search term",
      "columns": ["text_column", "region"],
      "filter": {"@eq": {"region": "North America"}},
      "limit": 5
    }'
  )
)['results'] AS results;
```

---

## Filter Operators Reference

| Operator | Description | Example |
|----------|-------------|---------|
| `@eq` | Equals | `{"@eq": {"region": "US"}}` |
| `@contains` | Contains value | `{"@contains": {"tags": "urgent"}}` |
| `@gte` | Greater than or equal | `{"@gte": {"score": 80}}` |
| `@lte` | Less than or equal | `{"@lte": {"score": 100}}` |
| `@and` | Logical AND | `{"@and": [...]}` |
| `@or` | Logical OR | `{"@or": [...]}` |
| `@not` | Logical NOT | `{"@not": {...}}` |

---

## Exporting from Test Account

After validating your service in the test account, extract the definition for production deployment.

### Step 1: Describe the Service

```sql
DESCRIBE CORTEX SEARCH SERVICE DATABASE.SCHEMA."Service_Name";
```

Key fields to capture:

| Field | Description |
|-------|-------------|
| `definition` | The source query (SELECT statement) |
| `search_column` | Column being indexed |
| `attribute_columns` | Filterable columns |
| `target_lag` | Refresh frequency |
| `warehouse` | Compute warehouse |
| `embedding_model` | Vector model (if specified) |

### Step 2: Generate Deployment Script

Use the DESCRIBE output to construct a `CREATE` statement:

```sql
CREATE OR REPLACE CORTEX SEARCH SERVICE PROD_DB.PROD_SCHEMA.my_search_service
  ON transcript_text
  ATTRIBUTES region, agent_id
  WAREHOUSE = prod_warehouse
  TARGET_LAG = '1 hour'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
AS (
  SELECT
    transcript_text,
    date,
    region,
    agent_id
  FROM PROD_DB.PROD_SCHEMA.transcripts
);
```

### Step 3: Save to Version Control

Save as `cortex_search_services/my_search_service.sql`:

```sql
-- cortex_search_services/my_search_service.sql
-- Cortex Search Service: my_search_service
-- Last updated: YYYY-MM-DD

CREATE OR REPLACE CORTEX SEARCH SERVICE ${database}.${schema}.my_search_service
  ON transcript_text
  ATTRIBUTES region, agent_id
  WAREHOUSE = ${warehouse}
  TARGET_LAG = '${target_lag}'
AS (
  SELECT
    transcript_text,
    date,
    region,
    agent_id
  FROM ${database}.${schema}.transcripts
);
```

---

## Declarative Deployment to Production

### Option 1: Snowflake CLI

Deploy using `snow sql`:

```bash
snow sql -f cortex_search_services/my_search_service.sql \
  -D database=PROD_DB \
  -D schema=PROD_SCHEMA \
  -D warehouse=PROD_WH \
  -D target_lag='1 hour' \
  --connection prod
```

### Option 2: GitHub Actions CI/CD

```yaml
name: Deploy Cortex Search Services

on:
  push:
    branches: [main]
    paths:
      - 'cortex_search_services/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      SNOWFLAKE_CONNECTIONS_DEFAULT_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
      SNOWFLAKE_CONNECTIONS_DEFAULT_USER: ${{ secrets.SNOWFLAKE_USER }}
      SNOWFLAKE_CONNECTIONS_DEFAULT_PASSWORD: ${{ secrets.SNOWFLAKE_PASSWORD }}

    steps:
      - uses: actions/checkout@v4

      - name: Install Snowflake CLI
        uses: Snowflake-Labs/snowflake-cli-action@v1.5
        with:
          cli-version: "latest"

      - name: Deploy Cortex Search Services
        run: |
          for file in cortex_search_services/*.sql; do
            snow sql -f "$file" \
              -D database=PROD_DB \
              -D schema=PROD_SCHEMA \
              -D warehouse=PROD_WH \
              -D target_lag='1 hour'
          done
```

### Option 3: Git Repository Integration

1. **Create Git Repository in Snowflake:**

```sql
CREATE OR REPLACE GIT REPOSITORY prod_db.admin.deployment_repo
  API_INTEGRATION = github_api_integration
  ORIGIN = 'https://github.com/your-org/snowflake-deployments.git';
```

2. **Execute from Git:**

```sql
EXECUTE IMMEDIATE FROM @prod_db.admin.deployment_repo/branches/main/cortex_search_services/my_search_service.sql
  USING (database => 'PROD_DB', schema => 'PROD_SCHEMA', warehouse => 'PROD_WH', target_lag => '1 hour');
```

---

## Deployment Checklist

| Step | Test | Production |
|------|------|------------|
| Source table exists | ✓ | Verify |
| Warehouse available | ✓ | Verify |
| Role has `CORTEX_USER` | ✓ | Verify |
| Target lag appropriate | ✓ | Adjust for prod |
| Test with `SEARCH_PREVIEW` | ✓ | Required |
| Grant usage to app roles | — | Required |

### Post-Deployment Grants

```sql
GRANT USAGE ON CORTEX SEARCH SERVICE PROD_DB.PROD_SCHEMA.my_search_service
  TO ROLE app_reader_role;
```

---

## Notes

- Service names created via Snowsight are **double-quoted identifiers**
- Use fully qualified names: `DATABASE.SCHEMA."Service_Name"`
- `SEARCH_PREVIEW` is for testing only—use Python API for production
- For complex source queries or multiple tables, use SQL instead of UI
- Always parameterize environment-specific values (database, schema, warehouse)
- Include deployment scripts in version control for audit trail

---

*Document generated for Cortex Search service creation via Snowsight UI*
