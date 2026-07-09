> Simplified from: guide-snowflake-cost-visibility/README.md

## One-Sentence Version

Before you can control Snowflake spending, you need four foundational capabilities: a monthly budget alert, a view that shows where credits went, warehouse-level guardrails that can actually stop spend, and a permission gate for who can call AI functions.

## The Story (analogy-driven)

Think of your Snowflake account as a house with multiple utility meters.

- **Budget object** — like setting a monthly utility budget; the power company texts you when you're trending over, but won't cut your power.
- **ACCOUNT_USAGE views** — like reading each meter (gas, electric, water) to see which one is driving the bill.
- **Resource monitors** — the actual circuit breakers; they can shut off a specific outlet (warehouse) when it hits a limit.
- **AI_FUNCTIONS_USER RBAC** — the lock on the control panel; decides who can flip on the expensive new appliances (AI functions).

Most houses are running without three of these four. The one most commonly missing — the lock on the AI control panel — matters most as AI usage grows, because by default everyone in the building has a key.

## The Cast (concept glossary)

- **Budget object** — Alerts you when projected monthly spend exceeds your threshold. Does not block spend.
- **METERING_DAILY_HISTORY** — The main view showing where credits went, broken down by service type. Up to 3 hours behind.
- **Resource monitor** — Can actually suspend a warehouse at a credit limit. Only covers warehouses — not AI, not serverless.
- **AI_FUNCTIONS_USER** — A narrow permission role that lets users call AI functions without granting access to agents, search, or the full Cortex surface.
- **CORTEX_USER** — The broader role that gives access to everything Cortex. Granted to all users by default.
- **SERVICE_TYPE** — The column that tells you what consumed the credits (warehouse compute, AI services, auto-clustering, etc.).

## What Changed

- Before: AI functions were accessible to every user by default, with no tiered access control and limited cost visibility.
- After: A new `AI_FUNCTIONS_USER` role (GA April 2026) lets you grant AI function access without the full Cortex surface. Combined with budgets, resource monitors, and attribution queries, you have a complete foundational governance layer.

## What to Watch Out For

- Resource monitors cover warehouses only. They cannot stop AI services, serverless tasks, or any non-warehouse compute. The budget object is your only native alert mechanism for those.
- The budget object only alerts — it never blocks spend. If you need hard enforcement, resource monitors (for warehouses) or custom tasks (for AI) are required.
- `CORTEX_USER` is granted to PUBLIC by default. Until you change this, every user in your account can call AI functions, spin up agents, and use CoWork.
- When you ALTER a resource monitor with a TRIGGERS clause, it replaces all existing triggers. Always re-specify every trigger you want to keep.
- Reading ACCOUNT_USAGE views requires `IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE`. Without the grant, queries return "object does not exist."

## The One Thing to Remember

Run the service-type breakdown query (`METERING_DAILY_HISTORY` grouped by `SERVICE_TYPE`) today — it takes two minutes and immediately tells you where your credits are actually going.

> For the full technical details, see the source document.
