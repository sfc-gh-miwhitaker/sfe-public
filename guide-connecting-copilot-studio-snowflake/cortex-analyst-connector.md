# Pattern B: Cortex Analyst via Power Automate Agent Flow

Delegate SQL generation to Snowflake's Cortex Analyst — grounded in a semantic model that enforces business metric definitions. Copilot Studio calls a Power Automate Agent Flow, which invokes a Snowflake stored procedure wrapping Cortex Analyst.

> **See also:** [Pattern C: MCP Server](mcp-server.md) for full multi-tool delegation, or [Pattern A: Knowledge Source](knowledge-source.md) for the no-code quick start.

---

## When to Use This Pattern

- Need consistent, repeatable SQL from natural language (semantic model grounding)
- Single analytical domain with well-defined metrics and dimensions
- Don't yet need multi-tool orchestration (Cortex Search, custom tools)
- Want to eliminate schema hallucination (93% reduction in 422 errors vs Pattern A)
- MCP connector isn't available or approved in your environment

**Limitations:**
- Single-shot only — no multi-step reasoning or follow-up questions
- No unstructured search (requires Pattern C with Cortex Search)
- Requires building and maintaining a semantic model (real investment)
- Copilot still owns response synthesis and formatting

---

## Prerequisites

- Completed [Entra ID OAuth setup from Pattern A](knowledge-source.md#step-1-register-snowflake-oauth-resource-in-entra-id) (Steps 1-4)
- Semantic View or staged semantic model YAML in Snowflake
- Power Automate license (included with Copilot Studio)

---

## Step 1: Create a Semantic View (or Stage a Semantic Model)

The semantic model defines your business metrics, dimensions, and join paths. Cortex Analyst generates SQL grounded in this model — not the raw schema.

```sql
USE ROLE SYSADMIN;

CREATE OR REPLACE SEMANTIC VIEW <DATABASE>.<SCHEMA>.MY_SEMANTIC_VIEW
  COMMENT = 'Sales analytics semantic model for Copilot Studio'
  AS SELECT * FROM <DATABASE>.<SCHEMA>.SALES_DATA
  WITH SEMANTICS (
    -- Define metrics, dimensions, time grains, etc.
    -- See: https://docs.snowflake.com/en/user-guide/semantic-views
  );
```

> **Alternative:** If using a YAML semantic model on a stage, reference it in the stored procedure as `@<STAGE>/model.yaml`.

---

## Step 2: Create a Stored Procedure Wrapping Cortex Analyst

This procedure accepts a natural language prompt and returns the Cortex Analyst response:

```sql
USE ROLE SYSADMIN;

CREATE OR REPLACE PROCEDURE <DATABASE>.<SCHEMA>.CALL_CORTEX_ANALYST(prompt STRING)
  RETURNS VARIANT
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  PACKAGES = ('snowflake-snowpark-python', 'requests')
  HANDLER = 'run'
  EXECUTE AS CALLER
  EXTERNAL_ACCESS_INTEGRATIONS = (<CORTEX_ANALYST_EAI>)
AS
$$
import _snowflake
import requests, json

def run(session, prompt: str):
    token = _snowflake.get_generic_secret_string('SNOWFLAKE_OAUTH_TOKEN')
    account_url = session.sql("SELECT CURRENT_ACCOUNT_URL()").collect()[0][0]
    payload = {
        "messages": [{"role": "user", "content": [{"type": "text", "text": prompt}]}],
        "semantic_model_file": "@<DATABASE>.<SCHEMA>.<STAGE>/model.yaml"
        # OR use: "semantic_model": "<DATABASE>.<SCHEMA>.MY_SEMANTIC_VIEW"
    }
    resp = requests.post(
        f"{account_url}/api/v2/cortex/analyst/message",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json=payload, timeout=60
    )
    return resp.json()
$$;

GRANT USAGE ON PROCEDURE <DATABASE>.<SCHEMA>.CALL_CORTEX_ANALYST(STRING) TO ROLE ANALYST;
```

> **Important:** Cortex Analyst is a REST API (`POST /api/v2/cortex/analyst/message`) — there is no native SQL scalar function. The stored procedure above uses a Python handler with an External Access Integration (EAI) to make the HTTP call. You must create the EAI and grant `USAGE` on it to SYSADMIN before creating the procedure. Alternatively, call the Cortex Analyst REST API directly from Power Automate using the built-in HTTP action (bypassing the stored procedure layer entirely), which simplifies the architecture.

---

## Step 3: Configure Power Automate Agent Flow

Two approaches — choose based on what's simpler to maintain in your environment:

**Option A: Call the stored procedure from Snowflake connector (original path)**

1. Open **Copilot Studio** → Your agent → **Tools** → **Add a tool**
2. Select **Create a new flow** (opens Power Automate)
3. Choose the **Agent Flow** template (receives text input, returns text output)
4. Add a **Snowflake** action → **Execute query**
   - Connection: Use the same Entra ID External OAuth connection from Pattern A
   - SQL: `CALL <DATABASE>.<SCHEMA>.CALL_CORTEX_ANALYST('<PROMPT>')`
   - Replace `<PROMPT>` with the dynamic content from the flow's input
5. Add a **Respond to agent** action with the query result
6. Save and test the flow

**Option B: Call Cortex Analyst REST API directly from Power Automate (recommended)**

1. Use the Power Automate **HTTP** action instead of the Snowflake connector
2. Configure the HTTP action:
   - **Method:** POST
   - **URL:** `https://<ORG-ACCOUNT>.snowflakecomputing.com/api/v2/cortex/analyst/message`
   - **Headers:** `Authorization: Bearer <TOKEN>`, `Content-Type: application/json`
   - **Body:** JSON payload with `messages` array and `semantic_model` pointing to your semantic view
3. For authentication, use the same Entra ID OAuth flow from Pattern A to obtain a bearer token

> **Option B advantage:** Avoids the EAI/stored procedure complexity. The REST API is the native Cortex Analyst interface.

**Flow structure (Option A):**

```
Trigger: When agent calls this flow
  ↓
Input: user_prompt (text)
  ↓
Action: Snowflake → Execute query
  SQL: CALL MY_DB.MY_SCHEMA.CALL_CORTEX_ANALYST(:user_prompt)
  ↓
Action: Respond to agent
  Output: query result (text)
```

---

## Step 4: Wire the Agent Flow as a Tool

1. Back in **Copilot Studio** → **Tools** → your new flow appears as a tool
2. Configure the tool:
   - **Name:** `Snowflake Analytics`
   - **Description:** `Use this tool to answer questions about sales data, revenue, metrics, and business performance. Delegates SQL generation to Snowflake's Cortex Analyst which uses a semantic model for accuracy.`
3. Under **Inputs**, map the user's message to the `user_prompt` parameter
4. Save

> **Tip:** The tool description is critical — Copilot uses it for tool selection. Be specific about what domain this tool covers.

---

## Step 5: Configure Orchestration (Optional)

You can control how Copilot delegates to the tool:

- **Orchestrator mode (default):** Copilot decides when to call the tool based on its description
- **Topic-based:** Create an explicit Topic that always routes certain intents to this tool

For deterministic routing:

1. Create a new **Topic** → Add trigger phrases:
   - "What were our sales..."
   - "How much revenue..."
   - "Show me metrics for..."
2. Add a **Call an action** node → Select your Agent Flow
3. Add a **Message** node to display the result

---

## Testing

Compare grounded (Pattern B) vs ungrounded (Pattern A) responses:

| Question | Pattern A (direct SQL) | Pattern B (Cortex Analyst) |
|----------|----------------------|---------------------------|
| "What's our MRR this quarter?" | May hallucinate column names, inconsistent definition | Uses semantic model's MRR definition consistently |
| "Revenue by region last month" | Might join wrong tables | Follows defined join paths in semantic model |
| "Top 5 customers" | Could pick wrong customer identifier | Uses canonical customer dimension |

Verify:
- Consistent answers across paraphrased questions
- No 422 errors (Analyst generates valid SQL from the semantic model)
- Business metric definitions are enforced (not re-invented per query)

---

## Governance

| Layer | How It Works |
|-------|-------------|
| **Snowflake RBAC** | Stored procedure runs as caller — limited to ANALYST role grants |
| **Semantic Model** | Defines what metrics exist and how tables join — Analyst can't query outside it |
| **Agent Flow** | Power Automate audit logs capture every invocation |
| **Tool Description** | Controls when Copilot delegates vs answers from its own knowledge |

---

## When to Graduate to Pattern C

Move to MCP Server + Cortex Agent when:
- Need multi-step reasoning (Analyst is single-shot)
- Need unstructured search (Cortex Search)
- Need multiple tools orchestrated in one conversation turn
- Want the Cortex Agent to decide which tool to use (not Copilot)
- Need the same agent accessible from Teams, web apps, and Snowflake Intelligence

> **Key insight:** Patterns B and C share the same semantic model. Building it for Pattern B means Pattern C is mostly orchestration plumbing — not a rewrite.

---

## Common Gotchas

| Issue | Cause | Fix |
|-------|-------|-----|
| "Procedure not found" | Wrong schema or missing USAGE grant | `GRANT USAGE ON PROCEDURE ... TO ROLE ANALYST` |
| Empty or null response | Semantic model doesn't cover the question domain | Expand semantic model definitions |
| Flow timeout | Complex query exceeds Power Automate timeout | Increase timeout in flow settings, or simplify the semantic model |
| Copilot doesn't call the tool | Tool description doesn't match user intent | Rewrite description to be more specific about covered domains |
| Inconsistent formatting | Cortex Analyst returns raw JSON | Add a parsing step in the flow to extract the answer text |
| Cortex credits unexpected | Each call consumes Cortex AI credits | Monitor via `SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY` |

---

## References

- [Cortex Analyst Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [Semantic Views](https://docs.snowflake.com/en/user-guide/semantic-views)
- [Power Automate Agent Flows](https://learn.microsoft.com/en-us/microsoft-copilot-studio/advanced-use-flow)
- [Snowflake Connector for Power Platform](https://docs.snowflake.com/en/connectors/microsoft/powerapps/about)
- [Copilot Studio: Agent Architecture Comparison (Jeff Baart)](https://blog.mwccomms.com/2026/04/connecting-copilot-studio-to-snowflake.html)
