---
name: msp-provider
description: "MSP multi-tenant Snowflake guide with vendor Snowsight access. Use when: MSP architecture, vendor onboarding, multi-tenant snowflake, managed service provider, 3rd party access, vendor isolation, managed access schema."
---

# MSP Provider Guide

## Purpose
One concrete architecture for per-customer Snowflake accounts where MSP staff, customer users, and 3rd-party vendors coexist. Covers role hierarchy, managed access schemas, vendor onboarding/offboarding, network rules, authentication policies, monitoring, and cost attribution.

## Architecture
```
Organisation: MSP-US
├─ MSP_OPS (central monitoring via Org Usage views)
├─ CUST_ACME_PROD
│   ├─ Roles: MSP_ACCOUNT_ADMIN > MSP_SECURITY_ADMIN > MSP_PLATFORM_ENGINEER
│   │         CUST_ADMIN > CUST_ANALYST
│   │         VENDOR_X_INGEST, VENDOR_X_READONLY (per vendor)
│   ├─ Databases: RAW_INTERNAL, RAW_VENDOR (managed access), INTEGRATION, PRESENTATION, WORKSPACE
│   ├─ Warehouses: MSP_ELT_WH, CUST_ANALYTICS_WH, VENDOR_X_INGEST_WH (per vendor)
│   └─ Guardrails: network rules, auth policies, masking, row access, resource monitors
└─ CUST_BRAVO_PROD (same pattern)
```

## Key Files

| File | Role |
|------|------|
| `README.md` | Complete guide (6 parts + troubleshooting) |
| `sql/01_account_baseline.sql` | Roles, databases, managed access schemas, warehouses, monitors, tags, delegation SP |
| `sql/02_vendor_onboard.sql` | Parameterised vendor onboarding (SET vendor_name pattern) |
| `sql/03_vendor_offboard.sql` | Vendor offboarding: disable, transfer ownership, revoke, clean up |
| `sql/04_monitoring.sql` | Org Usage cross-account queries + per-account audit |
| `sql/05_guardrails.sql` | Network rules, auth policies, masking, row access, audit checks |
| `diagrams/architecture.md` | Mermaid diagrams (org layout, role hierarchy, data flow) |

## Adding a New Vendor to an Existing Customer

1. Open `sql/02_vendor_onboard.sql`
2. Set the three variables: `vendor_name`, `vendor_wh_size`, `vendor_ip_range`
3. Run top to bottom as ACCOUNTADMIN in the customer account
4. Create vendor users (section 8 of the script)
5. Update the customer's YAML config file
6. Verify with `SHOW GRANTS TO ROLE <VENDOR>_INGEST`

## Snowflake Objects
- No Snowflake objects are created -- this is a reference guide
- SQL scripts are templates the customer copies and adapts
- Requires: Snowflake Organisation with ACCOUNTADMIN access to customer accounts

## Gotchas
- MSP_ACCOUNT_ADMIN is **granted** ACCOUNTADMIN, not layered above it -- ACCOUNTADMIN is the hierarchy ceiling
- CUST_ADMIN user management must use the stored procedure pattern; direct CREATE USER grants are dangerous
- Vendor schemas must use `WITH MANAGED ACCESS` or vendors can grant access to their objects
- Future grants are required on vendor schemas or MSP pipelines cannot read vendor-created tables
- Network policies at user level override account-level; test vendor IP ranges before applying
- Object ownership transfer (step 4 of offboarding) must happen before dropping vendor roles
- Authentication policies with `MFA_ENROLLMENT = 'REQUIRED'` may block service accounts; use separate policies
