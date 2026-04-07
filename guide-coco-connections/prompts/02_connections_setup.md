# Part 2: Setting Up Multiple Connections

**Time:** ~10 minutes
**Goal:** Add one named connection per customer/project to `config.toml`.

---

## Step 2.1 — Open Your config.toml

```bash
open ~/.snowflake/config.toml    # macOS: opens in default editor
# or
code ~/.snowflake/config.toml   # VS Code
# or
nano ~/.snowflake/config.toml   # Terminal editor
```

> **Security note:** `config.toml` contains account identifiers and usernames but NOT passwords or tokens (those use separate credential stores). It is still sensitive — do not commit it to git.
>
> **Two-file precedence:** Snowflake CLI also supports `~/.snowflake/connections.toml` (with `[name]` sections, no `connections.` prefix). If both files exist, `connections.toml` overrides `config.toml` for connection definitions. This guide uses `config.toml` exclusively -- if you've run the Cortex Code setup wizard and it created a `connections.toml`, either consolidate into one file or be aware of the override.

---

## Step 2.2 — Add a Connection Per Customer

Add one `[connections.<name>]` block per customer engagement. Use a consistent naming pattern:

```
[connections.<customer-alias>-<env>]
```

Examples: `[connections.acme-prod]`, `[connections.globex-dev]`, `[connections.internal-sfcogsops]`

**Template to copy and fill in:**

```toml
[connections.acme-prod]
account    = "acme-us-west-2"
user       = "your.email@acme.com"
authenticator = "externalbrowser"
warehouse  = "PARTNER_WH"
role       = "PARTNER_SE_ROLE"
database   = "ANALYTICS"
schema     = "PUBLIC"
```

**Repeat for each customer.** A fully populated file for a partner SE managing three accounts:

```toml
default_connection_name = "internal"

[connections.internal]
account       = "sfcogsops-snowhouse_aws_us_west_2"
user          = "jane.smith@snowflake.com"
authenticator = "externalbrowser"

[connections.acme-prod]
account       = "acme-us-west-2"
user          = "jane.smith@acme-partner.com"
authenticator = "externalbrowser"
warehouse     = "PARTNER_WH"
role          = "PARTNER_SE_ROLE"

[connections.globex-dev]
account       = "globex-us-east-1"
user          = "jane.smith@globex-partner.com"
authenticator = "externalbrowser"
role          = "DEVELOPER"

[connections.internal-sandbox]
account       = "myorg-sandbox"
user          = "jane.smith@snowflake.com"
authenticator = "externalbrowser"
warehouse     = "DEV_WH"
```

---

## Step 2.3 — Authentication Options

| Scenario | Recommended `authenticator` |
|----------|-----------------------------|
| Customer account with SSO | `externalbrowser` |
| Scripted / non-interactive | `PROGRAMMATIC_ACCESS_TOKEN` |
| Key-pair auth | `snowflake_jwt` + `private_key_path` |
| Username + password (legacy) | `snowflake` + `password` field |

**PAT example** (for accounts where SSO is inconvenient):

```toml
[connections.acme-scripted]
account       = "acme-us-west-2"
user          = "jane.smith@acme-partner.com"
authenticator = "PROGRAMMATIC_ACCESS_TOKEN"
token         = "<your-pat-here>"
```

> **Security:** Do not hardcode PATs in `connections.toml` for shared machines. Use `SNOWFLAKE_TOKEN` env var instead and leave `token` out of the file.

---

## Step 2.4 — Verify All Connections

After saving `config.toml`, verify Cortex Code can see all your connections:

```bash
cortex connections list
```

Test a specific connection (opens browser SSO, then prints account/user info):

```bash
cortex -c acme-prod -p "SELECT CURRENT_ACCOUNT(), CURRENT_USER(), CURRENT_ROLE();"
```

---

## Naming Convention Cheat Sheet

| Pattern | Example | When to Use |
|---------|---------|-------------|
| `[connections.customer-prod]` | `[connections.acme-prod]` | Active customer production account |
| `[connections.customer-dev]` | `[connections.acme-dev]` | Customer sandbox / dev account |
| `[connections.internal-xxx]` | `[connections.internal-sfcogsops]` | Your own Snowflake internal accounts |
| `[connections.poc-customer]` | `[connections.poc-globex]` | Short-term POC engagement |

> **Tip:** Keep the alias short and memorable — you'll type it on every `cortex -c` launch.

---

## Checkpoint

- [ ] Every active customer engagement has an entry in `config.toml`
- [ ] `cortex connections list` shows all of them
- [ ] At least one connection has been tested with `-p "SELECT CURRENT_ACCOUNT()..."`

**Next:** [Part 3 — Launch Patterns](03_cli_launch.md)
