# Path 3 — CoCo CLI in the VS Code integrated terminal

The shortest path. Run the full CoCo CLI (formerly Cortex Code) inside VS Code's terminal pane. Not "Copilot Chat", but Copilot Chat keeps working in the sidebar — you get both.

## What this path is

CoCo (formerly Cortex Code) is a generally available agentic terminal CLI for Snowflake. It carries 30+ bundled Snowflake skills (Streamlit, notebooks, warehouses, dynamic tables, semantic views, Cortex Search, Cortex Agents, lineage, data quality, governance, and more), can call MCP servers, and supports custom skills, subagents, and hooks. Inside VS Code, you run it from the integrated terminal and treat it as a peer to Copilot. Because it reads your schema, RBAC, and context before it acts, it's data-native — the foundation that makes its answers accurate is built into the platform, not bolted on per connection.

## When to use this path

- You want the full CoCo experience without configuring an MCP server.
- Your team is mixed — some on Copilot Chat, some on Cursor, some on Claude Code — and you want one consistent Snowflake tool across all of them.
- You want to use CoCo's bundled skills directly (`/skill list` shows them).
- You want fast experimentation: no security integration, no PAT to wire into JSON, no waiting on Snowflake admins.

## Prerequisites

- VS Code (any recent version). The integrated terminal is built in.
- A Snowflake account.
- Network reachability from your machine to Snowflake.

## Step 1: Install the CLI

The CoCo CLI is GA for macOS, Linux, WSL, and Windows native. Full instructions: [Cortex Code CLI install docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli).

```bash
# macOS / Linux / WSL
curl -LsS https://ai.snowflake.com/static/cc-scripts/install.sh | sh
```

```powershell
# Windows native (PowerShell)
irm https://ai.snowflake.com/static/cc-scripts/install.ps1 | iex
```

Verify:

```bash
which cortex
cortex --version
```

## Step 2: Authenticate

```bash
cortex connections create
```

The CLI walks you through account identifier and authentication method (browser SSO is recommended for organizations with single sign-on; PAT and key-pair are also supported).

```bash
cortex connections list
```

Confirm an active connection appears.

## Step 3: Run it inside VS Code

1. Open VS Code.
2. Open the integrated terminal (`Ctrl+`` on Windows/Linux, `Cmd+`` on macOS).
3. Run:
   ```bash
   cortex
   ```

The CLI starts a session with all bundled skills available. You can now ask it anything — *"create a semantic view for the SALES schema"*, *"what are the top spending warehouses last 7 days"*, *"build a Streamlit dashboard for invoice processing"*. Copilot Chat keeps running in the sidebar; the two do not interfere.

## Useful commands inside the CLI

| Command | What it does |
|---|---|
| `/skill list` | Show all available skills (bundled + user) |
| `/skill add <path>` | Add a skill from a local path, Git repo, tarball, or Snowflake stage |
| `/mcp` | Open the MCP server status viewer |
| `cortex mcp add <name> <command> ...` (outside the CLI) | Add an MCP server config |
| `/agents` (or `Ctrl-B`) | View running background subagents |
| `/feedback` | Submit feedback |

## Connecting the CoCo CLI to MCP servers

The CoCo CLI can also act as an MCP client. If you have a Snowflake-managed MCP server (Path 1), or any other MCP server, you can wire it into the CLI:

```bash
cortex mcp add snowflake-cortex \
  https://<org-account>.snowflakecomputing.com/api/v2/databases/<DB>/schemas/<SCHEMA>/mcp-servers/MY_MCP \
  --type http \
  -H "Authorization: Bearer <PAT>" \
  -H "X-Snowflake-Authorization-Token-Type: PROGRAMMATIC_ACCESS_TOKEN"
```

The CLI persists this in `~/.snowflake/cortex/mcp.json` and discovers tools at session start.

For OAuth-protected MCP servers, use the `oauth` block in the config file — the CLI opens a browser for sign-in on first connect and caches the token under `~/.snowflake/cortex/mcp_oauth/`.

## Optional: a polished CLI binary tailored for VS Code

The Snowflake-Labs `subagent-cortex-code` repo ships a `cortexcode-tool` Python CLI specifically for terminal environments (including VS Code's integrated terminal). It wraps `cortex -p "..."` calls with security envelopes, prompt sanitization, and audit logging.

```bash
git clone https://github.com/Snowflake-Labs/subagent-cortex-code.git
cd subagent-cortex-code/integrations/cli-tool
bash setup.sh
```

Verify:

```bash
cortexcode-tool --version
cortexcode-tool "How many databases do I have in Snowflake?" --envelope RO
```

This is useful when you want the full CoCo experience with the same security envelopes the subagent skill applies (RO / RW / RESEARCH / DEPLOY), without going through a coding agent intermediary. It's bonus on top of the plain `cortex` CLI, not a replacement.

## Troubleshooting

### `cortex` not on PATH after install

Reload the shell profile:

```bash
source ~/.zshrc       # zsh
source ~/.bashrc      # bash
```

Or open a new terminal pane in VS Code.

### Connection fails with browser SSO

Confirm Snowflake SSO is configured for your account and the user has been provisioned through it. Browser SSO uses the same Snowflake federation your Snowsight login uses.

### Permission errors on `~/.zshrc` or `~/.zprofile` during install

Check ownership:

```bash
ls -l ~/.zshrc ~/.zprofile
```

If owned by `root`, fix:

```bash
sudo chown $USER ~/.zshrc ~/.zprofile
```

This usually happens after running a package manager with `sudo` at some point.

## References

- [Cortex Code CLI documentation](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli)
- [Cortex Code CLI bundled skills](https://docs.snowflake.com/en/user-guide/cortex-code/bundled-skills)
- [Cortex Code CLI extensibility](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility)
- [Security best practices for Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code/security)
- [`Snowflake-Labs/subagent-cortex-code` — `cortexcode-tool` CLI](https://github.com/Snowflake-Labs/subagent-cortex-code/tree/main/integrations/cli-tool)
