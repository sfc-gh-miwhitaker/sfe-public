---
name: msp-provider
description: "MSP multi-tenant Snowflake guide with vendor Snowsight access. Use when: MSP architecture, vendor onboarding, multi-tenant snowflake, managed service provider, 3rd party access, vendor isolation, managed access schema, Connected App vs Managed App, Snowflake partner pattern, SPN Managed Applications, Gate 1 direct login, Gate 2 data responsibility, Gate 3 billing, systems integrator Snowflake, which pattern am I."
---

# MSP Provider Guide

## Purpose
One concrete architecture for per-customer Snowflake accounts where MSP staff, customer users, and 3rd-party vendors coexist. This is the **Managed App (MSP)** pattern in Snowflake's official terminology: the provider hosts data and workloads in their own org and answers Yes to all three gates:

| Gate | Question | MSP answer |
|------|----------|------------|
| 1 | Do 3rd parties log directly into Snowflake and write data? | Yes |
| 2 | Is the provider fully responsible for data quality and compliance? | Yes |
| 3 | Does the provider's Snowflake bill include customer consumption? | Yes |

A **Connected App** provider (Gate 1 = No, data stays in client's account) belongs in a different pattern. See Native Apps or Data Sharing instead.

Covers role hierarchy, managed access schemas, vendor onboarding/offboarding, network rules, authentication policies, monitoring, and cost attribution.

## Architecture
```
Organization: MSP-US
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
| `README.md` | Complete guide (7 parts + troubleshooting) |
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
- Requires: Snowflake Organization with ACCOUNTADMIN access to customer accounts

## Key Constraints
- **Pattern first:** establish whether the reader is a Managed App (Gates 1+2+3 = Yes), Partial MSP/integrator (Gates 1+2, No to Gate 3), or Connected App (Gate 1 = No) before advising on architecture
- MSP_ACCOUNT_ADMIN is **granted** ACCOUNTADMIN, not layered above it — ACCOUNTADMIN is the hierarchy ceiling
- Object ownership transfer (step 4 of offboarding) must happen before dropping vendor roles
- See README.md for complete technical constraints, ToS context, analytics access options (Part 7), and troubleshooting
