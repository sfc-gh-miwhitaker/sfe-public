# Weekly Shopify Pipeline Cost And Hygiene Review

Read-only. Query per-store `QUERY_ATTRIBUTION_HISTORY` using `SHOPIFY_NATIVE:*` query
tags, stage inventory, registry/schedule consistency, qualification status, and seven-day
freshness. Compare native-pipeline credits with `RECONCILIATION_BASELINE` when an incumbent
cost baseline is present. Write `/workspace/shopify/weekly-<current-date>.md` with cost by
store, anomalies, unused staged files, registered-but-inactive stores, and recommended
CoCo Desktop maintenance prompts. Do not estimate currency cost without an approved rate.
