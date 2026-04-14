# MSP Provider Guide -- Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

This guide covers the **Managed App (MSP)** pattern — the provider hosts customer data and workloads in their own Snowflake org. Three gates distinguish this from a Connected App (where data stays in the client's account):

- **Gate 1:** 3rd parties log directly into Snowflake and write data (Snowsight, connector, API)
- **Gate 2:** Provider is fully responsible for data quality, security, and compliance
- **Gate 3:** Provider's Snowflake bill covers all customer accounts (Managed Applications in SPN)

A Connected App provider (Gate 1 = No) belongs in a different pattern — Native Apps or Data Sharing.

- **Organization level:** One MSP_OPS account (org account or ORGADMIN-enabled) + one account per customer
- **Per-account layers:** RAW_INTERNAL, RAW_VENDOR (managed access), INTEGRATION, PRESENTATION, WORKSPACE
- **Role hierarchy:** MSP roles (inherit system roles) > Customer roles > Vendor roles (per-vendor)
- **Isolation:** Schema-level (managed access), warehouse-level, network policy per user, auth policy per user

## Conventions

- Vendor schemas use `WITH MANAGED ACCESS`
- SQL scripts use `SET vendor_name = 'VENDOR_X';` parameterisation
- Network controls use network rules (not legacy ALLOWED_IP_LIST)
- User management for CUST_ADMIN delegated via stored procedure, not direct CREATE USER grants
- Cost attribution via object tags on warehouses

## Project Structure

- `README.md` -- Complete guide (7 parts + troubleshooting)
- `sql/01_account_baseline.sql` -- Roles, databases, schemas, warehouses, resource monitors, tags, delegation SP
- `sql/02_vendor_onboard.sql` -- Parameterised vendor onboarding
- `sql/03_vendor_offboard.sql` -- Vendor offboarding and cleanup
- `sql/04_monitoring.sql` -- Org-level and per-account monitoring queries
- `sql/05_guardrails.sql` -- Network rules, auth policies, masking, row access, audit checks
- `sql/06_analytics_access.sql` -- Customer analytics access: Data Sharing, BI service account, SI human users, MCP server + OAuth
- `diagrams/architecture.md` -- Mermaid diagrams (org layout, role hierarchy, data flow)

## When Helping with This Project

- Establish which gate pattern applies before giving advice: Connected App (Gate 1 = No) vs Managed App / MSP (all 3 gates = Yes); a systems integrator who manages but doesn't own billing is a Partial MSP (Gates 1+2 only)
- This is a guide, not a demo -- no deploy_all.sql, no Snowflake objects to create
- SQL files are reference scripts the customer copies and adapts; they are not idempotent deployments
- All vendor SQL is parameterised with `SET vendor_name`
- See README.md for all technical details, constraints, ToS context, analytics access options, and troubleshooting

## Related Projects

- [`guide-external-access-playbook`](../guide-external-access-playbook/) -- External API egress patterns
- [`guide-data-quality-governance`](../guide-data-quality-governance/) -- DMFs, tagging, masking patterns
- [`tool-ai-spend-controls`](../tool-ai-spend-controls/) -- Cost monitoring patterns
