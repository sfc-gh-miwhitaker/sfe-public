---
name: guide-snowflake-firewall-allowlist
description: "Snowflake firewall allowlisting guide for network admins. SYSTEM$ALLOWLIST, SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES, FQDN vs CIDR, PrivateLink escape hatch, automation patterns."
---

# guide-snowflake-firewall-allowlist

## Purpose

Help network/firewall administrators allowlist Snowflake traffic in edge firewalls.
Covers both traffic directions, explains the dynamic IP reality, and provides
automation patterns for keeping rules current.

## Architecture

```
guide-snowflake-firewall-allowlist/
  README.md         Main guide content (single file)
  ELI5.md           Plain-language summary for non-technical stakeholders
  AGENTS.md         Project-specific AI instructions
  .claude/skills/   This skill file
```

## Key Files

| File | Role |
|------|------|
| README.md | Complete guide with SQL examples, decision matrix, FAQ |
| ELI5.md | Non-technical companion explanation |

## Snowflake Objects

No Snowflake objects are created by this guide. SQL examples reference:
- `SYSTEM$ALLOWLIST()` — returns FQDNs for outbound allowlisting
- `SYSTEM$ALLOWLIST_PRIVATELINK()` — PrivateLink variant
- `SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES()` — returns stable egress CIDRs

## Extension Playbook

### Adding a new traffic direction or use case

1. Identify the Snowflake system function that provides the relevant endpoints
2. Add a new section following the pattern: Problem → Why → What to allowlist → Automation
3. Add a row to the Decision Matrix in Section 3
4. Add a Q&A entry to Section 4
5. Update the Start Here table if the new direction changes the routing summary

### Updating for new cloud regions or platforms

1. Check `SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES()` availability status
2. Update the "Deployment Availability" subsection in Section 2
3. Verify the automation skeleton still works for the new platform

## Gotchas

- `SYSTEM$WHITELIST()` is deprecated but still appears in older docs and community posts — always redirect to `SYSTEM$ALLOWLIST()`
- Egress IP ranges have **explicit expiration dates** — any guide update must emphasize automation, not manual rule creation
- The OCSP endpoints require port 80 (HTTP), not 443 — network admins often miss this
- `APP_SERVICE_PUBLIC_WILDCARD` type uses wildcard hostnames — firewall must support wildcard FQDN matching for Snowflake Apps
- Stable egress IPs are GA on AWS Commercial only as of 2026-08 — Azure/GCP status changes; verify before presenting
