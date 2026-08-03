# Pattern A: Snowflake as Knowledge Source (No-Code)

Connect Copilot Studio directly to Snowflake tables with zero code. Copilot parses natural language, generates SQL, and returns grounded answers — all through a point-and-click interface.

> **See also:** [Pattern C: MCP Server](mcp-server.md) for full Cortex AI delegation, or [Pattern B: Cortex Analyst](cortex-analyst-connector.md) for semantic-model grounded SQL.

---

## When to Use This Pattern

- Quick POC or demo (~5 minutes to first query)
- Business users asking simple questions against well-structured tables
- No need for Cortex AI features (Analyst, Search, LLM inference)
- Acceptable that Copilot generates SQL directly (no semantic grounding)

**Limitations:**
- No access to Cortex Analyst, Cortex Search, or Cortex Agents
- Copilot generates SQL against raw schema — prone to hallucinating table/column names (54% success rate in [real-world testing](https://blog.mwccomms.com/2026/04/connecting-copilot-studio-to-snowflake.html))
- Single-shot queries only — no multi-step reasoning
- No semantic model enforcing metric definitions

---

## Prerequisites

- Snowflake account with admin privileges
- Microsoft Entra ID tenant with App Registration permissions
- Power Platform Admin Center access (to verify Snowflake connector isn't blocked by DLP policy)
- Microsoft Copilot Studio environment (Sandbox or Production)

---

## Step 1: Register Snowflake OAuth Resource in Entra ID

1. **Azure Portal** → Microsoft Entra ID → App Registrations → **New Registration**
2. Name: `Snowflake OAuth Resource`
3. Supported account types: **Single Tenant**
4. Click **Register**
5. Go to **Expose an API** → Click **Set** next to Application ID URI
   - Accept the default or set a custom URI (e.g., `api://<guid>`)
   - Save this as `<SNOWFLAKE_APPLICATION_ID_URI>`
6. Go to **App Roles** → Create New App Role:
   - Display name: `Snowflake Analyst`
   - Allowed member types: **Applications**
   - Value: `session:role:<YOUR_SNOWFLAKE_ROLE>` (e.g., `session:role:ANALYST`)
   - Enable the role
7. Go to **Overview** → **Endpoints** → Copy **OAuth 2.0 token endpoint (v2)**
   - Save as `<TOKEN_ENDPOINT>`

---

## Step 2: Register Snowflake OAuth Client in Entra ID

1. **Azure Portal** → App Registrations → **New Registration**
2. Name: `Copilot Snowflake Client`
3. Supported account types: **Single Tenant**
4. Click **Register**
5. Copy **Application (client) ID** → save as `<OAUTH_CLIENT_ID>`
6. Copy **Directory (tenant) ID** → save as `<TENANT_ID>`
7. **Certificates & secrets** → New client secret → Copy value → save as `<OAUTH_CLIENT_SECRET>`
8. **API Permissions** → Add Permission → My APIs → Select **Snowflake OAuth Resource**
   - Check **Application Permissions** → select the role from Step 1
9. Click **Grant Admin Consent**

---

## Step 3: Get the Azure `sub` Claim

The Snowflake user must be mapped to the `sub` claim in the JWT token. Obtain it:

**PowerShell:**

```powershell
$TenantId = "<TENANT_ID>"
$ClientId = "<OAUTH_CLIENT_ID>"
$ClientSecret = "<OAUTH_CLIENT_SECRET>"
$Scope = "api://<SNOWFLAKE_APPLICATION_ID_URI>/.default"

$Body = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    grant_type    = "client_credentials"
    scope         = $Scope
}

$Token = (Invoke-RestMethod -Method Post `
  -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
  -Body $Body).access_token

$Token
```

**Or with curl:**

```bash
TOKEN=$(curl -s -X POST \
  "https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token" \
  -d "client_id=<OAUTH_CLIENT_ID>" \
  -d "client_secret=<OAUTH_CLIENT_SECRET>" \
  -d "scope=api://<SNOWFLAKE_APPLICATION_ID_URI>/.default" \
  -d "grant_type=client_credentials" | jq -r .access_token)
```

Decode the token at [jwt.ms](https://jwt.ms/) and copy the `sub` value → save as `<AZURE_SUB>`.

---

## Step 4: Configure Snowflake

```sql
USE ROLE ACCOUNTADMIN;

-- Create a user mapped to the Azure service principal
CREATE USER COPILOT_OAUTH_USER
  LOGIN_NAME = '<AZURE_SUB>'
  DISPLAY_NAME = 'Copilot Studio OAuth User'
  COMMENT = 'Service principal for Copilot Studio knowledge source';

-- Create and assign a role
CREATE ROLE IF NOT EXISTS ANALYST;
GRANT ROLE ANALYST TO USER COPILOT_OAUTH_USER;
ALTER USER COPILOT_OAUTH_USER SET DEFAULT_ROLE = ANALYST;

-- Grant access to data
GRANT USAGE ON WAREHOUSE <WAREHOUSE_NAME> TO ROLE ANALYST;
GRANT USAGE ON DATABASE <DATABASE_NAME> TO ROLE ANALYST;
GRANT USAGE ON SCHEMA <DATABASE_NAME>.<SCHEMA_NAME> TO ROLE ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA <DATABASE_NAME>.<SCHEMA_NAME> TO ROLE ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA <DATABASE_NAME>.<SCHEMA_NAME> TO ROLE ANALYST;

-- Create External OAuth security integration
CREATE OR REPLACE SECURITY INTEGRATION copilot_external_oauth_azure
  TYPE = EXTERNAL_OAUTH
  ENABLED = TRUE
  EXTERNAL_OAUTH_TYPE = AZURE
  EXTERNAL_OAUTH_ISSUER = 'https://sts.windows.net/<TENANT_ID>/'
  EXTERNAL_OAUTH_JWS_KEYS_URL = 'https://login.microsoftonline.com/<TENANT_ID>/discovery/v2.0/keys'
  EXTERNAL_OAUTH_AUDIENCE_LIST = ('api://<SNOWFLAKE_APPLICATION_ID_URI>')
  EXTERNAL_OAUTH_TOKEN_USER_MAPPING_CLAIM = 'sub'
  EXTERNAL_OAUTH_SNOWFLAKE_USER_MAPPING_ATTRIBUTE = 'LOGIN_NAME'
  EXTERNAL_OAUTH_ANY_ROLE_MODE = 'ENABLE';
```

---

## Step 5: Add Snowflake as Knowledge Source in Copilot Studio

1. Open **Copilot Studio** → Create or edit your agent
2. Navigate to **Knowledge** tab → **Add knowledge source** → Select **Snowflake**
3. Supply connection details:
   - **Tenant ID:** `<TENANT_ID>`
   - **Client ID:** `<OAUTH_CLIENT_ID>`
   - **Client Secret:** `<OAUTH_CLIENT_SECRET>`
   - **Resource URL:** `api://<SNOWFLAKE_APPLICATION_ID_URI>`
   - **Snowflake URL:** `https://<ORG-ACCOUNT>.snowflakecomputing.com`
   - **Database:** `<DATABASE_NAME>`
   - **Warehouse:** `<WAREHOUSE_NAME>`
   - **Schema:** `<SCHEMA_NAME>`
   - **Role:** `ANALYST`
4. Click **Save** → Select tables to expose as knowledge
5. Test with a natural language question in the agent's test panel

---

## Testing

Ask your agent questions that map to the tables you selected:

- *"How many orders were placed last month?"*
- *"What are the top 5 products by revenue?"*
- *"Show me customer count by region"*

Verify that:
- Responses contain actual data (not hallucinated)
- SQL generated targets correct tables and columns
- Results are consistent across paraphrased questions

---

## When to Graduate

Move to Pattern B or C when you observe:
- Inconsistent answers for rephrased questions (semantic model solves this)
- 422 errors from malformed SQL (Cortex Analyst eliminates these)
- Need for unstructured search (requires Cortex Search via Agent)
- Need for multi-step reasoning (requires Cortex Agent)
- Need to enforce business metric definitions across users

---

## Common Gotchas

| Issue | Cause | Fix |
|-------|-------|-----|
| Connection fails on first attempt | Warehouse is suspended | Resume warehouse before creating connection |
| "User not found" error | LOGIN_NAME doesn't match `sub` claim | Verify with `SELECT LOGIN_NAME FROM SNOWFLAKE.ACCOUNT_USAGE.USERS` |
| Empty results | Role lacks SELECT on target tables | `GRANT SELECT ON ALL TABLES IN SCHEMA ... TO ROLE ANALYST` |
| Wrong data returned | Copilot hallucinated column names | Rename columns to be business-friendly, or graduate to Pattern B |
| DLP policy blocks connector | Power Platform admin center policy | Ask admin to allow Snowflake connector in your environment |
| Token validation fails | Issuer URL mismatch (trailing slash) | Ensure exact match: `https://sts.windows.net/<TENANT_ID>/` (with trailing slash) |

---

## References

- [Add Snowflake as a Knowledge Source (MS Learn)](https://learn.microsoft.com/en-us/power-platform/release-plan/2025wave1/microsoft-copilot-studio/add-snowflake-as-knowledge-source)
- [Connecting Snowflake to Copilot Studio (Microsoft CAT Blog)](https://microsoft.github.io/mcscatblog/posts/connecting-snfl-to-mcs/)
- [Snowflake Connector for Power Platform](https://docs.snowflake.com/en/connectors/microsoft/powerapps/about)
- [Configure Entra ID for External OAuth](https://docs.snowflake.com/en/user-guide/oauth-azure)
