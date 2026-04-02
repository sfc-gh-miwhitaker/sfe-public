# Part 4: Per-project AGENTS.md Connection Lock

**Time:** ~10 minutes
**Goal:** Add a connection hint to each project's `AGENTS.md` so CoCo always knows which account it's working against — and can warn you if something looks wrong.

---

## Why Add a Connection Hint?

AGENTS.md is read by CoCo at the start of every session. Adding the target connection there:

1. Tells CoCo which account to expect — it can catch accidental cross-account operations
2. Documents the intended connection for anyone else who picks up the project
3. Gives CoCo context to write correct SQL (right warehouse, role, database)

---

## Step 4.1 — The Minimal Addition

In any project's `AGENTS.md`, add a **Snowflake Connection** section:

```markdown
## Snowflake Connection

- **Connection name:** `acme-prod`
- **Account:** `acme-us-west-2`
- **Default role:** `PARTNER_SE_ROLE`
- **Default warehouse:** `PARTNER_WH`
- **Default database:** `ANALYTICS`

Launch with: `cortex -c acme-prod --workdir ~/projects/acme`
```

This is documentation for both CoCo and human readers. CoCo will use this context when writing SQL, suggesting roles, and referencing objects.

---

## Step 4.2 — Full AGENTS.md Template for a Customer Project

```markdown
# Acme Corp — Data Engineering POC

One-sentence description of what this project does.

## Snowflake Connection

- **Connection name:** `acme-prod`
- **Account:** `acme-us-west-2`
- **Default role:** `PARTNER_SE_ROLE`
- **Default warehouse:** `PARTNER_WH`
- **Default database:** `ANALYTICS`

Launch with: `cortex -c acme-prod --workdir ~/projects/acme`

> Always verify connection before running DDL: `SELECT CURRENT_ACCOUNT(), CURRENT_USER();`

## Project Structure

- `sql/` — DDL and queries for this engagement
- `notebooks/` — Exploratory analysis
- `docs/` — Architecture diagrams and notes

## Conventions

- Never run DDL in `ANALYTICS` without a transaction + confirmation query
- All objects created under schema `PARTNER_SE_<YOUR_INITIALS>`
- Teardown script: `sql/teardown.sql`

## Key Commands

```bash
cortex -c acme-prod -p "SELECT CURRENT_ACCOUNT(), CURRENT_ROLE();"   # verify connection
cortex -c acme-prod --workdir ~/projects/acme                         # start session
```
```

---

## Step 4.3 — Add a Safety Check Instruction

You can tell CoCo to verify the connection before any destructive operation:

```markdown
## Safety Rules

Before running any CREATE, DROP, INSERT, UPDATE, or DELETE statement,
verify the active account with: `SELECT CURRENT_ACCOUNT();`
If the result does not match `acme-us-west-2`, stop and alert the user.
```

This makes CoCo an active safeguard against cross-account accidents.

---

## Step 4.4 — Apply to All Your Active Projects

For each customer project directory:

1. Open or create `AGENTS.md` at the project root
2. Add the **Snowflake Connection** section
3. Add the `Launch with:` command line

Quick scaffold via CoCo:

```
Tell CoCo: "Add a Snowflake Connection section to this AGENTS.md.
Connection name: acme-prod, account: acme-us-west-2,
role: PARTNER_SE_ROLE, warehouse: PARTNER_WH, database: ANALYTICS"
```

---

## Checkpoint

- [ ] At least one customer project has a Snowflake Connection section in its `AGENTS.md`
- [ ] The `Launch with:` line in AGENTS.md matches a real connection in `connections.toml`
- [ ] Optional: safety check instruction added for DDL operations

**Next:** [Part 5 — Environment Isolation](05_isolation.md)
