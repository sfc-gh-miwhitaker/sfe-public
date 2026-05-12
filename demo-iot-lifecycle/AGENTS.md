# IoT Lifecycle Demo -- Project Instructions

## Architecture
```
Synthetic Data (SQL VALUES) → 11 TRANSIENT tables
  → 6 Analytics Views (fleet status, garment lifecycle, financial summary)
  → Semantic View (SV_IOT_FINANCIAL) → CFO_ASSISTANT Agent
  → Streamlit Dashboard (3 tabs: Fleet Map, IoT Dashboard, CFO Chat)
```

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: IOT_LIFECYCLE
- Warehouse: SFE_IOT_LIFECYCLE_WH
- Semantic Views: SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS

## Conventions
- All tables are TRANSIENT (no Time Travel)
- Object comments: `DEMO: <description> (Expires: 2026-06-11)`
- SQL scripts numbered by execution order: 01_setup, 02_data, 03_transformations, 04_cortex, 05_streamlit
- SFE_ prefix for account-level objects only
- GPS coordinates: Atlanta metro area (33.65-34.07 lat, -84.62 to -84.28 lng)

## Key Commands
```bash
# Deploy (in Snowsight)
# Copy deploy_all.sql → Paste into worksheet → Run All

# Teardown
# Copy teardown_all.sql → Paste into worksheet → Run All

# Local Streamlit development
cd demo-iot-lifecycle/streamlit
streamlit run streamlit_app.py
```

## Related Projects
- [demo-cortex-financial-agents](../_archive/demo-cortex-financial-agents/) -- Cortex Agent pattern reference
- [demo-dataquality-metrics](../demo-dataquality-metrics/) -- Streams + Tasks pattern reference
