# Replication Workbook

SQL guides for Snowflake replication setup: Enterprise (read-only replicas),
Business Critical (failover groups with promotion), and prerequisite account configuration.

## Project Structure
- `README.md` -- Overview, prerequisites, guide selection
- `account_setup_prerequisite_guide.sql` -- 7-step account prep (admin role, identifiers, target account)
- `enterprise_replication_guide.sql` -- 12-step Enterprise: replication groups, refresh, schedule
- `business_critical_failover_guide.sql` -- 15-step BC: failover groups, promotion, client redirect, failback

## Content Principles
- Step-by-step SQL with extensive comments (workbook format)
- Enterprise vs Business Critical as distinct guides with shared prerequisites
- Includes troubleshooting and validation at each step
- No automation -- designed for manual, guided execution

## When Helping with This Project
- This is a guide, not a demo -- no deploy_all.sql, no expiration
- Three independent SQL workbooks meant to be run step-by-step in Snowsight
- Prerequisites guide must run first (account setup, replication enablement)
- Enterprise guide: `CREATE REPLICATION GROUP` + `CREATE SECONDARY REPLICATION GROUP`
- BC guide: `CREATE FAILOVER GROUP` + `ALTER FAILOVER GROUP ... PRIMARY` for promotion
- Client redirect uses `ALTER CONNECTION` for transparent failover
- Error integration via notification integration for replication failure alerts
- All scripts require ACCOUNTADMIN or ORGADMIN role

## Related Projects
- [`tool-dr-cost-agent`](../tool-dr-cost-agent/) -- Estimate DR replication costs before setting up failover groups
