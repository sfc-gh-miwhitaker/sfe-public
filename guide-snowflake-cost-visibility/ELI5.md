> Simplified from: guide-snowflake-cost-visibility/README.md

## One-Sentence Version

Before you can control Snowflake spending, you need three foundational capabilities: a monthly budget alert, a view that shows where credits went, and warehouse-level guardrails that can actually stop spend.

## The Story (analogy-driven)

Think of your Snowflake account as a house with multiple utility meters.

- **Budget object** — like setting a monthly utility budget; the power company texts you when you're trending over, but won't cut your power.
- **ACCOUNT_USAGE views** — like reading each meter (gas, electric, water) to see which one is driving the bill.
- **Resource monitors** — the actual circuit breakers; they can shut off a specific outlet (warehouse) when it hits a limit.

Most houses are running without at least one of these. The gap is usually the circuit breakers — plenty of accounts have an alert and no way to actually stop anything.

There is a fourth lock — the one on the control panel, deciding who is even allowed to switch on the expensive AI appliances. That is a different job (access control, not cost visibility) and a different guide.

## The Cast (concept glossary)

- **Budget object** — Alerts you when projected monthly spend exceeds your threshold. Does not block spend.
- **METERING_DAILY_HISTORY** — The main view showing where credits went, broken down by service type. Up to 3 hours behind.
- **Resource monitor** — Can actually suspend a warehouse at a credit limit. Only covers warehouses — not AI, not serverless.
- **SERVICE_TYPE** — The column that tells you what consumed the credits (warehouse compute, AI services, auto-clustering, etc.).

## What Changed

- Before: credits were spent with no forecast, no attribution, and no automatic stop.
- After: the budget object warns you before month-end, `METERING_DAILY_HISTORY` tells you which service drove the bill, and resource monitors suspend a warehouse at a limit you choose. That is the foundational layer — visibility plus a hard stop on warehouse spend.

## What to Watch Out For

- Resource monitors cover warehouses only. They cannot stop AI services, serverless tasks, or any non-warehouse compute.
- The budget object only alerts — it never blocks spend. If you need hard enforcement, use resource monitors for warehouses. For AI credits specifically there are per-user caps (`SNOWFLAKE.CORE.QUOTA`, and per-surface daily limits for the coding assistant) — so the budget object is not your only option there, just the broadest alert.
- How far behind the usage views run depends on which view you read. There is no single number. `METERING_DAILY_HISTORY` is up to 3 hours behind; check any other view's own documentation.
- When you ALTER a resource monitor with a TRIGGERS clause, it replaces all existing triggers. Always re-specify every trigger you want to keep.
- Reading ACCOUNT_USAGE views requires `IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE`. Without the grant, queries return "object does not exist."

## The One Thing to Remember

Run the service-type breakdown query (`METERING_DAILY_HISTORY` grouped by `SERVICE_TYPE`) today — it takes two minutes and immediately tells you where your credits are actually going.

> For the full technical details, see the source document.

Pair-programmed by SE Community + Cortex Code
