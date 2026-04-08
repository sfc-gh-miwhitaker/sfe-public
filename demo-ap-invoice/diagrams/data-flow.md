# Data Flow - AP Invoice Pipeline

Author: SE Community
Last Updated: 2026-04-08
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: Review and customize for your requirements.

## Overview

PDF invoices land on an internal stage, get processed by AI_EXTRACT for field extraction and AI_CLASSIFY for GL coding. A validation score determines whether an invoice is auto-approved or routed to human review. All paths converge into the PROCESSED_INVOICES view, which feeds a Cortex Analyst semantic view for NL analytics.

## Diagram

```mermaid
flowchart LR
    subgraph Ingestion
        PDF[PDF Invoices]
        STAGE["@RAW_INVOICE_STAGE"]
    end

    subgraph AI Processing
        EXTRACT[AI_EXTRACT<br/>Field Extraction]
        MATCH[Vendor Fuzzy Match<br/>JAROWINKLER_SIMILARITY]
        SCORE[Validation Scoring<br/>0.0 - 1.0]
        CLASSIFY[AI_CLASSIFY<br/>GL Code Suggestion]
    end

    subgraph Storage
        HEADER[INVOICE_HEADER]
        LINES[INVOICE_LINE_ITEMS]
        QUEUE[REVIEW_QUEUE]
        AUDIT[AUDIT_LOG]
    end

    subgraph Automation
        STREAM[INVOICE_HEADER_STREAM]
        TASK[VALIDATE_INVOICES_TASK<br/>Every 5 min]
    end

    subgraph Analytics
        VIEW[PROCESSED_INVOICES<br/>View]
        SV[SV_AP_INVOICE<br/>Semantic View]
        SIS[Streamlit Dashboard]
    end

    PDF -->|Upload / PUT| STAGE
    STAGE -->|SP_PROCESS_INVOICE| EXTRACT
    EXTRACT --> MATCH
    MATCH --> SCORE
    EXTRACT --> CLASSIFY
    CLASSIFY --> LINES

    SCORE -->|"Score ≥ 0.75"| HEADER
    SCORE -->|"Score < 0.75"| QUEUE
    HEADER --> STREAM
    STREAM -->|SYSTEM$STREAM_HAS_DATA| TASK
    TASK --> HEADER

    HEADER --> VIEW
    LINES --> VIEW
    QUEUE --> SIS
    VIEW --> SV
    SV -->|Cortex Analyst| SIS
    HEADER --> AUDIT
    QUEUE --> AUDIT
```

## Component Descriptions

| Component | Role |
|-----------|------|
| **@RAW_INVOICE_STAGE** | Internal stage with directory table for PDF landing zone |
| **AI_EXTRACT** | Extracts vendor name, invoice number, date, PO reference, total amount from PDFs |
| **Vendor Fuzzy Match** | Resolves extracted vendor name against VENDOR_MASTER using alias array + JAROWINKLER_SIMILARITY |
| **Validation Scoring** | Composite score (0-1) from field completeness, format checks, vendor match success |
| **AI_CLASSIFY** | Classifies line item descriptions into GL codes from the GL_CODES taxonomy |
| **INVOICE_HEADER_STREAM** | Append-only stream tracking new extractions |
| **VALIDATE_INVOICES_TASK** | Scheduled task that routes new invoices based on validation threshold |
| **PROCESSED_INVOICES** | Joined view of headers + lines + vendors for analytics |
| **SV_AP_INVOICE** | Semantic view enabling natural language queries via Cortex Analyst |
| **Streamlit Dashboard** | 3-panel UI: pipeline status, review queue, analytics chat |

## Change History

See `.claude/DIAGRAM_CHANGELOG.md` or project-specific changelog.
