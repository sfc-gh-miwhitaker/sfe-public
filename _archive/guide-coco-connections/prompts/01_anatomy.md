# Part 1: Anatomy of a Connection

**Time:** ~5 minutes
**Goal:** Understand what `config.toml` is, where it lives, and how Cortex Code reads it.

---

## Step 1.1 — Find Your config.toml

Snowflake CLI (which Cortex Code uses under the hood) reads connections from:

```
~/.snowflake/config.toml
```

Check if it exists and what's already in it:

```bash
ls -la ~/.snowflake/config.toml
cat ~/.snowflake/config.toml
```

If the file doesn't exist:

```bash
mkdir -p ~/.snowflake
touch ~/.snowflake/config.toml
```

---

## Step 1.2 — Understand the Structure

A `config.toml` file is a TOML document. Each `[connections.<name>]` block is one connection, and `default_connection_name` at the top sets the fallback:

```toml
default_connection_name = "internal"

[connections.internal]
account = "myorg-myaccount"
user = "jane.smith@company.com"
authenticator = "externalbrowser"

[connections.acme-prod]
account = "acme-us-west-2"
user = "jane.smith@acme-partner.com"
authenticator = "externalbrowser"
warehouse = "PARTNER_WH"
role = "PARTNER_SE_ROLE"
database = "ANALYTICS"
```

Every field is optional except `account` and `user`. The key after `connections.` (e.g., `acme-prod`) is the connection name you'll pass to CoCo.

---

## Step 1.3 — See What CoCo Sees

List your connections the way Cortex Code does:

```bash
cortex connections list
```

The output shows every named connection and which one is currently active. The connection named in `default_connection_name` is used when you run `cortex` with no `-c` flag.

---

## Step 1.4 — Key Fields for Partner SEs

| Field | What It Controls | Partner SE Use |
|-------|-----------------|----------------|
| `account` | Which Snowflake account | One per customer |
| `user` | Login identity | May differ per account |
| `authenticator` | How you prove identity | `externalbrowser` for SSO, `PROGRAMMATIC_ACCESS_TOKEN` for PATs |
| `role` | Default role on connect | Set to your partner SE role |
| `warehouse` | Default compute | Avoid accidental use of customer's expensive WH |
| `database` / `schema` | Default context | Saves typing on every session |

---

## Checkpoint

Before moving to Part 2, you should be able to answer:

- [ ] Where does `config.toml` live?
- [ ] How do you list connections from the terminal?
- [ ] What does `default_connection_name` control?

**Next:** [Part 2 — Multi-customer Setup](02_connections_setup.md)
