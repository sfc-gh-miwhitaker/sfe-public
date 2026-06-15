# Data Model - IoT Lifecycle Demo

Author: SE Community
Last Updated: 2026-05-13
Expires: 2026-06-11
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: Review and customize for your requirements.

## Overview
Schema for Metro Textile Services -- 13 TRANSIENT tables in `SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE` covering fleet GPS telemetry, RFID-tagged garment lifecycle, customer risk attributes, retention alerts, route efficiency, and monthly P&L. Two semantic views layer on top: `SV_IOT_FINANCIAL` for the CFO Agent and `SV_IOT_OPERATIONS` for the Operations Agent.

## Diagram

```mermaid
erDiagram
    FLEET_VEHICLES ||--o{ GPS_TELEMETRY : "sends telemetry"
    ROUTES ||--o{ CUSTOMERS : "serves"
    CUSTOMERS ||--o{ INVOICES : "billed"
    CUSTOMERS ||--o{ GARMENTS : "assigned"
    CUSTOMERS ||--o{ RETENTION_ALERTS : "triggers"
    GARMENTS ||--o{ GARMENT_EVENTS : "tracked by"
    GARMENT_COSTS ||--o{ GARMENTS : "benchmarks"
    INVOICES ||--o{ INVOICE_LINE_ITEMS : "contains"
    GL_CODES ||--o{ FINANCIAL_ACTUALS : "categorizes"
    GL_CODES ||--o{ FINANCIAL_BUDGET : "categorizes"

    FLEET_VEHICLES {
        varchar VEHICLE_ID PK
        varchar LICENSE_PLATE
        varchar DRIVER_NAME
        varchar VEHICLE_TYPE
        varchar HOME_DEPOT
        varchar STATUS
    }

    GPS_TELEMETRY {
        number TELEMETRY_ID PK
        varchar VEHICLE_ID FK
        timestamp TIMESTAMP
        float LATITUDE
        float LONGITUDE
        number SPEED_MPH
        varchar ENGINE_STATUS
    }

    ROUTES {
        varchar ROUTE_ID PK
        varchar ROUTE_NAME
        varchar DAY_OF_WEEK
        number ESTIMATED_MILES
        number FUEL_COST_USD
        number AVG_FUEL_COST_USD
    }

    CUSTOMERS {
        varchar CUSTOMER_ID PK
        varchar CUSTOMER_NAME
        varchar INDUSTRY
        float LATITUDE
        float LONGITUDE
        varchar ROUTE_ID FK
        number MONTHLY_VALUE
        number CSAT_SCORE
        number RETURN_RATE_PCT
        number INVOICE_DISPUTE_COUNT
    }

    GARMENTS {
        varchar GARMENT_ID PK
        varchar RFID_TAG
        varchar GARMENT_TYPE FK
        varchar CUSTOMER_ID FK
        varchar STATUS
        varchar LIFECYCLE_STATE
        number WASH_COUNT
        number USEFUL_LIFE_CYCLES
        number REPLACEMENT_COST
        number DAYS_AT_LOCATION
    }

    GARMENT_EVENTS {
        number EVENT_ID PK
        varchar GARMENT_ID FK
        varchar EVENT_TYPE
        timestamp EVENT_TIMESTAMP
        varchar LOCATION
        varchar SCANNER_ID
    }

    GARMENT_COSTS {
        varchar GARMENT_TYPE PK
        number REPLACEMENT_COST
        number USEFUL_LIFE_CYCLES
        number AVG_LAUNDERING_COST_LB
    }

    RETENTION_ALERTS {
        varchar ALERT_ID PK
        varchar CUSTOMER_ID FK
        date ALERT_DATE
        number MISSING_TAG_COUNT
        number FINANCIAL_SAVE_USD
        varchar DRIVER_TALKING_POINT
        varchar STATUS
    }

    INVOICES {
        varchar INVOICE_ID PK
        varchar CUSTOMER_ID FK
        date INVOICE_DATE
        number TOTAL_AMOUNT
        varchar PAYMENT_STATUS
    }

    INVOICE_LINE_ITEMS {
        number LINE_ID PK
        varchar INVOICE_ID FK
        varchar DESCRIPTION
        number AMOUNT
    }

    GL_CODES {
        varchar GL_CODE PK
        varchar GL_NAME
        varchar GL_CATEGORY
        varchar GL_TYPE
    }

    FINANCIAL_ACTUALS {
        varchar PERIOD_ID PK
        number FISCAL_YEAR
        varchar FISCAL_QUARTER
        date FISCAL_MONTH
        varchar GL_CODE FK
        number AMOUNT
    }

    FINANCIAL_BUDGET {
        varchar PERIOD_ID PK
        varchar GL_CODE FK
        number BUDGET_AMOUNT
    }
```

## Component Descriptions

| Table | Purpose |
|-------|---------|
| `FLEET_VEHICLES` | 5 delivery trucks with driver and depot assignments |
| `GPS_TELEMETRY` | Streamed lat/lng/speed updates from each vehicle |
| `ROUTES` | Named delivery runs with fuel cost vs benchmark for anomaly detection |
| `CUSTOMERS` | 20 Atlanta-area sites with risk attributes (CSAT, return rate, disputes) |
| `GARMENTS` | RFID-tagged inventory with `LIFECYCLE_STATE` (IN_PLANT, AT_CUSTOMER, ZOMBIE, etc.) |
| `GARMENT_EVENTS` | Append-only event log for the 9-stage lifecycle loop |
| `GARMENT_COSTS` | Industry benchmark replacement cost and useful life by garment type |
| `RETENTION_ALERTS` | Pre-drafted driver talking points with $ save value |
| `INVOICES` / `INVOICE_LINE_ITEMS` | Customer billing with PAID/PENDING/OVERDUE status |
| `GL_CODES` / `FINANCIAL_ACTUALS` / `FINANCIAL_BUDGET` | Monthly P&L, fiscal year starts Feb 1 |

## Change History
See `.claude/DIAGRAM_CHANGELOG.md` or project-specific changelog.
