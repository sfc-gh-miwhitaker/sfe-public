# Pattern C: MCP Server + Cortex Agent (Recommended)

Full delegation to Snowflake. Copilot Studio's MCP connector calls a Snowflake-managed MCP Server, which routes to a Cortex Agent that orchestrates Cortex Analyst, Cortex Search, and custom tools. Zero 422 errors, multi-step reasoning, and the highest success rate in real-world testing.

> **See also:** [Pattern A: Knowledge Source](knowledge-source.md) for no-code quick start, or [Pattern B: Cortex Analyst](cortex-analyst-connector.md) for semantic-grounded SQL without MCP.

---

## When to Use This Pattern

- Production workloads requiring consistent, grounded answers
- Need multi-tool orchestration (structured + unstructured data in one turn)
- Want Snowflake's Cortex Agent to decide which tool to use (not Copilot)
- Same agent needs to be accessible from Copilot Studio, Teams, Snowflake Intelligence, and web apps
- Need zero structural (422) errors — Agent eliminated them entirely in [30-question testing](https://blog.mwccomms.com/2026/04/connecting-copilot-studio-to-snowflake.html)

**Trade-offs:**
- Most setup of the three patterns (~2 hours)
- Highest Snowflake-side cost (Agent + Analyst + Search credits stack)
- Two layers of orchestration = two layers to debug
- Capability surface is still evolving

---

## Prerequisites

- Snowflake account with ACCOUNTADMIN and SYSADMIN
- Cortex Agent + Semantic View (or Cortex Search Service) already created
- Microsoft Copilot Studio environment with MCP connector access
- Familiarity with Snowflake OAuth (different from the External OAuth in Patterns A/B)

---

## Snowflake-Side Setup

### Step 1: Create a Cortex Agent

```sql
USE ROLE SYSADMIN;

CREATE OR REPLACE AGENT <DATABASE>.<SCHEMA>.COPILOT_AGENT
  COMMENT = 'Cortex Agent for Copilot Studio MCP access'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  instructions:
    system: "You are a data analytics assistant. Answer questions about business data using the available tools. Be concise and accurate."

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "analyst"
        description: "Converts natural language to SQL using a semantic model for structured data queries"
    - tool_spec:
        type: "cortex_search"
        name: "search"
        description: "Searches unstructured documents and knowledge base content"

  tool_resources:
    analyst:
      semantic_view: "<DATABASE>.<SCHEMA>.MY_SEMANTIC_VIEW"
      execution_environment:
        type: warehouse
        warehouse: "<WAREHOUSE_NAME>"
        query_timeout: 60
    search:
      cortex_search_service: "<DATABASE>.<SCHEMA>.MY_SEARCH_SERVICE"
  $$;
```

> **Governance note:** By assigning only `cortex_analyst_text_to_sql` (and NOT `execute_sql`), the agent is structurally limited to read-only analytical queries generated through the semantic view.

### Step 2: Create the MCP Server

```sql
CREATE OR REPLACE MCP SERVER <DATABASE>.<SCHEMA>.COPILOT_MCP_SERVER
  FROM SPECIFICATION $$
    tools:
      - name: "copilot-agent"
        type: "CORTEX_AGENT_RUN"
        identifier: "<DATABASE>.<SCHEMA>.COPILOT_AGENT"
        description: "Analytics agent that orchestrates between structured data (Cortex Analyst) and unstructured search (Cortex Search)"
        title: "Copilot Analytics Agent"
  $$;
```

### Step 3: Grant Permissions

```sql
CREATE ROLE IF NOT EXISTS COPILOT_MCP_ROLE;

GRANT USAGE ON WAREHOUSE <WAREHOUSE_NAME> TO ROLE COPILOT_MCP_ROLE;
GRANT USAGE ON DATABASE <DATABASE> TO ROLE COPILOT_MCP_ROLE;
GRANT USAGE ON SCHEMA <DATABASE>.<SCHEMA> TO ROLE COPILOT_MCP_ROLE;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE COPILOT_MCP_ROLE;
GRANT USAGE ON AGENT <DATABASE>.<SCHEMA>.COPILOT_AGENT TO ROLE COPILOT_MCP_ROLE;
GRANT USAGE ON MCP SERVER <DATABASE>.<SCHEMA>.COPILOT_MCP_SERVER TO ROLE COPILOT_MCP_ROLE;
GRANT SELECT ON SEMANTIC VIEW <DATABASE>.<SCHEMA>.MY_SEMANTIC_VIEW TO ROLE COPILOT_MCP_ROLE;
```

> No SELECT on underlying tables is needed — the semantic view acts as the interface.

### Step 4: Create Snowflake OAuth Security Integration

Pattern C uses **Snowflake-native OAuth** (not External OAuth like Patterns A/B) because the MCP connector handles the OAuth flow directly with Snowflake.

```sql
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE SECURITY INTEGRATION copilot_mcp_oauth
  TYPE = OAUTH
  OAUTH_CLIENT = CUSTOM
  ENABLED = TRUE
  OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
  OAUTH_ISSUE_REFRESH_TOKENS = TRUE
  OAUTH_REFRESH_TOKEN_VALIDITY = 86400
  OAUTH_USE_SECONDARY_ROLES = IMPLICIT
  OAUTH_REDIRECT_URI = 'https://localhost';
```

> **Critical:** `OAUTH_USE_SECONDARY_ROLES = IMPLICIT` is required. Other values cause opaque failures.

> **Note:** `OAUTH_REDIRECT_URI` is a placeholder. After Copilot Studio generates the real redirect URL in Step 6, you'll update it.

### Step 5: Retrieve Client Credentials

```sql
SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('COPILOT_MCP_OAUTH');
```

Save the `OAUTH_CLIENT_ID` and `OAUTH_CLIENT_SECRET` from the output.

---

## Copilot Studio Configuration

### Step 6: Add MCP Tool to Your Agent

1. Open **Copilot Studio** → Your agent → **Tools** → **Add a tool**
2. Select **Model Context Protocol**
3. Configure the MCP connection:
   - **Name:** `Snowflake Analytics`
   - **Description:** `Analytics agent that answers questions about business data using Snowflake Cortex`
   - **MCP Server URL:**
     ```
     https://<ORG-ACCOUNT>.snowflakecomputing.com/api/v2/databases/<DATABASE>/schemas/<SCHEMA>/mcp-servers/<MCP_SERVER_NAME>
     ```

> **Hostname rule:** Always use hyphens (`-`), never underscores (`_`). Hostnames with underscores cause MCP connection failures.

4. Under **Authentication**, choose **OAuth 2.0** → Set to **Manual**
5. Fill in:

| Field | Value |
|-------|-------|
| Authorization URL | `https://<ORG-ACCOUNT>.snowflakecomputing.com/oauth/authorize` |
| Token URL | `https://<ORG-ACCOUNT>.snowflakecomputing.com/oauth/token-request` |
| Client ID | From Step 5 |
| Client Secret | From Step 5 |
| Scope | `session:role:<COPILOT_MCP_ROLE>` |

> **Scope limitation:** Snowflake OAuth does NOT support `session:role-any` from Copilot Studio. You must specify a single role.

6. Click **Next** — Copilot Studio generates a **redirect URL**

### Step 7: Update Snowflake with the Real Redirect URL

```sql
USE ROLE ACCOUNTADMIN;

ALTER SECURITY INTEGRATION copilot_mcp_oauth
  SET OAUTH_REDIRECT_URI = '<COPILOT_STUDIO_REDIRECT_URL>';
```

### Step 8: Create the Connection

1. Back in Copilot Studio, from the **Connection** dropdown, select **Create new connection**
2. Click **Create** — this launches the Snowflake OAuth sign-in flow
3. Complete Snowflake authentication
4. After OAuth completes, click **Add** to attach the tool to your agent

### Step 9: Configure Tool Settings

1. Under **Details** → expand additional settings
2. Choose identity mode:
   - **Per-user credentials** — each user authenticates individually (recommended for production)
   - **Shared credentials** — single service account for all users
3. Under **Tools**, Copilot lists the tools exposed by the MCP Server
4. Enable all tools or select specific ones

---

## Testing

### Test 1: Verify Agent in Snowsight

Before testing via Copilot, verify the agent works directly:
1. Navigate to the Agent in Snowsight → use the built-in chat panel
2. Ask: *"What were the top 5 products by revenue last quarter?"*
3. If this fails, fix Snowflake-side config before proceeding

### Test 2: Test MCP Endpoint with curl

```bash
TOKEN=$(curl -s -X POST \
  "https://<ORG-ACCOUNT>.snowflakecomputing.com/oauth/token-request" \
  -d "client_id=<CLIENT_ID>" \
  -d "client_secret=<SECRET>" \
  -d "grant_type=client_credentials" | jq -r .access_token)

curl -s -X POST \
  "https://<ORG-ACCOUNT>.snowflakecomputing.com/api/v2/databases/<DB>/schemas/<SCHEMA>/mcp-servers/<NAME>" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

### Test 3: Test in Copilot Studio

Ask your agent:
- *"What were our sales last month?"* (routes to Cortex Analyst)
- *"Summarize the latest product announcement"* (routes to Cortex Search)
- *"Compare Q1 revenue to Q2 and explain any trends mentioned in recent reports"* (multi-tool)

---

## Governance Model

Three layers working together:

| Layer | What It Controls | How |
|-------|-----------------|-----|
| **Snowflake RBAC** | Who can access the MCP server and agent | `GRANT USAGE ON MCP SERVER` + `GRANT USAGE ON AGENT` |
| **Semantic View** | What data the agent can see | Only tables/columns in the view are queryable |
| **Agent Tool List** | What operations are possible | Omitting `execute_sql` = structurally read-only |

---

## Pattern D: REST API / Custom MCP (Advanced)

If Pattern C's managed MCP isn't sufficient, you can:

1. **Cortex Agent REST API directly:** Build an Azure Web App that proxies between Copilot Studio and the Cortex Agent REST API (`POST /api/v2/databases/{db}/schemas/{schema}/agents/{name}:run`). This gives you full control over conversation state, response shaping, and multi-surface reuse.

2. **Self-hosted MCP Server:** Deploy the [Snowflake-Labs/mcp](https://github.com/Snowflake-Labs/mcp) open-source implementation for complete control over tool definitions, resources, and prompts.

**When to use Pattern D:**
- Need custom response shaping before returning to Copilot
- Need agent-to-agent orchestration (Copilot Agent ↔ Cortex Agent)
- Need the same endpoint accessible from Teams bots, web apps, and other surfaces
- Need configurable SQL statement permissions beyond the managed offering

> **Reality check:** Fewer than 10% of use cases need Pattern D. Start with Pattern C and only escalate if you hit a wall.

---

## Common Gotchas

| Issue | Cause | Fix |
|-------|-------|-----|
| Connection fails silently | `OAUTH_USE_SECONDARY_ROLES` not `IMPLICIT` | Set to `IMPLICIT` on the security integration |
| "does not exist or not authorized" | Role lacks USAGE on MCP server | `GRANT USAGE ON MCP SERVER ... TO ROLE ...` |
| URL connection failure / TLS error | Underscores in hostname | Replace `_` with `-` in org/account name |
| Scope error | Used `session:role-any` | Specify a single role: `session:role:<ROLE_NAME>` |
| Redirect URL mismatch | Placeholder not updated | `ALTER SECURITY INTEGRATION ... SET OAUTH_REDIRECT_URI = '<REAL_URL>'` |
| HTTP 200 but JSON-RPC error | Auth failure in response body | Check `error` field in JSON response, not HTTP status |
| Tools not visible in Copilot | Agent usage toggle not enabled | Enable it in Copilot's tool settings |
| Token expires mid-session | Refresh token validity too short | Set `OAUTH_REFRESH_TOKEN_VALIDITY = 86400` (24 hours) |
| Multi-turn context lost | MCP connector is stateless per call | Design agent instructions to be self-contained per turn |
| `SNOWFLAKE.CORTEX_USER` denied | Database role not granted | `GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE ...` |

---

## URL Format Reference

| Use Case | URL Pattern |
|---|---|
| Copilot Studio MCP connector | `https://<ORG-ACCOUNT>.snowflakecomputing.com/api/v2/databases/<DB>/schemas/<SCHEMA>/mcp-servers/<NAME>` |
| curl / REST testing | Same as above |
| Authorization endpoint | `https://<ORG-ACCOUNT>.snowflakecomputing.com/oauth/authorize` |
| Token endpoint | `https://<ORG-ACCOUNT>.snowflakecomputing.com/oauth/token-request` |

**Get your org-account identifier:**

```sql
SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();
```

---

## References

- [Snowflake MCP Server Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp)
- [CREATE MCP SERVER Reference](https://docs.snowflake.com/en/sql-reference/sql/create-mcp-server)
- [CREATE AGENT Reference](https://docs.snowflake.com/en/sql-reference/sql/create-agent)
- [Snowflake OAuth Custom Client](https://docs.snowflake.com/en/user-guide/oauth-custom)
- [Copilot Studio MCP Documentation (MS Learn)](https://learn.microsoft.com/en-us/microsoft-copilot-studio/agent-extend-action-mcp)
- [Integrating Copilot Studio with Cortex via MCP (Shankar Narayanan)](https://medium.com/snowflake/integrating-microsoft-copilot-studio-agents-with-snowflake-cortex-using-mcp-17c9998a4acf)
- [Getting Started with Copilot Studio and Cortex Agents (Quickstart)](https://www.snowflake.com/en/developers/guides/getting-started-with-microsoft-copilot-studio-and-cortex-agents/)
- [Custom Headers in MCP Connectors (Microsoft CAT Blog)](https://microsoft.github.io/mcscatblog/posts/mcp-custom-headers/)
- [Snowflake-Labs/mcp (GitHub)](https://github.com/Snowflake-Labs/mcp)
