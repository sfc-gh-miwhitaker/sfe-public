# Architecture Diagrams -- MSP Provider Guide

## Connected App vs Managed App (MSP)

Two fundamentally different patterns. Gate 1 — whether 3rd parties log directly into Snowflake and write data — is the dividing line.

```mermaid
flowchart TB
    subgraph connected [Connected App pattern]
        direction LR
        CA_APP["Provider App / UI\n(runs outside Snowflake)"]
        CA_ACCOUNT["Client's own Snowflake account\n(client retains governance + billing)"]
        CA_APP -->|"connection + queries"| CA_ACCOUNT
    end

    subgraph managed [Managed App / MSP pattern]
        direction LR
        MA_ORG["Provider's Snowflake Org\n(provider owns billing + ops)"]
        MA_ACME["CUST_ACME_PROD"]
        MA_BRAVO["CUST_BRAVO_PROD"]
        MA_OPS["MSP_OPS\n(monitoring)"]
        MA_ORG --> MA_ACME
        MA_ORG --> MA_BRAVO
        MA_ORG --> MA_OPS
    end
```

| | Connected App | Managed App (MSP) |
|-|--------------|-------------------|
| Gate 1: direct login + write | No | Yes |
| Gate 2: data responsibility | No | Yes |
| Gate 3: billing entity | Client | Provider |
| Data lives in | Client's account | Provider's org |
| SPN enrollment | AI Data Cloud Products → Connected | AI Data Cloud Products → Managed Applications |

---

## Organization Layout (Managed App / MSP Pattern)

```mermaid
flowchart TB
    subgraph org [Organization: ACME-MSP]
        OPS["MSP_OPS (us-east-1)"]
        ACME_DEV["CUST_ACME_DEV (us-east-1)"]
        ACME_PROD["CUST_ACME_PROD (us-east-1)"]
        BRAVO["CUST_BRAVO_PROD (eu-west-1)"]
        CHARLIE["CUST_CHARLIE_PROD (ap-southeast-2)"]
    end

    OPS -->|"Org Usage Views"| ACME_PROD
    OPS -->|"Org Usage Views"| BRAVO
    OPS -->|"Org Usage Views"| CHARLIE
```

## Per-Account Role Hierarchy (Gate 1 + 2: who can write, who owns the result)

```mermaid
flowchart BT
    ACCOUNTADMIN

    MSP_AA[MSP_ACCOUNT_ADMIN]
    MSP_SA[MSP_SECURITY_ADMIN]
    MSP_PE[MSP_PLATFORM_ENGINEER]
    CUST_A[CUST_ADMIN]
    CUST_AN[CUST_ANALYST]

    VX_I[VENDOR_X_INGEST]
    VX_R[VENDOR_X_READONLY]

    ACCOUNTADMIN --> MSP_AA
    SECURITYADMIN --> MSP_SA
    SYSADMIN --> MSP_PE

    MSP_SA --> MSP_AA
    MSP_PE --> MSP_SA

    CUST_AN --> CUST_A
    CUST_A --> MSP_PE

    VX_I --> MSP_PE
    VX_R --> MSP_PE
```

## Per-Account Data Flow (Gate 2: MSP owns everything past the RAW boundary)

```mermaid
flowchart LR
    subgraph vendors [Vendor Systems]
        VS[Vendor Source]
    end

    subgraph customer [Customer Systems]
        CS[Customer Source]
    end

    subgraph snowflake [Snowflake Account]
        subgraph raw [RAW Layer]
            RV[RAW_VENDOR.VENDOR_X]
            RI[RAW_INTERNAL.SRC_*]
        end
        subgraph integration [INTEGRATION Layer]
            CORE[INTEGRATION.CORE]
        end
        subgraph presentation [PRESENTATION Layer]
            ANALYTICS[PRESENTATION.ANALYTICS]
            API[PRESENTATION.API]
        end
    end

    VS -->|"Stage + COPY"| RV
    CS -->|"Stage + COPY"| RI
    RV -->|"MSP Pipelines"| CORE
    RI -->|"MSP Pipelines"| CORE
    CORE --> ANALYTICS
    CORE --> API
    API -.->|"Optional read-back"| VS
```

## Database and Schema Layout (Gate 2: Managed Access enforces who controls grants)

```mermaid
flowchart TB
    subgraph databases [Per-Account Databases]
        subgraph ri_db [RAW_INTERNAL]
            SRC[SRC_system]
        end
        subgraph rv_db [RAW_VENDOR]
            VX[VENDOR_X -- Managed Access]
            VY[VENDOR_Y -- Managed Access]
        end
        subgraph int_db [INTEGRATION]
            CORE_S[CORE -- Managed Access]
        end
        subgraph pres_db [PRESENTATION]
            ANALYTICS_S[ANALYTICS -- Managed Access]
            API_S[API -- Managed Access]
        end
        subgraph ws_db [WORKSPACE]
            MSP_S[MSP]
            CUST_S[CUST]
        end
    end
```

---

## Customer BI Tool Access (PowerBI example)

Three options with different Gate 1 positions. All three expose only `PRESENTATION.ANALYTICS` — no RAW, INTEGRATION, or WORKSPACE data leaves the managed boundary.

```mermaid
flowchart TB
    subgraph optA ["Option A: Data Sharing (ToS §1.4a explicit carveout)"]
        direction LR
        A_PBI["PowerBI"]
        A_ACCT["Customer Snowflake Account\nor MSP-provisioned Reader Account"]
        A_SHARE["CUST_ACME_ANALYTICS_SHARE\nSecure Share"]
        A_PRES["PRESENTATION.ANALYTICS\nin MSP Account"]
        A_PBI -->|"Snowflake connector"| A_ACCT
        A_ACCT -.->|"receives share"| A_SHARE
        A_SHARE --- A_PRES
    end

    subgraph optB ["Option B: Service Account (ToS §1.1 Contractor, read-only)"]
        direction LR
        B_PBI["PowerBI + gateway"]
        B_SVC["CUST_ACME_BI_SVC\nTYPE = SERVICE\nnetwork policy = gateway IP\nno MFA"]
        B_ROLE["CUST_ACME_BI_READONLY\nSELECT only on PRESENTATION"]
        B_PRES["PRESENTATION.ANALYTICS\nin MSP Account"]
        B_PBI -->|"key-pair auth"| B_SVC
        B_SVC --- B_ROLE
        B_ROLE -->|"SELECT only"| B_PRES
    end

    subgraph optC ["Option C: Embedded BI (no Gate 1 — Connected App pattern)"]
        direction LR
        C_USER["Customer user\nno Snowflake credentials"]
        C_APP["MSP Web App\nBI embed"]
        C_BE["MSP backend\nservice account"]
        C_PRES["PRESENTATION.ANALYTICS\nin MSP Account"]
        C_USER -->|"app login only"| C_APP
        C_APP -->|"server-side"| C_BE
        C_BE -->|"SELECT only\nkey-pair auth"| C_PRES
    end
```

| | Option A: Data Sharing | Option B: Service Account | Option C: Embedded |
|-|----------------------|--------------------------|-------------------|
| Gate 1 triggered | No — §1.4(a) carveout | Yes — read-only Contractor | No — app mediates |
| Customer has Snowflake credentials | Yes, in their own account | Yes, service account only | No |
| Write access possible | No — shares are read-only | No — role is SELECT only | No |
| MSP controls schema exposure | Via share definition | Via role GRANTs | Via app layer |
| Requires customer Snowflake account | Yes (or reader account) | No | No |
| Operational complexity | Low | Low | High |

---

## Snowflake Intelligence / Cortex Analyst Access

Snowflake Intelligence (the product) requires Snowsight. Cortex Analyst (the API) does not. `CLIENT_TYPES` can block Snowsight but **does not block REST APIs** — the network policy is the real security boundary.

```mermaid
flowchart TB
    subgraph optA ["Option A: Data Sharing (customer uses SI in own account)"]
        direction LR
        A_USER["Customer analyst"]
        A_ACCT["Customer Snowflake Account\nSnowflake Intelligence enabled"]
        A_SHARE["Share: PRESENTATION views\n+ Semantic Views"]
        A_PRES["PRESENTATION + Semantic Models\nin MSP Account"]
        A_USER -->|"Snowsight in own account"| A_ACCT
        A_ACCT -.->|"shared objects"| A_SHARE
        A_SHARE --- A_PRES
    end

    subgraph optB1 ["Option B1: Snowsight User — SI Product (Gate 1, human login)"]
        direction LR
        B1_USER["Customer analyst"]
        B1_LOGIN["Snowsight login\nMSP Account\nCLIENT_TYPES = SNOWFLAKE_UI\nnetwork policy + MFA"]
        B1_ROLE["CUST_ACME_SI_READONLY\n+ SNOWFLAKE.CORTEX_USER\nSELECT only"]
        B1_PRES["PRESENTATION.ANALYTICS\n+ Semantic Models\n+ Agents"]
        B1_USER -->|"direct Snowsight login"| B1_LOGIN
        B1_LOGIN --- B1_ROLE
        B1_ROLE -->|"read + AI queries"| B1_PRES
    end

    subgraph optB2 ["Option B2: API-Only User — Cortex Analyst REST (Gate 1, no Snowsight)"]
        direction LR
        B2_APP["Customer app server"]
        B2_SVC["CUST_ACME_API_SVC\nTYPE = SERVICE\nCLIENT_TYPES = DRIVERS\nnetwork policy = app server IP"]
        B2_ROLE["CUST_ACME_API_READONLY\n+ SNOWFLAKE.CORTEX_ANALYST_USER\nSELECT only"]
        B2_PRES["PRESENTATION.ANALYTICS\n+ Semantic Models"]
        B2_APP -->|"REST API\nkey-pair auth"| B2_SVC
        B2_SVC --- B2_ROLE
        B2_ROLE -->|"API queries only"| B2_PRES
    end

    subgraph optC ["Option C: Embedded — MSP calls Cortex Analyst API (no Gate 1)"]
        direction LR
        C_USER["Customer user\nno Snowflake credentials"]
        C_APP["MSP Web App\nchat interface"]
        C_BE["MSP backend\nservice account\n+ SNOWFLAKE.CORTEX_USER"]
        C_PRES["PRESENTATION.ANALYTICS\n+ Semantic Models"]
        C_USER -->|"app login only"| C_APP
        C_APP -->|"Cortex Analyst\nREST API"| C_BE
        C_BE -->|"SELECT + AI\nkey-pair auth"| C_PRES
    end
```

| | Option A: Data Sharing | Option B1: Snowsight User | Option B2: API-Only | Option C: Embedded |
|-|----------------------|-------------------------|---------------------|-------------------|
| Gate 1 triggered | No — §1.4(a) carveout | Yes — human login | Yes — credentials issued | No — app mediates |
| Snowsight access | In their own account | Yes — required for SI | No — `CLIENT_TYPES = DRIVERS` | No |
| Cortex Analyst API callable | In their own account | Yes — `CLIENT_TYPES` does not block APIs | Yes — primary access path | Yes — MSP-mediated |
| MFA required | In customer's own account | Yes — MSP-enforced | No — `TYPE = SERVICE`, key-pair | N/A |
| Write access possible | No — shares are read-only | No — role is SELECT only | No — role is SELECT only | No |
| MSP maintains semantic models | In MSP account (shared) | In MSP account (central) | In MSP account | In MSP account |
| Customer needs own SF account | Yes | No | No | No |

> **`CLIENT_TYPES` is not a security boundary.** Per Snowflake docs: *"It should not be used as the sole control to establish a security boundary. Notably, it does not restrict access to the Snowflake REST APIs."* For B1 users, the network policy (IP range) is your real enforcement. For B2, `TYPE = SERVICE` + key-pair auth + no password means Snowsight login is impossible anyway — `CLIENT_TYPES` is defense-in-depth, not primary control.

### Analytics Role Position in the Hierarchy

Both `CUST_ACME_BI_READONLY`, `CUST_ACME_SI_READONLY`, and `CUST_ACME_API_READONLY` are flat grant roles — they do not sit in the customer role hierarchy. `MSP_PLATFORM_ENGINEER` creates and owns them but they are not granted to `CUST_ADMIN`.

```mermaid
flowchart BT
    ACCOUNTADMIN
    MSP_AA[MSP_ACCOUNT_ADMIN]
    MSP_PE[MSP_PLATFORM_ENGINEER]
    CUST_A[CUST_ADMIN]
    CUST_AN[CUST_ANALYST]
    BI_RO["CUST_ACME_BI_READONLY\nservice account — PowerBI"]
    SI_RO["CUST_ACME_SI_READONLY\nhuman users — Snowsight + SI"]
    API_RO["CUST_ACME_API_READONLY\nservice account — Cortex Analyst API"]

    ACCOUNTADMIN --> MSP_AA
    SYSADMIN --> MSP_PE
    CUST_AN --> CUST_A
    CUST_A --> MSP_PE
    BI_RO -.->|"created by"| MSP_PE
    SI_RO -.->|"created by"| MSP_PE
    API_RO -.->|"created by"| MSP_PE
```
