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
