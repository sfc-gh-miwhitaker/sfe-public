# guide-claude-code-cortex-redirect — Project Instructions

<!-- Global rules apply automatically via ~/.claude/CLAUDE.md and ~/.claude/rules/. -->

## Architecture

Single-purpose guide with three markdown files:
- `README.md` — overview, routing table, prerequisites
- `claude-code-redirect.md` — Claude Code CLI redirect setup
- `sdk-redirect.md` — Anthropic SDK and OpenAI SDK redirect patterns

No Snowflake objects deployed. This guide is documentation only.

## Conventions

Topic: Redirecting the `claude` CLI and `anthropic` SDK clients to route all inference
through the Snowflake Cortex REST API instead of Anthropic's API directly.

Critical gotcha to preserve across edits: Anthropic SDK sends `x-api-key` by default;
Snowflake needs `Authorization: Bearer`. The `ANTHROPIC_AUTH_TOKEN` env var (not
`ANTHROPIC_API_KEY`) is what Claude Code uses for Bearer token auth.

Model names in Cortex REST API match Anthropic's names exactly (e.g., `claude-sonnet-4-6`).

## Key Commands

No deploy steps — guide only.
To verify links: `grep -r 'http' . --include='*.md' | grep -v '.claude'`
