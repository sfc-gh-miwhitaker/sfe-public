![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2027--03--10-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Consolidating AI Spend and Adoption Across Platforms in Snowflake

Your organization is paying for ChatGPT Enterprise, Microsoft 365 Copilot, GitHub Copilot, Box AI,
and Snowflake Cortex. Each vendor has its own admin console, its own definition of a "user", and
its own meter. Leadership wants one number for total AI spend, plus an answer to which groups are
driving it. This guide builds that view in Snowflake at **user-level grain**, without pretending
the vendors measure the same thing.

The hard part is not the API calls. It is deciding what a unified row *means* when one platform
bills metered credits and another bills a flat seat, and what a "user" is when one platform gives
you a login, another gives you a pseudonymized hash, and a third gives you a numeric ID. This
guide is mostly about those two decisions, because they are the ones that survive a vendor
shipping a new API.

**Audience:** SEs, platform and FinOps engineers, and data teams asked to produce cross-platform
AI cost and adoption reporting.

Pair-programmed by SE Community + Cortex Code

**Created:** 2026-09-10 | **Expires:** 2027-03-10 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use. The Snowflake-side SQL
> here was executed on the created date above. The **vendor API details were correct on that date
> and will drift** — every vendor in this guide changed a relevant endpoint during 2026. Treat the
> vendor sections as a worked illustration of the pattern, and the vendor's own documentation as
> the source of truth.

---

## Read These Words First

| Term | In plain words |
|---|---|
| **Metered** | The vendor charges per unit consumed — credits, tokens, requests. Cost varies with behavior. Snowflake Cortex, OpenAI credits, and GitHub AI credits work this way. |
| **Seat** | The vendor charges a fixed amount per licensed person per month. Cost does **not** vary with behavior. Microsoft 365 Copilot works this way. A heavy user and an untouched license cost the same. |
| **Native quantity** | The unit the vendor actually reports — credits, tokens, messages, AI Units, interactions. Preserved rather than converted, because there is no honest exchange rate between them. Box's "AI Unit" is the clearest case: a vendor-proprietary composite that means nothing outside Box. |
| **Identity spine** | The mapping from each vendor's subject key to one person, plus that person's department and cost centre. Sourced from your IdP or HR system, not from any AI vendor. |
| **Unresolved** | A usage row whose subject could not be matched to a person. Kept as a visible bucket, never dropped. |
| **Adapter** | The per-vendor code that pulls from an admin API and lands it in the shared contract. The disposable layer. |
| **Engagement tier** | A classification of users by activity depth — commonly low / medium / power. Every vendor defines this differently, so this guide computes its own and says so. |

---

## Start Here

### First fork: should you build this at all

Buying is often correct. Consider a vendor product instead when:

- You need **peer benchmarking** — "how does our adoption curve compare to similar companies".
  You cannot build this from your own data by definition.
- Your works council, privacy office, or employee relations function will only approve
  **team-level** reporting. Several commercial tools are built specifically to report aggregates
  without touching individual rows, and that constraint is easier to buy than to enforce.
- You want turnkey dashboards this quarter and have no data engineering capacity.

Build the pipeline in this guide when at least one of these is true:

- You need to **join AI usage to data only you have** — HR hierarchy, cost centres, project codes,
  revenue per team, ticket outcomes. This is the strongest reason and no vendor tool does it,
  because the join keys live in your systems.
- **Snowflake Cortex is already a material line item.** Half the work is then already done: the
  Snowflake-native side of this model comes straight out of `ACCOUNT_USAGE` with no connector at all.
- You need AI spend in the **same forecasting model as the rest of your platform spend**, owned by
  the same team, on the same refresh cadence.
- Your governance model will not permit employee activity metadata leaving your perimeter.

A reasonable middle path: build the Snowflake-native half first, because it needs no vendor API
and no credentials, and use it to prove the model and the reports before negotiating access to any
external admin API. It is the cheapest way to find out whether leadership actually wants what they
asked for.

### Second fork: what grain can each platform actually give you

Ask this **before** promising user-level reporting, because one of these platforms cannot deliver
it in the form people assume, and another delivers it only through a route most people miss.

| Platform | User-level rows? | Per-user cost? | The constraint that will surprise you |
|---|---|---|---|
| **Snowflake Cortex** | Yes | Yes, in credits | Four separate `ACCOUNT_USAGE` views with inconsistent column names. Cortex Code reports `USAGE_TIME` where the others report `START_TIME`, and carries no `USER_NAME` at all. |
| **GitHub Copilot** | Yes — user-level NDJSON report and API | Partly — AI credits are metered, the seat is a license | The legacy metrics API was **shut down in April 2026**. Seats come from a *different* API than usage. Team rollup needs a second report, and teams with fewer than five seated users are excluded from it. |
| **ChatGPT Enterprise** | Yes | Yes — credits by user, product, and model | The ChatGPT workspace and the OpenAI API Platform are **separate products with separate billing**. Summing them into one "OpenAI spend" number is the most common error on this path. The stateful conversation route was removed in June 2026. |
| **Box AI** | Yes | Yes — AI Units by user *and by agent* | Metered since **20 October 2025** — anyone still modelling Box AI as a bundled seat cost is a year out of date. The per-user cost view is a **console report**, not a JSON endpoint; the programmatic path is the Enterprise Events API, which has a hard retention cliff of **two weeks** on the streaming feed and **one year** on `admin_logs`. Miss the window and the data is gone. |
| **Microsoft 365 Copilot** | Nominally | **No** | User principal name and display name are **pseudonymized by default**, and the payload is last-activity dates rather than usage volume. Without a tenant-level change this platform answers "is this seat being touched" and nothing more. |

Three consequences worth stating out loud to whoever asked for this:

1. **A single "cost per AI user" number across all five platforms is not obtainable**, because one of
   them does not meter per user at all. What *is* obtainable is metered cost per user for four of
   them, plus seat utilization for the fifth. That is a better answer anyway — an unused seat is the
   cheapest saving available.
2. **Microsoft 365 Copilot will not support the engagement-tier analysis** they liked from ChatGPT
   Enterprise. Last-activity dates cannot distinguish a light user from a power user.
3. **Box AI adds a dimension the others mostly lack: cost per *agent*.** AI Units are consumed by
   configured agents as well as by people, so "which agent is expensive" becomes answerable — and
   that is closer to "where should we invest next" than any per-person number. Snowflake Cortex
   carries the same idea in its agent name; see [Extending the model](#extending-the-model).

---

## The Two Decisions That Matter

Everything else in this guide is plumbing. These two are the design.

### Decision 1: do not blend meters

The tempting model is one `cost_amount` column so every dashboard can `SUM` it. Resist. A metered
credit and a fixed monthly seat are different kinds of number, and a chart that adds them produces
a total that moves for the wrong reasons and a "cost per message" that is arithmetic nonsense.

`SHAPED.UNIFIED_AI_USAGE` carries an explicit discriminator:

```
usage_date, platform, subject_key, person_key, identity_confidence,
cost_model              METERED | SEAT
native_qty              credits | tokens | messages | interactions
native_unit             the vendor's own unit, preserved
cost_amount             NULL when cost_model = 'SEAT'
source_billing_context  e.g. CHATGPT_WORKSPACE vs OPENAI_API_PLATFORM
```

Seat cost lives separately in `CONTROL.SEAT_ENTITLEMENT`, keyed by platform, person, and period.
This split makes the two useful questions answerable independently: *what did consumption cost*
and *are we paying for licenses nobody touches*.

Budgeting still needs one blended number, so the guide provides one — in
`GOLD.AI_SPEND_ALLOCATED`, a clearly named view that applies seat amortization and **exposes the
allocation rule as a column**. The invented precision stays visible instead of hiding inside a
`SUM`. That is the whole trick: allocate deliberately in one labelled place, rather than
accidentally everywhere.

`source_billing_context` exists for one specific reason. ChatGPT Enterprise and the OpenAI API
Platform are separate contracts with separate meters. Keeping the context on every row makes it
impossible to accidentally produce a combined "OpenAI" figure that matches neither invoice.

### Decision 2: identity is the actual project

Every platform names people differently:

| Platform | Subject key you get |
|---|---|
| Snowflake | numeric `USER_ID`, resolvable to a login name |
| GitHub | GitHub login — often not the corporate email |
| ChatGPT Enterprise | workspace member identifier |
| Microsoft 365 Copilot | pseudonymized UPN hash, unless the tenant disables concealment |

There is no natural join key. `CONTROL.IDENTITY_MAP` is the spine, seeded from your IdP or HR
system — never from an AI vendor — and it carries the department and cost centre that make
allocation possible at all.

Two rules keep it honest:

- **Record confidence per row.** `identity_confidence` distinguishes a verified IdP match from a
  heuristic email-prefix guess. Allocation built on guesses should be visibly built on guesses.
- **Never drop unmatched rows.** They land in an `UNRESOLVED` bucket. Unattributed spend must stay
  in the total, because a 12 percent unresolved rate is itself a finding — and silently dropping
  those rows makes the platform total disagree with the invoice, which destroys trust in the whole
  report on first contact with finance.

---

## Architecture

```mermaid
flowchart LR
  subgraph vendors [Vendor admin APIs]
    OA["ChatGPT Enterprise"]
    GH["GitHub Copilot"]
    MS["M365 Copilot"]
    BX["Box AI"]
  end

  subgraph ctl [CONTROL]
    reg["PLATFORM_REGISTRY"]
    log["PULL_RUN_LOG"]
    idmap["IDENTITY_MAP"]
    seats["SEAT_ENTITLEMENT"]
  end

  subgraph rawlayer [RAW]
    stage["Stage: platform/report/date"]
    landing["LANDING_AI_USAGE<br/>VARIANT payload"]
  end

  subgraph shapedlayer [SHAPED]
    fact["UNIFIED_AI_USAGE<br/>cost_model discriminator"]
  end

  subgraph goldlayer [GOLD]
    eng["Engagement tiers"]
    dept["Department allocation"]
    fcst["Spend forecast"]
    anom["Anomaly flags"]
    alloc["AI_SPEND_ALLOCATED"]
  end

  SF["Snowflake ACCOUNT_USAGE<br/>four Cortex views"]

  OA --> stage
  GH --> stage
  MS --> stage
  BX --> stage
  stage --> landing
  reg --> landing
  landing --> log
  landing --> fact
  SF --> fact
  idmap --> fact
  seats --> fact
  fact --> eng
  fact --> dept
  fact --> fcst
  fact --> anom
  fact --> alloc
  goldlayer --> agent["Semantic view + Cortex Agent"]
```

Raw payloads land as `VARIANT` and are shredded in SQL rather than schematized on ingest. A
shredding bug is then fixed with `CREATE OR REPLACE` over data you already hold, rather than a
connector redeploy and a re-pull from an API with rate limits and a short retention window.

That retention point is not hypothetical. Box's streaming event feed holds **two weeks**, its
`admin_logs` feed **one year**, and anything older exists only as a console export. A shredding bug
discovered three weeks late is unrecoverable if you did not keep the raw payload. Landing the
vendor's bytes verbatim is the cheapest insurance in this design.

---

## What Is In This Guide

Run the SQL in numbered order. There is no `deploy_all.sql` — this is a reference implementation
you adapt, not a demo you deploy.

| File | What it does |
|---|---|
| [docs/adapter-contract.md](docs/adapter-contract.md) | **Read this second.** The landing contract every adapter satisfies, so a new vendor is a registry row and one procedure rather than a redesign. |
| [sql/01_landing.sql](sql/01_landing.sql) | Role, database, four schemas, warehouse, stage, and the four control tables. |
| [sql/02_network_secrets.sql](sql/02_network_secrets.sql) | Network rules per vendor host, external access integration, and `CREATE SECRET` templates left commented. |
| [sql/03_pull_github_copilot.sql](sql/03_pull_github_copilot.sql) | The one fully worked adapter. Watermarked, logged on both success and failure paths, `QUERY_TAG`ged. |
| [sql/04_adapter_stubs.sql](sql/04_adapter_stubs.sql) | Build specifications for ChatGPT Enterprise, Box AI, and M365 Copilot: endpoint family, auth shape, report list, required fields, and the trap each one hides. |
| [sql/05_snowflake_native.sql](sql/05_snowflake_native.sql) | The Snowflake side. No credentials, no API, works immediately. |
| [sql/06_normalize.sql](sql/06_normalize.sql) | `UNIFIED_AI_USAGE` plus identity resolution and the unresolved bucket. |
| [sql/07_gold_dts.sql](sql/07_gold_dts.sql) | Dynamic Tables for the five decisions, plus the labelled allocation view. |
| [sql/08_semantic_view_agent.sql](sql/08_semantic_view_agent.sql) | Semantic view and Cortex Agent, so leadership asks in English. |
| [sql/09_monitoring.sql](sql/09_monitoring.sql) | Freshness per platform, unresolved-identity rate, adapter drift detection. |
| [sql/99_teardown.sql](sql/99_teardown.sql) | Reverse-order removal. |

**Only one adapter is fully implemented on purpose.** Five hand-maintained vendor connectors would
be stale within two quarters — GitHub retired its legacy Copilot metrics API in April 2026, OpenAI
removed a conversation log route in June, and Box switched Box AI to metered AI Units with the
per-user report landing mid-2026. The contract, the identity spine, and the gold layer are the
durable parts, and they are what the numbered files after `05` protect. `04` gives each remaining
platform a build specification precise enough to implement against, without pretending its endpoint
paths will still be current a year from now.

---

## The Five Decisions It Supports

The reporting layer is built backwards from what leadership asked for.

| Decision | Where it lands | The caveat to state when you present it |
|---|---|---|
| **Spend forecasting** for budget cycles | `GOLD.AI_SPEND_FORECAST` | Trailing-window projection, not a seasonal model. Seat cost is near-deterministic; metered cost is the volatile part, so forecast the two separately and say which is which. |
| **Departmental allocation** | `GOLD.AI_SPEND_BY_DEPARTMENT` | Only as good as `IDENTITY_MAP`. Always publish the unresolved percentage next to the allocation, or someone will quietly assume it is zero. |
| **High and low usage populations** | `GOLD.AI_ENGAGEMENT_TIERS` | Tier thresholds are a **choice**, not a fact. This guide computes percentile-based tiers and documents the cut points. Do not silently inherit a vendor's definition — OpenAI's power-user definition, for instance, is top-20-percent by message volume using three or more tools, which is specific to their product surface and not portable. |
| **Anomalous consumption** | `GOLD.AI_USAGE_ANOMALIES` | Deviation against each user's own trailing baseline, not a global threshold. Flags for review, not enforcement. Snowflake-side *enforcement* belongs to `SNOWFLAKE.CORE.QUOTA` — see the cost-controls demo, not this guide. |
| **Adoption trend by platform** | `GOLD.AI_ADOPTION_TREND` | Active-user counts are only comparable within a platform. Reporting Copilot last-activity next to Cortex request volume as though they are the same measure is the trap. |

---

## Extending the Model

Two extensions are worth knowing about before you start, because both are cheaper to design in now
than to retrofit.

### Cost per agent, not just per person

The model as shipped attributes cost to **people**. But AI spend is increasingly consumed by
*configured things* rather than by humans typing: a Box AI agent processing an inbox, a Cortex Agent
answering questions, a scheduled extraction job. Two platforms already report this natively —
Box AI breaks AI Units down by agent, and `CORTEX_AGENT_USAGE_HISTORY` carries `AGENT_NAME`.

This matters because it answers a question none of the five decisions above can:
*which of the things we built is actually earning its cost.* Per-person spend tells you about
adoption; per-agent spend tells you where to invest next.

The change is small and deliberate:

1. Add `ENTITY_KEY` and `ENTITY_KIND` (`PERSON` | `AGENT` | `SERVICE`) to `SHAPED.UNIFIED_AI_USAGE`.
   `RAW.V_SNOWFLAKE_NATIVE_USAGE` already computes the value as `ENTITY_NAME` and discards it.
2. Add a `GOLD.AI_SPEND_BY_AGENT` Dynamic Table alongside `AI_SPEND_BY_DEPARTMENT`.
3. Keep the person grain as-is. A single row should not try to be both — an agent has no department,
   and forcing one produces exactly the fake attribution this guide argues against.

The reason it is not in the base model: an agent is not a person, so it does not belong in
engagement tiers, seat utilization, or departmental allocation. Adding the dimension without
thinking about which gold objects it applies to is how a clean model becomes a confusing one.

### Value, not just cost

Everything here measures consumption. None of it measures whether the consumption was worth it,
and no vendor telemetry can tell you that — the signal lives in your own systems: tickets closed,
cycle time, deal velocity, code merged.

The join key already exists. `PERSON_KEY` is a corporate identity, so `GOLD.PERSON_DAY_USAGE` joins
directly to any operational fact keyed by employee. That is the whole argument for building this in
Snowflake rather than buying a dashboard: a vendor tool cannot join to data it does not have.

Treat that as the phase-2 conversation, and be honest that it is correlation. "Power users close
tickets faster" may mean the tool helps, or that fast people adopt tools early. Worth measuring,
not worth over-claiming.

---

## Gotchas: Read Before You Build

### 1. Metered and seat costs are not addable

Covered above, and it is the most consequential mistake available here. A blended total drops when
a heavy user goes on leave even though the seat bill did not change, and it rises when a team's
metered usage spikes even though headcount is flat. Finance will find the discrepancy against the
invoice, and the report loses credibility permanently.

### 2. Microsoft 365 Copilot pseudonymizes user identity by default

`getMicrosoft365CopilotUsageUserDetail` returns hashed values in the `userPrincipalName` and
`displayName` fields unless the tenant has disabled report concealment. The hashes are stable, so
you can trend an anonymous individual, but you **cannot join them to a department** without that
tenant setting changed by an Entra administrator.

Verify this setting before promising user-level Copilot reporting. In some organizations it is
deliberately on, and a privacy office may decline to change it — a legitimate answer that removes
Copilot from user-level scope entirely.

### 3. ChatGPT Enterprise and the OpenAI API Platform are different products

Separate organizations, separate entitlements, separate meters, separate agreements. Merging their
exports produces a number that reconciles to no invoice. `source_billing_context` on every row is
the guard, and it is worth keeping even if you only ingest one of the two today.

Also separate within OpenAI's own surface: analytics endpoints answer adoption questions, and the
compliance log platform answers audit questions. They are not interchangeable and they legitimately
disagree, because compliance returns raw system records — including internal messages and rows
without timestamps — while analytics returns cleaned data. Neither is wrong. Use analytics for
adoption reporting and expect the counts to differ from compliance.

### 4. Box AI's numbers live in a console report, and the API feed expires

Box exposes AI usage three ways, and they are not interchangeable:

| Surface | Grain | Programmatic? | Retention |
|---|---|---|---|
| AI Insights dashboard | AI Units by user, by agent, by capability | No — console | Current period |
| AI Units Admin Report | AI Units by user and agent, monthly | Export only, can auto-deliver to a Box folder | Historical months |
| Enterprise Events API | Individual AI events | Yes — `admin_logs` or `admin_logs_streaming` | **2 weeks streaming, 1 year `admin_logs`, 7 years console export only** |

That splits the work in an awkward but manageable way. The number finance wants — AI Units per user
per month — comes from a **report**, so the adapter ingests a file Box drops in a folder rather than
calling a JSON endpoint. The events API gives you granularity and freshness but not the billing
unit directly.

The retention cliff is the part that bites. Two weeks on the streaming feed means a pipeline that
breaks over a holiday loses data permanently, and a watermark that resumes from the last success is
not enough on its own — you also need the health view to scream well inside the window. This is the
strongest argument in the whole guide for landing raw payloads immutably: it is the only copy you
will ever have.

Also worth correcting a common assumption: **Box AI has been metered since 20 October 2025.** If
someone tells you Box AI is bundled into the seat, they are describing the pre-2026 model.

### 5. GitHub splits usage and licensing across two APIs

Usage metrics do not include seat or license state; that lives in the user management API and is
the source of truth for entitlement. You need both to answer "who has a seat and is not using it",
which is the question that pays for the project.

Two further traps: the legacy metrics API was retired in April 2026, so older sample code and blog
posts will not run. And team-level rollup requires joining a separate user-teams report which
excludes teams with fewer than five seated users — small teams vanish from team views while their
members remain in per-user data, so team totals will not sum to the organization total.

### 6. Vendor schema drift is the operational risk, not API downtime

These are young admin APIs and they change. An adapter that silently maps a renamed field to
`NULL` produces a chart that looks fine and is wrong, which is worse than a failed pull.

Make adapters assert on their own payload shape and **fail loudly** when a required field is
missing. `CONTROL.V_PIPELINE_HEALTH` surfaces per-platform freshness so a quietly dead adapter
shows up as stale data rather than a plausible flat line. A missing feed should look broken.

### 7. User-level AI telemetry is monitoring-adjacent — clear it first

You are building a per-person record of AI tool use. In many jurisdictions and under many works
council agreements that is employee monitoring, whatever the stated intent.

Settle four things before the first pull, not after:

- A named owner accountable for the dataset
- A stated purpose, and a decision on whether individual rows may be used in performance
  conversations — the defensible answer is usually no
- A retention period with an actual pruning task, not an intention
- RBAC that separates aggregate reporting from row-level access, so the department-allocation
  dashboard does not require access to individual rows

Note that this pipeline deliberately handles **usage metadata only** — no prompts, no completions,
no file contents. That boundary is much easier to defend in a privacy review than "we ingest the
compliance logs and promise not to look", and it is sufficient for all five decisions above.

### 8. Do not convert native units into each other

Credits, tokens, messages, and interactions are not interchangeable, and no exchange rate between
them is defensible. Preserve `native_qty` with `native_unit` and compare platforms on **currency
cost** or on **user counts**, never on raw quantity. "We sent 40 percent more messages than
Cortex requests" is not a sentence that means anything.

---

## Related Guides

- [Cortex AI functions usage history](https://docs.snowflake.com/en/sql-reference/account-usage/cortex_ai_functions_usage_history) — the Snowflake-native per-user credit source
- [Snowflake quotas](https://docs.snowflake.com/en/user-guide/quotas) — enforcement for the Snowflake side, once visibility exists
- [Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-about) — the incremental engine behind the gold layer
- [External access with secrets](https://docs.snowflake.com/en/developer-guide/external-network-access/creating-using-external-network-access) — the credential pattern every adapter uses
- [Cortex Analyst semantic views](https://docs.snowflake.com/en/user-guide/views-semantic/overview) — the layer the agent reasons over

## External References

- [GitHub Copilot usage metrics data reference](https://docs.github.com/en/copilot/reference/copilot-usage-metrics/copilot-usage-metrics)
- [GitHub Copilot user management API](https://docs.github.com/en/rest/copilot/copilot-user-management)
- [OpenAI: Compliance API vs user analytics](https://help.openai.com/en/articles/11327494-compliance-api-vs-user-analytics-in-chatgpt-enterpriseedu)
- [OpenAI Compliance Platform](https://help.openai.com/en/articles/9261474-openai-compliance-platform-for-enterprise-and-edu-customers)
- [Microsoft Graph: getMicrosoft365CopilotUsageUserDetail](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/api/admin-settings/reports/copilotreportroot-getmicrosoft365copilotusageuserdetail)
- [Microsoft 365 admin center report concealment](https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/activity-reports)
- [Box AI Insights dashboard](https://docs.box.com/en/box-admin-tools/reporting-and-insights/ai-insights) — AI Units by user, agent, and capability
- [Box Enterprise Events API](https://developer.box.com/guides/events/enterprise-events/for-enterprise) — the programmatic path, and the retention tiers
- [Box Platform API reference](https://developer.box.com/reference/)
