![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2027--01--16-orange)

# Subscription Media LTV: Governed Member Value in CoWork

> DEMONSTRATION PROJECT - EXPIRES: 2027-01-16
> This demo uses Snowflake features current as of November 2026.
> After expiration, this project will be archived.

**Pair-programmed by:** SE Community + Cortex Code
**Purpose:** Show subscription lifetime value, churn, and ad economics answered in Snowflake CoWork by an agent grounded in governed business definitions, next to the same data with no definitions.
**Created:** 2026-11-17 | **Last verified:** 2026-11-17 | **Expires:** 2027-01-16 | **Status:** ACTIVE

Expiry is at most 60 days after verification. Retirement is the default; renewal requires an explicit keep decision and substantive re-verification.

> **No support provided.** Reference only; validate before production use. All data is synthetic.

---

## First Time Here?

1. Open Snowsight, create a SQL worksheet, paste [`deploy_all.sql`](deploy_all.sql), and select **Run All** (about 5 minutes).
2. Open **Snowflake CoWork** with the SYSADMIN role.
3. Pick **Member Value Analyst** and ask: *What is our 24-month net LTV and LTV to CAC by acquisition source?*
4. Ask the same question to **Raw Data Assistant (no business context)** and compare.
5. Follow the full [demo script](docs/01-DEMO-SCRIPT.md).

## What This Shows

A fictional subscription publisher sells monthly and annual memberships through
web checkout and three app stores, acquires members through six channels, and
also earns ad revenue from a free audience on outside podcast and video apps.

The demo answers the questions a finance or growth team asks about that
business:

- What is a member worth on a gross, net, contribution, and total-value basis?
- Which channels and payment platforms pay back acquisition cost, and how fast?
- How far does each ad platform's self-reported ROAS sit from the real return?
- Who is likely to cancel in the next 90 days, why, and how much revenue is at risk?
- Does a deeper first-year discount make more money or less?
- Which first-party audience segments are worth more as targeted inventory?

The point is not the dashboard. It is that the answers stay correct when anyone
asks in plain language, because the definitions live in Snowflake rather than in
each person's prompt.

## Architecture

```text
Synthetic tables ──► MEMBER_VALUE view (governed definitions, mature cohort)
     │                       │
     │                       ├─► DISCOUNT_ECONOMICS, AD_SEGMENT_ECONOMICS views
     │                       │
     ├─► CHURN_FEATURES ──► CHURN_MODEL (Snowflake ML classification) ──► CHURN_SCORES
     │
     ├─► SV_..._MEMBER_VALUE (metrics, synonyms, verified queries) ──► Member Value Analyst ─┐
     │                                                                                       ├─► CoWork
     └─► SV_..._RAW (bare tables, no definitions) ─────────────────► Raw Data Assistant ────┘
```

## Governed Definitions

| Term | Definition |
| --- | --- |
| Gross revenue | List price of every charge in the window |
| Net revenue (default LTV) | Amount charged minus payment platform fees |
| Contribution | Net revenue minus 0.40 USD delivery cost per active member month |
| Total member value | Contribution plus ad value from members listening on outside apps |
| Mature cohort | Members who signed up at least 24 months before the 2026-10-31 as-of date |
| LTV to CAC | 24-month contribution divided by CAC, same cohort for both |
| CAC payback | CAC divided by average monthly contribution |
| True ROAS | Paid channels only: 24-month contribution per dollar of acquisition spend |
| Revenue at risk | 90-day churn probability times next 90 days of net revenue |

## Project Structure

```text
demo-subscription-media-ltv/
  README.md
  ELI5.md
  AGENTS.md
  deploy_all.sql
  teardown_all.sql
  docs/01-DEMO-SCRIPT.md
  sql/01_setup/01_create_schema.sql
  sql/02_tables/01_reference_tables.sql
  sql/02_tables/02_generate_members_and_activity.sql
  sql/03_transformations/01_member_value_views.sql
  sql/04_cortex/01_churn_model.sql
  sql/04_cortex/02_semantic_views.sql
  sql/04_cortex/03_agents.sql
  sql/04_cortex/04_attach_cowork.sql
  tests/test_demo.py
  .claude/skills/demo-subscription-media-ltv/SKILL.md
```

## Synthetic Data

30,000 members who signed up between 2023-11-01 and 2026-10-31. Every random draw
is a hash of the member ID, and the data is pinned to a 2026-10-31 as-of date, so
every deploy produces identical rows and identical answers. Prices, fees, CAC,
CPMs, conversion rates, and audience sizes are fictional assumptions chosen to
look like a mid-sized subscription publisher. The viewing data falls off in the
three months before a member cancels, which is the pattern the churn model learns.

## Cost

Deploy runs on an XSMALL warehouse for about 5 minutes, including about 1 minute
to train the churn model. Each CoWork question runs a small query on the same
warehouse plus Cortex Agent usage. See the
[Credit Consumption Table](https://www.snowflake.com/legal-files/CreditConsumptionTable.pdf)
for current rates. The warehouse auto-suspends after 60 seconds.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Agents missing from CoWork | Run `sql/04_cortex/04_attach_cowork.sql` as ACCOUNTADMIN, or open the agent from **AI & ML > Agents** in Snowsight. |
| `Insufficient privileges` creating the API integration | Run step 2 of `deploy_all.sql` as ACCOUNTADMIN, or ask an administrator to create `SFE_GIT_API_INTEGRATION`. |
| `File not found` on `EXECUTE IMMEDIATE FROM` | Run `ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO FETCH;` and retry. |
| Agent answers but cannot see data | Use the SYSADMIN role in CoWork; the demo objects are owned by SYSADMIN. |

## Cleanup

Run [`teardown_all.sql`](teardown_all.sql). It removes the agents from CoWork and
drops the schema, both semantic views, and the warehouse. Shared objects
(`SNOWFLAKE_EXAMPLE`, `GIT_REPOS`, `SEMANTIC_MODELS`, `SFE_GIT_API_INTEGRATION`)
stay in place.

## Development Tools

- **AGENTS.md**: project instructions for Cortex Code and compatible AI tools
- **.claude/skills/**: project skill describing how to extend the demo
- **Cortex Code**: open this folder and ask *"Help me get started with this project."*

## External References

- [CREATE SEMANTIC VIEW](https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view)
- [Create and manage agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage)
- [User access and settings for agents in Snowflake CoWork](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/deploy-agents)
- [Classification (Snowflake ML functions)](https://docs.snowflake.com/en/user-guide/ml-functions/classification)
