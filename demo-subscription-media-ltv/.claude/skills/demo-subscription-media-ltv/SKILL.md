---
name: demo-subscription-media-ltv
description: "Project-specific skill for the Subscription Media LTV demo. Governed member value (gross, net, contribution, total value), CAC payback, reported vs true ROAS, Snowflake ML churn scores, discount and ad segment economics, served through a semantic view and Cortex Agent in Snowflake CoWork, with a no-context contrast agent. Use when working with this project in any AI-pair tool."
---

# Subscription Media LTV

## Purpose

Show subscription LTV, churn, and ad economics answered in Snowflake CoWork by a Cortex Agent grounded in a governed semantic view, contrasted with the same data and no business definitions.

## Architecture

```text
reference tables + generated MEMBERS / SUBSCRIPTION_PAYMENTS / VIEWING_MONTHLY / ACQUISITION_SPEND
        │
        ├─► MEMBER_VALUE (definitions) ─► DISCOUNT_ECONOMICS, AD_SEGMENT_ECONOMICS
        ├─► CHURN_FEATURES ─► CHURN_MODEL ─► CHURN_SCORES, CHURN_FEATURE_IMPORTANCE
        │
        ├─► SV_SUBSCRIPTION_MEDIA_LTV_MEMBER_VALUE ─► MEMBER_VALUE_AGENT ─┐
        └─► SV_SUBSCRIPTION_MEDIA_LTV_RAW ──────────► RAW_DATA_AGENT ────┴─► CoWork object
```

## Key Files

| File | Role |
|------|------|
| `deploy_all.sql` | Single entry point; Git fetch then `EXECUTE IMMEDIATE FROM` each script |
| `sql/02_tables/01_reference_tables.sql` | Fictional CAC, fees, CPMs, funnel, audience sizes |
| `sql/02_tables/02_generate_members_and_activity.sql` | Deterministic member, payment, viewing, spend generation |
| `sql/03_transformations/01_member_value_views.sql` | The governed definitions |
| `sql/04_cortex/01_churn_model.sql` | Feature snapshots, training, scoring |
| `sql/04_cortex/02_semantic_views.sql` | Governed and raw semantic views, verified queries |
| `sql/04_cortex/03_agents.sql` | Both agents |
| `sql/04_cortex/04_attach_cowork.sql` | Adds both agents to the CoWork object |
| `docs/01-DEMO-SCRIPT.md` | Live script with expected answers |

## Adding a New Metric

1. Compute the per-member value in `MEMBER_VALUE` (or a new view at its own grain).
2. In the governed semantic view, add a fact that applies the right mature-cohort filter, then a metric that aggregates it. A metric name must not equal a physical column name, or the view fails with a cyclic reference.
3. Add a verified query in `AI_VERIFIED_QUERIES` using logical names, and a sample question in `MEMBER_VALUE_AGENT`.
4. Redeploy `02_semantic_views.sql`, then ask the question through the agent, not Cortex Analyst directly, and record the expected answer in the demo script.

## How to Change the Synthetic Business

1. Edit rates in `01_reference_tables.sql` or hazards in `02_generate_members_and_activity.sql`.
2. Keep every draw keyed on `HASH(member_id, ...)` and the 2026-10-31 as-of date.
3. Rerun scripts 02 through 04, then re-verify every number in `docs/01-DEMO-SCRIPT.md`.

## Snowflake Objects

- Database: `SNOWFLAKE_EXAMPLE`
- Schema: `SUBSCRIPTION_MEDIA_LTV`
- Warehouse: `SFE_SUBSCRIPTION_MEDIA_LTV_WH`
- Model: `CHURN_MODEL` (SNOWFLAKE.ML.CLASSIFICATION)
- Semantic views: `SEMANTIC_MODELS.SV_SUBSCRIPTION_MEDIA_LTV_MEMBER_VALUE`, `SEMANTIC_MODELS.SV_SUBSCRIPTION_MEDIA_LTV_RAW`
- Agents: `MEMBER_VALUE_AGENT`, `RAW_DATA_AGENT`
- All objects have `COMMENT = 'DEMO: ... (Expires: 2027-01-16)'`

## Gotchas

- Verified queries written against physical tables trigger an internal "use logical names" correction that can leak into the answer text. Write them in logical names.
- Future cancellations shape the viewing drop-off but live only in a temporary table, so they never leak into a queryable object or the churn label.
- `state` has no effect on churn in the generator; it was removed from model features because the model ranked it as a spurious driver.
- The churn training label uses the 2026-07-31 snapshot; scoring uses 2026-10-31. Features read only data on or before each snapshot.
- An account with a CoWork object hides agents that are not attached to it. The attach script reports instead of failing.
- `SHOW_GLOBAL_EVALUATION_METRICS` returns `ERROR_METRIC` and `AVERAGE_TYPE`, not `METRIC_NAME`.
