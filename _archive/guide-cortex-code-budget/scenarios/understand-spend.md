# Scenario: Understand What You're Spending on Cortex Code

**Goal:** Get a clear picture of AI credit consumption — total, by user, by model, by surface — before setting any controls.

**Prerequisites:** `IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE` (or `ACCOUNTADMIN`)

**SQL worksheet:** `worksheets/understand-spend.sql`

---

## What data is available?

Two ACCOUNT_USAGE views, identical schemas, ~1–2 hour latency:

| View | Source |
|------|--------|
| `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY` | Cortex Code CLI (VS Code, terminal) |
| `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` | Cortex Code in Snowsight UI |

Key columns:

| Column | Type | Description |
|--------|------|-------------|
| `USAGE_TIME` | TIMESTAMP_LTZ | When the request was made |
| `USER_ID` | NUMBER | Snowflake internal user ID |
| `USER_NAME` | VARCHAR | Display name |
| `CREDITS_USED` | FLOAT | Total AI credits for this request |
| `CREDITS_GRANULAR` | VARIANT | Per-model breakdown: `{model: {input, output, cache_read_input, cache_write_input}}` |
| `DEPLOYMENT_NAME` | VARCHAR | Model alias (e.g. `claude-sonnet-4-5`) |

---

## Step 1: Confirm data is flowing

```sql
SELECT COUNT(*) AS total_requests,
       MAX(USAGE_TIME) AS most_recent_event
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY;
```

> **If empty:** Your team may not be using the CLI surface. Try the Snowsight view instead, or confirm users have been granted `SNOWFLAKE.CORTEX_USER`.

---

## Step 2: Daily credit spend (last 30 days)

```sql
SELECT DATE_TRUNC('day', USAGE_TIME)::DATE AS usage_date,
       ROUND(SUM(CREDITS_USED), 4) AS credits_used,
       COUNT(*) AS requests
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
WHERE USAGE_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP)
GROUP BY 1
ORDER BY 1 DESC;
```

> **Insight:** Look for weekday spikes vs. weekend baseline. A high baseline on weekends can indicate background processes (agentic, batch) vs. interactive use.

---

## Step 3: Who are your top spenders?

```sql
SELECT USER_NAME,
       ROUND(SUM(CREDITS_USED), 4) AS total_credits,
       COUNT(*) AS total_requests,
       ROUND(AVG(CREDITS_USED), 6) AS avg_credits_per_request
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
WHERE USAGE_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP)
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;
```

> **Decision point:** If the top 3 users account for >70% of spend, user-level controls (RBAC, per-user budget tag) may be more effective than account-wide limits.

---

## Step 4: Which models are being used?

```sql
SELECT f.key AS model,
       ROUND(SUM(f.value:input::FLOAT), 4) AS input_credits,
       ROUND(SUM(f.value:output::FLOAT), 4) AS output_credits,
       ROUND(SUM(NVL(f.value:cache_read_input::FLOAT, 0)), 4) AS cache_hit_credits,
       COUNT(DISTINCT h.USER_NAME) AS unique_users
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.CREDITS_GRANULAR) f
WHERE h.USAGE_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP)
GROUP BY 1
ORDER BY 2 + 3 DESC;
```

> **Insight:** High `output_credits` with low `cache_hit_credits` means users are regenerating the same context repeatedly. Consider enabling persistent cache or steering to a cheaper model.

---

## Step 5: Estimate monthly cost

```sql
SELECT ROUND(SUM(CREDITS_USED), 2) AS credits_this_month,
       ROUND(SUM(CREDITS_USED) * 2.00, 2) AS est_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
WHERE USAGE_TIME >= DATE_TRUNC('month', CURRENT_DATE);
```

> Rate: $2.00/credit on-demand. Enterprise agreements may have different rates — verify with your Snowflake rep.

---

## Next steps

| What you found | Where to go next |
|----------------|-----------------|
| Spend is higher than expected | [reduce-costs.md](reduce-costs.md) — model selection and cache |
| You need a hard monthly cap | [set-a-limit.md](set-a-limit.md) — account or custom budget |
| You want email/Slack when nearing limit | [get-notified.md](get-notified.md) |
| Specific users are over-consuming | [restrict-access.md](restrict-access.md) — RBAC |
