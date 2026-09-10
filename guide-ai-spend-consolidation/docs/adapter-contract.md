# The Adapter Contract

Pair-programmed by SE Community + Cortex Code

Every platform adapter — the fully worked GitHub one, the stubs, and any vendor you add later —
satisfies the same landing contract. Adding a platform is then a registry row plus one procedure,
not a redesign of the model downstream.

This document is the interface. Read it before writing an adapter, and treat any change to it as a
change that affects every adapter at once.

---

## Why a contract at all

Vendor admin APIs are the least stable part of this system. During 2026 alone, GitHub retired its
legacy Copilot metrics API and OpenAI removed a conversation log route. If the shape of the
downstream fact table depends on the shape of each vendor's payload, every vendor change is a
schema migration.

So the contract puts a boundary in exactly one place: **an adapter's only job is to get vendor
records into `RAW.LANDING_AI_USAGE` with correct metadata.** It does not interpret, normalize,
convert units, or resolve identity. Those all happen once, downstream, in
[../sql/06_normalize.sql](../sql/06_normalize.sql).

---

## The landing table

```sql
RAW.LANDING_AI_USAGE (
  PLATFORM_KEY      VARCHAR   -- registry key, e.g. 'GITHUB_COPILOT'
  REPORT_NAME       VARCHAR   -- which report within the platform
  BILLING_CONTEXT   VARCHAR   -- which contract/meter this row bills against
  PULLED_AT         TIMESTAMP_TZ
  SOURCE_FILE       VARCHAR   -- METADATA$FILENAME
  SOURCE_ROW_NUMBER NUMBER    -- METADATA$FILE_ROW_NUMBER
  RECORD            VARIANT   -- the vendor record, unmodified
  LOADED_AT         TIMESTAMP_TZ
)
```

`RECORD` holds the vendor's own JSON with **no transformation applied**. Not renamed, not cast, not
pruned. If a vendor ships a new field it lands automatically and is available for backfill; if a
vendor renames one, the old rows still hold the old name and history stays queryable.

---

## The six obligations

An adapter must do all six. The GitHub adapter in
[../sql/03_pull_github_copilot.sql](../sql/03_pull_github_copilot.sql) is the reference
implementation of every one.

### 1. Read its watermark from the run log

Never hardcode a window and never re-pull everything. The watermark is the high water mark of
successful pulls for that platform and report:

```sql
SELECT MAX(WATERMARK_TO)
FROM CONTROL.PULL_RUN_LOG
WHERE PLATFORM_KEY = :platform
  AND REPORT_NAME = :report
  AND STATUS = 'SUCCEEDED'
```

A `NULL` result means first run. Adapters decide their own first-run window and should keep it
small, because most of these APIs have short retention and unforgiving rate limits.

Note the asymmetry with a transactional source: most AI usage reports are **daily aggregates that
can be restated** for a day or two after first publication. An adapter should therefore overlap its
window slightly rather than resuming exactly at the watermark, and the normalization layer
deduplicates. Overlap plus dedup is correct here; exact resumption silently misses restatements.

**Some vendors restate for far longer than a day or two, and one of them is 30 days.** Anthropic's
Claude Enterprise revises a given date's cost and usage for up to 30 days as late events and
reconciliation arrive, and returns a `data_refreshed_at` timestamp so you can tell. For a feed like
that, "overlap slightly" is not enough — the adapter's window must be the vendor's full revision
period on every run, and only dates older than that period should be treated as invoicing-grade.

So the overlap length is a **per-platform property, not a constant**. Take it from the vendor's
documented revision window, record the vendor's own freshness timestamp alongside the rows when one
is offered, and prefer it to the date you asked for when deciding what is settled. The failure mode
if you do not is the quiet one: a number that was correct when captured and disagrees with the
vendor a week later, with nothing erroring in between.

**Watermark recovery is not the same as data safety.** Some feeds expire: Box's streaming event
stream holds two weeks and its `admin_logs` stream one year. A watermark will happily resume from
three weeks ago and pull nothing, reporting success. That is why `CONTROL.V_PIPELINE_HEALTH` alarms
on staleness rather than only on failure — for a short-retention feed, a late alarm and a failed
alarm cost the same thing.

### 2. Read credentials from a Snowflake secret, never from the payload or a parameter

```python
credentials = _snowflake.get_username_password(binding_alias)
# or, for token auth
token = _snowflake.get_generic_secret_string(binding_alias)
```

Secret values stay inside Snowflake and are only reachable by the handler that declares them.

Because `SECRETS =` aliases must be **static DDL**, they cannot be driven from a registry table at
runtime. This is the one place the design cannot be fully data-driven: adding a platform requires
editing the procedure's `SECRETS` clause. The registry still drives everything else.

### 3. Land to the stage first, then `COPY`

```text
@RAW.AI_USAGE_STAGE/{platform}/{report}/{YYYY}/{MM}/{DD}/{run_id}.jsonl
```

Write the raw response to the stage, then `COPY INTO` with `ON_ERROR = ABORT_STATEMENT`. This
leaves an immutable copy of exactly what the vendor returned, which is what lets you fix a
shredding bug without re-pulling and what lets you prove what the vendor said on a given day when
a number is disputed.

For short-retention feeds this is not a convenience, it is the only copy that will exist. Box's
streaming events are gone after two weeks; a shredding bug found in week three is unrecoverable
unless the raw bytes are already yours.

Use `auto_compress=False` and `overwrite=False`. A run ID collision should fail, not silently
overwrite evidence.

**Not every source is a JSON endpoint.** Box's AI Units report is a *file* Box delivers into a Box
folder, so that adapter fetches a file rather than paging an API. The contract is unchanged — land
the bytes, log the run, assert the shape — which is the point of defining it at this level rather
than around a particular HTTP shape.

### 4. Write a run log row on **both** paths

Success and failure. The failure row is the more important one — a pipeline that logs only
successes cannot distinguish "no usage yesterday" from "the adapter has been dead for a week".

```text
RUN_ID, PLATFORM_KEY, REPORT_NAME, STARTED_AT, COMPLETED_AT, STATUS,
FILE_NAME, RECORDS_FETCHED, ROWS_LOADED,
WATERMARK_FROM, WATERMARK_TO, ERROR_CLASS, ERROR_MESSAGE, QUERY_ID
```

`ERROR_CLASS` is the Python exception class name (`type(exc).__name__`). It makes the difference
between a credential problem, a rate limit, and a schema change visible in a `GROUP BY` rather than
in prose.

After logging a failure, **re-raise**. A swallowed exception leaves the task green and the data stale.

### 5. Assert on payload shape and fail loudly

This is the obligation most easily skipped and the one that causes silently wrong dashboards.

```python
REQUIRED_FIELDS = {"date", "user_login"}
missing = REQUIRED_FIELDS - set(record.keys())
if missing:
    raise RuntimeError(f"SCHEMA_DRIFT: {platform}/{report} missing {sorted(missing)}")
```

If a vendor renames a field, a permissive adapter maps it to `NULL` and the chart keeps drawing a
plausible line at the wrong value. A strict adapter fails the pull, the health view shows stale
data, and someone investigates. **Prefer the visible failure.**

Assert only on fields the normalization layer actually requires — typically the date and the
subject key. Do not assert on optional or additive fields, or every vendor improvement becomes an
outage.

### 6. Tag its queries

```sql
ALTER SESSION SET QUERY_TAG = 'AI_SPEND:{platform}:{report}'
```

Makes the pipeline's own Snowflake cost attributable. A cost-visibility pipeline that cannot report
its own cost is not a good look.

---

## What an adapter must not do

| Do not | Because |
| --- | --- |
| Rename or restructure vendor fields | Kills the ability to backfill and to reconstruct what the vendor actually returned |
| Convert credits to dollars | Rates change and are contractual. Currency conversion belongs in `SEAT_ENTITLEMENT` and the allocation view, in one place |
| Resolve identity | `IDENTITY_MAP` is applied once in normalization. An adapter that resolves identity itself will drift from the others |
| Filter out rows it thinks are uninteresting | Zero-usage rows are how you find unused seats — the highest-value finding available |
| Aggregate before landing | Destroys the grain you were asked for and cannot be undone |
| Decide the cost model | `cost_model` comes from `PLATFORM_REGISTRY`, so it is declared once per platform rather than asserted per row |

---

## Registering a platform

```sql
INSERT INTO CONTROL.PLATFORM_REGISTRY (
  PLATFORM_KEY, DISPLAY_NAME, BILLING_CONTEXT, COST_MODEL,
  NATIVE_UNIT, SUBJECT_KEY_KIND, CREDENTIAL_OBJECT_FQN,
  SUPPORTS_USER_GRAIN, SUPPORTS_USER_COST, IS_ACTIVE
)
SELECT 'BOX_AI', 'Box AI', 'BOX_ENTERPRISE', 'METERED',
       'AI_UNITS', 'EMAIL', 'AI_SPEND.CONTROL.BOX_API_CREDENTIALS',
       TRUE, TRUE, FALSE;
```

`IS_ACTIVE` defaults to `FALSE` deliberately. A newly registered platform does not get pulled until
someone flips it on, so a half-configured adapter cannot start writing.

`SUPPORTS_USER_GRAIN` and `SUPPORTS_USER_COST` are declared honestly per platform and consumed by
the monitoring layer. They are what let a report say "Copilot cannot answer this" rather than
rendering an empty panel that looks like a bug.

---

## Adding a new platform: the checklist

1. Confirm the vendor actually exposes the grain you need. Do this **first** — it is the step that
   kills projects, and finding out after the credential request is the expensive order.
2. Insert a `PLATFORM_REGISTRY` row with `IS_ACTIVE = FALSE` and honest capability flags.
3. Add a network rule for the vendor host and attach it to the external access integration.
4. Create the secret. Grant `READ` to the pipeline role.
5. Write the adapter procedure satisfying the six obligations. Add its secret alias to the
   `SECRETS` clause.
6. Run it once by hand. Inspect `RAW.LANDING_AI_USAGE` and confirm the record shape matches what
   the normalization layer expects.
7. Add the platform's shredding branch to [../sql/06_normalize.sql](../sql/06_normalize.sql).
8. Verify the unresolved-identity rate for the new platform in `CONTROL.V_PIPELINE_HEALTH`. A new
   platform arriving at 90 percent unresolved means its subject key is not in `IDENTITY_MAP` yet —
   fix that before anyone sees a department chart.
9. Set `IS_ACTIVE = TRUE`.

Step 8 is the one people skip. A new platform silently landing entirely in the `UNRESOLVED` bucket
will show correct platform totals and a department breakdown missing an entire tool.
