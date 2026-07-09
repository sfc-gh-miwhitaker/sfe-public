> Simplified from: guide-cortex-ai-cost-controls/README.md

## One-Sentence Version

This guide shows you how to see, attribute, limit, and protect your Snowflake AI spending so nobody gets a surprise bill.

## The Story (analogy-driven)

Think of your Snowflake account as a building with electricity running to every floor. AI features are new appliances you plugged in — some run all day, some only when someone flips the switch. Your electricity bill just tripled, and you need to figure out which floor is responsible.

First you read the meters (usage views) to see the totals. Then you label each appliance (tags) so you know which team owns which cost. Next you install per-circuit breakers (user limits) so one team can't overload the building. Finally you add a main breaker (account budget) and a smart sensor (runaway query detection) for things that spike unexpectedly.

Snowflake's built-in AI coding tool (CoCo) has a simple on/off credit limit — one setting, done. Everything else requires you to build the enforcement yourself with scheduled checks and access revocations. The guide gives you the SQL for both.

## The Cast (concept glossary)

- **ACCOUNT_USAGE views** — Snowflake's audit log for credit consumption; always 45-60 minutes behind real time.
- **Tags** — Labels you stick on agents, warehouses, or users so you can ask "how much did the sales team spend?"
- **Budget object** — A monthly spending threshold that alerts you (but does not block spend) when you approach it.
- **AI_FUNCTIONS_USER** — A permission toggle that gates who can call AI SQL functions. Revoke it, and that person can't use AI functions.
- **CoCo** — Snowflake's coding agent; the only AI service with a built-in per-user credit limit.
- **Runaway query** — A single AI function call pointed at millions of rows, silently burning credits until someone notices.

## What Changed

- Before: AI features bill to one undifferentiated "AI_SERVICES" line. No per-user limits exist for most services.
- After: 14 separate usage views let you break spend down by service, user, and agent. Tags enable cost-center attribution. Scheduled tasks enforce per-user caps where Snowflake doesn't offer a native toggle.

## What to Watch Out For

- Usage views lag 45-60 minutes. A runaway query can burn significant credits before it appears in any view. Always pair cost-based detection with a hard time-based warehouse timeout.
- The enforcement tasks themselves cost credits to run. Four tasks polling all day is a real, small ongoing bill.
- Tags only work forward. Historical spend from before tagging remains unattributed.
- Setting limits without knowing your baseline leads to limits that either never fire or block legitimate work on day one. Collect a week of data first.

## The One Thing to Remember

Set `STATEMENT_TIMEOUT_IN_SECONDS` on your AI warehouse today — it takes 30 seconds and is the single fastest protection against a runaway query burning your budget while you sleep.

> For the full technical details, see the source document.
