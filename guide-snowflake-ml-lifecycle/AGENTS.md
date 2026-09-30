# Snowflake ML Lifecycle — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Evaluation guide for ML platform teams comparing Snowflake ML with an existing AWS
(SageMaker) stack. Five sections, one thesis: **design once, measure your own numbers.**

1. End-to-end design (Feature Store → training → Registry → inference → retraining → lineage)
2. Monitoring (model version monitors, custom metrics, alerts)
3. Live serving versus AWS — a bake-off protocol, never parity numbers
4. Cross-cloud registry (external models, sharing, replication, system of record)
5. Total compute cost of deployed models

`README.md` is the deliverable. `sql/` and `python/` are copy-paste leave-behinds; nothing is deployed.

## Conventions

- **Never publish latency, QPS, or cost parity numbers versus SageMaker.** Section 3 is a method.
- Credits, not dollars. Point at the Credit Consumption Table; do not quote per-hour rates.
- Tag every capability GA or Preview. Postgres online feature store, stream/real-time feature
  views, feature groups, and `feature_sources_per_function` are Preview.
- ML Lineage has no `FEATURE_VIEW` domain: feature views use `'TABLE'`, models use `'MODULE'`.
- Compute pools require `MIN_NODES >= 1`; the pool idles until `AUTO_SUSPEND_SECS` (default 3600).
  Service `min_instances=0` is a separate, service-level control. Do not conflate them.
- Placeholder names only: `ML_DB.ML`, `ML_WH`, `ML_CPU_POOL`, `CHURN_MODEL`.

## Key Commands

```bash
# Compile-check SQL without executing (use snowflake_sql_execute only_compile=true per statement)
ls sql/ python/
```

Pair-programmed by SE Community + Cortex Code
