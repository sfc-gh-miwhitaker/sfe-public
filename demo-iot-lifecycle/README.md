![Status](https://img.shields.io/badge/Status-Active-success)
![Expires](https://img.shields.io/badge/Expires-2026--06--11-yellow)

# IoT Lifecycle Demo -- Animated Fleet Map, RFID Tracking & CFO Agent

End-to-end IoT lifecycle demonstration for **Metro Textile Services**, a fictional uniform rental and linen supply company operating in the Atlanta, GA metro area.

## What It Does

| Component | Feature | Tech |
|-----------|---------|------|
| **Fleet Dashboard** | GPU-animated vehicle trails on dark Atlanta map with play/pause timeline | React, deck.gl TripsLayer, MapLibre, SPCS |
| **IoT Data** | RFID garment lifecycle tracking, loss rates, GPS telemetry | Streams, Views, Synthetic data |
| **CFO Agent** | Natural language financial Q&A (Snowflake Intelligence) | Semantic View, Cortex Agent |

## Architecture

```
┌─────────────────────────────────────────────────┐
│  React Frontend (Vite + deck.gl + Tailwind)     │
│  • TripsLayer animated vehicle paths            │
│  • ScatterplotLayer customers + depot           │
│  • Timeline play/pause/scrub controls           │
├─────────────────────────────────────────────────┤
│  FastAPI Backend (Python)                       │
│  • /api/telemetry → GPS_TELEMETRY table         │
│  • /api/customers → CUSTOMERS table             │
│  • /api/vehicles → FLEET_VEHICLES table         │
├─────────────────────────────────────────────────┤
│  Snowpark Container Services (SPCS)             │
│  • CPU_X64_XS compute pool                      │
│  • Public endpoint → shareable URL              │
└─────────────────────────────────────────────────┘
         ↕
┌─────────────────────────────────────────────────┐
│  Snowflake Data Layer                           │
│  • 11 tables (fleet, GPS, garments, financials) │
│  • 6 analytics views                            │
│  • Semantic view + Cortex Agent (Intelligence)  │
└─────────────────────────────────────────────────┘
```

## Quick Start

### Deploy Data + Agent (Snowsight)

1. Copy `deploy_all.sql` into a Snowsight worksheet
2. Click **Run All**
3. The CFO Agent is available in Snowflake Intelligence

### Deploy Fleet Dashboard (SPCS)

```bash
cd demo-iot-lifecycle/app

# Build and push container image
docker build -t fleet-dashboard .
docker tag fleet-dashboard <account>.registry.snowflakecomputing.com/snowflake_example/iot_lifecycle/iot_image_repo/fleet-dashboard:latest
docker push <account>.registry.snowflakecomputing.com/snowflake_example/iot_lifecycle/iot_image_repo/fleet-dashboard:latest

# Service is created by deploy_all.sql -- get the URL:
SHOW ENDPOINTS IN SERVICE SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.FLEET_DASHBOARD_SERVICE;
```

### Local Development

```bash
cd demo-iot-lifecycle/app/frontend
npm install && npm run dev

# In another terminal:
cd demo-iot-lifecycle/app/backend
pip install -r requirements.txt
SNOWFLAKE_CONNECTION_NAME=default uvicorn main:app --reload
```

## Object Catalog

| Object | Name | Purpose |
|--------|------|---------|
| Database | `SNOWFLAKE_EXAMPLE` | Shared demo database |
| Schema | `IOT_LIFECYCLE` | All project objects |
| Warehouse | `SFE_IOT_LIFECYCLE_WH` | XSMALL, auto-suspend 60s |
| Compute Pool | `IOT_FLEET_POOL` | CPU_X64_XS for SPCS |
| Service | `FLEET_DASHBOARD_SERVICE` | React dashboard container |
| Image Repo | `IOT_IMAGE_REPO` | Container registry |
| Tables | 11 TRANSIENT | Fleet, GPS, garments, events, invoices, financials |
| Views | 6 | Fleet status, garment lifecycle, financials |
| Semantic View | `SV_IOT_FINANCIAL` | CFO Agent structured data |
| Agent | `CFO_ASSISTANT` | Snowflake Intelligence |

## Cleanup

```sql
-- Copy teardown_all.sql into a Snowsight worksheet and Run All
```

## License

Apache License 2.0.
