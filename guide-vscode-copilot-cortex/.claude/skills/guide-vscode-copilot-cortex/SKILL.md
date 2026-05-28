---
name: guide-vscode-copilot-cortex
description: "Use when a user asks how to connect VS Code with GitHub Copilot to Snowflake Cortex. Covers only generally available Snowflake and Visual Studio Code components. The skill does not document, recommend, or speculate about any unreleased product.""
---

# guide-vscode-copilot-cortex

## Purpose

Help a customer engineer or SE pick and execute one of three generally available paths to connect VS Code's GitHub Copilot surfaces to Snowflake Cortex. The guide is strictly limited to components with public, independently verified documentation. Do not extend it with unreleased product references.

## Architecture

Documentation-only guide. No deploy scripts. The three paths target different surfaces in the same VS Code window:

- Path 1 → GitHub Copilot Chat (the sidebar extension, Agent mode) ← Snowflake-managed MCP
- Path 2 → GitHub Copilot CLI (`gh copilot` in a terminal pane, a sibling product to Copilot Chat) ← `subagent-cortex-code` skill
- Path 3 → any VS Code terminal pane ← Cortex Code CLI

GitHub Copilot Chat and GitHub Copilot CLI are different products. The guide is explicit about this distinction in the README, in `path-2-subagent-skill.md`, and in the FAQ.

## Key files

| File | Role |
|---|---|
| `README.md` | Landing page. Three-path diagram, decision tree, comparison table, prerequisites, FAQ. |
| `path-1-mcp.md` | Snowflake-managed MCP for Copilot Chat. SQL for `CREATE MCP SERVER`, OAuth security integration with `OAUTH_ALTERNATE_REDIRECT_URIS`, PAT fallback, `.vscode/mcp.json` for both auth options, verification queries against `ACCOUNT_USAGE.QUERY_HISTORY`. |
| `path-2-subagent-skill.md` | `subagent-cortex-code` for the GitHub Copilot CLI. Honest framing of which Copilot product is being extended. `npx skills add` install, security envelopes (RO / RW / RESEARCH / DEPLOY), routing scope, uninstall. |
| `path-3-coco-cli-terminal.md` | Cortex Code CLI in a VS Code terminal pane. Install, authenticate, run, useful commands, optional `cortexcode-tool` wrapper. |
| `AGENTS.md` | Layer-3 project conventions, gotchas, SE-only context flag. |
| `diagrams/` | Mermaid sources mirrored from the diagrams in the rendered docs. |

## Snowflake objects (referenced, not deployed)

The guide references these object types as part of Path 1 setup, but does not ship a deploy script:

- `MCP SERVER` (database-scoped, with `CORTEX_SEARCH_SERVICE_QUERY` / `CORTEX_ANALYST_MESSAGE` / `CORTEX_AGENT_RUN` / `SYSTEM_EXECUTE_SQL` / `GENERIC` tools)
- `SECURITY INTEGRATION` (OAuth, type `OAUTH_CLIENT = CUSTOM`, with `OAUTH_ALTERNATE_REDIRECT_URIS` for VS Code's multiple callback URLs)
- A user `DEFAULT_ROLE` and `DEFAULT_WAREHOUSE` for OAuth sessions
- A Programmatic Access Token (PAT) for the fallback auth flow

## Extension Playbook

### How to add a new path doc when a new GA component ships

When a Snowflake-on-VS-Code surface goes GA and earns public corporate documentation, add it as a new path:

1. Confirm the surface is generally available on Snowflake's side (release notes / public docs page) and on the client side (Microsoft's published Visual Studio Code stable channel docs).
2. Create `path-N-<short-name>.md` matching the existing path-doc structure:
   - One-paragraph "what this is" intro that names the exact Copilot product being extended (Chat vs. CLI matters).
   - "When to use this path vs. the others" comparison.
   - Prerequisites with cross-links to the top-level prerequisites in `README.md`.
   - Numbered setup steps.
   - Verification commands or queries.
   - Limitations and known gotchas (mirror cross-cutting items to the Cross-path gotchas section in `README.md`).
3. Update `README.md`:
   - Add a column to the comparison table.
   - Add a row to the "Detailed guides" table.
   - Update the three-path mermaid diagram and the decision tree.
4. Update `AGENTS.md` if a new gotcha is cross-cutting.
5. Update this SKILL.md `Key files` table.
6. If the component is not generally available, do not document it in this guide.

## Gotchas

- **DCR is unsupported.** Snowflake-managed MCP does not implement Dynamic Client Registration. Use the OAuth security integration flow with `OAUTH_ALTERNATE_REDIRECT_URIS` for VS Code's multiple callback URLs, or fall back to PAT bearer auth.
- **Hostnames with underscores break MCP.** Always use the hyphenated `<org>-<account>` form in the MCP URL.
- **OAuth sessions use `DEFAULT_ROLE` only.** Set each user's `DEFAULT_ROLE` and `DEFAULT_WAREHOUSE` correctly. Secondary roles are not honored, even if the client requests `session:role:all` (the consent screen may show "secondary roles = ALL" cosmetically — Snowflake does not honor it).
- **Cortex Analyst over MCP returns SQL text, not query results.** Configure a `SYSTEM_EXECUTE_SQL` tool on the same MCP server for execution.
- **Tool responses are size-capped.** Generic and SQL execution responses are truncated at 250 KB.
- **Maximum 50 tools per MCP server.** Snowflake recommends splitting if more are needed; tool-selection accuracy degrades past 50.
- **The subagent skill targets the GitHub Copilot CLI, not VS Code's Copilot Chat extension.** The two are different products. Path 1 is the path for adding Snowflake to Copilot Chat itself.
- **Date-suffixed model IDs are rejected.** Pin to bare names like `claude-sonnet-4-6` if a client resolves to date-suffixed IDs.
