![Status](https://img.shields.io/badge/Status-Active-success)
![Expires](https://img.shields.io/badge/Expires-2026--06--11-yellow)

# IoT Lifecycle Demo -- Fleet Map, RFID Tracking & CFO Agent

End-to-end IoT lifecycle demonstration for **Metro Textile Services**, a fictional uniform rental and linen supply company operating in the Atlanta, GA metro area.

## What It Does

| Tab | Feature | Snowflake Features |
|-----|---------|--------------------|
| **Fleet Map** | Live pydeck map of delivery vehicles moving across Atlanta | Streamlit, pydeck, GPS telemetry |
| **IoT Dashboard** | RFID garment lifecycle tracking, loss rates, event logs | Streams, Views, Synthetic IoT data |
| **CFO Chat** | Natural language financial Q&A via Cortex Agent | Semantic View, Cortex Agent, Intelligence |

## Quick Start

### Deploy in Snowsight (recommended)

1. Copy `deploy_all.sql` into a new Snowsight SQL worksheet
2. Click **Run All**
3. Navigate to **Projects > Streamlit** and open **IoT Lifecycle Dashboard**

### Deploy with AI Assistant

```bash
cd demo-iot-lifecycle
# Tell your AI assistant: "Help me deploy this project"
```

## Object Catalog

| Object | Name | Purpose |
|--------|------|---------|
| Database | `SNOWFLAKE_EXAMPLE` | Shared demo database |
| Schema | `IOT_LIFECYCLE` | All project tables and views |
| Warehouse | `SFE_IOT_LIFECYCLE_WH` | XSMALL, auto-suspend 60s |
| Tables | 11 TRANSIENT | Fleet, GPS, garments, events, invoices, financials |
| Views | 6 | Fleet status, garment lifecycle, loss rates, financials |
| Semantic View | `SV_IOT_FINANCIAL` | Financial analysis for Cortex Analyst |
| Agent | `CFO_ASSISTANT` | CFO-facing financial Q&A agent |
| Streamlit | `IOT_LIFECYCLE_DASHBOARD` | 3-tab dashboard |

## Synthetic Data

All data is generated via inline SQL VALUES -- no external files or stages required.

- **12 fleet vehicles** across 3 depots (Atlanta Central, Marietta, Decatur)
- **20 customers** across Atlanta metro (hospitals, hotels, restaurants, factories)
- **8 delivery routes** covering different neighborhoods
- **~100 GPS telemetry points** for 5 vehicles on a sample day
- **40 RFID-tagged garments** (scrubs, linens, shop towels, floor mats)
- **42 garment lifecycle events** (check-in, wash, dry, fold, dispatch, deliver, lost)
- **30 invoices** with line items
- **24 months of financial data** (actuals + budget) across 15 GL codes

## Cost Estimate

| Resource | Estimate |
|----------|----------|
| Warehouse | ~$0.02/deployment (XSMALL, < 30s total) |
| Storage | < 1 MB (all TRANSIENT tables) |
| Agent queries | ~$0.01-0.03 per question |

## Cleanup

```sql
-- Copy teardown_all.sql into a Snowsight worksheet and Run All
```

## License

Apache License 2.0. See [LICENSE](../LICENSE).
