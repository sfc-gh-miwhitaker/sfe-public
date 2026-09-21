# Weekly Shopify Pipeline Cost And Hygiene Review

Read-only. Query per-store `QUERY_ATTRIBUTION_HISTORY` using `SHOPIFY_NATIVE:*` query
tags, stage inventory, registry/schedule consistency, qualification status, and seven-day
freshness. Compare native-pipeline credits with the incumbent cost baseline when one is recorded.
Also check `SHOPIFY_CONTROL.META.V_CONTRACT_CONFORMANCE` and the grain smoke test. Write `/workspace/shopify/weekly-<current-date>.md` with cost by
store, anomalies, unused staged files, registered-but-inactive stores, and recommended
CoCo Desktop maintenance prompts. Do not estimate currency cost without an approved rate.
