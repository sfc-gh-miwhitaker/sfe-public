![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2026--08--28-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake Adaptive Compute

**Adaptive Compute removes the warehouse sizing decision.** Instead of choosing XS–4XL and tuning multi-cluster counts, you set a performance cap and a throughput multiplier — Snowflake handles everything else from a shared compute pool dedicated to your account.

**Audience:** Snowflake administrators who manage warehouses today and need to understand what Adaptive changes operationally.
**Created:** 2026-07-29 | **Expires:** 2026-08-28 | **Status:** ACTIVE

Pair-programmed by SE Community + Cortex Code

> **No support provided.** Reference only; test before relying on it in production. Every SQL claim verified against Snowflake docs on the created date above; re-verify before quoting.

**Docs:** https://docs.snowflake.com/en/user-guide/warehouses-adaptive

---

## What Changed

Standard warehouses (Gen1 and Gen2) use a fixed-size compute model. You pick a size, optionally enable multi-cluster scaling, and manage QAS separately. Adaptive replaces all of that.

| Concept | Standard (Gen1/Gen2) | Adaptive |
|---|---|---|
| **Compute model** | Fixed warehouse size (XS–4XL) | Query-level resource allocation from shared pool |
| **Concurrency** | Multi-cluster with min/max counts | `QUERY_THROUGHPUT_MULTIPLIER` — system manages the pool |
| **Sizing** | You choose and manage | Snowflake selects resources per query, up to your cap |
| **QAS** | Separate charge, explicit enable/disable | Included in compute credits automatically |
| **Resume behavior** | Suspend/resume cycle | Always enabled (or explicitly disabled) |
| **Billing granularity** | Per-second warehouse uptime | Per-query credit attribution |

**Key distinction:** Gen2 is a better engine under the same compute model. Adaptive removes the model entirely. Both Gen1 and Gen2 warehouses can convert to Adaptive.

---

## The Two Parameters You Control

Adaptive warehouses expose exactly two tuning knobs:

### MAX_QUERY_PERFORMANCE_LEVEL

The maximum level of performance enhancements Adaptive Compute will apply to any single query. Smaller or simpler queries may receive less than the cap.

**Values:** `XSMALL`, `SMALL`, `MEDIUM`, `LARGE`, `XLARGE`, `XXLARGE`, `XXXLARGE`, `X4LARGE`
**Default (greenfield):** `XLARGE`

Think of this as the ceiling on how much compute a single query can consume. It replaces the warehouse size decision.

### QUERY_THROUGHPUT_MULTIPLIER

A scaling factor that controls concurrent throughput capacity for queries running at the maximum performance level. This is not a count of parallel queries — it's a multiplier on capacity.

**Values:** Integer ≥ 2, or `0` for unlimited
**Default (greenfield):** `2`

Think of this as replacing multi-cluster configuration. Higher values allow more concurrent workload at peak.

---

## When Adaptive Is a Good Fit

| Good candidates | Poor candidates |
|---|---|
| Mixed workloads where query sizes vary widely | Snowpark-optimized warehouses (not supported) |
| High-concurrency workloads using multi-cluster or QAS | Interactive warehouses (not supported) |
| Teams that struggle to pick the right warehouse size | X5LARGE or X6LARGE warehouses (not supported) |
| Any workload currently paying separate QAS charges | HTAP / key-value lookup patterns |
| Operational simplicity is a priority | SLA-sensitive workloads requiring predictable, explicit control |

**Performance framing:** Adaptive delivers generally better performance at similar costs to Gen2. It is a performance and simplicity improvement — not a cost-reduction feature.

---

## Converting an Existing Warehouse

### Prerequisites

1. **Enterprise edition or above** (Enterprise, Business Critical, VPS)
2. **Supported region** — check [the docs](https://docs.snowflake.com/en/user-guide/warehouses-adaptive) for current region availability

Verify both before attempting conversion:

```sql
-- Check region
SELECT CURRENT_REGION();

-- Check edition (requires ORGADMIN or check Snowsight → Admin → Account)
SHOW ORGANIZATION ACCOUNTS LIKE CURRENT_ACCOUNT();
```

### The Conversion

Zero-downtime, live operation. Running queries are not interrupted. No need to suspend first.

```sql
ALTER WAREHOUSE my_warehouse SET WAREHOUSE_TYPE = 'ADAPTIVE';
```

**You do not need to set parameters manually.** Snowflake automatically derives `MAX_QUERY_PERFORMANCE_LEVEL` and `QUERY_THROUGHPUT_MULTIPLIER` from your existing warehouse configuration (size, cluster count, QAS settings). Tune afterward if needed.

### Rollback

Also zero-downtime:

```sql
ALTER WAREHOUSE my_warehouse SET WAREHOUSE_TYPE = 'STANDARD';
```

### Bulk Conversion

For migrating many warehouses at once:

```sql
-- Dry run first (no changes made)
SELECT SYSTEM$BULK_UPDATE_WH(
  'WAREHOUSE_TYPE',
  'ADAPTIVE',
  '{"WAREHOUSE_TYPE": "STANDARD"}',
  'DRY_RUN'
);

-- Execute after reviewing dry run results
SELECT SYSTEM$BULK_UPDATE_WH(
  'WAREHOUSE_TYPE',
  'ADAPTIVE',
  '{"WAREHOUSE_TYPE": "STANDARD"}',
  'ACTIVE'
);
```

### Enable / Disable

Adaptive warehouses use `ENABLE`/`DISABLE` instead of `SUSPEND`/`RESUME`:

```sql
-- Block all new query submissions
ALTER WAREHOUSE my_warehouse DISABLE;

-- Re-allow query submissions
ALTER WAREHOUSE my_warehouse ENABLE;
```

Check state via `SHOW WAREHOUSES` — the `STATE` column shows `ENABLED` or `DISABLED`.

---

## Creating a New Adaptive Warehouse

```sql
-- Minimal
CREATE ADAPTIVE WAREHOUSE my_new_wh;

-- With explicit parameters
CREATE ADAPTIVE WAREHOUSE my_new_wh
  WITH MAX_QUERY_PERFORMANCE_LEVEL = XLARGE
       QUERY_THROUGHPUT_MULTIPLIER = 2;
```

Standard warehouse properties (`WAREHOUSE_SIZE`, `MIN_CLUSTER_COUNT`, `MAX_CLUSTER_COUNT`, `SCALING_POLICY`) cannot be set on an adaptive warehouse.

---

## Billing and Monitoring

### What Changes

| Before (Standard) | After (Adaptive) |
|---|---|
| Per-second warehouse uptime billing | Per-query credit attribution |
| QAS charged separately | QAS included in compute credits |
| `WAREHOUSE_METERING_HISTORY` for aggregates | Same view still works |
| No per-query cost visibility | `QUERY_METERING_HISTORY` for per-query credits |

### Key Views

| View | What it shows |
|---|---|
| `QUERY_METERING_HISTORY` | Per-query credits (365-day retention, ~1h latency) |
| `WAREHOUSE_METERING_HISTORY` | Aggregated warehouse-level billing |
| `QUERY_HISTORY` | Identify adaptive queries via `warehouse_size = 'ADAPTIVE'` |
| `WAREHOUSE_LOAD_HISTORY` | Queuing behavior for tuning decisions |
| `WAREHOUSE_EVENTS_HISTORY` | Conversion audit trail (`EVENT_NAME = 'CONVERT_WAREHOUSE'`) |

### Top Queries by Cost (Last 7 Days)

```sql
SELECT
    query_id,
    SUM(credits_used)               AS total_credits,
    SUM(credits_used_compute)       AS compute_credits,
    SUM(credits_used_cloud_services) AS cloud_services_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_METERING_HISTORY
WHERE warehouse_name = 'MY_WAREHOUSE'
  AND query_start_time >= DATEADD(day, -7, CURRENT_DATE())
GROUP BY query_id
ORDER BY total_credits DESC
LIMIT 20;
```

Long-running queries produce one row per metering hour — always `GROUP BY query_id` with `SUM()`.

---

## Tuning After Conversion

### Queries are queueing → increase QUERY_THROUGHPUT_MULTIPLIER

Diagnose:

```sql
SELECT
    DATE_TRUNC('hour', start_time)  AS hour,
    AVG(avg_queued_load)            AS avg_queued,
    MAX(avg_queued_load)            AS peak_queued
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_LOAD_HISTORY
WHERE warehouse_name = 'MY_WAREHOUSE'
  AND start_time >= DATEADD(day, -7, CURRENT_DATE())
GROUP BY 1
ORDER BY avg_queued DESC
LIMIT 24;
```

If `avg_queued_load` is consistently > 0:

```sql
ALTER WAREHOUSE my_warehouse
  SET QUERY_THROUGHPUT_MULTIPLIER = 4;  -- increase from current value
```

### Single queries running slowly → increase MAX_QUERY_PERFORMANCE_LEVEL

```sql
ALTER WAREHOUSE my_warehouse
  SET MAX_QUERY_PERFORMANCE_LEVEL = XXLARGE;  -- one level up from current
```

Hard cap is `X4LARGE`. If already there, investigate query optimization instead.

### Costs feel high → understand the tradeoff

Reducing parameters trades performance for lower cost. Options:

```sql
-- Reduce throughput capacity (~20% decrease)
ALTER WAREHOUSE my_warehouse
  SET QUERY_THROUGHPUT_MULTIPLIER = 2;

-- Reduce per-query performance level
ALTER WAREHOUSE my_warehouse
  SET MAX_QUERY_PERFORMANCE_LEVEL = LARGE;
```

Use `QUERY_METERING_HISTORY` to determine whether spend is driven by volume (many queries) or per-query cost (expensive individual queries) before choosing which lever to pull.

---

## What You No Longer Manage

After converting to Adaptive, these operational tasks go away:

- Choosing warehouse size
- Configuring multi-cluster scaling policies
- Enabling/disabling QAS
- Worrying about suspend/resume timing and cold-start latency
- Right-sizing warehouses as workload patterns change

What remains:
- Setting `MAX_QUERY_PERFORMANCE_LEVEL` and `QUERY_THROUGHPUT_MULTIPLIER`
- Resource monitors and budgets for cost governance
- Granting warehouse usage to roles (unchanged)
- Monitoring via the same ACCOUNT_USAGE views

---

## Quick Reference

| Task | SQL |
|---|---|
| Convert to adaptive | `ALTER WAREHOUSE x SET WAREHOUSE_TYPE = 'ADAPTIVE';` |
| Revert to standard | `ALTER WAREHOUSE x SET WAREHOUSE_TYPE = 'STANDARD';` |
| Create new adaptive | `CREATE ADAPTIVE WAREHOUSE x;` |
| Disable (block queries) | `ALTER WAREHOUSE x DISABLE;` |
| Re-enable | `ALTER WAREHOUSE x ENABLE;` |
| Set performance cap | `ALTER WAREHOUSE x SET MAX_QUERY_PERFORMANCE_LEVEL = XLARGE;` |
| Set throughput multiplier | `ALTER WAREHOUSE x SET QUERY_THROUGHPUT_MULTIPLIER = 4;` |
| Check current config | `SHOW WAREHOUSES LIKE 'x';` |
| Per-query credits | `SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_METERING_HISTORY WHERE warehouse_name = 'X';` |
