# MSP Provider Guide -- Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Multi-tenant Snowflake account design for MSPs with 3rd-party vendor Snowsight access:

- **Organisation level:** One MSP_OPS account + one account per customer
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

- `README.md` -- Complete guide (6 parts + troubleshooting)
- `sql/01_account_baseline.sql` -- Roles, databases, schemas, warehouses, resource monitors, tags, delegation SP
- `sql/02_vendor_onboard.sql` -- Parameterised vendor onboarding
- `sql/03_vendor_offboard.sql` -- Vendor offboarding and cleanup
- `sql/04_monitoring.sql` -- Org-level and per-account monitoring queries
- `sql/05_guardrails.sql` -- Network rules, auth policies, masking, row access, audit checks
- `diagrams/architecture.md` -- Mermaid diagrams (org layout, role hierarchy, data flow)

## When Helping with This Project

- This is a guide, not a demo -- no deploy_all.sql, no Snowflake objects to create
- SQL files are reference scripts the customer copies and adapts; they are not idempotent deployments
- All vendor SQL is parameterised with `SET vendor_name`
- MANAGED ACCESS is critical: without it, vendors can grant access to objects they create
- Future grants are required so MSP pipelines can read vendor-created objects
- Network policies at the user level override account-level policies
- CUST_ADMIN user management must go through stored procedure, never direct privilege grants

## Related Projects

- [`guide-external-access-playbook`](../guide-external-access-playbook/) -- External API egress patterns
- [`guide-data-quality-governance`](../guide-data-quality-governance/) -- DMFs, tagging, masking patterns
- [`tool-ai-spend-controls`](../tool-ai-spend-controls/) -- Cost monitoring patterns
