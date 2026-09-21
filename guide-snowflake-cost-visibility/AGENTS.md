# Snowflake Cost Visibility — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

This guide covers three foundational cost visibility capabilities:

1. **Budget object** (`sql/budget_setup.sql`) — account-level predictive spend alerting
2. **ACCOUNT_USAGE queries** (`sql/account_usage_queries.sql`) — `METERING_DAILY_HISTORY`-based attribution
3. **Resource monitors** (`sql/resource_monitors.sql`) — warehouse-level credit guardrails

Single thesis: **see your credits, then cap them.** Cortex AI access control (`CORTEX_USER`,
`AI_FUNCTIONS_USER`, `USE AI FUNCTIONS`, model application roles) is deliberately OUT OF SCOPE —
it lives in `guide-cortex-access-control`. Section 4 of the README is a scope note naming those
mechanisms, not a how-to. Do not re-add RBAC procedure here; if a reader needs it, the section-4
pointer is the answer.

The guide (`README.md`) is the primary deliverable. SQL files are the leave-behind artifacts — each file
is self-contained and copy-paste ready.

## Conventions

- No customer names or specific credit amounts anywhere in committed files
- Role names use generic patterns: `ANALYST_ROLE`, `DATA_ENG_ROLE`, `NEW_BU_ROLE`, `TRUSTED_ROLE`
- Email addresses use placeholder domains: `admin@example.com`
- SQL files include comment blocks explaining what to substitute before running
- **Never state a single flat ACCOUNT_USAGE latency figure.** Latency is documented per view.
  Quote a number only when it is scoped to a named view (e.g. `METERING_DAILY_HISTORY`, up to 3 hours).
- The Budget object is **not** "the only native mechanism covering AI spend" — `SNOWFLAKE.CORE.QUOTA`
  and the `CORTEX_CODE_*_DAILY_EST_CREDIT_LIMIT_PER_USER` parameters also cap AI credits. Keep the
  claim scoped to what is true: it is the only account-wide *predictive alert* spanning all credit types.

## Key Commands

```bash
# Verify file list
ls -la sql/

# Check for any customer name leakage
# Check for any customer name leakage before committing:
# grep -ri "<customer-name>" . --include="*.md" --include="*.sql"
```

Pair-programmed by SE Community + Cortex Code
