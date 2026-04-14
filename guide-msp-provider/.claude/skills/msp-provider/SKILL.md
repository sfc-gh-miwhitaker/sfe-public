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
- Requires: Snowflake Organization with ACCOUNTADMIN access to customer accounts

## Gotchas
- **ToS basis for the gates:** Gate 1 ↔ §1.1 (vendor as Contractor of MSP) + §1.4(a) (no third-party access except via Data Sharing); Gate 2 ↔ §2.2(a) (Customer solely responsible for Customer Data); Gate 3 ↔ §1.4(a) service bureau prohibition — resolved by SPN Managed Applications capacity agreement. §1.4(b) is the Connected App tension (no running Snowflake for benefit of third parties). Always direct legal questions to the reader's legal team.
- **Pattern first:** establish whether the reader is a Managed App (Gates 1+2+3 = Yes), Partial MSP/integrator (Gates 1+2, No to Gate 3), or Connected App (Gate 1 = No) before advising on architecture
- **Gate 3 + ORGANIZATION_USAGE:** Partial MSPs (systems integrators) do not own the Snowflake org and cannot access `SNOWFLAKE.ORGANIZATION_USAGE`; they need the client to run Part 5 or share cost data another way
- **SPN enrollment:** Managed App providers should enroll under AI Data Cloud Products → Managed Applications; Connected App providers enroll under Connected
- MSP_ACCOUNT_ADMIN is **granted** ACCOUNTADMIN, not layered above it -- ACCOUNTADMIN is the hierarchy ceiling
- CUST_ADMIN user management must use the stored procedure pattern; direct CREATE USER grants are dangerous
- Vendor schemas must use `WITH MANAGED ACCESS` or vendors can grant access to their objects
- Future grants are required on vendor schemas or MSP pipelines cannot read vendor-created tables
- Network policies at user level override account-level; test vendor IP ranges before applying
- Object ownership transfer (step 4 of offboarding) must happen before dropping vendor roles
- Authentication policies with `MFA_ENROLLMENT = 'REQUIRED'` may block service accounts; use separate policies
- **Customer analytics access (Part 7):** four options — Data Sharing (§1.4(a) explicit carveout, preferred), B1 Snowsight User for SI product (human + MFA + `CORTEX_USER` + `CLIENT_TYPES = ('SNOWFLAKE_UI')`), B2 API-Only for Cortex Analyst REST (service account + `CORTEX_ANALYST_USER` + `CLIENT_TYPES = ('DRIVERS')` + no Snowsight), Embedded/C (MSP backend calls same Cortex Analyst API, no customer credentials). Critical nuances: `CLIENT_TYPES` is best-effort and does NOT restrict REST APIs — network policy is the real security boundary; `MFA_ENROLLMENT = REQUIRED` forces `CLIENT_TYPES` to include `SNOWFLAKE_UI` (MFA enrollment catch-22); `TYPE = SERVICE` users cannot log into Snowsight regardless of CLIENT_TYPES; `BI_READONLY`, `SI_READONLY`, `API_READONLY` are flat grant roles not in customer hierarchy; granting any non-SELECT privilege under "analytics access" crosses into full Gate 1
