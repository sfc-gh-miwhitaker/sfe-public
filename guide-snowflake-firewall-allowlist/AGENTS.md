# guide-snowflake-firewall-allowlist — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Single-file reference guide (README.md) with no deployment artifacts.
Content is organized for a non-Snowflake audience (network/firewall admins).

Two-direction structure:
- Section 1: Outbound (corp network → Snowflake) — FQDN-based allowlisting
- Section 2: Inbound (Snowflake → corp network) — CIDR-based allowlisting with expiry

## Conventions

- All SQL examples use explicit column aliases and ORDER BY
- FQDN examples use angle-bracket placeholders: `<org>-<account>`
- No account identifiers in committed content
- Audience-appropriate tone: direct, no Snowflake jargon without explanation

## Key Commands

```bash
# Validate guide content (no deploy needed)
cd /Users/miwhitaker/src/sfe-public/guide-snowflake-firewall-allowlist
cat README.md | wc -l  # Should be under 300 lines
```
