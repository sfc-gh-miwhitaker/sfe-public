---
name: guide-adaptive-compute
description: "SE guide on Snowflake Adaptive Compute for admins: what changed, parameters, conversion, billing, tuning. Triggers: adaptive compute, adaptive warehouse, WAREHOUSE_TYPE ADAPTIVE, MAX_QUERY_PERFORMANCE_LEVEL, QUERY_THROUGHPUT_MULTIPLIER."
---

# Adaptive Compute Guide

## Purpose
Concise reference for Snowflake administrators who need to understand the shift from sized warehouses to Adaptive Compute — covering the operational pivot, conversion path, and tuning.

## Architecture
Single README.md — no deploy artifacts.

## Key Files

| File | Role |
|------|------|
| `README.md` | The guide itself |
| `AGENTS.md` | Project-specific instructions |

## Snowflake Objects
None — this is a documentation-only guide.

## Extension Playbook

### Adding a new section
1. Identify the topic (e.g., a new limitation or feature)
2. Add a `## Section Title` after the relevant existing section
3. Keep SQL examples using placeholder warehouse names
4. Verify against current docs before publishing

## Gotchas
- Adaptive is **not** a cost-reduction feature — never frame it that way
- `QUERY_THROUGHPUT_MULTIPLIER` is not a parallel query count — it's a capacity multiplier
- Parameters are auto-derived on conversion from standard; don't override unless tuning
- `ENABLE`/`DISABLE` replaces `SUSPEND`/`RESUME` for adaptive warehouses
- `QUERY_METERING_HISTORY` rows split across metering hours — always GROUP BY query_id
