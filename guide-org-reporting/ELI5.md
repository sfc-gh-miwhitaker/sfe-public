> Simplified from: guide-org-reporting/README.md

## One-Sentence Version

Snowflake lets you see what's happening across all your accounts in one place, but the depth of what you can see depends on which type of access you set up.

## The Story

Imagine your company has twenty offices, and each office keeps its own logbook of who came in, what they spent, and what they worked on. One day you're asked: "What's happening across all twenty offices?" You need a central report.

Snowflake's answer is a set of read-only summary reports called ORGANIZATION_USAGE. They pull numbers from every account (office) into one view. But there's a catch: there are two tiers of access. The basic tier shows you spending and storage — like seeing each office's utility bills. The premium tier shows you everything: who logged in, what they queried, what security policies exist — like getting full access to every office's logbook.

The basic tier is free to query. The premium tier bills you for every record it processes, so you don't want dashboards hitting it live on every page load. Instead, you run one scheduled job that copies the numbers into your own table, and point your dashboards at that.

Two walls you can't see through: accounts outside your Snowflake organization never appear (even if you share data with them), and billing views disappear entirely if you bought Snowflake through a reseller.

## The Cast

- **ORGANIZATION_USAGE** — The central schema where cross-account reports live
- **Organization account** — A special admin account that gets the full (premium) view set
- **ORGADMIN-enabled account** — A regular account with limited cross-account visibility (no premium views)
- **Premium views** — The detailed reports (query history, logins, security policies) that cost extra to read
- **Application roles** — Named permission bundles in the organization account (e.g., "security viewer")
- **Database roles** — Simpler permission bundles in a regular ORGADMIN account (only three exist)
- **Materialization** — Copying live report data into a table you own on a schedule

## What Changed

- Before: Each account's usage data lived only in that account's ACCOUNT_USAGE schema
- After: ORGANIZATION_USAGE aggregates the same data across every account, adding account_name as a dimension
- The non-premium path gives ~25 views covering credits, storage, and billing
- The premium path adds ~80+ views covering queries, security, governance, and object inventory
- Premium views need ~2 weeks to backfill 365 days of history after the org account is created

## What to Watch Out For

- **ORGADMIN role doesn't automatically have access.** Enabling it is step one; you still need ACCOUNTADMIN to grant the database roles. People get stuck here.
- **Unbounded queries are expensive.** Always filter by the view's time column. Even `SELECT COUNT(*)` without a time range scans all history across all accounts.
- **Never use SELECT *.** Snowflake can add columns to these views at any time, which breaks downstream consumers.
- **Billing views vanish for reseller contracts.** If you bought through a partner, USAGE_IN_CURRENCY_DAILY and friends won't exist.
- **The org boundary is invisible.** If an acquired company hasn't been consolidated into your Snowflake org, their accounts simply won't show up — and nothing warns you they're missing.

## The One Thing to Remember

Decide whether you need "how much did we spend" (free ORGADMIN path) or "who did what across all accounts" (premium org account path) — that choice determines everything else.

> For the full technical details, see the source document.
