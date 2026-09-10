![Shared](https://img.shields.io/badge/Applies_to-All_4_patterns-blue)
![Verified](https://img.shields.io/badge/SQL-Executed_2026--09--10-success)

# Shredding and Reporting

Every ingestion pattern lands the same thing: raw OTLP JSON envelopes in a `VARIANT` column. This
file turns those envelopes into queryable spans, logs, and metric points, then builds a Dynamic
Table gold layer and the reporting queries on top.

This is the half of the work that delivers the value, and it is identical regardless of which
pattern you chose. Everything below was **executed against Snowflake**, not just compiled —
`LATERAL FLATTEN` paths can be syntactically valid and still return nothing.

> **What "verified" means here.** The shredding logic for all three signals, the attribute
> collapse across every OTLP value type, the metric shred across gauge / sum / histogram, the
> `CONNECT BY` waterfall, the RED-metric and error-budget arithmetic, and the pipeline monitors
> were all executed against synthetic OTLP payloads on 2026-09-10 and their output inspected.
> The `CREATE VIEW`, `CREATE DYNAMIC TABLE`, and `CREATE TASK` statements are the same logic
> wrapped in DDL; they were not created in an account, so re-check object names and privileges
> against your own environment.

Pair-programmed by SE Community + Cortex Code

> Part of [OpenTelemetry into Snowflake](README.md). Read the
> [gotchas](README.md#gotchas-read-before-you-build) first.

---

## Adjust for Your Pattern

The queries below read `PAYLOAD` from three per-signal tables. Adjust the source depending on
which pattern you built:

| Pattern | Envelope column | Table shape |
|---|---|---|
| 1: Openflow | `PAYLOAD` | `RAW_TRACES`, `RAW_LOGS`, `RAW_METRICS` — as written below |
| 2: Kafka | `RECORD_CONTENT` | Same three tables; substitute the column name |
| 3: Snowpipe Streaming | `PAYLOAD` | `STREAM_TRACES`, `STREAM_LOGS`, `STREAM_METRICS` |
| 4: Batch | `PAYLOAD` | One `ARCHIVE_TELEMETRY` table; filter on the envelope key — see [below](#pattern-4-one-table-three-signals) |

---

## The One Trick Worth Learning First

OTLP attributes are not objects. They are arrays of typed unions:

```json
[
  {"key": "service.name", "value": {"stringValue": "checkout"}},
  {"key": "http.status",  "value": {"intValue": "500"}},
  {"key": "sampled",      "value": {"boolValue": false}}
]
```

You cannot query that. `attributes:"service.name"` returns nothing because `attributes` is an
array and the type key varies per entry. Collapsing it to a real `OBJECT` is the single most
important transformation in this guide, and `REDUCE` does it in one expression:

```sql
REDUCE(
    <attributes array>,
    {},
    (acc, a) -> OBJECT_INSERT(
        acc,
        a:key::STRING,
        COALESCE(
            a:value:stringValue,
            a:value:intValue,
            a:value:doubleValue,
            a:value:boolValue,
            a:value:arrayValue:values,
            a:value:kvlistValue:values
        ),
        TRUE   -- overwrite duplicate keys rather than erroring
    )
)
```

**Use `REDUCE`, not `OBJECT_AGG` over a `LATERAL FLATTEN`.** The `OBJECT_AGG` approach works but
requires flattening attributes into their own row set, aggregating, and joining back — and that
join has a correctness trap: `FLATTEN`'s `index` is only unique *within* a source row, so joining
on flatten indices silently mixes attributes between payload rows once your landing table has
more than one row. `REDUCE` stays inside the row and cannot exhibit that bug.

Three verified behaviors of the expression above:

- `boolValue: false` survives, because `COALESCE` skips only `NULL`. Do not rewrite this with
  `IFNULL` chains that treat falsy values as absent.
- An empty attributes array returns `{}`, and a missing one returns `NULL`. Both are safe.
- `arrayValue` and `kvlistValue` stay nested — you get `[{"stringValue":"a"}]`, not `["a"]`. If
  you need scalars, `TRANSFORM` the inner array as well.

---

## Step 1: Shred Traces

```sql
CREATE SCHEMA IF NOT EXISTS OTEL_LAKE.SHAPED
    COMMENT = 'Event-table-shaped views over raw OTLP envelopes';

CREATE OR REPLACE VIEW OTEL_LAKE.SHAPED.V_SPANS
    COMMENT = 'One row per OTLP span, shaped like Snowflake event table columns'
AS
SELECT
    -- Event table column contract: TIMESTAMP is when the span ended.
    TO_TIMESTAMP_NTZ(TO_NUMBER(sp.value:endTimeUnixNano::STRING), 9)   AS TIMESTAMP,
    TO_TIMESTAMP_NTZ(TO_NUMBER(sp.value:startTimeUnixNano::STRING), 9) AS START_TIMESTAMP,
    OBJECT_CONSTRUCT(
        'trace_id', sp.value:traceId::STRING,
        'span_id',  sp.value:spanId::STRING
    )                                                                  AS TRACE,
    REDUCE(rs.value:resource:attributes, {}, (acc, a) -> OBJECT_INSERT(acc,
        a:key::STRING,
        COALESCE(a:value:stringValue, a:value:intValue, a:value:doubleValue,
                 a:value:boolValue, a:value:arrayValue:values,
                 a:value:kvlistValue:values), TRUE))                   AS RESOURCE_ATTRIBUTES,
    OBJECT_CONSTRUCT(
        'name',    ss.value:scope:name::STRING,
        'version', ss.value:scope:version::STRING
    )                                                                  AS SCOPE,
    'SPAN'                                                             AS RECORD_TYPE,
    OBJECT_CONSTRUCT(
        'name',           sp.value:name::STRING,
        'kind',           sp.value:kind::NUMBER,
        'parent_span_id', NULLIF(sp.value:parentSpanId::STRING, ''),
        'status',         sp.value:status
    )                                                                  AS RECORD,
    REDUCE(sp.value:attributes, {}, (acc, a) -> OBJECT_INSERT(acc,
        a:key::STRING,
        COALESCE(a:value:stringValue, a:value:intValue, a:value:doubleValue,
                 a:value:boolValue, a:value:arrayValue:values,
                 a:value:kvlistValue:values), TRUE))                   AS RECORD_ATTRIBUTES,
    -- Convenience columns. Not part of the event table contract, but every
    -- query wants them and computing them once here avoids repetition.
    sp.value:traceId::STRING                                           AS TRACE_ID,
    sp.value:spanId::STRING                                            AS SPAN_ID,
    NULLIF(sp.value:parentSpanId::STRING, '')                          AS PARENT_SPAN_ID,
    sp.value:name::STRING                                              AS SPAN_NAME,
    sp.value:status:code::NUMBER                                       AS STATUS_CODE,
    sp.value:status:message::STRING                                    AS STATUS_MESSAGE,
    (TO_NUMBER(sp.value:endTimeUnixNano::STRING)
       - TO_NUMBER(sp.value:startTimeUnixNano::STRING)) / 1e6          AS DURATION_MS
FROM OTEL_LAKE.RAW.RAW_TRACES r,
     LATERAL FLATTEN(input => r.PAYLOAD:resourceSpans) rs,
     LATERAL FLATTEN(input => rs.value:scopeSpans)     ss,
     LATERAL FLATTEN(input => ss.value:spans)          sp
WHERE r.PAYLOAD IS NOT NULL;
```

Details that matter:

- **`TIMESTAMP` is the span's *end* time.** That is Snowflake's event table convention: for events
  representing a span of time, `TIMESTAMP` is the end of the span and `START_TIMESTAMP` is the
  beginning. Following it keeps your queries portable.
- **`/ 1e6` converts nanoseconds to milliseconds.** Subtract the raw nanosecond integers first,
  then divide — dividing before subtracting loses precision.
- **`WHERE r.PAYLOAD IS NOT NULL`** discards rows where `TRY_PARSE_JSON` failed. Monitor that
  count; see [Step 6](#step-6-monitor-the-pipeline-itself).
- **`STATUS_CODE = 2` means error.** OTLP status codes are `0` unset, `1` OK, `2` error. Only `2`
  is a failure — treating `0` as an error will make almost everything look broken, since most spans
  never set a status.

### Span events

Spans can carry attached events, which map to Snowflake's `SPAN_EVENT` record type. Shred them
separately — they are a different grain and would fan out your span rows if joined in.

```sql
CREATE OR REPLACE VIEW OTEL_LAKE.SHAPED.V_SPAN_EVENTS
    COMMENT = 'One row per event attached to a span; grain differs from V_SPANS'
AS
SELECT
    TO_TIMESTAMP_NTZ(TO_NUMBER(ev.value:timeUnixNano::STRING), 9) AS TIMESTAMP,
    OBJECT_CONSTRUCT(
        'trace_id', sp.value:traceId::STRING,
        'span_id',  sp.value:spanId::STRING
    )                                                             AS TRACE,
    'SPAN_EVENT'                                                  AS RECORD_TYPE,
    OBJECT_CONSTRUCT('name', ev.value:name::STRING)               AS RECORD,
    REDUCE(ev.value:attributes, {}, (acc, a) -> OBJECT_INSERT(acc,
        a:key::STRING,
        COALESCE(a:value:stringValue, a:value:intValue, a:value:doubleValue,
                 a:value:boolValue, a:value:arrayValue:values,
                 a:value:kvlistValue:values), TRUE))              AS RECORD_ATTRIBUTES,
    sp.value:traceId::STRING                                      AS TRACE_ID,
    sp.value:spanId::STRING                                       AS SPAN_ID,
    ev.value:name::STRING                                         AS EVENT_NAME
FROM OTEL_LAKE.RAW.RAW_TRACES r,
     LATERAL FLATTEN(input => r.PAYLOAD:resourceSpans) rs,
     LATERAL FLATTEN(input => rs.value:scopeSpans)     ss,
     LATERAL FLATTEN(input => ss.value:spans)          sp,
     LATERAL FLATTEN(input => sp.value:events)         ev
WHERE r.PAYLOAD IS NOT NULL;
```

## Step 2: Shred Logs

```sql
CREATE OR REPLACE VIEW OTEL_LAKE.SHAPED.V_LOGS
    COMMENT = 'One row per OTLP log record, shaped like event table columns'
AS
SELECT
    TO_TIMESTAMP_NTZ(TO_NUMBER(lr.value:timeUnixNano::STRING), 9)         AS TIMESTAMP,
    TO_TIMESTAMP_NTZ(TO_NUMBER(lr.value:observedTimeUnixNano::STRING), 9) AS OBSERVED_TIMESTAMP,
    OBJECT_CONSTRUCT(
        'trace_id', NULLIF(lr.value:traceId::STRING, ''),
        'span_id',  NULLIF(lr.value:spanId::STRING, '')
    )                                                                     AS TRACE,
    REDUCE(rl.value:resource:attributes, {}, (acc, a) -> OBJECT_INSERT(acc,
        a:key::STRING,
        COALESCE(a:value:stringValue, a:value:intValue, a:value:doubleValue,
                 a:value:boolValue, a:value:arrayValue:values,
                 a:value:kvlistValue:values), TRUE))                      AS RESOURCE_ATTRIBUTES,
    OBJECT_CONSTRUCT('name', sl.value:scope:name::STRING)                 AS SCOPE,
    'LOG'                                                                 AS RECORD_TYPE,
    OBJECT_CONSTRUCT(
        'severity_text',   lr.value:severityText::STRING,
        'severity_number', lr.value:severityNumber::NUMBER
    )                                                                     AS RECORD,
    REDUCE(lr.value:attributes, {}, (acc, a) -> OBJECT_INSERT(acc,
        a:key::STRING,
        COALESCE(a:value:stringValue, a:value:intValue, a:value:doubleValue,
                 a:value:boolValue, a:value:arrayValue:values,
                 a:value:kvlistValue:values), TRUE))                      AS RECORD_ATTRIBUTES,
    -- The log message. A body can be a string or a structured object;
    -- fall back to the raw JSON rather than returning NULL.
    COALESCE(lr.value:body:stringValue::STRING, TO_JSON(lr.value:body))    AS VALUE,
    NULLIF(lr.value:traceId::STRING, '')                                  AS TRACE_ID,
    NULLIF(lr.value:spanId::STRING, '')                                   AS SPAN_ID,
    lr.value:severityText::STRING                                         AS SEVERITY_TEXT,
    lr.value:severityNumber::NUMBER                                       AS SEVERITY_NUMBER
FROM OTEL_LAKE.RAW.RAW_LOGS r,
     LATERAL FLATTEN(input => r.PAYLOAD:resourceLogs) rl,
     LATERAL FLATTEN(input => rl.value:scopeLogs)     sl,
     LATERAL FLATTEN(input => sl.value:logRecords)    lr
WHERE r.PAYLOAD IS NOT NULL;
```

Two notes:

- **`NULLIF(..., '')` on the trace IDs is required.** Uncorrelated log records carry `""`, not
  `null`. Skip the `NULLIF` and your log-to-trace join silently matches every uncorrelated log
  against every other one — a cartesian explosion that looks like a performance problem rather
  than a logic bug.
- **`SEVERITY_NUMBER` beats `SEVERITY_TEXT` for filtering.** The number is a defined ordinal scale
  (1-4 trace, 5-8 debug, 9-12 info, 13-16 warn, 17-20 error, 21-24 fatal), so `>= 17` reliably
  means error-or-worse. `SEVERITY_TEXT` is free-form and varies by language and library.

## Step 3: Shred Metrics

Metrics are the fiddly one, because a metric can be any of five point types and each stores its
value differently. A shredder that reads only `asDouble` and `asInt` drops every histogram
**silently** — losing exactly the latency distributions you care about, with no error.

```sql
CREATE OR REPLACE VIEW OTEL_LAKE.SHAPED.V_METRIC_POINTS
    COMMENT = 'One row per OTLP metric data point across all five point types'
AS
SELECT
    TO_TIMESTAMP_NTZ(TO_NUMBER(dp.value:timeUnixNano::STRING), 9)      AS TIMESTAMP,
    TO_TIMESTAMP_NTZ(TO_NUMBER(dp.value:startTimeUnixNano::STRING), 9) AS START_TIMESTAMP,
    REDUCE(rm.value:resource:attributes, {}, (acc, a) -> OBJECT_INSERT(acc,
        a:key::STRING,
        COALESCE(a:value:stringValue, a:value:intValue, a:value:doubleValue,
                 a:value:boolValue, a:value:arrayValue:values,
                 a:value:kvlistValue:values), TRUE))                   AS RESOURCE_ATTRIBUTES,
    OBJECT_CONSTRUCT('name', sm.value:scope:name::STRING)              AS SCOPE,
    'METRIC'                                                           AS RECORD_TYPE,
    OBJECT_CONSTRUCT(
        'metric', OBJECT_CONSTRUCT(
            'name', m.value:name::STRING,
            'unit', m.value:unit::STRING
        ),
        'metric_type', CASE
            WHEN m.value:gauge                IS NOT NULL THEN 'gauge'
            WHEN m.value:sum                  IS NOT NULL THEN 'sum'
            WHEN m.value:histogram            IS NOT NULL THEN 'histogram'
            WHEN m.value:exponentialHistogram IS NOT NULL THEN 'exponential_histogram'
            WHEN m.value:summary              IS NOT NULL THEN 'summary'
        END
    )                                                                  AS RECORD,
    REDUCE(dp.value:attributes, {}, (acc, a) -> OBJECT_INSERT(acc,
        a:key::STRING,
        COALESCE(a:value:stringValue, a:value:intValue, a:value:doubleValue,
                 a:value:boolValue, a:value:arrayValue:values,
                 a:value:kvlistValue:values), TRUE))                   AS RECORD_ATTRIBUTES,
    -- Scalar value for gauge and sum. NULL for distribution types.
    COALESCE(dp.value:asDouble::FLOAT, dp.value:asInt::FLOAT)           AS VALUE,
    m.value:name::STRING                                               AS METRIC_NAME,
    m.value:unit::STRING                                               AS METRIC_UNIT,
    CASE
        WHEN m.value:gauge                IS NOT NULL THEN 'gauge'
        WHEN m.value:sum                  IS NOT NULL THEN 'sum'
        WHEN m.value:histogram            IS NOT NULL THEN 'histogram'
        WHEN m.value:exponentialHistogram IS NOT NULL THEN 'exponential_histogram'
        WHEN m.value:summary              IS NOT NULL THEN 'summary'
    END                                                                AS METRIC_TYPE,
    -- Distribution columns. Populated for histogram and summary points.
    dp.value:count::NUMBER                                             AS POINT_COUNT,
    dp.value:sum::FLOAT                                                AS POINT_SUM,
    dp.value:bucketCounts                                              AS BUCKET_COUNTS,
    dp.value:explicitBounds                                            AS EXPLICIT_BOUNDS
FROM OTEL_LAKE.RAW.RAW_METRICS r,
     LATERAL FLATTEN(input => r.PAYLOAD:resourceMetrics) rm,
     LATERAL FLATTEN(input => rm.value:scopeMetrics)     sm,
     LATERAL FLATTEN(input => sm.value:metrics)          m,
     -- COALESCE across point types: exactly one is populated per metric.
     LATERAL FLATTEN(input => COALESCE(
         m.value:gauge:dataPoints,
         m.value:sum:dataPoints,
         m.value:histogram:dataPoints,
         m.value:exponentialHistogram:dataPoints,
         m.value:summary:dataPoints
     ))                                                  dp
WHERE r.PAYLOAD IS NOT NULL;
```

The `COALESCE` inside `LATERAL FLATTEN` is what makes one view cover all five types. Verified
behavior: a gauge yields `VALUE`, a sum yields `VALUE`, and a histogram yields `NULL` for `VALUE`
but populates `POINT_COUNT`, `POINT_SUM`, `BUCKET_COUNTS`, and `EXPLICIT_BOUNDS`.

**On histogram percentiles, stated honestly.** `BUCKET_COUNTS` and `EXPLICIT_BOUNDS` let you
estimate percentiles by interpolating within the bucket where the target rank falls. That estimate
is bounded by your bucket resolution and no better. If you need trustworthy p99, compute it from
span `DURATION_MS` with `APPROX_PERCENTILE` instead — spans carry exact durations. Use histograms
for shape and trend, spans for precision.

## Step 4: Gold Layer with Dynamic Tables

The views above are correct but re-shred the raw envelopes on every query, which gets expensive
fast. Materialize incrementally with Dynamic Tables.

```sql
CREATE SCHEMA IF NOT EXISTS OTEL_LAKE.GOLD
    COMMENT = 'Incrementally materialized reporting layer';

-- Materialized spans. This is the table your dashboards read.
CREATE OR REPLACE DYNAMIC TABLE OTEL_LAKE.GOLD.SPANS
    TARGET_LAG = '5 minutes'
    WAREHOUSE  = OTEL_TRANSFORM_WH
    CLUSTER BY (TO_DATE(TIMESTAMP), SERVICE_NAME)
    COMMENT = 'Shredded spans with service_name promoted to a typed column'
AS
SELECT
    TIMESTAMP,
    START_TIMESTAMP,
    TRACE_ID,
    SPAN_ID,
    PARENT_SPAN_ID,
    SPAN_NAME,
    STATUS_CODE,
    STATUS_MESSAGE,
    DURATION_MS,
    RESOURCE_ATTRIBUTES:"service.name"::STRING            AS SERVICE_NAME,
    RESOURCE_ATTRIBUTES:"deployment.environment"::STRING  AS ENVIRONMENT,
    RECORD_ATTRIBUTES:"http.route"::STRING                AS HTTP_ROUTE,
    RECORD_ATTRIBUTES:"http.response.status_code"::NUMBER AS HTTP_STATUS_CODE,
    RESOURCE_ATTRIBUTES,
    RECORD_ATTRIBUTES
FROM OTEL_LAKE.SHAPED.V_SPANS;
```

Promoting `service.name`, `http.route`, and the HTTP status to typed columns is the point of this
layer. Predicates on typed columns prune partitions; predicates that reach into a `VARIANT` do
not. Keep the full attribute objects alongside them as the escape hatch for ad-hoc questions.

`CLUSTER BY (TO_DATE(TIMESTAMP), SERVICE_NAME)` matches how telemetry is actually queried — a
time range, then a service. Cluster on the **date**, not the raw timestamp: a high-cardinality
clustering key produces excessive micro-partitions and costs more to maintain than it saves.

```sql
-- Per-minute service health. Small enough to query interactively over weeks.
CREATE OR REPLACE DYNAMIC TABLE OTEL_LAKE.GOLD.SERVICE_HEALTH_1MIN
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE  = OTEL_TRANSFORM_WH
    COMMENT = 'RED metrics per service, operation, and minute'
AS
SELECT
    DATE_TRUNC('minute', TIMESTAMP)                        AS MINUTE_BUCKET,
    SERVICE_NAME,
    ENVIRONMENT,
    SPAN_NAME                                             AS OPERATION,
    COUNT(*)                                              AS REQUEST_COUNT,
    SUM(IFF(STATUS_CODE = 2, 1, 0))                       AS ERROR_COUNT,
    AVG(DURATION_MS)                                      AS AVG_DURATION_MS,
    APPROX_PERCENTILE(DURATION_MS, 0.50)                  AS P50_DURATION_MS,
    APPROX_PERCENTILE(DURATION_MS, 0.95)                  AS P95_DURATION_MS,
    APPROX_PERCENTILE(DURATION_MS, 0.99)                  AS P99_DURATION_MS,
    MAX(DURATION_MS)                                      AS MAX_DURATION_MS
FROM OTEL_LAKE.GOLD.SPANS
-- Root spans only: one row per inbound request, not per internal operation.
WHERE PARENT_SPAN_ID IS NULL
GROUP BY MINUTE_BUCKET, SERVICE_NAME, ENVIRONMENT, OPERATION;
```

Two deliberate choices:

- **`TARGET_LAG = DOWNSTREAM`** on the intermediate. It refreshes only when something downstream
  needs it, rather than on its own clock — the correct setting for anything that is not the last
  table in a chain.
- **`WHERE PARENT_SPAN_ID IS NULL`** restricts to root spans. Without it, request counts are
  inflated by every internal span and "requests per minute" becomes meaningless. This is the most
  common error in first-pass trace dashboards.

Store counts, not rates. `ERROR_COUNT` and `REQUEST_COUNT` re-aggregate correctly to any time
grain; a stored `ERROR_RATE` does not, because averaging rates across buckets of different sizes
is wrong. Compute the rate at read time — as the queries below do.

```sql
CREATE WAREHOUSE IF NOT EXISTS OTEL_TRANSFORM_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 1800
    COMMENT = 'Dynamic Table refreshes for the OTel gold layer';
```

## Step 5: Reporting Queries

### Service health: the RED metrics

Rate, Errors, Duration — the standard request-driven service view, and the first dashboard to
build.

```sql
SELECT
    SERVICE_NAME,
    OPERATION,
    SUM(REQUEST_COUNT)                                AS requests,
    SUM(ERROR_COUNT)                                  AS errors,
    ROUND(100.0 * SUM(ERROR_COUNT)
          / NULLIF(SUM(REQUEST_COUNT), 0), 2)         AS error_rate_pct,
    ROUND(SUM(REQUEST_COUNT) / 60.0, 2)               AS requests_per_sec,
    ROUND(MAX(P95_DURATION_MS), 2)                    AS worst_p95_ms,
    ROUND(MAX(P99_DURATION_MS), 2)                    AS worst_p99_ms
FROM OTEL_LAKE.GOLD.SERVICE_HEALTH_1MIN
WHERE MINUTE_BUCKET >= DATEADD('hour', -1, SYSDATE())
  AND ENVIRONMENT = 'prod'
GROUP BY SERVICE_NAME, OPERATION
HAVING SUM(REQUEST_COUNT) > 10
ORDER BY error_rate_pct DESC, requests DESC;
```

`NULLIF(SUM(REQUEST_COUNT), 0)` prevents division by zero. The `HAVING` clause suppresses
low-traffic noise — one error out of two requests is 50%, which will dominate a dashboard sorted
by error rate while telling you nothing. Set the threshold to whatever makes the ranking useful
for your traffic.

`MAX(P95_DURATION_MS)` is the worst minute in the window, not the hour's p95. Percentiles do not
average, so aggregating pre-computed percentiles gives an approximation, not a true p95. When you
need the exact hourly figure, compute it from `GOLD.SPANS` directly.

### Error budget burn

```sql
-- Are we spending the error budget faster than the SLO allows?
WITH slo AS (
    SELECT 'checkout' AS service_name, 99.9 AS availability_target_pct
),
observed AS (
    SELECT
        SERVICE_NAME,
        SUM(REQUEST_COUNT) AS requests,
        SUM(ERROR_COUNT)   AS errors
    FROM OTEL_LAKE.GOLD.SERVICE_HEALTH_1MIN
    WHERE MINUTE_BUCKET >= DATEADD('day', -30, SYSDATE())
      AND ENVIRONMENT = 'prod'
    GROUP BY SERVICE_NAME
)
SELECT
    o.SERVICE_NAME,
    o.requests,
    o.errors,
    s.availability_target_pct,
    ROUND((100 - s.availability_target_pct) / 100.0 * o.requests, 0) AS error_budget,
    ROUND(100.0 * o.errors
          / NULLIF((100 - s.availability_target_pct) / 100.0 * o.requests, 0), 1)
                                                                    AS budget_consumed_pct
FROM observed o
JOIN slo s ON s.service_name = o.SERVICE_NAME
ORDER BY budget_consumed_pct DESC;
```

Replace the inline `slo` CTE with a real table once you have more than one SLO. This is also the
join that makes telemetry-in-Snowflake worth the build: `slo` can just as easily be a contract
table, a customer tier, or a revenue model.

### Trace waterfall

The single most useful query when investigating one bad request.

```sql
SELECT
    LPAD(' ', 2 * (LEVEL - 1), ' ') || SPAN_NAME AS span_tree,
    SERVICE_NAME,
    ROUND(DURATION_MS, 2)                        AS duration_ms,
    STATUS_CODE,
    STATUS_MESSAGE,
    START_TIMESTAMP,
    SPAN_ID,
    PARENT_SPAN_ID,
    LEVEL,
    -- Depth-first ordering key. Snowflake has no ORDER SIBLINGS BY, so build
    -- a sortable path from each ancestor's start time instead.
    SYS_CONNECT_BY_PATH(
        TO_CHAR(START_TIMESTAMP, 'YYYYMMDDHH24MISSFF3'), '/'
    )                                            AS sort_path
FROM OTEL_LAKE.GOLD.SPANS
START WITH TRACE_ID = '5b8aa5a2d2c872e8321cf37308d69df2'
       AND PARENT_SPAN_ID IS NULL
CONNECT BY PARENT_SPAN_ID = PRIOR SPAN_ID
       AND TRACE_ID = PRIOR TRACE_ID
ORDER BY sort_path;
```

`CONNECT BY` reconstructs the parent-child tree and `LPAD` on `LEVEL` renders it as an indented
waterfall.

Two things this query gets right that are easy to get wrong:

- **`ORDER SIBLINGS BY` does not exist in Snowflake.** It is valid Oracle and it is the obvious
  thing to reach for; it raises a syntax error here. `SYS_CONNECT_BY_PATH` over a zero-padded
  timestamp gives you the same depth-first, chronologically-ordered result.
- **`TRACE_ID = PRIOR TRACE_ID` in the `CONNECT BY` is not optional.** Span IDs are only unique
  within a trace, so omitting it lets the recursion wander into unrelated traces. Verified: with
  the guard, a reused span ID in a different trace is correctly excluded.

### Slowest operations

```sql
-- Where is time actually going? Ranked by total time, not average.
SELECT
    SERVICE_NAME,
    SPAN_NAME,
    COUNT(*)                                   AS call_count,
    ROUND(SUM(DURATION_MS) / 1000.0, 1)        AS total_seconds,
    ROUND(AVG(DURATION_MS), 2)                 AS avg_ms,
    ROUND(APPROX_PERCENTILE(DURATION_MS, 0.99), 2) AS p99_ms
FROM OTEL_LAKE.GOLD.SPANS
WHERE TIMESTAMP >= DATEADD('hour', -6, SYSDATE())
GROUP BY SERVICE_NAME, SPAN_NAME
ORDER BY total_seconds DESC
LIMIT 25;
```

Ranking by `SUM(DURATION_MS)` rather than `AVG` is the point. An operation taking 5 ms called ten
million times costs far more wall-clock time than one taking 3 seconds called twice, and only the
total surfaces it. Optimizing by average latency reliably sends people after the wrong thing.

### Logs correlated to a failing trace

```sql
SELECT
    l.TIMESTAMP,
    l.SEVERITY_TEXT,
    l.VALUE                                    AS message,
    s.SPAN_NAME,
    s.SERVICE_NAME,
    l.RECORD_ATTRIBUTES:"code.function"::STRING AS code_function
FROM OTEL_LAKE.SHAPED.V_LOGS l
JOIN OTEL_LAKE.GOLD.SPANS s
  ON  s.TRACE_ID = l.TRACE_ID
  AND s.SPAN_ID  = l.SPAN_ID
WHERE l.TRACE_ID = '5b8aa5a2d2c872e8321cf37308d69df2'
  AND l.TIMESTAMP >= DATEADD('hour', -24, SYSDATE())
ORDER BY l.TIMESTAMP;
```

The join is safe only because `V_LOGS` applies `NULLIF(..., '')` to the trace IDs. Uncorrelated
logs carry empty-string IDs, and joining on those produces a cartesian result.

### Error clustering

```sql
-- Group failures by message shape to find the few root causes behind many errors.
SELECT
    SERVICE_NAME,
    SPAN_NAME,
    COALESCE(STATUS_MESSAGE, '(no message)') AS failure_message,
    COUNT(*)                                 AS occurrences,
    MIN(TIMESTAMP)                           AS first_seen,
    MAX(TIMESTAMP)                           AS last_seen,
    COUNT(DISTINCT TRACE_ID)                 AS distinct_traces
FROM OTEL_LAKE.GOLD.SPANS
WHERE TIMESTAMP >= DATEADD('hour', -24, SYSDATE())
  AND STATUS_CODE = 2
GROUP BY SERVICE_NAME, SPAN_NAME, failure_message
ORDER BY occurrences DESC
LIMIT 50;
```

`first_seen` is the column to look at during an incident — it usually lines up with a deploy.

## Step 6: Monitor the Pipeline Itself

Telemetry pipelines fail quietly. The absence of data looks identical to the absence of problems,
so monitor explicitly rather than assuming silence is health.

```sql
-- Parse failures. A rising count means an upstream producer changed shape.
SELECT
    DATE_TRUNC('hour', INGESTED_AT) AS hour_bucket,
    COUNT(*)                        AS total_rows,
    SUM(IFF(PAYLOAD IS NULL, 1, 0)) AS unparseable_rows,
    ROUND(100.0 * SUM(IFF(PAYLOAD IS NULL, 1, 0))
          / NULLIF(COUNT(*), 0), 3) AS reject_rate_pct
FROM OTEL_LAKE.RAW.RAW_TRACES
WHERE INGESTED_AT >= DATEADD('day', -2, SYSDATE())
GROUP BY hour_bucket
HAVING SUM(IFF(PAYLOAD IS NULL, 1, 0)) > 0
ORDER BY hour_bucket DESC;
```

```sql
-- Did any service stop reporting? This catches the failure the RED dashboard
-- cannot: a service that emits nothing looks perfectly healthy.
WITH recent AS (
    SELECT DISTINCT SERVICE_NAME
    FROM OTEL_LAKE.GOLD.SPANS
    WHERE TIMESTAMP >= DATEADD('minute', -15, SYSDATE())
),
baseline AS (
    SELECT DISTINCT SERVICE_NAME
    FROM OTEL_LAKE.GOLD.SPANS
    WHERE TIMESTAMP >= DATEADD('day', -7, SYSDATE())
      AND TIMESTAMP <  DATEADD('hour', -1, SYSDATE())
)
SELECT
    b.SERVICE_NAME,
    'No spans in the last 15 minutes' AS finding
FROM baseline b
LEFT JOIN recent r ON r.SERVICE_NAME = b.SERVICE_NAME
WHERE r.SERVICE_NAME IS NULL
ORDER BY b.SERVICE_NAME;
```

```sql
-- Dynamic Table refresh health. A rising lag or repeated failures here mean
-- your dashboards are showing stale data while looking fine.
SELECT
    NAME,
    STATE,
    STATE_MESSAGE,
    DATA_TIMESTAMP,
    REFRESH_START_TIME,
    REFRESH_END_TIME,
    DATEDIFF('second', DATA_TIMESTAMP, SYSDATE()) AS staleness_seconds
FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME => 'OTEL_LAKE.GOLD.SPANS'
))
WHERE REFRESH_START_TIME >= DATEADD('hour', -24, SYSDATE())
ORDER BY REFRESH_START_TIME DESC
LIMIT 20;
```

Note the namespace: this function lives in `SNOWFLAKE.INFORMATION_SCHEMA`, not in your database's
`INFORMATION_SCHEMA`. The unqualified form raises `Invalid identifier`.

## Step 7: Retention

Telemetry grows without bound and almost none of it is valuable after a few weeks. Decide the
retention window deliberately, per layer.

```sql
-- Time Travel on raw telemetry you will never roll back is pure cost.
ALTER TABLE OTEL_LAKE.RAW.RAW_TRACES  SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER TABLE OTEL_LAKE.RAW.RAW_LOGS    SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER TABLE OTEL_LAKE.RAW.RAW_METRICS SET DATA_RETENTION_TIME_IN_DAYS = 1;

CREATE TASK IF NOT EXISTS OTEL_LAKE.RAW.PRUNE_RAW_TELEMETRY
    WAREHOUSE = OTEL_TRANSFORM_WH
    SCHEDULE  = 'USING CRON 30 3 * * * UTC'
    COMMENT   = 'Drop raw envelopes older than the shredding window'
AS
    DELETE FROM OTEL_LAKE.RAW.RAW_TRACES
    WHERE INGESTED_AT < DATEADD('day', -14, CURRENT_DATE());

ALTER TASK OTEL_LAKE.RAW.PRUNE_RAW_TELEMETRY RESUME;
```

The tiering that usually makes sense: keep **raw** envelopes for days (long enough to re-shred
after a bug), **shredded spans** for weeks (incident investigation), and **aggregates** for
months or years (trends and capacity planning). Aggregates are tiny, so long retention there is
nearly free — which is the opposite of the intuition that older data costs more.

One ordering constraint: deleting raw rows before the Dynamic Tables have consumed them loses data
permanently. Keep the raw retention window comfortably longer than your worst-case refresh lag,
and confirm with the refresh-history query above before shortening it.

---

## Pattern 4: One Table, Three Signals

Pattern 4 lands all three signals in `ARCHIVE_TELEMETRY`. Filter on the envelope key rather than
reading three tables:

```sql
CREATE OR REPLACE VIEW OTEL_LAKE.SHAPED.V_SPANS_ARCHIVE
    COMMENT = 'Span shred over the single-table batch landing zone'
AS
SELECT
    TO_TIMESTAMP_NTZ(TO_NUMBER(sp.value:endTimeUnixNano::STRING), 9)   AS TIMESTAMP,
    TO_TIMESTAMP_NTZ(TO_NUMBER(sp.value:startTimeUnixNano::STRING), 9) AS START_TIMESTAMP,
    sp.value:traceId::STRING                                           AS TRACE_ID,
    sp.value:spanId::STRING                                            AS SPAN_ID,
    NULLIF(sp.value:parentSpanId::STRING, '')                          AS PARENT_SPAN_ID,
    sp.value:name::STRING                                              AS SPAN_NAME,
    sp.value:status:code::NUMBER                                       AS STATUS_CODE,
    (TO_NUMBER(sp.value:endTimeUnixNano::STRING)
       - TO_NUMBER(sp.value:startTimeUnixNano::STRING)) / 1e6          AS DURATION_MS,
    REDUCE(rs.value:resource:attributes, {}, (acc, a) -> OBJECT_INSERT(acc,
        a:key::STRING,
        COALESCE(a:value:stringValue, a:value:intValue, a:value:doubleValue,
                 a:value:boolValue, a:value:arrayValue:values,
                 a:value:kvlistValue:values), TRUE))                   AS RESOURCE_ATTRIBUTES,
    r.SOURCE_FILE,
    r.EVENT_HOUR
FROM OTEL_LAKE.RAW.ARCHIVE_TELEMETRY r,
     LATERAL FLATTEN(input => r.PAYLOAD:resourceSpans) rs,
     LATERAL FLATTEN(input => rs.value:scopeSpans)     ss,
     LATERAL FLATTEN(input => ss.value:spans)          sp
WHERE r.PAYLOAD IS NOT NULL
  -- Signal discriminator. Also prunes: log and metric files never match.
  AND r.PAYLOAD:resourceSpans IS NOT NULL;
```

Keep `SOURCE_FILE` and `EVENT_HOUR` in the view. `EVENT_HOUR` is derived from the file prefix, so
it prunes without opening the payload, and `SOURCE_FILE` makes a bad batch removable by predicate.

---

## External References

- [Event table columns](https://docs.snowflake.com/en/developer-guide/logging-tracing/event-table-columns) — the column contract this layer mirrors
- [FLATTEN](https://docs.snowflake.com/en/sql-reference/functions/flatten)
- [REDUCE](https://docs.snowflake.com/en/sql-reference/functions/reduce)
- [OBJECT_INSERT](https://docs.snowflake.com/en/sql-reference/functions/object_insert)
- [APPROX_PERCENTILE](https://docs.snowflake.com/en/sql-reference/functions/approx_percentile)
- [Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-about)
- [CONNECT BY](https://docs.snowflake.com/en/sql-reference/constructs/connect-by)
- [OTLP JSON encoding](https://opentelemetry.io/docs/specs/otlp/#json-protobuf-encoding) — why integers arrive as strings
- [OTel semantic conventions](https://opentelemetry.io/docs/specs/semconv/)
