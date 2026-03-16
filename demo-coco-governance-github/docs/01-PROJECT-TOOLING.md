# Act 1: Project Tooling -- Same Files, Both Surfaces

The core idea: an `AGENTS.md` file and a custom skill live in a GitHub repo. Clone the repo for CLI. Connect a workspace for Snowsight. Cortex Code reads the same project tooling on both surfaces automatically.

No custom agents. No SQL functions. The files ARE the tooling.

## What's in this repo

| File | Purpose | Loaded by |
|------|---------|-----------|
| `AGENTS.md` | Project standards (SQL quality, naming, security) | Cortex Code automatically -- every conversation |
| `.claude/skills/.../SKILL.md` | SQL review procedure (on-demand) | Cortex Code when you ask for a review |

These two files embody the **always-on vs on-demand** split:

- **Always-on:** `AGENTS.md` is read at the start of every conversation. Standards apply without you asking.
- **On-demand:** The skill is invoked when you explicitly request a SQL review or Cortex Code recognizes the trigger.

## Path A: Cortex Code CLI

### Setup

```bash
git clone https://github.com/sfc-gh-miwhitaker/sfe-public.git
cd sfe-public/demo-coco-governance-github
cortex
```

That's it. Cortex Code CLI reads `AGENTS.md` from the working directory and loads skills from `.claude/skills/`.

### Verify

```text
/skill list
```

You should see `demo-coco-governance-github` in the output.

### Test the standards

Ask Cortex Code to write a query:

```text
Write a query that finds the top 5 customers by total order amount
```

Because `AGENTS.md` is active, Cortex Code should:
- List columns explicitly (no `SELECT *`)
- Use `QUALIFY` instead of a subquery for ranking
- Reference the `CUSTOMERS` and `ORDERS` tables in `SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB`

### Test the review skill

Write a deliberately flawed query and ask for a review:

```text
Review this SQL:

SELECT *
FROM ORDERS o
JOIN CUSTOMERS c ON o.CUSTOMER_ID = c.CUSTOMER_ID::VARCHAR
WHERE YEAR(o.ORDER_DATE) = 2025
```

The skill should flag:
1. `SELECT *` -- list columns explicitly
2. `YEAR(o.ORDER_DATE)` -- non-sargable predicate, use a date range instead
3. `c.CUSTOMER_ID::VARCHAR` -- join type mismatch, both sides should be NUMBER

## Path B: Cortex Code in Snowsight

### Step 1: Deploy sample data

Open `deploy_all.sql` in a Snowsight worksheet and click **Run All**. This creates:
- Schema `SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB`
- Three sample tables: `CUSTOMERS`, `ORDERS`, `PRODUCTS`
- A Git repository stage (so the repo is accessible from Snowflake)

### Step 2: Create a Git workspace

1. In Snowsight, go to **Projects > Workspaces**
2. Select **Create > From Git repository**
3. Paste the repo URL: `https://github.com/sfc-gh-miwhitaker/sfe-public`
4. Select your API integration (or use public repository access)
5. Name the workspace (e.g., `sfe-public`)

The workspace now contains all the files from the repo, including `AGENTS.md` at the root of `demo-coco-governance-github/`.

### Step 3: Use Cortex Code with standards

Open the Cortex Code panel (icon in the lower-right corner of the workspace). Because the workspace is connected to the Git repo that contains `AGENTS.md`, Cortex Code reads it automatically.

Try the same prompts from Path A:

```text
Write a query that finds the top 5 customers by total order amount
from SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB
```

You should see the same standards applied: explicit columns, `QUALIFY` for ranking, no `SELECT *`.

## Same files, same behavior

| Aspect | CLI | Snowsight |
|--------|-----|-----------|
| How AGENTS.md is loaded | From working directory (`cd` into repo) | From Git-connected workspace |
| How skills are loaded | From `.claude/skills/` in repo | Personal skills in workspace |
| How standards are applied | Every conversation, automatically | Every conversation, automatically |
| How you test | Ask CoCo to write/review SQL | Ask CoCo to write/review SQL |

The key insight: there is no separate "Snowsight version" of the standards. The same `AGENTS.md` file serves both surfaces. Update it once, and every team member who pulls (CLI) or syncs (Snowsight) gets the update.

## Next

Now that project tooling works on both surfaces, the question is: how does a team manage these standards together?

[Act 2: GitHub Team Management](02-GITHUB-TEAM-MANAGEMENT.md)
