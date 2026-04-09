# Dual-Surface Deployment: Same Standards on CLI and Snowsight

*How do I get the same coding standards enforced in Cortex Code on CLI and in Snowsight -- without maintaining two sets of configs?*

Store `AGENTS.md` and skills (`.cortex/skills/` or `.claude/skills/`) in a GitHub repo. Cortex Code reads them automatically on both surfaces. GitHub's collaboration features become the standards management layer.

> This content was previously in `demo-coco-governance-github`. The optional lab SQL is available at the bottom of this page.

---

## How It Works

| File | Purpose | Loaded by |
|------|---------|-----------|
| `AGENTS.md` | Project standards (SQL quality, naming, security) | Cortex Code automatically -- every conversation |
| `.claude/skills/.../SKILL.md` | Review procedure (on-demand) | Cortex Code when you ask for a review |

These files embody the **always-on vs on-demand** split documented in [Claude Code Memory](https://docs.anthropic.com/en/docs/claude-code/memory).

---

## Path A: Cortex Code CLI

Clone a repo containing `AGENTS.md`, then run `cortex` in the directory. Standards are active immediately.

```bash
cd your-project-with-agents-md
cortex
```

Verify with `/skill list` to see project skills. Test by asking CoCo to write a query -- it should follow the standards in `AGENTS.md`.

## Path B: Cortex Code in Snowsight

1. Open `deploy_all.sql` (if any) in a Snowsight worksheet and click **Run All**
2. Go to **Projects > Workspaces > Create > From Git repository**
3. Paste the repo URL and select your API integration
4. Open the Cortex Code panel in the workspace

Because the workspace is connected to the Git repo containing `AGENTS.md`, Cortex Code reads it automatically.

## Same Files, Same Behavior

| Aspect | CLI | Snowsight |
|--------|-----|-----------|
| How AGENTS.md is loaded | From working directory | From Git-connected workspace |
| How skills are loaded | From `.cortex/skills/` or `.claude/skills/` in repo + user `~/.snowflake/cortex/skills/` | Personal skills in `.snowflake/cortex/skills` within the workspace ([Agent Skills from Git-connected repos](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-snowsight) also supported) |
| How you update | `git pull` | Sync button in workspace |

---

## GitHub as the Management Layer

Since project tooling lives in a GitHub repo, GitHub's collaboration features handle team management.

### Instant Onboarding

New team members clone the repo (CLI) or connect a workspace (Snowsight). Standards are active immediately -- no setup scripts, no config files to copy.

### Standards Evolution via Pull Requests

When the team discovers the AI did something unexpected, update `AGENTS.md` via PR:

1. Create a branch and update the rule
2. Open a PR with the rationale
3. Team reviews
4. Merge to main -- every team member gets the update on next sync

### Gap Tracking via Issues

File GitHub Issues when standards miss something. Over time, the Issues tab becomes a record of what the team has learned about governing AI behavior.

### Branch Protection

Protect `main` so standards changes require approval:

| Setting | Value | Why |
|---------|-------|-----|
| Require pull request reviews | 1 reviewer | Standards changes affect the whole team |
| Restrict who can push | Team leads | Prevent accidental direct pushes |

### GitHub MCP in Cortex Code

The [GitHub MCP server](https://github.com/modelcontextprotocol/servers/tree/main/src/github) lets Cortex Code interact with Issues and PRs without leaving the terminal.

Add to `~/.snowflake/cortex/mcp.json` (CoCo) or `~/.claude.json` (Claude Code):

**With 1Password (recommended for teams):**

```json
{
  "mcpServers": {
    "github": {
      "command": "op",
      "args": [
        "run", "--env-file=/Users/YOUR_USERNAME/.config/op/mcp.env",
        "--no-masking", "--",
        "npx", "-y", "@modelcontextprotocol/server-github"
      ],
      "env": { "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" }
    }
  }
}
```

**With PAT (simpler for individual use):**

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_YOUR_TOKEN_HERE" }
    }
  }
}
```

Start with `--toolsets repos,issues` to scope available tools. See the reference configs in `reference/` for complete templates.

---

## Adding Intune Enterprise Enforcement

For organizations where opt-in standards aren't enough, deploy `managed-settings.json` via MDM. See [Step 2: Org Policy](../prompts/02_org_policy.md) for the full walkthrough, including Intune, Jamf, and Ansible deployment patterns.

The managed-settings layer sits above GitHub. Developers' personal `CLAUDE.md` or a project's `AGENTS.md` cannot override what `managed-settings.json` enforces.

| Layer | Mechanism | Can be overridden? |
|-------|-----------|-------------------|
| Project | `AGENTS.md` + skills in Git | Yes (developer can edit locally) |
| Team | GitHub PRs, branch protection | Yes (repo admin can change settings) |
| Organization | `managed-settings.json` via MDM | No (requires admin access to the machine) |

---

## Optional Lab: Sample Snowflake Objects

To try this pattern with sample data, create these objects in Snowflake:

```sql
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB;
CREATE WAREHOUSE IF NOT EXISTS SFE_COCO_GOVERNANCE_GITHUB_WH
  WITH WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: coco-governance-github - Standards testing (Temporary)';

USE SCHEMA SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB;

CREATE OR REPLACE TABLE CUSTOMERS (
  CUSTOMER_ID NUMBER, NAME VARCHAR, EMAIL VARCHAR, REGION VARCHAR,
  CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'DEMO: Sample customers for standards testing';

CREATE OR REPLACE TABLE ORDERS (
  ORDER_ID NUMBER, CUSTOMER_ID NUMBER, ORDER_DATE DATE,
  AMOUNT NUMBER(10,2), STATUS VARCHAR
)
COMMENT = 'DEMO: Sample orders for standards testing';

CREATE OR REPLACE TABLE PRODUCTS (
  PRODUCT_ID NUMBER, NAME VARCHAR, CATEGORY VARCHAR,
  PRICE NUMBER(10,2)
)
COMMENT = 'DEMO: Sample products for standards testing';
```

Cleanup: `DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.COCO_GOVERNANCE_GITHUB CASCADE;`
