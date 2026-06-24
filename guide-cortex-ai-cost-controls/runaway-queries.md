# Runaway Query Protection — Deep Dive

This page explains the full task-based pattern for detecting and cancelling Cortex AI Functions queries that exceed a credit threshold while still running.

If you haven't read the main guide's [Section 4](README.md#4-catching-runaway-queries), start there. This page is the implementation detail.

---

## Why AI Functions Need Special Treatment

Most Snowflake queries operate on rows you've already stored. Their cost is predictable — it's compute time on your warehouse. AI Functions are different: each row processed makes an LLM call, and each LLM call has a per-token credit cost. A query that scans 10 million rows might make 10 million separate inference calls.

This means:
- A table-scan AI_CLASSIFY query can run for 30 minutes and burn hundreds of credits
- The cost scales with row count AND prompt complexity — you can't predict it from the query text alone
- Standard time-based limits (`STATEMENT_TIMEOUT_IN_SECONDS`) help, but they don't distinguish between a cheap 30-minute query and an expensive 30-minute query

## The Detection Mechanism

`CORTEX_AI_FUNCTIONS_USAGE_HISTORY` has a column called `IS_COMPLETED`:

| Value | Meaning |
|-------|---------|
| `TRUE` | Query has finished executing |
| `FALSE` | Query is still running right now |

When `IS_COMPLETED = FALSE`, the `CREDITS` column shows the cost consumed **so far** for that running query. This is the signal we use.

## The Latency Problem (Read This Carefully)

> The view has a **maximum latency of 60 minutes**, though data may appear in as few as 10 minutes after execution begins.

What this means in practice:

1. Query starts at 2:00 PM, running `SELECT AI_COMPLETE(...) FROM big_table`
2. By 2:05 PM, it has consumed 15 credits. But the view may not show this data yet.
3. At 2:10 PM (best case) or 2:45 PM (worst case), the row appears with `IS_COMPLETED = FALSE, CREDITS = 15`
4. Your task picks it up at its next scheduled run and cancels it
5. Between the view updating and the task running, the query may have consumed additional credits

**This is a safety net, not a real-time kill switch.** The combination of view latency + task interval means there's a window where the query runs unchecked. Set your threshold conservatively to account for this.

## Recommended: Layer Both Approaches

| Protection | How it works | Latency | Best for |
|-----------|--------------|---------|----------|
| `STATEMENT_TIMEOUT_IN_SECONDS` | Kills any query exceeding N seconds | **Instant** | Catching queries that run too long |
| Credit-based task (this pattern) | Cancels still-running queries exceeding N credits | **10-60 min** | The narrow band STATEMENT_TIMEOUT misses: expensive queries that run *under* the time cap but over the credit cap |

> **Be honest about the overlap.** Because of view latency, the credit-based task only catches queries that are still running 10+ minutes in. A query that's expensive but finishes in 5 minutes is gone before the view sees it — cancellation is a no-op. If almost all your runaways are long-running, STATEMENT_TIMEOUT alone may cover you and this pattern adds little.

Use both. Set a warehouse timeout of 30 minutes as the hard floor:

```sql
ALTER WAREHOUSE ai_functions_wh SET STATEMENT_TIMEOUT_IN_SECONDS = 1800;
```

Then layer the credit-based pattern on top for cost-aware protection.

## The Implementation

### Components

```
┌─────────────────────────────┐
│  runaway_query_config       │  ← Your threshold setting (e.g., 5 credits)
├─────────────────────────────┤
│  cancel_runaway_ai_queries  │  ← Stored procedure: finds + cancels + logs
├─────────────────────────────┤
│  cancel_runaway_ai_queries  │  ← Task: runs the procedure every 10 minutes
│         _task               │
├─────────────────────────────┤
│  runaway_query_log          │  ← Audit trail of cancellations
└─────────────────────────────┘
```

### How it flows

1. Task fires every 10 minutes (matching the minimum view refresh window)
2. Procedure reads the credit threshold from `runaway_query_config`
3. Queries `CORTEX_AI_FUNCTIONS_USAGE_HISTORY` for `IS_COMPLETED = FALSE AND CREDITS >= threshold`
4. For each match: calls `SYSTEM$CANCEL_QUERY(query_id)` and logs the cancellation
5. User sees their query cancelled with an error message

### Setting the threshold

Start with your baseline data. Run this to see what "normal" looks like:

```sql
SELECT
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY credits) AS p95_credits,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY credits) AS p99_credits,
    MAX(credits) AS max_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
  AND is_completed = TRUE;
```

Set your threshold above the 99th percentile but below the maximum. If your p99 is 3 credits and your max outlier was 50, a threshold of 5 credits catches genuine runaways without false-positiving on heavy but legitimate workloads.

### Full SQL

The complete implementation — config table, procedure, task, and log table — is in [`sql/runaway_query_protection.sql`](sql/runaway_query_protection.sql). It's ready to run after you replace `<your_warehouse>` with your warehouse name.

## What the User Experiences

When a query is cancelled via `SYSTEM$CANCEL_QUERY()`:
- The query fails with a cancellation error
- Any partial results are discarded
- The user sees a message indicating the query was cancelled by an administrator
- Credits consumed up to the cancellation point are still billed (you can't undo spend, only stop it from growing)

## Tuning the Schedule

The task runs every 10 minutes by default. Considerations:

- **Shorter interval (5 min):** Catches runaways slightly faster, but costs more warehouse compute for the task itself. Minimal benefit since the view latency is the bottleneck.
- **Longer interval (30 min):** Less task overhead, but widens the window where a runaway runs unchecked after appearing in the view.
- **10 minutes** is the sweet spot: matches the view's minimum refresh cadence, so you're checking as frequently as new data could theoretically appear.

## Monitoring

Check recent cancellations:

```sql
SELECT
    cancelled_at,
    query_id,
    credits_at_cancellation,
    function_name,
    model_name,
    user_id
FROM COST_GOVERNANCE.ENFORCEMENT.runaway_query_log
ORDER BY cancelled_at DESC
LIMIT 20;
```

If you're seeing frequent cancellations for the same user, consider reducing their access to large tables or adding a pre-check that validates table size before allowing AI Functions to run against it.

---

Back to the [main guide](README.md).
