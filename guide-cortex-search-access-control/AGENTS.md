# Cortex Search Access Control — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Documentation-only guide — no SQL deploy scripts, no Streamlit app, no Snowflake objects created.

```
README.md                  → overview, decision tree, pattern comparison table, roadmap
filter-attribute-ubac.md   → Pattern 1: ATTRIBUTES + @contains filter (recommended for dynamic access)
separate-services.md       → Pattern 2: separate service per data boundary (static groups)
ELI5.md                    → plain-language companion for non-technical readers
```

## Snowflake Environment

None. This is a reference guide with no infrastructure.

## Conventions

- Pattern pages are named for the pattern: `filter-attribute-ubac.md`, `separate-services.md`
- All SQL examples use generic object names (`db`, `schema`, `docs_search_svc`, `your_content_table`)
- No customer names, meeting references, or account identifiers
- "External account identifier" is the generic term for any CRM/system key (Salesforce Account ID, tenant ID, workspace ID, etc.)
- Honest about gaps: caller's rights referenced as "reported by Cortex Search team, no GA date"

## Key Commands

No deployment. To add a new pattern page: create `<pattern-name>.md` and link it from the decision tree in `README.md`.
