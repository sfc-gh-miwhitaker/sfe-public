---
name: demo-iot-lifecycle
description: "IoT lifecycle demo with live fleet map, RFID garment tracking, and CFO financial agent. Triggers: IoT, fleet tracking, RFID, garment lifecycle, pydeck map, CFO agent, uniform rental, linen supply, GPS telemetry, semantic view financial."
---

# IoT Lifecycle Demo

## Purpose
End-to-end IoT lifecycle demonstration for a uniform rental and linen supply company (Metro Textile Services) operating in Atlanta, GA. Combines real-time fleet tracking via GPS telemetry, RFID garment lifecycle management, and a CFO-facing Cortex Agent for financial analysis.

## Architecture
```
FLEET_VEHICLES (12) + GPS_TELEMETRY (~100 pings)
  → V_FLEET_STATUS → Streamlit Fleet Map (pydeck)

GARMENTS (40) + GARMENT_EVENTS (~42 events)
  → V_GARMENT_LIFECYCLE, V_GARMENT_LOSS_RATE → IoT Dashboard

FINANCIAL_ACTUALS + FINANCIAL_BUDGET (24 months x 15 GL codes)
  → SV_IOT_FINANCIAL semantic view → CFO_ASSISTANT agent → CFO Chat tab
```

## Key Files

| File | Purpose |
|------|---------|
| `deploy_all.sql` | One-click deployment via Snowsight Run All |
| `sql/02_data/01_create_tables.sql` | 11 TRANSIENT tables for fleet, garments, finance |
| `sql/02_data/02_load_sample_data.sql` | All synthetic data including Atlanta GPS coords |
| `sql/03_transformations/01_create_views.sql` | 6 analytics views |
| `sql/04_cortex/01_create_semantic_view.sql` | Financial semantic view with verified queries |
| `sql/04_cortex/02_create_agent.sql` | CFO Assistant agent + Intelligence registration |
| `streamlit/streamlit_app.py` | 3-tab app: Fleet Map, IoT Dashboard, CFO Chat |
| `teardown_all.sql` | Complete cleanup preserving shared infra |

## Extension Playbook: Adding a New Vehicle Route

1. Add the vehicle to `FLEET_VEHICLES` in `02_load_sample_data.sql`
2. Add a route in `ROUTES` linking the vehicle to customer stops
3. Generate GPS telemetry points along the route path (lat/lng between depot and stops)
4. The `V_FLEET_STATUS` view automatically picks up the new vehicle
5. Streamlit map renders new route paths via the PathLayer

## Snowflake Objects

| Object | Name |
|--------|------|
| Schema | `SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE` |
| Warehouse | `SFE_IOT_LIFECYCLE_WH` |
| Tables | 11 TRANSIENT (fleet, customers, routes, GPS, garments, events, invoices, GL, financials) |
| Views | `V_FLEET_STATUS`, `V_GARMENT_LIFECYCLE`, `V_GARMENT_LOSS_RATE`, `V_ROUTE_EFFICIENCY`, `V_FINANCIAL_SUMMARY`, `V_REVENUE_BY_CUSTOMER` |
| Stream | `GPS_TELEMETRY_STREAM` (append-only) |
| Task | `REFRESH_FLEET_STATUS` (5-minute, created SUSPENDED) |
| Semantic View | `SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_IOT_FINANCIAL` |
| Agent | `CFO_ASSISTANT` (cortex_analyst_text_to_sql + data_to_chart) |
| Streamlit | `IOT_LIFECYCLE_DASHBOARD` |

## Gotchas

- pydeck requires External Offerings Terms acknowledgement in warehouse Streamlit runtime
- GPS telemetry covers a single sample day (2026-04-15) for vehicles V-001 through V-005 only
- Financial data uses randomized multipliers -- exact dollar amounts vary between deployments
- The garment INSERT uses GENERATOR + seq4() so garment IDs are deterministic (G-0000 through G-0039)
- CFO Chat in Streamlit uses SEMANTIC_VIEW_QUERY function (not the Agent REST API directly)
- Task is created SUSPENDED for demo safety -- manually resume if needed
- Teardown must remove agent from Intelligence before dropping the agent object
