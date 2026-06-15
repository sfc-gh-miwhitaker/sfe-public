# Connecting VS Code GitHub Copilot to Snowflake Cortex — Project Instructions

## Architecture

Documentation-only guide (no deploy scripts, no Snowflake objects to create).

Three independently usable paths:

- `README.md` — landing page, decision tree, prerequisites, FAQ
- `path-1-mcp.md` — Snowflake-managed MCP server in **VS Code GitHub Copilot Chat** (the sidebar extension, Agent mode)
- `path-2-subagent-skill.md` — Snowflake-Labs `subagent-cortex-code` skill installed into **GitHub Copilot CLI** (`gh copilot` in the terminal — a sibling product to Copilot Chat)
- `path-3-coco-cli-terminal.md` — CoCo CLI (formerly Cortex Code) inside the VS Code integrated terminal

Path-specific troubleshooting lives in each path doc; cross-path gotchas are in `README.md`.

## Summit 26 naming (June 2026)

- **Cortex Code -> CoCo** (the agentic CLI; binary still invoked as `cortex`, config still in `~/.snowflake/cortex/`).
- **Snowflake Intelligence -> Snowflake CoWork** (the business-user agent).
- Use the new names with "formerly" on first mention. Doc-page link titles that literally read "Cortex Code CLI" stay as-is (that is still the docs page title).
- The shared accuracy foundation across all three paths is a semantic view + verified queries; point readers to authoritative learning rather than re-teaching it.

## Conventions

- Body content stays customer-shareable: no internal Slack archive URLs, no `go/...` short links, no internal Confluence/Jira paths, and no URLs sourced from internal communications without independent verification that the URL is publicly accessible and accurately characterized.
- **URL rule (hard):** before any URL appears in a deliverable, fetch it anonymously, confirm it loads (200), confirm the page content matches the claim, and confirm it is a customer-facing domain. Mention of a URL in internal Slack/Glean/Confluence/Jira does not count. When in doubt, do not cite.
- Preview capabilities may be named ONLY when (a) the citing URL passes the rule above and (b) the maturity is labeled explicitly (e.g., "private preview"). Do not speculate about unreleased features.
- Be precise about which Copilot product each path targets. GitHub Copilot Chat (the VS Code sidebar) and GitHub Copilot CLI (`gh copilot` in the terminal) are different products. Path 1 targets Chat; Path 2 targets CLI.
- Placeholder syntax: `<UPPERCASE_WITH_UNDERSCORES>` for values the reader replaces.
- Hostnames in URLs use **hyphens, not underscores** (Snowflake MCP requirement).
- Every path doc is self-contained — readers can follow one without reading the others.

## Key Commands

```bash
# Get account URL for MCP endpoints (run in Snowsight)
SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();

# Path 2: install subagent skill globally
npx skills add snowflake-labs/subagent-cortex-code --copy --global

# Path 3: confirm the CoCo CLI is available
which cortex && cortex --version
```

## Critical Gotchas

- Snowflake-managed MCP does **not** support Dynamic Client Registration (DCR). Recommend OAuth via security integration (with `OAUTH_ALTERNATE_REDIRECT_URIS` for VS Code's multiple callback URLs); fall back to PAT bearer.
- MCP hostnames must use hyphens, not underscores — connection failures otherwise.
- The `subagent-cortex-code` skill targets the GitHub Copilot CLI, not VS Code's Copilot Chat extension. It exposes the prompt surface — Copilot CLI calls `cortex -p "..."` — not CoCo's first-class tools.
- Cortex Analyst over MCP returns generated SQL only; it does not execute. Customers expecting query results need a separate `SYSTEM_EXECUTE_SQL` tool on the same MCP server.

## SE-only Context

Internal SEs may have access to additional Snowflake-built surfaces beyond what this guide covers. This guide intentionally stays customer-shareable: only paths whose Snowflake side and client side are both generally available. Do not extend this guide with internal-only tooling, internal Slack/Confluence/Jira links, or any URL whose public accessibility hasn't been independently verified by anonymously fetching it.

## Related Projects

- [`guide-connecting-claude-snowflake`](../guide-connecting-claude-snowflake/) — same shape for Claude Desktop and Claude Code
- [`guide-connecting-copilot-studio-snowflake`](../guide-connecting-copilot-studio-snowflake/) — same shape for Microsoft Copilot Studio
- [`guide-mcp-auth`](../guide-mcp-auth/) — comprehensive MCP authentication patterns
