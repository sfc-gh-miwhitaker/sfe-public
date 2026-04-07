# Scenario: Reduce Costs Without Restricting Access

**Goal:** Lower Cortex Code AI credit spend through smarter model selection, cache strategies, and configuration — without blocking any users.

---

## Model cost tiers

All AI credit rates per 1M tokens (on-demand at $2.00/credit):

| Model | Input ($/1M tok) | Output ($/1M tok) | Cache read | Best for |
|-------|-----------------|-------------------|-----------|---------|
| `claude-haiku-3-5` | $0.08 | $0.25 | $0.01 | High-volume completions, autocomplete |
| `llama3.1-8b` | $0.05 | $0.05 | — | Fast, cheap, local-friendly tasks |
| `llama3.1-70b` | $0.35 | $0.35 | — | Mid-tier reasoning |
| `claude-sonnet-4-5` | $3.00 | $15.00 | $0.30 | Default; balanced quality/cost |
| `claude-sonnet-4-6` | $3.00 | $15.00 | $0.30 | Latest Sonnet; same pricing |
| `openai-gpt-4.1` | $2.00 | $8.00 | $0.50 | Strong reasoning, GPT preference |
| `claude-opus-4-5` | $15.00 | $75.00 | $1.50 | Complex agentic, long-context tasks |

> **Biggest lever:** Switching from `claude-sonnet-4-5` (default) to `claude-haiku-3-5` for a power user can reduce per-request cost by 37–98x.

---

## Step 1: Find your highest-cost model + user combination

```sql
SELECT h.USER_NAME,
       f.key AS model,
       ROUND(SUM(f.value:input::FLOAT + f.value:output::FLOAT), 4) AS ai_credits,
       COUNT(*) AS requests
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.CREDITS_GRANULAR) f
WHERE h.USAGE_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP)
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 20;
```

> **Insight:** If a user is on `claude-opus-4-5` and only using it for autocomplete or docstrings, switching to `claude-haiku-3-5` will have almost no quality impact.

---

## Step 2: Check cache efficiency

Cortex Code supports prompt cache — reusing context for repeated requests (same file, same system prompt) charges `cache_read_input` instead of full `input` tokens.

```sql
SELECT f.key AS model,
       ROUND(SUM(NVL(f.value:cache_read_input::FLOAT, 0)), 4) AS cache_credits,
       ROUND(SUM(f.value:input::FLOAT), 4) AS full_input_credits,
       ROUND(
           SUM(NVL(f.value:cache_read_input::FLOAT, 0)) /
           NULLIF(SUM(f.value:input::FLOAT) + SUM(NVL(f.value:cache_read_input::FLOAT, 0)), 0)
           * 100, 1
       ) AS cache_hit_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.CREDITS_GRANULAR) f
WHERE h.USAGE_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP)
GROUP BY 1
ORDER BY 4 DESC;
```

> **Benchmark:** Cache hit rates below 20% suggest users are frequently starting new sessions or not persisting context. Encourage users to keep the IDE open between tasks.

---

## Step 3: Configure a default model per user

Users can set a default in their Cortex Code `settings.json` (no admin needed — user self-service):

```json
{
  "snow.cortex.defaultModel": "claude-haiku-3-5"
}
```

**Recommended model selection guide for users:**

| Task type | Recommended model |
|-----------|-----------------|
| Autocomplete / tab completion | `claude-haiku-3-5` or `llama3.1-8b` |
| Code explanation, docstrings | `claude-haiku-3-5` |
| Code review, refactoring | `claude-sonnet-4-5` or `claude-sonnet-4-6` |
| Architecture, design discussions | `claude-sonnet-4-5` or `openai-gpt-4.1` |
| Long document analysis, agentic | `claude-opus-4-5` (use sparingly) |

---

## Step 4: Identify opportunity — projected savings

Estimate how much you'd save by steering top users to cheaper models:

```sql
WITH user_model_spend AS (
    SELECT h.USER_NAME,
           f.key AS current_model,
           SUM(f.value:input::FLOAT) AS input_credits,
           SUM(f.value:output::FLOAT) AS output_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY h,
         LATERAL FLATTEN(input => h.CREDITS_GRANULAR) f
    WHERE h.USAGE_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP)
      AND f.key IN ('claude-opus-4-5', 'claude-sonnet-4-5', 'claude-sonnet-4-6')
    GROUP BY 1, 2
)
SELECT USER_NAME,
       current_model,
       ROUND((input_credits + output_credits), 3) AS current_credits,
       ROUND((input_credits + output_credits) * 0.02, 3) AS est_savings_if_haiku
FROM user_model_spend
ORDER BY current_credits DESC;
```

> The `0.02` factor approximates the cost ratio of `claude-haiku-3-5` vs `claude-sonnet-4-5` output tokens.

---

## Summary of levers (effort vs. impact)

| Lever | Effort | Impact | Who acts |
|-------|--------|--------|----------|
| Switch default model in settings.json | Low | High (up to 50x) | User |
| Educate users on model tiers | Low | Medium | Manager/SE |
| Keep sessions open (cache reuse) | Low | Low–medium | User |
| Tag + budget expensive warehouses | Medium | Medium | Admin |
| Revoke CORTEX_USER from idle users | Low | High (per user) | Admin |
| Restrict to Haiku-only via policy | High (custom enforcement) | Very high | Admin + Dev |

---

## Next steps

| | |
|--|--|
| Want to understand current baseline spend before optimizing | [understand-spend.md](understand-spend.md) |
| Want to block high-cost model access entirely | [restrict-access.md](restrict-access.md) |
| Want a budget to enforce after optimizing | [set-a-limit.md](set-a-limit.md) |
