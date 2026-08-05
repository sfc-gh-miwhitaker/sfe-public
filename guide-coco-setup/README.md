![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2027--02--05-yellow)
![Status](https://img.shields.io/badge/Status-Active-success)

# Get Started with Cortex Code

Cortex Code (CoCo) is Snowflake's AI coding assistant — it writes SQL, explores your catalog, and builds pipelines from natural language. This guide covers where to find it, how to enable it for your team, how to control costs, and how to extend it with custom skills.

Pair-programmed by SE Community + Cortex Code

**Created:** 2025-05-15 | **Expires:** 2027-02-05 | **Status:** ACTIVE

> **No support provided.** This content is for reference only. Review and validate before applying to any production workflow.

---

## Who This Is For

| You are... | Your question | Jump to |
|---|---|---|
| **Admin** | "My users can't access CoCo — how do I fix it?" | [Part 2: Unblock Access](#part-2-why-your-users-cant-access-coco) |
| **Admin** | "How do I enable this without surprise charges?" | [Part 3: Cost Guardrails](#part-3-enable-with-cost-guardrails) |
| **Developer** | "Where do I use CoCo?" | [Part 1: Surfaces](#part-1-where-coco-lives) |
| **Team lead** | "How do I enforce standards across the team?" | [Part 5: Skills](#part-5-build-your-first-skill--snowflake-standards) |

---

## Part 1: Where CoCo Lives

> **TL;DR:** If you're already in Snowsight, you already have CoCo. Click the icon in the lower-right corner. No install required.

CoCo is available across five surfaces — pick the one that fits where you already work:

### Snowsight (Built-In — Zero Install)

CoCo is integrated directly into Snowsight. If your users have the required roles and cross-region inference is enabled, they already have it.

| | |
|---|---|
| **Open it** | Click the CoCo icon in the lower-right corner of any Snowsight page |
| **What it does** | Agentic coding in Workspaces: SQL, notebooks, dbt, Streamlit |
| **Customizable** | Supports `AGENTS.md` and personal skills in the workspace |
| **RBAC** | Uses the same role as your Snowsight session |

> **Can't see the icon?** Your account likely has one of the [three common blockers](#the-three-blockers).

---

### VS Code (Snowflake Extension)

For developers who live in VS Code — **no separate app download required.**

| Step | Action |
|------|--------|
| 1 | Install the **Snowflake** extension from the VS Code Marketplace |
| 2 | Click the snowflake icon in the sidebar → sign in to your account |
| 3 | Click the **CoCo** icon in the Activity Bar to open the chat panel |
| 4 | Start prompting — full access to your workspace context + Snowflake catalog |

Same RBAC requirements as Snowsight. Inline AI code suggestions also appear as you type SQL.

---

### Desktop (Full Agentic IDE)

A native Mac/Windows application — file editor, integrated terminal, agentic browser, notebooks, and deep Snowflake awareness.

**Best for:** Multi-file projects, autonomous workflows, local file access.

1. **Download:** [Get CoCo Desktop](https://ai.snowflake.com) (macOS and Windows)
2. **Sign in:** Launch → four-step onboarding (Welcome → Connect → View → Theme)
3. **Auth:** Local OAuth (recommended), SSO, Password, or Key Pair (JWT)

> **Tip:** If you have `~/.snowflake/connections.toml` from the Snowflake CLI, Desktop detects it automatically.

---

### CLI (Terminal Agent)

**Best for:** Terminal-native devs, CI/CD, scripting.

```bash
# macOS / Linux / WSL
curl -LsS https://ai.snowflake.com/static/cc-scripts/install.sh | sh

# Windows (PowerShell)
irm https://ai.snowflake.com/static/cc-scripts/install.ps1 | iex
```

Run `cortex` after install — the setup wizard handles connection.

---

### Other Editors (ACP)

CoCo CLI runs as a subprocess inside ACP-compatible editors:

- **Zed** — built-in agent panel
- **JetBrains IDEs** — via ACP plugin
- **Neovim** — via ACP client

See [Cortex Code in Your Editor](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-in-your-editor).

---

## Part 2: Why Your Users Can't Access CoCo

> **The short version:** ~2/3 of Snowsight users are blocked from CoCo by one of three configuration gaps. Most accounts have at least one.

### The Three Blockers

| # | Blocker | What users see | Fix time |
|---|---------|---------------|----------|
| 1 | **Cross-region inference disabled** | Empty model picker, "no models available" | 1 minute |
| 2 | **Model allowlist too restrictive** | Empty model picker (different root cause) | 1 minute |
| 3 | **CORTEX_USER revoked from PUBLIC** | CoCo icon missing or grayed out | 1 minute |

---

### Fix #1: Enable Cross-Region Inference

> **This is the most common blocker.** CoCo needs Claude/GPT models, which aren't deployed in every Snowflake region. Without CRI, no models are available.

```sql
-- Recommended: broadest Claude model access
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'AWS_GLOBAL';
```

<details>
<summary><strong>All CRI options</strong></summary>

| Setting | What it enables |
|---------|----------------|
| `AWS_GLOBAL` | All Claude models on AWS **(recommended for most)** |
| `AZURE_GLOBAL` | OpenAI GPT models on Azure |
| `ANY_REGION` | All models across all clouds |
| `AWS_US`, `AWS_EU`, `AWS_APJ` | Regional subsets of Claude |

</details>

---

### Fix #2: Check Model Allowlist

```sql
SHOW PARAMETERS LIKE 'CORTEX_MODELS_ALLOWLIST' IN ACCOUNT;
```

- **Value = `ALL`** → No action needed. All models are available.
- **Value = specific model list** → Ensure it includes at least one CoCo model:

```sql
-- Comma-separated string (not a SQL array)
ALTER ACCOUNT SET CORTEX_MODELS_ALLOWLIST = 'claude-opus-4-6,claude-sonnet-4-6';

-- Or restore full access:
ALTER ACCOUNT SET CORTEX_MODELS_ALLOWLIST = 'ALL';
```

---

### Fix #3: Restore CORTEX_USER Access

```sql
-- Option A: Re-grant to PUBLIC (all users get CoCo)
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE PUBLIC;

-- Option B: Targeted — specific roles only
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE DATA_ENGINEER;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE ANALYST;
```

> **Least-privilege alternative:** `SNOWFLAKE.CORTEX_AGENT_USER` enables CoCo without granting access to other Cortex AI functions (AI_COMPLETE, AI_CLASSIFY, etc.).

---

## Part 3: Enable With Cost Guardrails

> **The key insight:** CoCo has no fixed monthly fee — you pay per token of inference. The risk isn't "will it cost something?" (it will), it's "will it cost more than I expect?" Set limits BEFORE you enable access.

### Do Both at Once

Don't enable CRI and walk away. **Enable + set limits in the same change window:**

```sql
-- Step 1: Unblock model access
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'AWS_GLOBAL';

-- Step 2: Set daily per-user credit guardrails (all three surfaces)
ALTER ACCOUNT SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
ALTER ACCOUNT SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
ALTER ACCOUNT SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
```

When a user hits their daily limit, that surface is blocked until the rolling 24-hour window resets. Other surfaces are unaffected.

---

### Credit Limit Quick Reference

| Value | What happens |
|-------|-------------|
| `-1` (default) | **No limit** — unlimited usage |
| `0` | **Blocked** — surface completely disabled |
| `20` | Blocked after ~20 credits in a rolling 24-hour window |

**User overrides take precedence over account defaults:**

```sql
-- Block Desktop for everyone, then allow power users
ALTER ACCOUNT SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 0;
ALTER USER power_user SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 50;
```

---

### Monitor What You're Spending

CoCo usage is tracked in **three separate views** (one per surface):

```sql
-- Desktop usage by user (last 7 days)
SELECT USER_NAME, SUM(TOKEN_CREDITS) AS total_credits, COUNT(*) AS requests
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
WHERE USAGE_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY USER_NAME
ORDER BY total_credits DESC;
```

> Replace `DESKTOP` with `SNOWSIGHT` or `CLI` for the other surfaces.

For **aggregate totals** across all CoCo surfaces (30-day view):

```sql
SELECT SERVICE_TYPE, SUM(CREDITS_USED) AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE SERVICE_TYPE LIKE 'CORTEX_CODE%'
  AND USAGE_DATE >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY SERVICE_TYPE
ORDER BY total_credits DESC;
```

---

### Common Scenarios

| I want to... | Do this |
|---|---|
| Cap daily spend per user | Set all three `*_DAILY_EST_CREDIT_LIMIT_PER_USER` params |
| Block one surface entirely | Set that surface's param to `0` |
| Allow only specific users on Desktop | Account = `0`, then per-user positive values |
| Use cheaper models only | `ALTER ACCOUNT SET CORTEX_MODELS_ALLOWLIST = 'claude-sonnet-4-6';` |
| See who's spending the most | Query the per-surface usage views above |

---

### The Gotcha

> **Don't revoke `SNOWFLAKE.CORTEX_USER` from PUBLIC as a cost control.** It disables CoCo **AND** all Cortex AI functions (AI_COMPLETE, AI_CLASSIFY, AI_TRANSLATE, AI_SENTIMENT, etc.) for every role that inherited it. It's a sledgehammer when you need a scalpel. Use credit limits instead — they control CoCo per-surface without collateral damage.

---

## Part 4: Understand the Configuration Hierarchy

Cortex Code follows the same layered configuration model as Claude Code. Higher layers override lower ones. Understanding this hierarchy is the single most important concept for getting good results.

**Read the source:** [Claude Code Memory and CLAUDE.md](https://docs.anthropic.com/en/docs/claude-code/memory)

### What Cortex Code Adds

| Scope | Shared (CoCo + Claude Code + Cursor) | Cortex Code adds |
|-------|---------------------------------------|------------------|
| **Org** (IT-managed) | — | `managed-settings.json` |
| **User** | `~/.claude/CLAUDE.md`, `~/.claude/skills/` | `~/.snowflake/cortex/settings.json`, `~/.snowflake/cortex/skills/`, `~/.snowflake/cortex/plugins/` |
| **Project** | `AGENTS.md`, `.claude/skills/` | `.cortex/skills/`, `.cortex/plugins/` |

> **Best practice:** Write instructions in `AGENTS.md` and skills in `.claude/skills/` for cross-tool compatibility. Use `.cortex/` paths only for CoCo-exclusive functionality.

See the full diagram in [`diagrams/guidance-hierarchy.md`](diagrams/guidance-hierarchy.md). For the complete extensibility model, see [CoCo CLI Extensibility](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility).

---

## Part 5: Build Your First Skill — Snowflake Standards

Skills are on-demand extensions that load when triggered. For how skills work in general, see [Claude Code Skills](https://docs.anthropic.com/en/docs/claude-code/skills). This section focuses on what to put in a Snowflake-specific skill.

```bash
mkdir -p ~/.claude/skills/team-standards
cp reference/first-skill/SKILL.md ~/.claude/skills/team-standards/SKILL.md
cp -r reference/first-skill/references ~/.claude/skills/team-standards/
```

**Verify:** Type `/skill list` (Desktop), `/skills` (CLI), or check the `/` menu (Snowsight). You should see `team-standards`.

**Test:** Ask *"Write a query that finds the top 10 customers by revenue from the ORDERS table"* — the skill should prevent SELECT * and enforce QUALIFY for window function filtering.

> **Customize:** The template uses `{PLACEHOLDER}` values. Search for `{` and replace with your team's database, schema, and warehouse names.

---

## Part 6: What's Next

| Capability | What it does | Where to learn |
|------------|-------------|----------------|
| **Plugins** | Bundles of skills + hooks + MCP in one package | Skills & Plugins catalog in Desktop |
| **Memory** | Persistent context across conversations | `/memory` in chat |
| **Hooks** | Shell commands on events (session start, tool calls) | [Extensibility](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility) |
| **MCP Servers** | External tools (GitHub, Jira, databases) | [MCP Support](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/mcp) |
| **Plan Mode** | Read-only planning before implementation | Built-in — ask "plan this first" |
| **tgrep** | Semantic code search by meaning | Built-in — `/tgrep auth flow` |
| **Agent SDK** | Programmatic agents (TypeScript/Python) | [Quickstart](https://docs.snowflake.com/en/user-guide/cortex-code-agent-sdk/quickstart) |
| **Managed Settings** | IT fleet policy for Desktop | [Managed Settings](https://docs.snowflake.com/en/user-guide/cortex-code/managed-settings) |

---

## Related Guides

- [CoCo in Snowsight](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-snowsight) — full Snowsight integration reference
- [CoCo Desktop](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop) — Desktop feature reference
- [CoCo CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) — install, connect, commands, models
- [Cost Controls](https://docs.snowflake.com/en/user-guide/cortex-code/credit-usage-limit) — full credit limit parameter docs
- [Extensibility](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility) — skills, hooks, plugins, MCP
- [Claude Code Memory](https://docs.anthropic.com/en/docs/claude-code/memory) — CLAUDE.md hierarchy and best practices
- [Claude Code Skills](https://docs.anthropic.com/en/docs/claude-code/skills) — skill format, triggers, references

---

## External References

| Resource | URL |
|----------|-----|
| CoCo in Snowsight | https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-snowsight |
| CoCo Desktop | https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop |
| CoCo Desktop Onboarding | https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/onboarding-and-authentication |
| CoCo CLI | https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli |
| CoCo in Your Editor | https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-in-your-editor |
| Cost Controls for CoCo | https://docs.snowflake.com/en/user-guide/cortex-code/credit-usage-limit |
| CoCo Extensibility | https://docs.snowflake.com/en/user-guide/cortex-code/extensibility |
| Agent SDK Quickstart | https://docs.snowflake.com/en/user-guide/cortex-code-agent-sdk/quickstart |
| Claude Code Memory (CLAUDE.md) | https://docs.anthropic.com/en/docs/claude-code/memory |
| Claude Code Skills | https://docs.anthropic.com/en/docs/claude-code/skills |
| Cross-region Inference | https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions#cross-region-inference |
| Control Model Access | https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions#control-model-access |
| Managed Settings | https://docs.snowflake.com/en/user-guide/cortex-code/managed-settings |
