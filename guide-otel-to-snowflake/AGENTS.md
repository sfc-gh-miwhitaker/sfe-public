# guide-otel-to-snowflake — Project Instructions

Pair-programmed by SE Community + Cortex Code

<!-- Global rules (data integrity, SQL standards, security, attribution) apply
     automatically via ~/.claude/CLAUDE.md and the repo-root AGENTS.md.
     Do not duplicate them here. -->

## What this guide is

A reference guide for the **inbound** direction of OpenTelemetry: landing external
application telemetry (logs, metrics, traces) in Snowflake tables the reader owns, then
reporting on it. No deploy script.

This is deliberately the mirror image of `guide-snowflake-splunk-ingestion`, which covers
the outbound direction. If you edit one, check whether the other needs the same change.

## Directional discipline — the core editorial rule

Snowflake has three distinct OTel-adjacent things that are constantly confused. Never let an
edit blur them:

| Thing | Direction | Correct role in this guide |
|---|---|---|
| Event tables | Snowflake's own telemetry, generated internally | Column-layout template only. **Not a writable target.** |
| `snowflakereceiver` (collector-contrib) | Pulls Snowflake metrics *out* to an APM tool | Named only as an explicit trap in Gotchas |
| Patterns 1-4 in this guide | External telemetry *into* Snowflake | The actual subject |

There is **no merged Snowflake exporter** in `opentelemetry-collector-contrib` (issue #29618
was proposed, never merged). If a future edit claims one exists, verify against the
collector-contrib exporter directory before accepting it. Pattern 3's "you build the exporter"
framing depends on this fact.

## Structure

```
README.md                          Hub: forks, decision tree, comparison, landing model, gotchas
pattern-1-openflow-listenotlp.md   First-party OTLP listener
pattern-2-kafka-connector.md       Collector -> Kafka -> Connector v4
pattern-3-snowpipe-streaming.md    Custom exporter -> Snowpipe Streaming HP
pattern-4-batch-stage-iceberg.md   Files -> stage -> COPY / Iceberg
shredding-and-reporting.md         Shared by all four patterns; the DDL and SQL
ELI5.md                            Plain-language version of README
```

Shredding and reporting live in their own file rather than in README because all four patterns
converge on them. Keep them there; do not inline SQL into pattern files beyond what is specific
to that pattern's landing table.

## Conventions specific to this guide

- **Land raw `VARIANT`, shred in SQL.** Every pattern. Do not add guidance that relies on
  connector-side schematization to flatten OTLP — JSON arrays are explicitly unsupported for
  schematization, and OTLP is arrays all the way down.
- **Always cast OTLP integers through `::STRING`.** `TO_NUMBER(x:timeUnixNano::STRING)`. A
  direct `::FLOAT` on a 19-digit nanosecond epoch rounds silently and does not error.
- **Use `TRY_PARSE_JSON`, never `PARSE_JSON`**, on any landing-path example.
- **Metric shredding must handle all five point types** — `gauge`, `sum`, `histogram`,
  `exponentialHistogram`, `summary`. A shredder reading only `asDouble`/`asInt` drops
  histograms silently.
- **Cardinality guidance belongs in the Collector**, not in Snowflake. Filtering upstream is
  free; deleting from Snowflake later is a rewrite.

## Verification requirement

The shredding SQL is the load-bearing part of this guide and compilation does not prove a
`LATERAL FLATTEN` path is correct. Before publishing any change to
`shredding-and-reporting.md`, run the modified query against a synthetic OTLP literal covering:

- all three signals
- a gauge, a sum, and a histogram metric point
- an attribute set spanning `stringValue`, `intValue`, `boolValue` (with `false`),
  `doubleValue`, and `arrayValue`
- a log record both with and without trace correlation

Confirm row counts, non-null `trace_id`/`span_id` where expected, and correct
nanosecond-to-`TIMESTAMP_NTZ` conversion. The current SQL was validated this way on 2026-09-10.

## Maintenance triggers

Re-verify on expiry (2027-03-10), or earlier if any of these change:

- A Snowflake exporter merges into `opentelemetry-collector-contrib` — Pattern 3 would be
  substantially rewritten and its remaining "you build the bridge" gate would go away.
- ~~Snowpipe Streaming high-performance architecture extends beyond AWS~~ — **resolved 2026-09-10.**
  HP went GA on Azure (2025-11-05) and GCP (2025-11-10) and is now available in all commercial
  regions except government regions. The decision tree's cloud gate was removed. Watch for
  government-region availability, which is the only remaining exclusion.
- Snowpipe Streaming SDK changes its SPCS support — Pattern 3's
  [Where to run the relay](pattern-3-snowpipe-streaming.md#where-to-run-the-relay) documents
  `authorization_type: SPCS` and `enableCustomCredentials`, both introduced in SDK 1.5.0. Also
  watch for a documented instance-ordinal environment variable for long-running services, which
  would resolve the caveat in that section's requirement 3.
- Kafka connector v3 formal deprecation lands (announcement expected mid-2026, then an
  18-month window) — Pattern 2's version guidance needs the dates.
- Event tables become writable by users — Gotcha 1 would be void.
