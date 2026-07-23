![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2026--07--23-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Cortex AI — Cost Monitoring & Controls

If you've deployed any Cortex AI feature in the last year, you've noticed something: the credits disappear faster than they did before. The charge shows up in your monthly statement next to "AI_SERVICES," and when someone asks you what that number represents, the honest answer is "I'm not entirely sure."

This guide is for that moment.

By the end of it, you'll understand how to **see** where AI spend is going, **attribute** it to the right team or project, **set limits** so nobody burns through the budget unnoticed, and **protect** against runaway queries that consume credits while you sleep.

**Audience:** Account admins, FinOps engineers, and anyone responsible for Snowflake cost governance who is new to Cortex AI billing.

Pair-programmed by SE Community + Cortex Code
**Created:** 2026-06-23 | **Expires:** 2026-07-23 | **Status:** ACTIVE

> **No support provided.** Reference only; validate before production use.

---

## The Mental Model

Think of your Snowflake account as a building with electricity running to every floor. Cortex AI features are new appliances you've plugged in — some run continuously, some run only when a user turns them on. Your job is to:

1. **Read the meter** — see how much electricity each floor is using (system views)
2. **Label each appliance** — know which team owns which device (tags)
3. **Install circuit breakers** — stop individual users from overloading their circuit (per-user limits)
4. **Set a main breaker** — prevent total building draw from exceeding capacity (account budget)
5. **Add a smart breaker** — one that trips on *cost* rather than *time* (runaway query protection)
6. **Get a text from the utility company** when something looks abnormal (anomaly detection)

Each section of this guide maps to one of those six capabilities.

---

## Vocabulary (Read This First)

These terms appear throughout the guide. They're explained here once, in plain language, so you don't need to decode them later.

| Term | What it means |
|------|---------------|
| **ACCOUNT_USAGE views** | Snowflake's audit log for everything that costs credits. Lives in the `SNOWFLAKE` database. Has ~45-minute latency — you're always looking at the recent past, not right now. |
| **Database role** | A role that lives inside the `SNOWFLAKE` database and controls access to specific platform features. `AI_FUNCTIONS_USER` is one. `CORTEX_AGENT_USER` is another. You can revoke them independently. |
| **Tags** | Key-value labels you attach to Snowflake objects (warehouses, agents, users). The mechanism that lets you ask "how much did the sales team spend?" |
| **Budget object** | A first-class Snowflake object that watches spend against a threshold you set, then notifies you (or runs a custom action) when you approach it. Resets monthly. |
| **AI_FUNCTIONS_USER** | The database role that gates access to AI SQL functions (AI_CLASSIFY, AI_COMPLETE, AI_EXTRACT, AI_FILTER, AI_SENTIMENT, etc.). Revoking it blocks AI function access without touching broader Cortex access. GA April 2026. |
| **TOKEN_CREDITS / CREDITS** | The credit column. Frustratingly, its name varies by view — some use `CREDITS`, some use `TOKEN_CREDITS`, some use `CREDITS_USED`. The SQL scripts in this guide always comment which column to use. |
| **CoCo** | Cortex Code — the agentic IDE (CLI + Desktop + Snowsight). The only Cortex service with native per-user credit limits built in. |
| **CoWork / SI** | Snowflake CoWork (formerly Snowflake Intelligence) — the business-user agent surface. In SQL, it's still `SNOWFLAKE_INTELLIGENCE`. No native per-user limits. |

> **Two things that will bite you before you start.**
> 1. **Reading the views requires a grant.** If you're not `ACCOUNTADMIN`, your role needs `GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE <your_role>;` or every query in Section 1 returns "object does not exist."
> 2. **The enforcement tasks cost credits to run.** Each `user_limits_*` and runaway task spins up compute on its schedule (every 10-15 min). Four tasks polling all day is a real, if small, ongoing bill — the governance itself isn't free. Use a dedicated XS warehouse or serverless tasks, and don't schedule more frequently than the view latency justifies.

---

## 1. Seeing Your Spend

The first step is knowing what exists. Snowflake automatically records credit consumption for every Cortex AI service into dedicated ACCOUNT_USAGE views — you don't configure anything, they just populate.

### The view catalog

| # | View | What it tracks | Credit column |
|---|------|----------------|---------------|
| 1 | `METERING_DAILY_HISTORY` | All AI services rolled up (look for `SERVICE_TYPE = 'AI_SERVICES'`) | `CREDITS_USED` |
| 2 | `CORTEX_AI_FUNCTIONS_USAGE_HISTORY` | AI SQL functions (AI_CLASSIFY, AI_COMPLETE, etc.) | `CREDITS` |
| 3 | `CORTEX_AGENT_USAGE_HISTORY` | Cortex Agents | `TOKEN_CREDITS` |
| 4 | `CORTEX_ANALYST_USAGE_HISTORY` | Cortex Analyst (text-to-SQL) | `CREDITS` |
| 5 | `SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY` | Snowflake CoWork (the business agent) | `TOKEN_CREDITS` |
| 6 | `CORTEX_CODE_CLI_USAGE_HISTORY` | CoCo CLI | `TOKEN_CREDITS` |
| 7 | `CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` | CoCo in Snowsight | `TOKEN_CREDITS` |
| 8 | `CORTEX_SEARCH_DAILY_USAGE_HISTORY` | Cortex Search (daily rollup) | `CREDITS` |
| 9 | `CORTEX_SEARCH_SERVING_USAGE_HISTORY` | Cortex Search (per-query serving) | `CREDITS` |
| 10 | `CORTEX_SEARCH_BATCH_QUERY_USAGE_HISTORY` | Cortex Search batch queries | `CREDITS_USED` |
| 11 | `CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY` | Document AI / AI_PARSE_DOCUMENT | `CREDITS_USED` |
| 12 | `CORTEX_FINE_TUNING_USAGE_HISTORY` | Fine-tuning jobs | `TOKEN_CREDITS` |
| 13 | `CORTEX_REST_API_USAGE_HISTORY` | REST API calls | `TOKENS` (no direct credit column) |
| 14 | `CORTEX_PROVISIONED_THROUGHPUT_USAGE_HISTORY` | Provisioned throughput commitments | `PTU_CREDITS` |

All views live in `SNOWFLAKE.ACCOUNT_USAGE`. You need `ACCOUNTADMIN` or a role with `IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE` to query them.

### Your first query: "How much AI spend this month?"

```sql
SELECT
    usage_date,
    credits_used,
    credits_billed
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type = 'AI_SERVICES'
  AND usage_date >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY usage_date DESC;
```

If that number surprises you, the cross-service summary in [`sql/visibility_queries.sql`](sql/visibility_queries.sql) breaks it down by individual service.

### What "45-minute latency" actually means

These views are not real-time. When a Cortex Agent processes a request at 2:00 PM, that usage may not appear in `CORTEX_AGENT_USAGE_HISTORY` until 2:45 PM. This is fine for daily reporting and trend analysis. It is **not** fine for real-time enforcement (we'll address that gap in the enforcement section).

For faster feedback, the Snowsight UI (Admin → Cost Management) provides near-real-time service consumption charts. It doesn't give you SQL-level control, but it's where you go when you need to see what's happening right now.

---

## 2. Knowing Who's Spending (Tag-Based Attribution)

The views above tell you *how much* was spent. They don't tell you *by whom* or *for what project* — at least not at the granularity most organizations need.

Tags are the answer.

### The problem without tags

Imagine your data team has deployed three Cortex Agents: a sales assistant, a support triage bot, and a finance summarizer. By month-end, AI_SERVICES consumed 1,200 credits. But which agent burned what? Without tags, your only option is to manually sum per-agent rows in `CORTEX_AGENT_USAGE_HISTORY`. With three agents, that's manageable. With thirty, across five teams, it's not.

### The three-layer tagging strategy

Apply tags at three levels for complete attribution:

```
Layer 1: Tag the agents themselves        → "this agent belongs to sales_team"
Layer 2: Tag the warehouses and tools      → "this warehouse serves AI workloads for project_x"
Layer 3: Tag the users                     → "this person's spend counts toward marketing_budget"
```

The usage views already expose `AGENT_TAGS` and `USER_TAGS` columns (as arrays). Once you've applied tags, you query these columns to group spend by cost center, team, project, or anything else that matters.

### Setting it up

```sql
-- Create a cost center tag
CREATE TAG IF NOT EXISTS COST_GOVERNANCE.TAGS.COST_CENTER
  COMMENT = 'Identifies the team or project that owns this cost';

-- Apply to agents
ALTER AGENT my_db.my_schema.sales_agent
  SET TAG COST_GOVERNANCE.TAGS.COST_CENTER = 'sales_team';

-- Apply to users
ALTER USER alice SET TAG COST_GOVERNANCE.TAGS.COST_CENTER = 'sales_team';
```

### Querying attributed spend

First inspect the tag array shape on your account (the key names inside the array vary), then filter on the tag name with FLATTEN:

```sql
-- Inspect first:
SELECT agent_tags FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE ARRAY_SIZE(agent_tags) > 0 LIMIT 5;

-- Then attribute (adjust t.value:name / t.value:value to match what you saw):
SELECT
    h.agent_name,
    t.value:value::VARCHAR AS cost_center,
    SUM(h.token_credits) AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.agent_tags) t
WHERE h.start_time >= DATEADD('day', -30, CURRENT_DATE())
  AND t.value:name::VARCHAR = 'COST_CENTER'
GROUP BY h.agent_name, cost_center
ORDER BY total_credits DESC;
```

The full tag setup — including warehouse tagging, user tagging, and verification queries — is in [`sql/tag_setup.sql`](sql/tag_setup.sql).

> **Tags only work going forward.** If you apply a tag today, historical spend from yesterday is unattributed. The sooner you tag, the more complete your attribution data will be.

---

## 3. Setting Limits

This is where the enforcement story gets honest.

**Cortex Code (CoCo) has native per-user credit limits.** One ALTER statement, done. It's a rolling 24-hour window, it blocks the user when they hit the limit, and user-level settings override account-level settings. This is the gold standard.

**Everything else requires you to build the enforcement yourself.** AI Functions, Cortex Agents, Cortex Analyst, and Snowflake Intelligence/CoWork all have usage views and access-control database roles, but no built-in parameter that says "block this user after N credits." You need to write a stored procedure, point a task at it, and manage a limits table. It works, but it's engineering effort — not a toggle.

### The honest per-service breakdown

| Service | Native per-user limit? | Access control mechanism | How to enforce |
|---------|----------------------|--------------------------|----------------|
| CoCo CLI | **Yes** — `CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER` | `CORTEX_USER` database role | ALTER ACCOUNT/USER SET parameter |
| CoCo Desktop | **Yes** — `CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER` | `CORTEX_USER` database role | ALTER ACCOUNT/USER SET parameter |
| CoCo Snowsight | **Yes** — `CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER` | `CORTEX_USER`, `COPILOT_USER` | ALTER ACCOUNT/USER SET parameter |
| AI Functions | **No** — custom task required | `AI_FUNCTIONS_USER` database role | Task + procedure revokes role when over budget |
| Cortex Agents | **No** — custom task required | `CORTEX_AGENT_USER`, or USAGE on specific agent | Task + procedure revokes USAGE per agent |
| Cortex Analyst | **No** — custom task required | `CORTEX_ANALYST_USER` database role | Task + procedure revokes role |
| Snowflake Intelligence | **No** — custom task required | `CORTEX_AGENT_USER` or USAGE on SI object | Task + procedure revokes USAGE |

### Cortex Code: The easy one

Three parameters, one per surface. Set them at the account level (applies to everyone) or override per user:

```sql
-- Every user gets 20 credits/day on each CoCo surface
ALTER ACCOUNT SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
ALTER ACCOUNT SET CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;
ALTER ACCOUNT SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 20;

-- Power user gets more on CLI
ALTER USER power_user SET CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 50;

-- Block someone entirely from Snowsight CoCo
ALTER USER restricted_user SET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 0;
```

Full script with audit query: [`sql/user_limits_cortex_code.sql`](sql/user_limits_cortex_code.sql)

### AI Functions: The DIY pattern

This is the most common enforcement target because AI Functions are the easiest to call (a single SQL statement) and the most likely to produce unexpectedly large bills when pointed at large tables without forethought.

The pattern:

1. **Limits table** — stores each user's daily credit cap
2. **Stored procedure** — queries `CORTEX_AI_FUNCTIONS_USAGE_HISTORY`, compares to limits, revokes or restores `AI_FUNCTIONS_USER`
3. **Task** — runs the procedure every 15 minutes

```sql
-- The limits table
CREATE TABLE ai_function_user_limits (
    user_name         VARCHAR NOT NULL,
    daily_credit_limit NUMBER(10,2) NOT NULL,
    is_revoked        BOOLEAN DEFAULT FALSE,
    ...
);

-- Set limits
INSERT INTO ai_function_user_limits (user_name, daily_credit_limit)
VALUES ('ALICE', 10.00), ('BOB', 5.00);
```

Full implementation: [`sql/user_limits_ai_functions.sql`](sql/user_limits_ai_functions.sql)

### Cortex Agents: Per-agent granularity

The advantage here: because agents are Snowflake objects, you can revoke access to **one specific agent** without touching the others. If Alice's sales-agent budget is exhausted, she can still use her marketing agent.

```sql
-- USAGE ON AGENT is granted to ROLES, not users. To block one user, revoke from
-- a role only that user holds (e.g., their default role). If a shared role holds
-- the grant, revoking blocks everyone on it — see the note in the SQL file.
REVOKE USAGE ON AGENT my_db.my_schema.sales_agent FROM ROLE alice_role;

-- Alice can still use other agents her roles have USAGE on
```

Full implementation with scheduled enforcement: [`sql/user_limits_agents_si.sql`](sql/user_limits_agents_si.sql)

### Account-level budget: The main breaker

You get exactly one account-level budget. It monitors overall spend (or specific resources) against a monthly threshold and fires notifications or custom actions when you approach it.

```sql
-- Create budget object
CREATE SNOWFLAKE.CORE.BUDGET IF NOT EXISTS COST_GOVERNANCE.BUDGETS.ACCOUNT_AI_BUDGET();

-- Set monthly limit
CALL COST_GOVERNANCE.BUDGETS.ACCOUNT_AI_BUDGET!SET_SPENDING_LIMIT(1000);

-- Notify at thresholds
CALL COST_GOVERNANCE.BUDGETS.ACCOUNT_AI_BUDGET!SET_EMAIL_NOTIFICATIONS(
    'admin@yourcompany.com',
    ARRAY_CONSTRUCT(50, 80, 100)
);
```

Full implementation with custom actions (e.g., auto-reduce CoCo limits when budget hits 90%): [`sql/account_budget.sql`](sql/account_budget.sql)

---

## 4. Catching Runaway Queries

AI Functions are the one place where a single query can silently burn through your budget. A `SELECT AI_COMPLETE(...)` pointed at a 10-million-row table will happily process every row, calling the LLM once per row, accumulating credits the entire time.

Traditional protection is time-based: `STATEMENT_TIMEOUT_IN_SECONDS` on the warehouse kills anything running longer than N seconds. That works for most queries, but it doesn't know whether a 20-minute query has consumed 2 credits or 200.

Snowflake added **cost-aware query visibility** through the `IS_COMPLETED` column in `CORTEX_AI_FUNCTIONS_USAGE_HISTORY`. When a query is still running, `IS_COMPLETED = FALSE` and `CREDITS` shows how much it has consumed so far.

### The catch: latency

> **The view has up to 60 minutes of latency.** Data may appear as quickly as 10 minutes after execution begins, but the maximum is 60. By the time a runaway query shows up, it may have already consumed significantly more credits than your threshold. This is a safety net, not a real-time circuit breaker.

### The recommendation: use both

1. **Time-based (immediate):** `ALTER WAREHOUSE ai_wh SET STATEMENT_TIMEOUT_IN_SECONDS = 1800;` — kills anything running longer than 30 minutes, regardless of cost.
2. **Cost-based (delayed):** Task polling `CORTEX_AI_FUNCTIONS_USAGE_HISTORY` for `IS_COMPLETED = FALSE AND CREDITS >= threshold`, then calling `SYSTEM$CANCEL_QUERY()`.

Together they give you a hard time cap (fires instantly) plus a credit cap (fires with latency). Be honest about the overlap: because the view lags 10-60 minutes, the credit-based task can only cancel queries that are **still running** when they finally appear — i.e., queries that run *longer* than ~10 minutes AND exceed the threshold. A query that's expensive but finishes in 5 minutes is already done before the view sees it; cancellation is a harmless no-op. The credit cap's real job is catching the expensive-and-slow query that sits *under* your time cap (e.g., 25 minutes, 200 credits, with a 30-minute timeout). If that band is narrow for your workload, STATEMENT_TIMEOUT alone may be enough.

The full task + procedure pattern is documented in [`runaway-queries.md`](runaway-queries.md) and implemented in [`sql/runaway_query_protection.sql`](sql/runaway_query_protection.sql).

---

## 5. Detecting Anomalies

Once you have visibility and limits in place, the last layer is proactive detection: being told when something looks wrong before you notice it yourself.

Snowflake's **Anomaly Detection** (available in Snowsight under Admin → Cost Management) automatically identifies unexpected spikes in consumption. It looks at your historical usage pattern and flags days or services that deviate significantly.

What you get:
- Automatic detection of expense anomalies across services
- Email notifications when anomalies are detected
- Historical exploration pivoting by time and account
- No setup required for the detection itself — it runs automatically for ACCOUNTADMIN users

To share access without granting ACCOUNTADMIN, delegate the `USAGE_VIEWER` or `USAGE_ADMIN` database roles in the SNOWFLAKE database.

For programmatic alerting beyond the UI, you can combine the usage views from Section 1 with Snowflake Alerts:

```sql
-- Alert when daily AI spend exceeds 2x the 7-day average
CREATE OR REPLACE ALERT ai_spend_anomaly_alert
  WAREHOUSE = '<your_warehouse>'
  SCHEDULE = 'USING CRON 0 8 * * * America/Los_Angeles'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
    WHERE service_type = 'AI_SERVICES'
      AND usage_date = CURRENT_DATE() - 1
      AND credits_used > (
        SELECT AVG(credits_used) * 2
        FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
        WHERE service_type = 'AI_SERVICES'
          AND usage_date >= DATEADD('day', -8, CURRENT_DATE())
          AND usage_date < CURRENT_DATE() - 1
      )
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'ai_cost_alerts',
      'admin@yourcompany.com',
      'AI Spend Anomaly Detected',
      'Yesterday''s AI_SERVICES spend exceeded 2x the 7-day average. Review in Snowsight → Admin → Cost Management.'
    );
```

---

## Recommended Sequence

If you're starting from zero, do this in order:

| Step | What | Why first |
|------|------|-----------|
| 1 | Run the cross-service summary query from Section 1 | You need to know what your baseline is before you can set meaningful limits |
| 2 | Set CoCo limits (Section 3, native parameters) | Takes 2 minutes, immediately prevents the easiest source of uncontrolled spend |
| 3 | Apply cost center tags to your agents and users (Section 2) | Tags only work forward — every day you wait is a day of unattributed spend |
| 4 | Set `STATEMENT_TIMEOUT_IN_SECONDS` on AI workload warehouses | Immediate protection against any single long-running query |
| 5 | Implement AI Functions enforcement task (Section 3) | The DIY pattern takes real effort — do it once you have baseline data to set reasonable thresholds |
| 6 | Configure account budget notifications (Section 3) | Safety net for total spend — alerts before you overshoot |
| 7 | Implement runaway query protection (Section 4) | Requires the enforcement schema from Step 5 — layer on top |

> **Don't skip Step 1.** Setting limits without knowing your baseline leads to either limits so high they never fire, or limits so low they block legitimate work on day one. Spend a week collecting data, then set thresholds at 1.5x to 2x your observed daily usage per user.

---

## What's Next

This guide teaches the concepts and gives you the SQL to implement them. A **companion demo** (a deployable Streamlit-in-Snowflake application) will be available separately — it packages these patterns into an operational dashboard with visualizations, alerting, and one-click enforcement toggles. The demo makes good on the promises in this guide; this guide makes the demo understandable.

---

## Reference

- [Cortex Code credit limits](https://docs.snowflake.com/en/user-guide/cortex-code/credit-usage-limit) — Native parameter documentation
- [Snowflake Budgets](https://docs.snowflake.com/en/user-guide/budgets) — Budget object reference
- [AI SQL function privileges](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-privileges-and-access) — AI_FUNCTIONS_USER and model allowlist
- [Cortex Agent access control](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents/cortex-agents-access-control) — Agent privileges and database roles
- [ACCOUNT_USAGE schema](https://docs.snowflake.com/en/sql-reference/account-usage) — Full view reference
- [Snowflake Tags](https://docs.snowflake.com/en/user-guide/object-tagging) — Tag creation and application
- [Snowflake Alerts](https://docs.snowflake.com/en/user-guide/alerts) — Programmatic alert reference

---

Pair-programmed by SE Community + Cortex Code
