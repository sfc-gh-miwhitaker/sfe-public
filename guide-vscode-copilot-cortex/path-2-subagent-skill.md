# Path 2 — `subagent-cortex-code` skill in GitHub Copilot CLI

The Snowflake-Labs `subagent-cortex-code` skill teaches a coding agent to detect Snowflake-shaped prompts and shell out to the local Cortex Code CLI for Snowflake-specific work. Inference stays on the agent's normal model.

## What this path is — and what it is not

The repository's GitHub Copilot install path targets the **GitHub Copilot CLI** (the `gh copilot` terminal experience), not the **GitHub Copilot Chat extension** inside VS Code. The two are different products:

| Product | What it is | Skill path supported? |
|---|---|---|
| GitHub Copilot CLI (`gh copilot`) | Terminal-based Copilot, reads the universal `~/.agents/skills/` directory | Yes — `npx skills add` installs here |
| GitHub Copilot Chat extension (in VS Code) | Sidebar chat in VS Code with Agent mode | Not directly — extend with MCP (Path 1) or run the CLI in a terminal pane |

If the customer asks for "Cortex Code-style intelligence inside the GitHub Copilot CLI", this is the right path. If they want it inside VS Code's Copilot Chat sidebar, they should use **Path 1** (MCP) or **Path 3** (Cortex Code CLI in the integrated terminal).

You can run all of this side-by-side: GitHub Copilot CLI in one terminal pane, Copilot Chat in the sidebar, Cortex Code CLI in another pane.

## When to use this path

- Engineers who already use the GitHub Copilot CLI and want Snowflake operations to route to Cortex Code CLI automatically.
- Teams who want a low-friction install (`npx skills add ...`) that also reaches 40+ other coding agents in one command.

## Prerequisites

- **Cortex Code CLI** installed and authenticated. Verify:
  ```bash
  which cortex
  cortex connections list   # must show an active connection
  ```
- **GitHub Copilot CLI** installed and signed in. See [GitHub Copilot CLI docs](https://docs.github.com/en/copilot/how-tos/copilot-cli).
- **Node.js** for `npx`.

If `cortex` is not on your PATH, follow the [Cortex Code CLI install instructions](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) before continuing.

## Step 1: Install the skill

```bash
npx skills add snowflake-labs/subagent-cortex-code --copy --global
```

The installer writes to `~/.agents/skills/cortex-code/` — the universal skills directory that the GitHub Copilot CLI reads from automatically. The same `npx` run also installs to other agents the `skills` CLI knows about (Amp, Antigravity, Cline, Deep Agents, Firebender, Gemini CLI, Kimi Code CLI, OpenCode, Warp). If you only want it for Copilot CLI, you can ignore the other locations.

Verify:

```bash
ls ~/.agents/skills/cortex-code/SKILL.md
```

## Step 2 (optional): Configure a security mode

Cortex Code routing has three approval modes — `prompt` (default, asks before each route), `auto` (no prompt, audit-logged), and `envelope_only` (no prompt within an allowed envelope).

```bash
cp ~/.agents/skills/cortex-code/config.yaml.example \
   ~/.agents/skills/cortex-code/config.yaml
# edit security.approval_mode and security.allowed_envelopes
```

The four security envelopes are:

| Envelope | Allowed | Blocked |
|---|---|---|
| `RO` | Reads, queries | Edit, Write, Bash |
| `RW` | Data modifications | Destructive shell patterns |
| `RESEARCH` | Exploration | Edit, Write, Bash |
| `DEPLOY` | Deployment ops | Bash, destructive shell — requires explicit confirmation |
| `NONE` | (rejected by the skill) | All |

For a customer rollout, organization admins can pin settings via `~/.snowflake/cortex/claude-skill-policy.yaml`. Relaxed approval or envelope settings can only be enabled if that policy explicitly authorizes the relaxed value.

## Step 3: Verify routing

Start a GitHub Copilot CLI session and ask a Snowflake-shaped question:

```
gh copilot suggest "list the semantic views in my Snowflake account"
```

The skill should detect the Snowflake intent, prompt you to confirm (in default `prompt` mode), and run `cortex -p "..."` headlessly. Output flows back into the Copilot CLI session.

To explicitly invoke the skill regardless of routing:

```
/cortex-code list semantic views in MY_DB.PUBLIC
```

## What gets routed and what does not

The skill is intentionally narrow:

| Routes to Cortex Code | Stays with the Copilot agent |
|---|---|
| Snowflake databases, warehouses, schemas, tables | Local file operations |
| SQL written for Snowflake | General programming (Python, JS, etc.) |
| Cortex AI features (Search, Analyst, ML functions) | Non-Snowflake databases (Postgres, MySQL, Mongo, etc.) |
| Snowpark, Dynamic Tables, Streams, Tasks | Web development, frontend |
| Data governance, RBAC, network policies in Snowflake | Git, GitHub, version control |
| Anything where the user explicitly says "Cortex" or "Snowflake" | Infrastructure unrelated to Snowflake |

This is by design. Routing everything would let the skill capture intent it cannot satisfy. The skill discovers Cortex Code's bundled skills at session start (via `cortex skill list`) and uses their trigger patterns to boost its routing scores, so it stays current as new Cortex Code skills ship.

## Important caveats

- **The skill exposes the prompt surface, not Cortex Code's first-class tools.** Built-in Cortex Code capabilities like `system-create-semantic-view` are not made available to Copilot directly — Copilot calls `cortex -p "..."`, which then internally chooses skills and tools. This is good enough for natural-language Snowflake operations and bad if you need fine-grained tool-by-tool control. For tool-level control, use Path 1 (MCP).
- **Sessions are independent.** The skill maintains its own Cortex Code session per request. Long multi-turn conversations don't persist across `cortex -p` invocations the way they do inside the Cortex Code CLI itself.
- **Audit logs land locally** at the path the skill's `config.yaml` points at. Inspect them for compliance review; they use HMAC-signed JSONL with hash chaining.
- **License is not Apache 2.0.** The repo is shipped under the Snowflake Skills License. Read it before redistributing.

## Uninstall

```bash
rm -rf ~/.agents/skills/cortex-code
# remove other agent-specific copies if you used them
rm -rf ~/.codeium/windsurf/skills/cortex-code  # Windsurf
rm -rf ~/.cursor/skills/cortex-code            # Cursor
rm -rf ~/.claude/skills/cortex-code            # Claude Code
```

## Troubleshooting

### Skill installs but Copilot CLI doesn't use it

Confirm the file is at the universal location the Copilot CLI reads from:

```bash
ls ~/.agents/skills/cortex-code/SKILL.md
```

If missing, re-run:

```bash
npx skills add snowflake-labs/subagent-cortex-code --copy --global
```

Restart the Copilot CLI session.

### "Cortex CLI not found" when the skill tries to route

The skill shells out to `cortex -p "..."`. That requires the Cortex Code CLI to be installed and on PATH:

```bash
which cortex
cortex connections list
```

If missing, install per the [Cortex Code CLI docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) and verify a connection exists.

### The skill keeps prompting for approval

Default approval mode is `prompt`. Change to `auto` or `envelope_only` in `~/.agents/skills/cortex-code/config.yaml` if you accept the security tradeoff. Note that organization policy at `~/.snowflake/cortex/claude-skill-policy.yaml` can override and lock these settings; relaxed values must be explicitly authorized by the org policy.

### The skill is routing things I want Copilot to handle

The skill scopes routing narrowly to Snowflake-shaped prompts. If something is being routed incorrectly, file an issue against [`Snowflake-Labs/subagent-cortex-code`](https://github.com/Snowflake-Labs/subagent-cortex-code/issues). In the meantime, prefix prompts with explicit non-Snowflake context to bias against routing.

## References

- [`Snowflake-Labs/subagent-cortex-code`](https://github.com/Snowflake-Labs/subagent-cortex-code)
- [Cortex Code CLI extensibility — skills, subagents, hooks, MCP](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility)
- [Cortex Code CLI bundled skills](https://docs.snowflake.com/en/user-guide/cortex-code/bundled-skills)
- [GitHub Copilot CLI documentation](https://docs.github.com/en/copilot/how-tos/copilot-cli)
