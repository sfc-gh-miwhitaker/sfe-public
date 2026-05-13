# Data Flow - IoT Lifecycle Demo

Author: SE Community
Last Updated: 2026-05-13
Expires: 2026-06-11
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: Review and customize for your requirements.

## Overview
Synthetic data flows from 13 TRANSIENT tables into 10 analytics views. Two semantic views feed two Cortex Agents (CFO + Operations) accessible in Snowflake Intelligence. A FastAPI + React frontend deployed as an SPCS service exposes the live fleet map and garment pipeline UI.

## Diagram

```mermaid
flowchart LR
  subgraph synthetic [Synthetic Data - 13 TRANSIENT Tables]
    Fleet[FLEET_VEHICLES]
    GPS[GPS_TELEMETRY]
    Customers[CUSTOMERS]
    Routes[ROUTES]
    Garments[GARMENTS]
    Events[GARMENT_EVENTS]
    GarmentCosts[GARMENT_COSTS]
    Alerts[RETENTION_ALERTS]
    Invoices[INVOICES]
    GLCodes[GL_CODES]
    Actuals[FINANCIAL_ACTUALS]
    Budget[FINANCIAL_BUDGET]
  end

  subgraph views [10 Analytics Views]
    VFleet[V_FLEET_STATUS]
    VLifecycle[V_GARMENT_LIFECYCLE]
    VZombie[V_ZOMBIE_GARMENTS]
    VRisk[V_CUSTOMER_RISK]
    VRetire[V_RETIREMENT_RISK]
    VRetention[V_RETENTION_ALERTS]
    VRoute[V_ROUTE_EFFICIENCY]
    VLoss[V_GARMENT_LOSS_RATE]
    VFinance[V_FINANCIAL_SUMMARY]
    VRevenue[V_REVENUE_BY_CUSTOMER]
  end

  subgraph cortex [Cortex Layer]
    SVF[SV_IOT_FINANCIAL]
    SVO[SV_IOT_OPERATIONS]
    AgentCFO[CFO_ASSISTANT]
    AgentOps[OPERATIONS_AGENT]
  end

  subgraph app [SPCS Service: FLEET_DASHBOARD_SERVICE]
    direction TB
    Backend[FastAPI Backend]
    Frontend[React + deck.gl Frontend]
    Backend --> Frontend
  end

  subgraph users [Users]
    Browser[Browser]
    SI[Snowflake Intelligence]
  end

  Fleet --> VFleet
  GPS --> VFleet
  Routes --> VRoute
  Garments --> VLifecycle
  Events --> VLifecycle
  Garments --> VZombie
  Garments --> VRetire
  Customers --> VRisk
  Garments --> VRisk
  Customers --> VRetention
  Alerts --> VRetention
  Garments --> VLoss
  Actuals --> VFinance
  Budget --> VFinance
  GLCodes --> VFinance
  Invoices --> VRevenue
  Customers --> VRevenue

  Actuals --> SVF
  Budget --> SVF
  GLCodes --> SVF
  Invoices --> SVF
  Customers --> SVF
  GarmentCosts --> SVF
  SVF --> AgentCFO

  Garments --> SVO
  Customers --> SVO
  Routes --> SVO
  GarmentCosts --> SVO
  Alerts --> SVO
  SVO --> AgentOps

  VFleet --> Backend
  GPS --> Backend
  Customers --> Backend
  VLifecycle --> Backend
  VZombie --> Backend
  VRetention --> Backend
  Events --> Backend

  Frontend --> Browser
  AgentCFO --> SI
  AgentOps --> SI
  Browser -->|Ask Agent link| SI
```

## Component Descriptions

| Layer | Component | Purpose |
|-------|-----------|---------|
| Data | 13 TRANSIENT tables | Synthetic seed data; fleet, garments, customers, financials, alerts |
| Views | `V_ZOMBIE_GARMENTS`, `V_CUSTOMER_RISK`, `V_RETENTION_ALERTS` | Power the agentic operations narrative |
| Views | `V_GARMENT_LIFECYCLE`, `V_FLEET_STATUS` | Power the live React dashboard |
| Views | `V_FINANCIAL_SUMMARY`, `V_REVENUE_BY_CUSTOMER` | Power the CFO P&L narrative |
| Semantic | `SV_IOT_FINANCIAL` | Verified queries for monthly P&L, budget variance, top customers |
| Semantic | `SV_IOT_OPERATIONS` | Verified queries for silent leaks, zombie summary, fuel anomalies |
| Agent | `CFO_ASSISTANT` | Financial Q&A in Snowflake Intelligence |
| Agent | `OPERATIONS_AGENT` | Zombie / retention / route Q&A in Snowflake Intelligence |
| App | `FLEET_DASHBOARD_SERVICE` | SPCS-hosted React + FastAPI dashboard with deck.gl map |

## Change History
See `.claude/DIAGRAM_CHANGELOG.md` or project-specific changelog.
