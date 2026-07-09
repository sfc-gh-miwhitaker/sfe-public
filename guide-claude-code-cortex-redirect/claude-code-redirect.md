# Claude Code CLI Redirect to Snowflake Cortex

Step-by-step setup to redirect all `claude` CLI inference to your Snowflake account.

> **Auth gotcha first:** The Anthropic SDK (which Claude Code uses internally) sends credentials as `x-api-key` by default. Snowflake requires `Authorization: Bearer`. These are different headers. Using `ANTHROPIC_API_KEY` will fail silently or with a 403. Use `ANTHROPIC_AUTH_TOKEN` instead — it's the variable that sends as `Authorization: Bearer`.

---

## Step 1: Get a Snowflake PAT

A Programmatic Access Token (PAT) is the simplest auth method. To create one:

1. Sign into Snowflake, click your username (top right) → **My Profile**
2. Scroll to **Programmatic access tokens** → **Generate new token**
3. Set a name (e.g., `claude-code-redirect`), choose an expiration, click **Generate**
4. Copy the token — it is shown only once

The token looks like a long alphanumeric string. Keep it out of shell history and files.

> **OAuth alternative:** If your org already has an OAuth integration configured, you can use an OAuth access token in place of the PAT. The `Authorization: Bearer` header format is identical.

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
export ANTHROPIC_MODEL="claude-sonnet-4-6"
```

Then `source ~/.zshrc` or open a new terminal.

**Fish shell:**

```fish
# Add to ~/.config/fish/config.fish
set -x ANTHROPIC_BASE_URL "https://<account-identifier>.snowflakecomputing.com/api/v2/cortex"
set -x ANTHROPIC_AUTH_TOKEN "<your-snowflake-pat>"
set -x ANTHROPIC_MODEL "claude-sonnet-4-6"
```

---

## Persist via Claude Code settings

Claude Code also accepts env vars in its `settings.json`. This scopes the redirect to Claude Code only (not your whole shell):

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://<account-identifier>.snowflakecomputing.com/api/v2/cortex",
    "ANTHROPIC_AUTH_TOKEN": "<your-snowflake-pat>",
    "ANTHROPIC_MODEL": "claude-sonnet-4-6"
  }
}
```

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

> **Do not put the PAT in managed-settings.json** — it would be readable by all local users. Instead, deploy the PAT via a secrets manager or OS credential store, and reference it via an environment variable that your deployment tooling injects at login.

**Approach 3 — Docker / devcontainer**

Add to your `devcontainer.json` or `Dockerfile`:

```json
// devcontainer.json
{
  "containerEnv": {
    "ANTHROPIC_BASE_URL": "https://<account-identifier>.snowflakecomputing.com/api/v2/cortex",
    "ANTHROPIC_AUTH_TOKEN": "${localEnv:SNOWFLAKE_PAT}",
    "ANTHROPIC_MODEL": "claude-sonnet-4-6"
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

> Claude Code uses `claude-sonnet-4-6` (or similar) by default. Setting `ANTHROPIC_MODEL` overrides this.

> **Region note:** Not all models are available in all Snowflake regions. If you hit a 400 "unknown model" error, check [model availability by region](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-rest-api#model-availability). Enable cross-region inference (AWS_GLOBAL or AZURE_GLOBAL) to access all models from any region.

---

## Governance

When inference goes through Snowflake, you get:

**Audit trail:** Every request appears in `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_REST_API_USAGE_HISTORY` with model name, token counts, user ID, timestamp, and inference region. You can query, export, and alert on this data like any other Snowflake table.

**RBAC access control:** Snowflake's `SNOWFLAKE.CORTEX_USER` database role controls who can call the API. To restrict access to specific users:

```sql
-- Revoke the default (PUBLIC has it by default)
REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE PUBLIC;

-- Grant only to approved roles
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_REST_API_USER TO ROLE claude_code_users;
GRANT ROLE claude_code_users TO USER alice;
```

`CORTEX_REST_API_USER` grants access to the REST API only, without enabling Cortex AI functions (CORTEX.COMPLETE, AI_EXTRACT, etc.).

**Cost attribution:** Cortex inference costs appear on your Snowflake invoice alongside compute costs, making AI spend visible in the same budgeting process as warehouse spend. Use `CORTEX_REST_API_USAGE_HISTORY` to break down by user, model, or time window.

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
