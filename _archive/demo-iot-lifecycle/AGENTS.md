# IoT Lifecycle Demo -- Project Instructions

<!-- Global rules live in ~/.claude/CLAUDE.md (Layer 3). This file is project-specific only. -->

## Architecture
```
Synthetic Data (SQL GENERATOR + VALUES) -> 13 TRANSIENT tables
  -> 10 Analytics Views (fleet, garment lifecycle, zombies, customer risk, retention, financial)
  -> 2 Semantic Views (SV_IOT_FINANCIAL + SV_IOT_OPERATIONS)
  -> 2 Cortex Agents (CFO_ASSISTANT + OPERATIONS_AGENT) in Snowflake Intelligence
React + deck.gl frontend (Vite) + FastAPI backend -> packaged as SPCS service
  -> FLEET_DASHBOARD_SERVICE on IOT_FLEET_POOL (CPU_X64_XS)
```

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: IOT_LIFECYCLE (tables/views), SEMANTIC_MODELS (semantic views)
- Warehouse: SFE_IOT_LIFECYCLE_WH (XSMALL, auto-suspend 60s)
- Compute Pool: IOT_FLEET_POOL
- Image Repo: IOT_IMAGE_REPO
- Service: FLEET_DASHBOARD_SERVICE
- EAI: OSM_TILES_ACCESS (OpenStreetMap tile access)

## Conventions
- All tables are TRANSIENT (no Time Travel)
- Object comments: `DEMO: <description> (Expires: 2026-06-11)`
- SQL scripts numbered by execution order: 01_setup, 02_data, 03_transformations, 04_cortex
- App code in app/frontend (React + Vite + deck.gl + Tailwind) and app/backend (FastAPI)
- SFE_ prefix for account-level objects only
- GPS coordinates: Atlanta metro area (33.65-34.07 lat, -84.62 to -84.28 lng)
- SPCS auth: `/snowflake/session/token` + SNOWFLAKE_HOST/SNOWFLAKE_ACCOUNT envs
- QUALIFY ROW_NUMBER() for deduplication (no correlated subqueries)

## Key Scripts (top-level, single-purpose)
- `deploy_all.sql` -- create all data, semantic views, agents, image repo, compute pool
- `build_and_push.sh` -- build React frontend + container image, push to IOT_IMAGE_REPO
- `deploy_service.sql` -- create FLEET_DASHBOARD_SERVICE for the first time
- `update_service.sql` -- in-place ALTER SERVICE to roll new :latest image without drop/recreate
- `teardown_all.sql` -- remove everything

## Key Commands
```bash
# Step 1: data + agents (Snowsight)
# Run All on deploy_all.sql

# Step 2: build & push container (terminal)
./build_and_push.sh

# Step 3: start service (Snowsight)
# Run All on deploy_service.sql

# Re-deploy after code change: push new image then Run All on update_service.sql
```

## Related Projects
- [demo-cortex-financial-agents](../_archive/demo-cortex-financial-agents/) -- Cortex Agent pattern reference
- [demo-dataquality-metrics](../demo-dataquality-metrics/) -- Streams + Tasks pattern reference
