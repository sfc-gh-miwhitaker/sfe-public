# Claude Code CLI Redirect to Snowflake Cortex

Step-by-step setup to redirect all `claude` CLI inference to your Snowflake account.

> **Auth gotcha first:** The Anthropic SDK (which Claude Code uses internally) sends credentials as `x-api-key` by default. Snowflake requires `Authorization: Bearer`. These are different headers. Using `ANTHROPIC_API_KEY` will fail silently or with a 403. Use `ANTHROPIC_AUTH_TOKEN` instead — it's the variable that sends as `Authorization: Bearer`.

---

## Step 1: Get a credential

The simplest option is a Snowflake Programmatic Access Token (PAT). For more secure alternatives — OS credential store, key-pair JWT via `apiKeyHelper`, CI/CD, or Claude Desktop OAuth — see **[Authentication Options](authentication.md)**.

**Quick start: create a PAT**

1. Sign into Snowflake, click your username (top right) → **My Profile**
2. Scroll to **Programmatic access tokens** → **Generate new token**
3. Set a name, restrict it to a role (recommended), set a short expiry (90 days), click **Generate**
4. Copy the token — it is shown only once

> If you plan to use `apiKeyHelper` (so the token never sits in a config file), follow [Option 2 in the auth guide](authentication.md#option-2-apikeyhelper--os-credential-store) instead of Step 2 below.

---

## Step 2: Set the environment variables

These two variables are all Claude Code needs:

```bash
# Points Claude Code at Snowflake's Cortex Messages API
export ANTHROPIC_BASE_URL="https://<account-identifier>.snowflakecomputing.com/api/v2/cortex"

# Sends your Snowflake PAT as Authorization: Bearer (NOT x-api-key)
export ANTHROPIC_AUTH_TOKEN="<your-snowflake-pat>"
```

Replace `<account-identifier>` with your Snowflake account identifier (the prefix of your `.snowflakecomputing.com` URL).

**Optionally pin the model:**

```bash
# Use a specific Cortex model (otherwise Claude Code uses its default)
export ANTHROPIC_MODEL="claude-sonnet-4-6"
```

> If you leave `ANTHROPIC_API_KEY` set in your environment, Claude Code may still try to use it. Either unset it or leave it set — the `ANTHROPIC_AUTH_TOKEN` takes precedence for the Bearer token, but having both in your environment is messy. Cleanest: unset `ANTHROPIC_API_KEY` when using the redirect.

---

## Step 3: Run Claude Code

```bash
claude "summarize the architecture of this codebase"
```

If the redirect is working, the request goes to Snowflake, not Anthropic. Confirm this with [Verification](#verification) below.

---

## Persist the redirect (per-user)

To make the redirect permanent for your shell session:

**zsh (macOS default):**

```bash
# Add to ~/.zshrc
export ANTHROPIC_BASE_URL="https://<account-identifier>.snowflakecomputing.com/api/v2/cortex"
export ANTHROPIC_AUTH_TOKEN="<your-snowflake-pat>"
# Optional: pin to a specific Cortex model (Claude Code's default passes through otherwise)
# export ANTHROPIC_MODEL="claude-sonnet-4-6"
```

Then `source ~/.zshrc` or open a new terminal.

**bash (Linux):**

```bash
# Add to ~/.bashrc or ~/.bash_profile
export ANTHROPIC_BASE_URL="https://<account-identifier>.snowflakecomputing.com/api/v2/cortex"
export ANTHROPIC_AUTH_TOKEN="<your-snowflake-pat>"
# export ANTHROPIC_MODEL="claude-sonnet-4-6"
```

**Windows — PowerShell:**

Set for the current session:

```powershell
$env:ANTHROPIC_BASE_URL  = "https://<account-identifier>.snowflakecomputing.com/api/v2/cortex"
$env:ANTHROPIC_AUTH_TOKEN = "<your-snowflake-pat>"
```

To persist across sessions, add the same lines to your PowerShell profile (`$PROFILE` — typically `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`). Create the file if it doesn't exist:

```powershell
New-Item -Path $PROFILE -ItemType File -Force  # skip if profile already exists
notepad $PROFILE                                # add the $env: lines above, save
```

To set machine-wide persistent env vars instead (requires admin):

```powershell
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL",  "https://<account-identifier>.snowflakecomputing.com/api/v2/cortex", "User")
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", "<your-snowflake-pat>", "User")
```

Or use the GUI: **System Properties → Advanced → Environment Variables → User variables**.

**Windows — WSL (Windows Subsystem for Linux):**

If you run Claude Code inside WSL, use the bash/zsh instructions above within your WSL shell. Note that env vars set in Windows (PowerShell / System Properties) are NOT automatically available inside WSL — set them in your WSL shell profile (`~/.bashrc` or `~/.zshrc`).

---

## Persist via Claude Code settings

Claude Code also accepts env vars in its `settings.json`. This scopes the redirect to Claude Code only (not your whole shell):

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://<account-identifier>.snowflakecomputing.com/api/v2/cortex",
    "ANTHROPIC_AUTH_TOKEN": "<your-snowflake-pat>"
  }
}
```

To pin a specific Cortex model, add `"ANTHROPIC_MODEL": "claude-sonnet-4-6"` to the `env` block.

Location of `settings.json`:
- macOS / Linux: `~/.claude/settings.json`
- Windows: `%APPDATA%\Claude\settings.json`

> **Security note:** Storing the PAT in `settings.json` puts it in a plain-text file. Use this only on a personal machine. For shared or CI environments, inject the token via environment variables at the system level.

---

## Org-wide enforcement

For IT admins deploying Claude Code across a team or organization:

**Approach 1 — Shell profile injection (individual workstations)**

Push a snippet to each user's shell profile via MDM/config management (Ansible, Puppet, etc.):

```bash
# /etc/profile.d/snowflake-cortex-redirect.sh  (Linux/macOS)
export ANTHROPIC_BASE_URL="https://<account-identifier>.snowflakecomputing.com/api/v2/cortex"
export ANTHROPIC_AUTH_TOKEN="<shared-service-account-pat>"
# Pin the model org-wide to control cost and ensure a Cortex-compatible model is used
export ANTHROPIC_MODEL="claude-sonnet-4-6"
```

> Shared service account PATs limit per-user attribution in `CORTEX_REST_API_USAGE_HISTORY`. If per-user audit is important, issue individual PATs or use OAuth.

**Approach 2 — Claude Code enterprise managed settings**

Claude Code supports a managed settings file that takes precedence over user settings:

- macOS / Linux: `/Library/Application Support/ClaudeCode/managed-settings.json` (macOS) or `/etc/claude/managed-settings.json` (Linux)

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://<account-identifier>.snowflakecomputing.com/api/v2/cortex",
    "ANTHROPIC_MODEL": "claude-sonnet-4-6"
  }
}
```

> Setting `ANTHROPIC_MODEL` in managed settings is a deliberate org-wide policy choice — it ensures all users run the same model regardless of what Claude Code would otherwise select, which matters for cost governance and ensuring only Cortex-available models are used.

> **Do not put the PAT in managed-settings.json** — it would be readable by all local users. Instead, deploy the PAT via a secrets manager or OS credential store, and reference it via an environment variable that your deployment tooling injects at login.

**Approach 3 — Docker / devcontainer**

Add to your `devcontainer.json` or `Dockerfile`:

```json
// devcontainer.json
{
  "containerEnv": {
    "ANTHROPIC_BASE_URL": "https://<account-identifier>.snowflakecomputing.com/api/v2/cortex",
    "ANTHROPIC_AUTH_TOKEN": "${localEnv:SNOWFLAKE_PAT}"
  }
}
```

The `${localEnv:SNOWFLAKE_PAT}` syntax passes the PAT from the developer's local machine into the container without hardcoding it.

---

## Verification

After configuring the redirect, confirm it's working:

**Test 1 — Quick CLI check:**

```bash
claude "Say 'redirect confirmed' and nothing else"
```

If it returns a response, the redirect is alive. If you get a 403 or connection error, check the troubleshooting section below.

**Test 2 — Check Snowflake query history:**

Run this in Snowflake (requires `IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE`):

```sql
SELECT
    start_time,
    model_name,
    tokens_granular:"input"::INT AS input_tokens,
    tokens_granular:"output"::INT AS output_tokens,
    inference_region
FROM snowflake.account_usage.cortex_rest_api_usage_history
WHERE start_time >= DATEADD('minute', -10, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 10;
```

If your Claude Code inference arrived at Snowflake, you'll see rows here (note: up to 45 minutes of latency in the view).

---

## Available models

Use bare model names — no date suffixes. Claude models available via the Cortex REST API (from the [Snowflake Service Consumption Table](https://www.snowflake.com/legal-files/CreditConsumptionTable.pdf), effective July 1, 2026):

| Model | Status | Input (credits/M tokens) | Output (credits/M tokens) | Notes |
|-------|--------|--------------------------|---------------------------|-------|
| `claude-sonnet-4-6` | GA | 1.50 | 7.50 | Best default for Claude Code |
| `claude-opus-4-6` | GA | 2.50 | 12.50 | High capability, lower throughput |
| `claude-sonnet-4-5` | GA | 1.50 | 7.50 | Previous generation sonnet |
| `claude-haiku-4-5` | GA | 0.50 | 2.50 | Fastest and cheapest |
| `claude-opus-4-5` | GA | 2.50 | 12.50 | Previous generation opus |
| `claude-4-sonnet` | Legacy | 1.50 | 7.50 | Legacy alias, still available |
| `claude-opus-4-7` | Preview | 2.50 | 12.50 | Higher capability; preview caveat |
| `claude-opus-4-8` | Preview | 2.50 | 12.50 | Latest opus; preview caveat |
| `claude-sonnet-5` | Preview | 1.00 | 5.00 | Promotional pricing through Sep 2026 |
| `claude-fable-5` | Preview | 5.00 | 25.00 | Preview; use with caution in production |

> Preview features (footnote 5 in the pricing table) are not suitable for production workloads per Snowflake's Preview Terms. Use GA models for any customer-facing or business-critical workloads.

> If `ANTHROPIC_MODEL` is not set, Claude Code picks its own default model and passes that name through to Cortex. This works as long as Claude Code's default is a model Cortex supports. Set `ANTHROPIC_MODEL` when you want to pin a specific model — for cost control, to use a preview model, or to ensure a Cortex-compatible model is always used regardless of Claude Code version.

> **Region note:** Not all models are available in all Snowflake regions. If you hit a 400 "unknown model" error, check [model availability by region](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-rest-api#model-availability). Enable cross-region inference (AWS_GLOBAL or AZURE_GLOBAL) to access all models from any region.

---

## Governance

When inference goes through Snowflake, you get:

**RBAC access control:** Snowflake's `SNOWFLAKE.CORTEX_USER` database role controls who can call the API. To restrict access to specific users:

```sql
-- Revoke the default (PUBLIC has it by default)
REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE PUBLIC;

-- Grant only to approved roles
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_REST_API_USER TO ROLE claude_code_users;
GRANT ROLE claude_code_users TO USER alice;
```

`CORTEX_REST_API_USER` grants access to the REST API only, without enabling Cortex AI functions (CORTEX.COMPLETE, AI_EXTRACT, etc.).

**Cost visibility:** REST API costs are billed as AI Credits (dollars per million tokens) — not warehouse credits. No warehouse resource monitor applies. To see what the redirect is costing you today:

```sql
SELECT
    model_name,
    COUNT(*) AS requests,
    SUM(tokens_granular:"input"::INT)      AS input_tokens,
    SUM(tokens_granular:"output"::INT)     AS output_tokens,
    SUM(tokens_granular:"cache_read_input"::INT) AS cached_tokens
FROM snowflake.account_usage.cortex_rest_api_usage_history
WHERE start_time >= CURRENT_DATE()
GROUP BY model_name
ORDER BY input_tokens DESC;
```

Cached tokens are billed at 10% of the input rate (when ≥1024 per request). Claude Code's agentic loop produces high cache hit rates, so most token volume is in `cache_read_input` — the cheapest category.

**Enforcement options:** No native hard cap exists for raw REST API calls. Your options:

- **Resource Budgets** — GA for Cortex Agents (tag-based, auto-revoke at threshold). Does not directly scope to raw REST API calls. See [Resource budgets for Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-resource-budgets).
- **Snowflake ALERT + revoke** — query `CORTEX_REST_API_USAGE_HISTORY` on a schedule; when daily spend exceeds a threshold, revoke `CORTEX_REST_API_USER` from the user's role. The per-user enforcement pattern is documented in [Managing Cortex AI Function costs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-func-cost-management).
- **Account-level Budget** — covers all Snowflake spend including AI Credits, but not scoped to REST API specifically. See [Custom budgets](https://docs.snowflake.com/en/user-guide/cost-management/budgets/budgets-custom).

**For ongoing dashboarding and cost estimation**, Snowflake publishes three quickstart guides with complete Streamlit code:

- [Cortex REST API Usage Monitor](https://www.snowflake.com/en/developers/guides/cortex-rest-api-usage/) — token volume tracking
- [Cortex REST API Budget Monitors](https://www.snowflake.com/en/developers/guides/cortex-rest-api-budget-monitors/) — daily/weekly budget enforcement with rolling alerts
- [Cortex REST API Billing & Cost Analysis](https://www.snowflake.com/en/developers/guides/cortex-rest-api-billing-cost/) — USD cost estimation using `TOKENS_GRANULAR`, prompt-caching discount logic, and per-model pricing

**Data residency:** Requests to `/api/v2/cortex/v1/messages` are processed inside your Snowflake account's region. Your prompts and responses do not leave Snowflake's perimeter (subject to cross-region inference settings — see [model availability](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-rest-api#model-availability)).

---

## Troubleshooting

**403 Not Authorized:**
- Check that the PAT is set in `ANTHROPIC_AUTH_TOKEN`, not `ANTHROPIC_API_KEY`
- Verify your Snowflake user's default role has `SNOWFLAKE.CORTEX_USER` or `SNOWFLAKE.CORTEX_REST_API_USER`
- Check that the PAT hasn't expired

**400 unknown model:**
- You're using a model not available in your region. Check the [availability table](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-rest-api#model-availability)
- Enable cross-region inference or switch to a model natively available in your region

**Connection refused / DNS error:**
- Verify `ANTHROPIC_BASE_URL` has the correct account identifier
- Check that your machine can reach `<account-identifier>.snowflakecomputing.com` (proxy or firewall blocking?)

**Claude Code ignores ANTHROPIC_BASE_URL:**
- Ensure you're running the `claude` CLI, not the VS Code extension (the extension does not yet support `ANTHROPIC_BASE_URL`)
- Confirm the env var is exported, not just assigned: `export ANTHROPIC_BASE_URL="..."` not `ANTHROPIC_BASE_URL="..."`
- Check for a managed settings file overriding your env var

**Responses are slow:**
- Cross-region inference adds latency (the request routes to a region where the model is available)
- Switch to a model natively in your region, or accept the latency tradeoff for model access
