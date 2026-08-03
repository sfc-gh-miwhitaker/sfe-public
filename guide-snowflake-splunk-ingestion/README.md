![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2026--10--30-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Snowflake Logs → Splunk: Integration Guide

Snowflake does not generate traditional server log files. Its audit trail lives inside Snowflake itself — as SQL-queryable views in `SNOWFLAKE.ACCOUNT_USAGE`. Getting that data into Splunk requires one of four distinct patterns depending on your Splunk edition, cost tolerance, and latency needs.

This guide covers all four, with working SQL, decision criteria, and what each pattern does not do.

**Audience:** SEs, security architects, Splunk administrators setting up Snowflake monitoring.
**Created:** 2026-07-30 | **Expires:** 2026-10-30 | **Status:** ACTIVE

Pair-programmed by SE Community + Cortex Code

> **No support provided.** Reference only; test before you rely on it in production. SQL examples were verified against Snowflake docs on the created date above — re-verify before quoting them.

---

## Read These Words First

| Term | In plain words |
|---|---|
| **ACCOUNT_USAGE** | A shared database Snowflake provides to every account. Contains audit views like `LOGIN_HISTORY`, `QUERY_HISTORY`, `ACCESS_HISTORY`. No extra cost to query. Has 45-minute to 3-hour data latency. |
| **Information Schema** | A lower-latency (7-day retention) alternative to ACCOUNT_USAGE. Use for operational queries; ACCOUNT_USAGE for long-term audit. |
| **Rising Column** | The DB Connect technique for incremental ingest — a monotonically increasing column (like `EVENT_ID`) that tells Splunk "only fetch rows newer than this checkpoint." |
| **Splunk HEC** | HTTP Event Collector — Splunk's REST endpoint for receiving JSON events. External systems push events to it. Requires a token for auth. |
| **DB Connect** | A Splunk add-on that runs SQL queries against external databases via JDBC and ingests the results as Splunk events. The traditional Snowflake→Splunk integration path. |
| **Federated Search** | A newer Splunk capability (GA July 2026, Cloud AWS only) that lets Splunk query Snowflake in-place without ingesting data. No SIEM storage cost for Snowflake data. |
| **Sentry** | Snowflake's open-source security monitoring framework. Pre-built MITRE-mapped detection queries you deploy inside Snowflake, exporting only findings to your SIEM. |
| **PAT** | Programmatic Access Token — Snowflake's preferred credential for service accounts. Used as a password by tools (like DB Connect) that don't support key-pair auth. |

---

## Which Pattern Do You Need?

```mermaid
flowchart TD
    Start["Need Snowflake audit data in Splunk"] --> Q1{"Splunk Cloud\non AWS?"}

    Q1 -->|"Yes"| Q2{"Want logs\nin Splunk index\nfor correlation rules?"}
    Q1 -->|"No (Enterprise\nor other cloud)"| Q3{"High-volume tables\nor tight SIEM\nbudget?"}

    Q2 -->|"No — query in-place\nis fine"| P1["Pattern 1: Federated Search\nGA July 2026; Splunk Cloud AWS only\nNo data movement, no ingest cost"]
    Q2 -->|"Yes — need\nlogs indexed"| P2["Pattern 2: DB Connect\nJDBC pull from ACCOUNT_USAGE\nIncremental via Rising Column"]

    Q3 -->|"Yes"| Q4{"Only need\nalerts/findings\nnot raw logs?"}
    Q3 -->|"No — standard\nvolume"| P2

    Q4 -->|"Yes"| P4["Pattern 4: Sentry\nRun detections in Snowflake;\npush only findings to HEC"]
    Q4 -->|"No — need\nraw logs too"| P3["Pattern 3: External Stage\nCOPY INTO S3/Azure/GCS;\nSplunk S3 Add-on ingests"]
```

---

## Pattern Comparison

| | [Pattern 1: Federated Search](pattern-1-federated-search.md) | [Pattern 2: DB Connect](pattern-2-db-connect.md) | [Pattern 3: External Stage](pattern-3-external-stage.md) | [Pattern 4: Sentry](pattern-4-sentry.md) |
|---|---|---|---|---|
| **Data moves to Splunk?** | No — queried in-place | Yes — ingested as events | Yes — via cloud storage | Findings only |
| **Splunk ingest cost** | None | Per-GB of audit log volume | Per-GB (scope to what you need) | Minimal (findings only) |
| **Latency** | ACCOUNT_USAGE lag (45min–3hr) | ACCOUNT_USAGE lag (45min–3hr) | Configurable (task schedule) | Configurable (task schedule) |
| **Splunk edition** | Cloud AWS only (July 2026) | Cloud + Enterprise | Cloud + Enterprise | Cloud + Enterprise |
| **Complexity** | Low (add data source in UI) | Medium (JDBC driver, config) | Medium (SQL task + S3 config) | Medium-High (Sentry deploy) |
| **Best for** | Splunk Cloud teams wanting zero ingest cost | Most orgs; correlation rules requiring indexed data | High-cardinality tables, budget-constrained | Minimizing SIEM costs; detection-in-place |
| **Strategic direction?** | Yes | Mature / widely deployed | Complementary | Yes (Snowflake-preferred) |

---

## The Audit Views Worth Knowing

All views are in `SNOWFLAKE.ACCOUNT_USAGE`:

| View | What It Contains | ACCOUNT_USAGE Lag | Recommended Rising Column |
|---|---|---|---|
| `LOGIN_HISTORY` | All login attempts (success + failure), client type, MFA status | ~2 hours | `EVENT_ID` |
| `QUERY_HISTORY` | All queries: user, role, warehouse, runtime, bytes scanned | ~45 min | `START_TIME` (cast to TIMESTAMP_NTZ) |
| `ACCESS_HISTORY` | Which tables/columns each query touched; lineage | ~3 hours | `QUERY_START_TIME` (cast to TIMESTAMP_NTZ) |
| `SESSIONS` | Session open/close events | ~3 hours | `SESSION_ID` |
| `COPY_HISTORY` | Files loaded/unloaded; Snowpipe activity | ~2 hours | `LAST_LOAD_TIME` |
| `GRANT_TO_ROLES` | Privilege grants (point-in-time snapshot) | ~2 hours | No good rising column; batch daily |
| `DATA_TRANSFER_HISTORY` | Bytes transferred out of Snowflake | ~2 hours | `START_TIME` |

> **Cost note:** Querying ACCOUNT_USAGE is free. You pay for the virtual warehouse you use to run the queries (DB Connect, tasks) and for Splunk's ingest/storage pricing on what you land there. `ACCESS_HISTORY` and `QUERY_HISTORY` are high-cardinality — size your Splunk ingest budget before enabling them.

---

## Pattern Guides

1. [Splunk Federated Search](pattern-1-federated-search.md) — Query Snowflake from Splunk without moving data (Splunk Cloud AWS, GA July 2026)
2. [Splunk DB Connect](pattern-2-db-connect.md) — JDBC pull with Rising Column incremental ingest (most widely deployed)
3. [External Stage Export](pattern-3-external-stage.md) — COPY INTO cloud storage + Splunk S3 Add-on (high-volume / cost-sensitive)
4. [Sentry Detection Push](pattern-4-sentry.md) — Run detections in Snowflake, push only findings to Splunk HEC

## Related Guides

For guides that work alongside this one, see the [**Start Here** index](../README.md#start-here).

---

## External References

- [Snowflake ACCOUNT_USAGE — Differences vs Information Schema](https://docs.snowflake.com/en/sql-reference/account-usage#differences-between-account-usage-and-information-schema)
- [Splunk DB Connect on Splunkbase](https://splunkbase.splunk.com/app/2686/)
- [Splunk DBX Add-on for Snowflake JDBC](https://splunkbase.splunk.com/app/6153)
- [Splunk Federated Search for Snowflake — Cisco press release](https://newsroom.cisco.com/c/r/newsroom/en/us/a/y2025/m09/cisco-advances-open-data-ecosystems-with-splunk-federated-search-for-snowflake.html)
- [Snowflake Sentry project](https://snowflake-labs.github.io/Sentry/)
- [Snowflake SIEM Integration Architectures (Snowflake blog)](https://medium.com/snowflake/siem-integration-architectures-patterns-9b29e0f42b1a)
- [Integrating Snowflake and Splunk with DBConnect (Snowflake Community)](https://community.snowflake.com/s/article/Integrating-Snowflake-and-Splunk-with-DBConnect)

---

Pair-programmed by SE Community + Cortex Code
