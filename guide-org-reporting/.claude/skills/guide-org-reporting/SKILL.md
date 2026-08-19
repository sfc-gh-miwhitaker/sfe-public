---
name: guide-org-reporting
description: "Organization-level reporting in Snowflake via ORGANIZATION_USAGE schema. Multi-account visibility, premium vs non-premium views, application roles, database roles, query discipline."
---

# guide-org-reporting

## Purpose

SE reference guide for configuring and querying SNOWFLAKE.ORGANIZATION_USAGE to report
across a multi-account Snowflake footprint. Covers access paths, role grants, query
performance discipline, and the materialization pattern.

## Architecture

```
guide-org-reporting/
  README.md       — Full guide content (single-file reference)
  ELI5.md         — Plain-language companion for non-technical stakeholders
  AGENTS.md       — Project-specific instructions
  .claude/skills/guide-org-reporting/SKILL.md  — This file
```

No Snowflake objects deployed. Guide reads from existing SNOWFLAKE shared database views.

## Key Files

| File | Role |
|------|------|
| README.md | Complete guide: two access paths, role grants, query patterns, latency table |
| ELI5.md | Non-technical summary |

## Snowflake Objects

None created. Guide references:
- `SNOWFLAKE.ORGANIZATION_USAGE.*` (read-only shared database views)
- Application roles: `SNOWFLAKE.ORG_USAGE_ADMIN`, `SNOWFLAKE.ORGANIZATION_*_VIEWER`
- Database roles: `SNOWFLAKE.ORGANIZATION_USAGE_VIEWER`, `SNOWFLAKE.ORGANIZATION_BILLING_VIEWER`, `SNOWFLAKE.ORGANIZATION_ACCOUNTS_VIEWER`

## Extension Playbook

### How to add a new reporting view section

1. Check the view's reference topic at docs.snowflake.com for column definitions and latency
2. Determine if it's a premium view (org account only) or non-premium
3. Add to the appropriate section in README.md under "What each path gives you"
4. Add the view's primary time filter column to the "Query discipline" table
5. If the view requires a new application role, add it to the "Granting access" section

## Gotchas

- **ORGADMIN ≠ organization account**: Enabling ORGADMIN on a regular account does NOT give premium views. The PDF and guide call this out explicitly.
- **ORGADMIN role lacks SNOWFLAKE DB access by default**: Must grant via ACCOUNTADMIN. The ORGADMIN role itself cannot query ORGANIZATION_USAGE until granted.
- **Premium view billing**: Premium views bill per records processed. Materialize results on a schedule.
- **Latency is freshness, not query cost**: 2-72 hour latency means data staleness — querying live gives no advantage over a scheduled refresh.
- **Reseller billing views unavailable**: USAGE_IN_CURRENCY_DAILY, RATE_SHEET_DAILY, REMAINING_BALANCE_DAILY, CONTRACT_ITEMS are missing for orgs contracted through a reseller.
- **Org scope is hard**: Accounts in a different Snowflake organization never appear, regardless of data sharing relationships.
