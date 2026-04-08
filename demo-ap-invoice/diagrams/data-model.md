# Data Model - AP Invoice Pipeline

Author: SE Community
Last Updated: 2026-04-08
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: Review and customize for your requirements.

## Overview

The AP Invoice Pipeline uses a star-like schema with INVOICE_HEADER as the central fact table. Reference tables (VENDOR_MASTER, GL_CODES) support fuzzy matching and AI classification. REVIEW_QUEUE and AUDIT_LOG capture the human-in-the-loop and auditability layers.

## Diagram

```mermaid
erDiagram
    VENDOR_MASTER ||--o{ INVOICE_HEADER : "resolves to"
    VENDOR_MASTER {
        number VENDOR_ID PK
        varchar VENDOR_NAME
        array VENDOR_ALIASES
        varchar PAYMENT_TERMS
    }
    GL_CODES ||--o{ INVOICE_LINE_ITEMS : "classifies"
    GL_CODES {
        varchar GL_CODE PK
        varchar GL_DESCRIPTION
        varchar CATEGORY
    }
    INVOICE_HEADER ||--|{ INVOICE_LINE_ITEMS : "has"
    INVOICE_HEADER ||--o{ REVIEW_QUEUE : "flagged in"
    INVOICE_HEADER ||--o{ AUDIT_LOG : "tracked by"
    INVOICE_HEADER {
        number INVOICE_ID PK
        varchar SOURCE_FILE
        varchar VENDOR_NAME_RAW
        number VENDOR_ID_RESOLVED FK
        varchar INVOICE_NUMBER
        date INVOICE_DATE
        number TOTAL_AMOUNT
        varchar PROPERTY
        number VALIDATION_SCORE
        varchar STATUS
        variant AI_EXTRACT_RAW
    }
    INVOICE_LINE_ITEMS {
        number LINE_ID PK
        number INVOICE_ID FK
        varchar DESCRIPTION
        number LINE_TOTAL
        varchar GL_CODE_SUGGESTED FK
        number GL_CODE_CONFIDENCE
        varchar GL_CODE_CONFIRMED
        boolean REVIEWER_OVERRIDE
    }
    REVIEW_QUEUE {
        number QUEUE_ID PK
        number INVOICE_ID FK
        array FLAGGED_FIELDS
        number VALIDATION_SCORE
        varchar REVIEWER_ID
        varchar RESOLUTION
    }
    AUDIT_LOG {
        number LOG_ID PK
        number INVOICE_ID FK
        varchar ACTION
        varchar ACTOR
        varchar ACTOR_TYPE
        timestamp ACTION_TS
    }
```

## Component Descriptions

| Table | Purpose |
|-------|---------|
| **VENDOR_MASTER** | Canonical vendor list with alias arrays for fuzzy matching |
| **GL_CODES** | GL account taxonomy passed to AI_CLASSIFY as category labels |
| **INVOICE_HEADER** | One row per PDF invoice with extracted fields and validation score |
| **INVOICE_LINE_ITEMS** | Many rows per invoice with AI-classified GL codes |
| **REVIEW_QUEUE** | Low-scoring invoices awaiting human review |
| **AUDIT_LOG** | Immutable record of every AI and human decision |

## Change History

See `.claude/DIAGRAM_CHANGELOG.md` or project-specific changelog.
