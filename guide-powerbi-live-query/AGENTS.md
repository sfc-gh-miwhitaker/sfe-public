# Power BI Live Query at Scale on Snowflake

Patterns for architecting Snowflake to serve Power BI DirectQuery workloads at high concurrency and low latency, using interactive tables, hybrid tables, and supporting optimizations.

## Project Structure

- `README.md` -- Complete guide (9 sections: cost realities, decision framework, anti-patterns, interactive tables, hybrid tables, Power BI config, monitoring, Cortex Analyst sidebar)

## Content Principles

- Interactive tables + interactive warehouses are the primary recommendation for dashboard-scale DirectQuery
- Hybrid tables are scoped to point-lookup operational dashboards only
- Cost realities appear before architecture recommendations so readers make informed decisions
- Anti-patterns section addresses the most common "Power BI is slow on Snowflake" complaints
- Query folding coverage is limited to known good patterns + Microsoft docs link (avoids staleness)
- All SQL examples use generic table/column names

## When Helping with This Project

- This is a guide, not a demo -- no deploy_all.sql, no Snowflake objects to create
- All SQL is embedded in README.md (no separate .sql files)
- Interactive warehouses have a 5-second SELECT timeout and 24-hour minimum auto-suspend -- always mention these constraints
- Interactive tables require CLUSTER BY -- never show a CREATE INTERACTIVE TABLE without it
- Interactive warehouses cannot query standard tables -- always note the warehouse-switching requirement
- Max 10 interactive tables per interactive warehouse -- this is a hard limit
- Hybrid tables are NOT recommended for aggregation-heavy BI -- steer users to interactive tables for that pattern
- Power BI SSO requires ACCOUNTADMIN for security integration creation
- Network policies can now be scoped to the OAuth integration (Jan 2026)

## When Users Ask for Help

### "Power BI is slow on Snowflake" / "How do I speed up DirectQuery?"

1. Ask what their current setup looks like (standard tables? clustering? warehouse size?)
2. Check if they're hitting the common anti-patterns from the guide
3. Run the partition efficiency query from the Monitoring section
4. Recommend the appropriate table type from the decision framework based on their workload

### "Should I use interactive tables or hybrid tables?"

Walk them through the decision framework:
- Dashboard aggregations (GROUP BY, SUM, COUNT) → interactive tables
- Point lookups by ID/key → hybrid tables
- If unsure, ask what their most common Power BI query pattern looks like

### "How much will interactive warehouses cost?"

Be direct about the cost model:
- 24-hour minimum auto-suspend (warehouse runs at least 24 hours once resumed)
- 1-hour minimum billing on each resume
- Designed for always-on workloads, not occasional queries
- Size based on working set, not total data volume

## Related Projects

- [`guide-cost-drivers`](../guide-cost-drivers/) -- Diagnose slow queries and high warehouse costs (complementary)
- [`tool-cortex-cost-intelligence`](../tool-cortex-cost-intelligence/) -- Cortex cost governance with BI-ready views
