![Status](https://img.shields.io/badge/Status-Active-success)
![Expires](https://img.shields.io/badge/Expires-2026--06--11-yellow)

# IoT Lifecycle Demo — Agentic Operations Engine

End-to-end IoT lifecycle demonstration for **Metro Textile Services**, a fictional uniform rental and linen supply company operating in the Atlanta, GA metro area. Pivots from "cloud data warehouse" to **Agentic Operations Engine** — garments flowing through a lifecycle loop with zombie detection, retention alerts for route drivers, route efficiency analysis, and dual AI agents (CFO + Operations) powered by Snowflake Intelligence.

## Screenshots

| Fleet Map | Garment Lifecycle Pipeline |
|-----------|---------------------------|
| ![Fleet Map](images/fleet.png) | ![Garment Pipeline](images/garment-pipeline.png) |

**Fleet Map** — Live vehicle positions on an OpenStreetMap Atlanta base layer (deck.gl ScatterplotLayer). Customer dots are color-coded by risk band: red = zombie cluster, yellow = elevated risk, green = golden customer. KPI bar shows fleet metrics, zombie garment count (169), and financial exposure ($1,048). "Ask Agent" button links to Snowflake Intelligence.

**Garment Pipeline** — Customer Loop (CLEAN OUT → AT CUSTOMER → SOILED RETURN) with animated "126 ZOMBIES" badge, factory pipeline (CHECK IN → WASH → DRY → FOLD → DISPATCH → DELIVER), Retention Alerts panel with $ save values and driver talking points, and inventory table with lifecycle state color-coding (ZOMBIE in red, AT_CUSTOMER in amber, IN_PLANT in blue), days-at-location highlights (>14d red), and Life % column.

| CFO Agent | Operations Agent |
|-----------|-----------------|
| ![CFO Agent](images/cfo-agent.png) | ![Operations Agent](images/operations-agent.png) |

**CFO Agent** — Snowflake Intelligence answering "Identifying Most Profitable Customers" with healthcare invoice breakdown by payment status (PAID vs PENDING), stacked bar chart, and narrative analysis showing 82.4% collection rate.

**Operations Agent** — Snowflake Intelligence answering "What are the top 3 silent operational leaks right now?" with zombie cluster table (Peachtree General 120 zombies/$660, Dunwoody Hilton 26/$263, Smyrna Collision 19/$66.50), key observations, and recovery recommendations.

## What It Does

| Component | Feature | Tech |
|-----------|---------|------|
| **Fleet Dashboard** | Live vehicle simulation with risk-banded customer dots (red/yellow/green) | React, deck.gl ScatterplotLayer + TileLayer, SPCS |
| **Garment Pipeline** | RFID lifecycle with Customer Loop, zombie badge, retention alerts, factory pipeline | React, FastAPI polling, QUALIFY deduplication |
| **Zombie Detection** | 120+ towels stalled at C-001, scrubs near retirement at C-013, route fuel anomaly R-006 | Seeded anomalies in synthetic data |
| **Retention Alerts** | Auto-generated driver talking points with customer ID, missing tags, $ save value | V_RETENTION_ALERTS view, Operations Agent |
| **Live Simulator** | Background thread cycling garments through 9-stage loop + moving vehicles | FastAPI BackgroundTasks, Snowflake connector |
| **CFO Agent** | Natural language financial Q&A (Snowflake Intelligence) | Semantic View, Cortex Agent |
| **Operations Agent** | Zombie detection, retention alerts, route efficiency, risk correlation | Semantic View, Cortex Agent |

## Architecture

```
┌─────────────────────────────────────────────────┐
│  React Frontend (Vite + deck.gl + Tailwind)     │
│  • ScatterplotLayer: vehicles + customers       │
│  • TileLayer: OpenStreetMap base map            │
│  • Customer Loop + zombie badge + retention alerts│
│  • 5-second polling for live updates            │
├─────────────────────────────────────────────────┤
│  FastAPI Backend (Python)                       │
│  • /api/positions → simulated GPS coords        │
│  • /api/garments → V_GARMENT_LIFECYCLE view     │
│  • /api/garment-pipeline → loop + factory counts │
│  • /api/zombie-summary → zombie KPIs            │
│  • /api/retention-alerts → driver alerts         │
│  • /api/garment-events → latest 50 events       │
│  • /api/customers → risk-banded with exposure    │
│  • Background simulator thread                  │
├─────────────────────────────────────────────────┤
│  Snowpark Container Services (SPCS)             │
│  • CPU_X64_XS compute pool                      │
│  • Public endpoint → shareable URL              │
│  • EAI for OpenStreetMap tile access            │
└─────────────────────────────────────────────────┘
         ↕
┌─────────────────────────────────────────────────┐
│  Snowflake Data Layer                           │
│  • 13 tables (fleet, garments, costs, alerts)   │
│  • 10 analytics views (zombie, risk, retention) │
│  • 2 Semantic views + 2 Cortex Agents           │
└─────────────────────────────────────────────────┘
```

## Quick Start

### Step 1: Deploy data + agent (Snowsight)

1. Open Snowsight, create a new SQL worksheet
2. Paste the contents of `deploy_all.sql`
3. Click **Run All**
4. This creates all tables, views, the CFO Agent, image repo, and compute pool
5. The final output confirms success and tells you to proceed to Step 2

### Step 2: Build & push the container (terminal)

```bash
cd demo-iot-lifecycle
./build_and_push.sh
```

The script will:
- Build the React frontend natively (Node.js)
- Auto-detect your registry URL from Snowflake (via Snow CLI)
- Build the container image for linux/amd64 (Podman)
- Authenticate to the registry via Snow CLI
- Push the image

> **Requires:**
> - [Podman](https://podman.io/getting-started/installation) (no Docker license needed)
> - [Snow CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation) with a configured connection
> - [Node.js](https://nodejs.org/) for the frontend build

### Step 3: Start the service (Snowsight)

1. Open a new SQL worksheet
2. Paste the contents of `deploy_service.sql`
3. Click **Run All**
4. The last query output shows your dashboard URL in the `ingress_url` column
5. Open that URL in your browser — takes ~60 seconds on first launch

### Running the Demo

1. Open the dashboard URL
2. Click **Start Simulation** — vehicles begin moving along Atlanta routes, garments cycle through processing stages
3. Switch between **Fleet** and **Garments** tabs to show different aspects
4. The live event feed and pipeline update every 5 seconds
5. Click **Stop Simulation** when done

### Using the CFO Agent

Both agents are available in **Snowflake Intelligence** (the sidebar panel in Snowsight).

**CFO Assistant** — Ask financial questions:
- "What is our P&L for the last quarter?"
- "How much margin is at risk from unreturned garments?"

**Operations Agent** — Ask operational questions:
- "What are the top 3 silent operational leaks right now?"
- "Draft a retention alert for our highest-risk customer"
- "Which routes have fuel cost anomalies?"

### Local Development (optional)

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
| Tables | 13 TRANSIENT | Fleet, garments, events, costs, alerts, invoices, financials |
| Views | 10 | Zombie, customer risk, route efficiency, retirement, retention, financials |
| Semantic Views | `SV_IOT_FINANCIAL`, `SV_IOT_OPERATIONS` | CFO + Operations structured data |
| Agents | `CFO_ASSISTANT`, `OPERATIONS_AGENT` | Snowflake Intelligence |
| EAI | `OSM_TILES_ACCESS` | OpenStreetMap tile loading |

## Key Design Patterns

| Pattern | Where | Why |
|---------|-------|-----|
| `QUALIFY ROW_NUMBER()` | Views, pipeline query | Deduplicate to latest event per garment without correlated subqueries |
| SPCS OAuth token | `/snowflake/session/token` | Zero-credential Snowflake connection inside containers |
| EAI + Network Rule | Service spec | Allow outbound HTTPS to `tile.openstreetmap.org` for map tiles |
| Background thread | FastAPI `on_event("startup")` | Simulate live IoT data without external scheduler |
| Polling (5s) | React `useEffect` | Real-time feel without WebSocket complexity |

## Cleanup

```sql
-- Copy teardown_all.sql into a Snowsight worksheet and Run All
```

## License

Apache License 2.0.
