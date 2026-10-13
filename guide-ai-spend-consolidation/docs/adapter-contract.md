# The Adapter Contract

Pair-programmed by SE Community + Cortex Code

Every external adapter must publish **complete report partitions**, not merely append rows.
The worked GitHub adapter implements this contract for one organization. Other vendor sections
are build specifications; their typed shredding views remain inert until qualified.

Read this before implementing an adapter. The authoritative object definitions are in
[../sql/01_landing.sql](../sql/01_landing.sql), publication logic in
[../sql/06_normalize.sql](../sql/06_normalize.sql), and monitoring in
[../sql/09_monitoring.sql](../sql/09_monitoring.sql).

## Start Here

1. Qualify the source's scope, grain, privacy, completion signal, revision policy, and billing meaning.
2. Register the platform **and each required report**, leaving the platform inactive and task suspended.
3. Implement ingestion and the corresponding shredding branch; activation alone implements neither.
4. In a qualification environment, activate the platform while leaving its task suspended. Run controlled
   pulls and reconcile complete partitions, empty partitions, pricing, identity, and coverage.
5. Enable scheduled operation only after those checks pass. Keep raw evidence and correct forward.

## Control objects and publication

| Object | Contract |
| --- | --- |
| `CONTROL.PLATFORM_REGISTRY` | Billing context, usage cost model, units, identity/capability flags, expected lag, and `IS_ACTIVE`. External pulls and normalized facts are activity-gated. |
| `CONTROL.REPORT_REGISTRY` | One expected report per platform/report, `IS_REQUIRED`, and `SOURCE_KIND` (`EXTERNAL` or `NATIVE`). Required feeds define monitoring completeness even when they have never succeeded. This is not a procedure dispatcher. |
| `CONTROL.PULL_RUN_LOG` | Per-report run status, bounds, counts, and controlled error metadata. Only `SUCCEEDED` runs may publish. |
| `CONTROL.REPORT_SNAPSHOT` | One manifest per completed partition: `RUN_ID`, `PLATFORM_KEY`, `REPORT_NAME`, `PARTITION_DATE`, `RECORD_COUNT`, including count zero. |
| `CONTROL.IDENTITY_MAP` | Dated subject-to-person mapping, confidence, department, cost centre, and `ENTITY_KIND`. |
| `CONTROL.PLATFORM_RATE` | Effective-dated currency per qualified billable native unit; no default rate. |
| `CONTROL.SEAT_RATE` | Finance-supplied monthly seat rate and currency, required by the GitHub scheduler's projection. |
| `CONTROL.SEAT_ENTITLEMENT` | Monthly seat amounts, assignment state, source, and `SOURCE_RUN_ID`. Roster estimates are not invoice actuals. |
| `CONTROL.ACTIVITY_COVERAGE` | Explicit owner qualification of complete platform/month activity coverage, including quiet days. It is not inferred from event minima/maxima. |

`V_REPORT_HEALTH` evaluates every required report; a successful usage pull cannot conceal a missing
seat feed. `V_PIPELINE_HEALTH` also surfaces missing registration, source/fact lag, shape drift,
unpriced cost, and identity gaps. Native report health uses observed source activity, not fictitious
external pull logs: `NO_OBSERVED_USAGE` and `VERIFY_QUIET_OR_STALE` require investigation, not a
claim that an API failed or that a month was completely idle.

## Landing schema

The following is a column contract, not executable DDL:

```text
RAW.LANDING_AI_USAGE
  PLATFORM_KEY       VARCHAR
  REPORT_NAME        VARCHAR
  BILLING_CONTEXT    VARCHAR
  PULLED_AT          TIMESTAMP_TZ
  SOURCE_FILE        VARCHAR          -- METADATA$FILENAME
  SOURCE_ROW_NUMBER  NUMBER           -- METADATA$FILE_ROW_NUMBER
  RECORD             VARIANT
  LOADED_AT          TIMESTAMP_TZ
  RUN_ID             VARCHAR(36)      -- required for publication
```

`RUN_ID` is nullable only to permit forward upgrades of existing landing tables. Legacy rows with
no run ID or completion manifest stay retained but cannot publish. Re-pull qualified partitions;
do not infer or manufacture completion evidence from old rows.

Preserve the approved vendor metadata fields and source provenance. NDJSON is one vendor record
per line. For CSV, retain the original file, parse with a CSV parser, and preserve headers and
string values in a lossless record envelope; perform semantic casts in shredding. CSV support is
adapter work, not something the worked JSON file format already implements. The GitHub handler
re-serializes JSON records, so its staged JSONL preserves field values, not byte-for-byte HTTP bodies.

**Privacy precedes preservation.** Do not land arbitrary logs and promise to filter them later.
For Code Assist, allow only `labels.product = code_assist`, the `MetadataLog` payload type, and the
approved project log name ending `cloudaicompanion.googleapis.com%2Fmetadata` **before staging or
COPY**. Request and response streams can contain prompts and source files. Reject unexpected
payload types before they enter the immutable landing area.

## The six obligations

### 1. Resume per report and restate complete partitions

The orchestrator reads `MAX(WATERMARK_TO)` from successful runs for the same platform/report and
passes it to the pull. A watermark describes completed source coverage, not merely the newest event.
Use bounded first-run/backfill windows, explicit timezone/day boundaries, and the report's actual
publication lag. Retention gaps must fail visibly rather than advance the watermark over missing data.

Revision policy is source-specific. GitHub's overlap and publication-lag constants in `sql/03`
are qualification choices, not vendor SLAs. Claude Enterprise cost/usage can revise until **about
seven days after calendar month-end**: reload every still-open month through settlement, splitting
requests to endpoint limits. A fixed rolling 30-day window misses early-month changes. Retain
`data_refreshed_at`; exclude the incomplete tail by setting `ending_at` at or before a previously
returned freshness timestamp. The Analytics API has no data before January 1, 2026.

Period reports need a different reporting grain. M365 v2 D28 totals must not be repeated as daily
facts or summed across overlapping snapshots. Its current shredding view is deliberately empty;
implement period-aware reporting before activation.

### 2. Keep credentials and egress narrowly scoped

Read secrets through the procedure's static `SECRETS` bindings. The registry stores object names,
never secret values. Adding a source requires qualified secret bindings, integration configuration,
and exact approved hosts in [../sql/02_network_secrets.sql](../sql/02_network_secrets.sql).

The worked GitHub connector calls `/orgs/{org}/copilot/metrics/reports/users-1-day?day=YYYY-MM-DD`,
validates `report_day`, and downloads **all** `download_links` as NDJSON. It uses the same single
organization for `/orgs/{org}/copilot/billing/seats`. Enterprise-wide scope needs separate inventory
and overlap qualification; changing the URL prefix is not sufficient.

Signed downloads receive **no API Authorization header, session auth, or implicit environment
credentials**. Approve exact HTTPS download hosts in both `DOWNLOAD_HOSTS` and the EAI network
rule; never trust a host automatically because an API returned it. Reject unexpected redirects,
ports, embedded credentials, or schemes. Do not log signed URLs or response bodies. Box file
retrieval can redirect to `dl.boxcloud.com`; approve the exact host separately, not an upload host.

### 3. Stage, load, manifest, then publish

```text
@RAW.AI_USAGE_STAGE/{platform}/{report}/{YYYY}/{MM}/{DD}/{run_id}.jsonl
```

Use a unique run ID, `auto_compress=False`, `overwrite=False`, and check that upload succeeded.
Load explicit columns with `COPY INTO ... ON_ERROR = ABORT_STATEMENT`; verify loaded counts.
Every record must carry the run ID. Write `REPORT_SNAPSHOT` only after the partition's complete
set of files/pages has been validated and loaded. A valid empty partition writes a manifest with
`RECORD_COUNT = 0` even though there are no landing rows.

Write the run's `SUCCEEDED` record **last**, after every requested partition has completed.
A later-page failure can leave staged/landed evidence and manifests, but a failed run cannot
publish any of them. Readers continue to use the previous successful partition until a corrected
run completes. Do not mutate a published run.

`SHAPED.V_CURRENT_REPORT_PARTITIONS` chooses the latest successful snapshot per
`(PLATFORM_KEY, REPORT_NAME, PARTITION_DATE)`, ordered by completion time and run ID.
Normalization joins that snapshot to rows using the platform, report, date, and run ID, then
aggregates **all records within it**. A corrected partition replaces prior membership, including
removed subjects; an empty correction suppresses all earlier rows for that partition.

Never use latest-row-per-person/day deduplication to select a report: it loses product/model
breakdowns and multiple events. Event feeds must deduplicate on vendor event identity, reconstruct
complete partitions, and preserve the original evidence before publishing. With the current
manifest key, one deployment supports one source scope per platform/report; multi-tenant ingestion
requires extending the keys throughout, not silently mixing organizations in a day partition.

### 4. Log both outcomes and propagate failure

```text
RUN_ID, PLATFORM_KEY, REPORT_NAME, STARTED_AT, COMPLETED_AT, STATUS,
FILE_NAME, RECORDS_FETCHED, ROWS_LOADED, WATERMARK_FROM, WATERMARK_TO,
ERROR_CLASS, ERROR_MESSAGE, QUERY_ID
```

Failure logs must contain controlled error classes/messages without bearer tokens, signed URLs,
response bodies, or arbitrary exception text. Re-raise after logging. A caught error returned as
ordinary text leaves the task green. `PULL_GITHUB_ALL` attempts both required reports, then fails
if either pull or the current-month seat projection fails. Inspect task history as well as report
logs: seat projection can fail after both pulls succeeded.

### 5. Validate every record and the completion signal

Validate required field presence, types, nonblank subjects, valid dates, requested partition
membership, numeric precision/ranges, envelope shape, pagination termination, and total counts.
Inspect every record, not just the first. Optional additive fields need not fail a pull, but a
missing required cost/activity field must not silently become zero.

For GitHub seats, require `seats` and `total_seats`, retrieve every page, check a consistent total
throughout pagination, reconcile the final count, and reject duplicate assignees. A safety page
limit means failure, not successful truncation. Missing report links, unavailable reports, and
unexpected HTTP statuses are not successful empty reports. A downloaded and validated zero-record
report is distinct from all of these.

### 6. Tag SQL without changing an owner-rights session

Use per-statement parameters, as `sql/03` does:

```python
session.sql(statement, params=parameters).collect(
    statement_params={"QUERY_TAG": f"AI_SPEND:{platform}:{report}"}
)
```

Do not use `ALTER SESSION` inside an owner-rights call hierarchy. A caller-rights child called by
an owner-rights orchestrator still operates in that owner-rights context. Use the task's query tag
for orchestration and per-statement tags for ingestion. Refresh history identifies Dynamic Table
work; a query tag alone does not attribute all warehouse credits.

## Shredding, money, and identity

Each external shredding branch exposes the typed columns of `V_EXTERNAL_USAGE`, including:

```text
PLATFORM_KEY, REPORT_NAME, BILLING_CONTEXT, USAGE_DATE, SUBJECT_KEY,
SUBJECT_DISPLAY_NAME, ENTITY_KIND, NATIVE_QTY, ACTIVITY_COUNT,
VENDOR_ENGAGEMENT_LABEL, COST_BASIS, BILLABLE_NATIVE_QTY,
REPORTED_COST_AMOUNT, REPORTED_CURRENCY, RUN_ID, PULLED_AT,
SOURCE_FILE, SOURCE_ROW_NUMBER, LOADED_AT
```

`COST_MODEL` describes usage rows, not the whole contract. Seat fees live in `SEAT_ENTITLEMENT`.
The report-specific `COST_BASIS` determines whether any usage may become money:

| Basis | Meaning |
| --- | --- |
| `ACTIVITY_ONLY` | Consumption/adoption without qualified charge. GitHub `ai_credits_used` belongs here: consumption is explicitly not invoicing. |
| `BILLABLE_NATIVE` | Qualified billable-only quantity, excluding included allowances when necessary, multiplied by exactly one applicable `PLATFORM_RATE`. |
| `REPORTED_CURRENCY` | Qualified vendor-reported monetary amount with explicit currency; bypass `PLATFORM_RATE`. Convert documented decimal cents in SQL, not in the adapter. |
| `UNKNOWN` | Unqualified cost input. Keep the cost unknown and visible for review. |

A missing rate yields `COST_AMOUNT = NULL` and `MISSING_RATE`. Overlapping/ambiguous rates or
invalid cost inputs yield NULL and `INVALID_COST_INPUT`; there is **no $1 default**. `SEAT` and
activity-only rows have no metered cost. Currency-bearing aggregates, windows, comparisons, and
reconciliation must retain `CURRENCY_CODE`. Human engagement/adoption carry no currency amount.

`AI_SPEND_ALLOCATED` includes only priced metered amounts plus labelled seat allocations. Unknown
amounts are excluded, not zero: show `UNPRICED_ROWS` and report health alongside any total.
A native-credit quantity and a cash invoice are not interchangeable. Enterprise plan generations,
allowances, discounts, and settlement must be qualified before labelling a source as billable.

Resolve identities downstream using `USAGE_DATE BETWEEN VALID_FROM AND VALID_TO`; seat allocation
uses month-start identity as an explicit convention. Close prior intervals when inserting a new
mapping or rate and test overlaps: deterministic identity tie-breaking does not make overlaps valid.
Keep unresolved subjects in totals. `ENTITY_KIND` distinguishes `PERSON`, `SERVICE`, `SYSTEM`, and
`UNKNOWN`; non-person spend remains visible but does not enter human engagement/adoption ranks.

The separate GitHub seat projection is an intentional exception to adapter-only landing: it maps
roster subjects using month-start identities and the same unresolved key convention. The scheduler
requires exactly one current-month `SEAT_RATE` and calls `PROJECT_GITHUB_SEATS`. Its
`GITHUB_ROSTER_ESTIMATE` rows preserve seats observed during the month; they do not reconstruct
historical billed entitlements or prove reclaimable savings.

A dormant-seat claim requires a closed month, qualified billed entitlement, resolved person
identity, and explicit complete `ACTIVITY_COVERAGE`. Missing events or a fresh pull alone do not
prove inactivity. Roster estimates and incomplete periods remain `UNKNOWN_*`, never `DORMANT`.

## Native source and access boundaries

`RAW.V_SNOWFLAKE_NATIVE_USAGE` reads four native surfaces directly, bypassing external manifests.
Those views cover only a subset of Snowflake AI spend. `ACCOUNT_USAGE` retains a bounded history
(365 days for these usage views); neither a view nor a fully refreshed Dynamic Table is a durable
archive. Longer retention requires a separately qualified owned accumulator before source expiry.
`METERING_RECORD_COUNT` counts metering rows, not requests; `REQUEST_COUNT` counts distinct source
IDs and means query IDs, not per-row AI calls, for AI functions.

Usage metadata and identity maps remain sensitive. The person-level semantic view is **not an
aggregate-only security boundary**: `SELECT` exposes its public person dimensions and facts without
base-table `SELECT`. Grant it only to approved individual-data roles. For aggregate-only audiences,
publish a separate aggregate model and review small-cohort disclosure. Agent instructions are not
access controls. Use least privilege for pipeline credentials, operators, and reporting roles.

## Qualification checklist

- Register every required feed and test a never-successful sibling report.
- Test late restatement, removed subject, empty correction, multi-file/page failure, retry, and inactive gating.
- Reconcile all source records and breakdowns before daily aggregation; never infer coverage from row count alone.
- Test missing/overlapping rates, reported currency, included usage, two currencies, and future seat dates.
- Test historical identity changes, unresolved people, service accounts, and incomplete activity coverage.
- Check schema drift before filtering malformed subjects/dates out of the fact.
- Qualify source and Dynamic Table freshness independently, including quiet native services.
- Inspect actual refresh modes and history; constant `VALUES` support does not certify an incremental DAG.
- Reconcile source partitions, finance amounts, and least-privilege access before presenting results.

## External References

- [GitHub usage report API](https://docs.github.com/en/rest/copilot/copilot-usage-metrics)
- [GitHub usage metric definitions](https://docs.github.com/en/copilot/reference/copilot-usage-metrics/copilot-usage-metrics)
- [Microsoft v2 Copilot report](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/api/admin-settings/reports/copilotreportroot-getmicrosoft365copilotusageuserdetail)
- [Box AI Units CSV](https://docs.box.com/en/box-admin-tools/reporting-and-insights/ai-units-report)
- [Box file downloads](https://developer.box.com/guides/downloads/file)
- [Claude Enterprise freshness and settlement](https://platform.claude.com/docs/en/manage-claude/analytics-api)
- [Claude Enterprise versus Console billing APIs](https://platform.claude.com/docs/en/manage-claude/usage-cost-api)
- [Code Assist metadata versus content logs](https://docs.cloud.google.com/gemini/docs/log-gemini)
- [Stored procedure rights](https://docs.snowflake.com/en/developer-guide/stored-procedure/stored-procedures-rights)
- [Querying semantic views and privileges](https://docs.snowflake.com/en/user-guide/views-semantic/querying)
