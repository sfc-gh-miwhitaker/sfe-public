# Path 2 — Delegate to CoCo from GitHub Copilot

The `subagent-cortex-code` skill teaches GitHub Copilot to detect Snowflake-shaped prompts and hand them off to the local CoCo CLI. Snowflake operations go to CoCo; everything else stays with Copilot.

## What this path is — and what it is not

This targets the **GitHub Copilot CLI** (`gh copilot` in a terminal), not the Copilot Chat extension in the VS Code sidebar. The two are different products.

| Product | Surface | This path? |
|---|---|---|
| GitHub Copilot CLI (`gh copilot`) | Terminal | Yes |
| GitHub Copilot Chat (VS Code sidebar) | Sidebar chat panel | No — use Path 1 or Path 3 |

If you want CoCo inside **Copilot Chat**, use **Path 1** (VS Code extension). If you want Snowflake tools wired directly into Copilot Chat as callable functions, use **Path 3** (MCP).

## When to use this path

Engineers who already use `gh copilot` in a terminal and want Snowflake operations to route to CoCo automatically — without changing how they use Copilot for everything else.

## Prerequisites

- **CoCo CLI** installed and authenticated:
  ```bash
  which cortex
  cortex connections list   # must show an active connection
  ```
- **GitHub Copilot CLI** (`gh copilot`) installed and signed in.
- **Node.js** for `npx`.

## Setup

**Install the skill:**

```bash
npx skills add snowflake-labs/subagent-cortex-code --copy --global
```

This installs to `~/.agents/skills/cortex-code/` — the universal skills directory the GitHub Copilot CLI reads automatically.

**Verify:**

```bash
ls ~/.agents/skills/cortex-code/SKILL.md
```

**Optional — configure approval mode:**

```bash
cp ~/.agents/skills/cortex-code/config.yaml.example \
   ~/.agents/skills/cortex-code/config.yaml
# edit security.approval_mode: prompt (default) | auto | envelope_only
```

## How routing works

The skill routes to CoCo when prompts mention Snowflake databases, schemas, tables, SQL for Snowflake, Cortex features (Search, Analyst, ML functions), Snowpark, Dynamic Tables, or anything explicitly labeled "Snowflake" or "Cortex". Everything else — local files, general Python/JS, non-Snowflake databases, git — stays with Copilot.

Start a Copilot CLI session and ask a Snowflake question:

```bash
gh copilot suggest "list the semantic views in my Snowflake account"
```

The skill detects Snowflake intent, asks for approval (default mode), and runs `cortex -p "..."` headlessly. Output flows back into the Copilot session.

Explicit invocation:
```
/cortex-code list semantic views in MY_DB.PUBLIC
```

## Important caveats

- **Prompt surface only.** The skill calls `cortex -p "..."`. CoCo's built-in capabilities (tools, skills) work normally; Copilot doesn't get direct tool-by-tool control. For tool-level control, use Path 3 (MCP).
- **Sessions are independent.** Each `cortex -p` invocation is its own CoCo session — no memory carries across invocations.
- **License is not Apache 2.0.** The repo ships under the Snowflake Skills License.

## Troubleshooting

**Skill not routing** — Confirm the file is at `~/.agents/skills/cortex-code/SKILL.md`. If missing, re-run the `npx` install and restart the CLI session.

**"cortex not found"** — Install the CoCo CLI per the [Cortex Code CLI docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) and verify `cortex connections list` shows an active connection.

**Keeps prompting for approval** — Change `approval_mode` to `auto` in `config.yaml`. Note: org policy at `~/.snowflake/cortex/claude-skill-policy.yaml` can override and lock this setting.

---

## References

- [`Snowflake-Labs/subagent-cortex-code`](https://github.com/Snowflake-Labs/subagent-cortex-code)
- [GitHub Copilot CLI documentation](https://docs.github.com/en/copilot/how-tos/copilot-cli)
- [CoCo CLI extensibility](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility)
