![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2027--02--19-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Cortex Code Access Control and Observability

Cortex Code (CoCo) — across Desktop, CLI, and Snowsight — is enabled for **every user** in a new Snowflake account by default. This guide shows an administrator how to restrict access to a specific role, roll it out progressively without surprises, and monitor ongoing usage with copy-paste SQL queries.

**Audience:** Snowflake administrators (ACCOUNTADMIN or SECURITYADMIN) responsible for governing AI tool usage.
**Created:** 2026-08-19 | **Expires:** 2027-02-19 | **Status:** ACTIVE

Pair-programmed by SE Community + Cortex Code

> **No support provided.** Reference only; validate before production use. Every SQL claim was verified against Snowflake documentation on the created date above.

---

## Start Here

| If you want to... | Jump to |
|---|---|
| Understand what controls CoCo access | [How Access Works](#how-cortex-code-access-works) |
| Lock it down to one role right now | [Lockdown Procedure](#lockdown-procedure) |
| Roll out gradually without breaking things | [Progressive Rollout](#progressive-rollout-for-the-paranoid) |
| See who is using CoCo today | [Observability Queries](#observability-queries) |
| Avoid common mistakes | [Gotchas](#gotchas-and-faq) |

---

## How Cortex Code Access Works

Three layers must ALL pass for a user to invoke Cortex Code:

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 1: CORTEX_USER database role                             │
│  Gates access to ALL Cortex AI features (CoCo, Agents,         │
│  Analyst, Search, Fine-tuning). Granted to PUBLIC by default.   │
├─────────────────────────────────────────────────────────────────┤
│  Layer 2: USE AI FUNCTIONS account privilege                    │
│  Gates AI function calls (AI_COMPLETE, AI_EXTRACT, etc.).       │
│  Granted to PUBLIC by default.                                  │
├─────────────────────────────────────────────────────────────────┤
│  Layer 3: Model RBAC (application roles)                        │
│  Controls which LLMs are available. CORTEX-MODEL-ROLE-ALL is    │
│  bootstrapped to SNOWFLAKE.PUBLIC → PUBLIC by default.          │
└─────────────────────────────────────────────────────────────────┘
```

**The single most impactful action:** revoking `SNOWFLAKE.CORTEX_USER` from `PUBLIC` disables Cortex Code (and all Cortex AI) for anyone without an explicit grant.

> Important: `CORTEX_USER` is a database role on the `SNOWFLAKE` database. Database roles cannot be granted directly to users — they must be granted to account-level roles.

---

## Lockdown Procedure

Run these statements as `ACCOUNTADMIN`. Each step is independent and reversible.

### Step 1 — Revoke CORTEX_USER from PUBLIC

```sql
USE ROLE ACCOUNTADMIN;

REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE PUBLIC;
```

This immediately removes Cortex Code access from every role that inherited it through PUBLIC. Users with an explicit grant elsewhere retain access.

### Step 2 — Create a dedicated role

```sql
CREATE ROLE IF NOT EXISTS CORTEX_CODE_USER_RL
  COMMENT = 'Grants access to Cortex Code (all surfaces)';
```

### Step 3 — Grant the required database role

```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE CORTEX_CODE_USER_RL;
```

### Step 4 — Grant USE AI FUNCTIONS

```sql
GRANT USE AI FUNCTIONS ON ACCOUNT TO ROLE CORTEX_CODE_USER_RL;
```

If you also revoked `USE AI FUNCTIONS` from PUBLIC (optional, separate action), this step is required. If you only revoked `CORTEX_USER`, this step is unnecessary because `USE AI FUNCTIONS` still flows through PUBLIC.

### Step 5 — Grant model access

```sql
-- Option A: All models (simplest)
GRANT APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-ALL" TO ROLE CORTEX_CODE_USER_RL;

-- Option B: Specific models only
GRANT APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-CLAUDE-4-SONNET" TO ROLE CORTEX_CODE_USER_RL;
GRANT APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-LLAMA3.1-70B" TO ROLE CORTEX_CODE_USER_RL;
```

If you did NOT revoke the CORTEX-MODEL-ROLE-ALL bootstrap from SNOWFLAKE.PUBLIC, model access still flows to everyone via PUBLIC. To restrict models:

```sql
-- Remove the bootstrap grant (use the stored procedure, not plain REVOKE)
CALL SNOWFLAKE.LOCAL.REVOKE_FROM_PUBLIC_APPLICATION_ROLE(
  'APP_ROLE',
  'CORTEX-MODEL-ROLE-ALL'
);
```

### Step 6 — Assign to users

```sql
GRANT ROLE CORTEX_CODE_USER_RL TO USER alice;
GRANT ROLE CORTEX_CODE_USER_RL TO USER bob;
```

Or grant to an existing role that a group already uses:

```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE DATA_ENGINEERING_RL;
```

### Step 7 — Verify

Switch to a test user or role and confirm:

```sql
USE ROLE CORTEX_CODE_USER_RL;
SELECT AI_COMPLETE('llama3.1-70b', 'Say hello');
-- Should succeed

USE ROLE PUBLIC;
SELECT AI_COMPLETE('llama3.1-70b', 'Say hello');
-- Should fail with access denied
```

---

## Progressive Rollout for the Paranoid

For administrators who want certainty before making changes.

### Phase 1 — Observe (7-14 days)

**Change nothing.** Run the observability queries below to answer:
- Who is already using Cortex Code?
- How many credits per day?
- Which surfaces and models?

This establishes a baseline and identifies stakeholders you need to notify.

### Phase 2 — Pilot (7 days)

1. Create `CORTEX_CODE_USER_RL` per the lockdown procedure above.
2. Grant it to every user identified in Phase 1 (they should notice no change).
3. Revoke `CORTEX_USER` from PUBLIC.
4. Announce internally: "Cortex Code now requires an explicit role grant. Current users are already granted. New users request access via [your process]."
5. Monitor for 7 days — watch for support tickets or broken automation.

### Phase 3 — Steady State

1. Formalize onboarding (request form, manager approval, SCIM group mapping, etc.).
2. Set up a Snowflake ALERT on the usage views to catch anomalies (see query #9 below).
3. Periodically review the "unused access" query (#8) to right-size grants.

### Rollback (any phase)

One command restores the original state:

```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE PUBLIC;
```

---

## Observability Queries

All queries use `SNOWFLAKE.ACCOUNT_USAGE` views (up to 1-hour latency, 365-day retention). Replace date ranges as needed.

### Query 1 — Who is using Cortex Code today?

```sql
SELECT
    u.name                    AS user_name,
    u.login_name              AS login_name,
    u.email                   AS email,
    COUNT(h.request_id)       AS total_requests,
    SUM(h.token_credits)      AS total_credits,
    MIN(h.usage_time)         AS first_seen,
    MAX(h.usage_time)         AS last_seen
FROM (
    SELECT user_id, request_id, token_credits, usage_time
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT user_id, request_id, token_credits, usage_time
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
    UNION ALL
    SELECT user_id, request_id, token_credits, usage_time
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
) h
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u
  ON h.user_id = u.user_id
WHERE h.usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND u.deleted_on IS NULL
GROUP BY u.name, u.login_name, u.email
ORDER BY total_credits DESC;
```

### Query 2 — Which surface is most popular?

```sql
SELECT
    'CLI'        AS surface,
    COUNT(request_id) AS requests,
    SUM(token_credits) AS credits
  FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
  WHERE usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
UNION ALL
SELECT
    'Desktop'    AS surface,
    COUNT(request_id) AS requests,
    SUM(token_credits) AS credits
  FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
  WHERE usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
UNION ALL
SELECT
    'Snowsight'  AS surface,
    COUNT(request_id) AS requests,
    SUM(token_credits) AS credits
  FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
  WHERE usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
ORDER BY credits DESC;
```

### Query 3 — What models are being consumed?

```sql
SELECT
    f.key                       AS model_name,
    COUNT(h.request_id)         AS request_count,
    SUM(f.value:input::NUMBER + 
        f.value:output::NUMBER + 
        COALESCE(f.value:cache_read_input::NUMBER, 0) +
        COALESCE(f.value:cache_write_input::NUMBER, 0)
    )                           AS total_tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY h,
     LATERAL FLATTEN(input => h.tokens_granular) f
WHERE h.usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY f.key
ORDER BY total_tokens DESC;
```

> Repeat with `CORTEX_CODE_DESKTOP_USAGE_HISTORY` and `CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` for full coverage, or UNION ALL the three before flattening.

### Query 4 — Monthly credits per user

```sql
SELECT
    u.name                      AS user_name,
    DATE_TRUNC('month', h.usage_time) AS month,
    SUM(h.token_credits)        AS credits
FROM (
    SELECT user_id, usage_time, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT user_id, usage_time, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
    UNION ALL
    SELECT user_id, usage_time, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
) h
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u
  ON h.user_id = u.user_id
WHERE h.usage_time >= DATEADD('month', -3, CURRENT_TIMESTAMP())
  AND u.deleted_on IS NULL
GROUP BY u.name, month
ORDER BY month DESC, credits DESC;
```

### Query 5 — Peak usage hours (hour-of-day distribution)

```sql
SELECT
    EXTRACT(HOUR FROM CONVERT_TIMEZONE('UTC', usage_time)) AS hour_utc,
    COUNT(request_id)    AS requests,
    SUM(token_credits)   AS credits
FROM (
    SELECT usage_time, request_id, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT usage_time, request_id, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
    UNION ALL
    SELECT usage_time, request_id, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
) h
WHERE usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY hour_utc
ORDER BY hour_utc;
```

### Query 6 — Top 10 heaviest users (last 30 days)

```sql
SELECT
    u.name                  AS user_name,
    COUNT(h.request_id)     AS total_requests,
    SUM(h.token_credits)    AS total_credits,
    SUM(h.tokens)           AS total_tokens
FROM (
    SELECT user_id, request_id, token_credits, tokens
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT user_id, request_id, token_credits, tokens
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
    UNION ALL
    SELECT user_id, request_id, token_credits, tokens
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
) h
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u
  ON h.user_id = u.user_id
WHERE h.usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND u.deleted_on IS NULL
GROUP BY u.name
ORDER BY total_credits DESC
LIMIT 10;
```

### Query 7 — What roles are people using CoCo with?

```sql
SELECT
    h.metadata:role_name::VARCHAR   AS role_name,
    COUNT(h.request_id)             AS requests,
    COUNT(DISTINCT h.user_id)       AS distinct_users,
    SUM(h.token_credits)            AS credits
FROM (
    SELECT user_id, request_id, token_credits, metadata
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT user_id, request_id, token_credits, metadata
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
    UNION ALL
    SELECT user_id, request_id, token_credits, metadata
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
) h
WHERE h.usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY role_name
ORDER BY credits DESC;
```

### Query 8 — Users with CORTEX_USER access who have NEVER used CoCo

```sql
WITH coco_users AS (
    SELECT DISTINCT user_id
    FROM (
        SELECT user_id FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
        UNION
        SELECT user_id FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
        UNION
        SELECT user_id FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
    )
)
SELECT
    u.name          AS user_name,
    u.login_name    AS login_name,
    u.email         AS email,
    u.created_on    AS user_created
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS u
LEFT JOIN coco_users c
  ON u.user_id = c.user_id
WHERE c.user_id IS NULL
  AND u.deleted_on IS NULL
  AND COALESCE(u.disabled, 'false')::VARCHAR != 'true'
ORDER BY u.created_on DESC;
```

> Note: This shows users who have never used CoCo in the 365-day retention window. It does not confirm they currently have CORTEX_USER — combine with `SHOW GRANTS` for precision.

### Query 9 — Daily credit trend (last 30 days)

```sql
SELECT
    DATE_TRUNC('day', usage_time)::DATE AS day,
    COUNT(request_id)                   AS requests,
    SUM(token_credits)                  AS credits
FROM (
    SELECT usage_time, request_id, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT usage_time, request_id, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
    UNION ALL
    SELECT usage_time, request_id, token_credits
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
) h
WHERE usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY day
ORDER BY day;
```

### Query 10 — New users in the last 7 days (adoption tracking)

```sql
WITH first_use AS (
    SELECT
        user_id,
        MIN(usage_time) AS first_usage
    FROM (
        SELECT user_id, usage_time FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
        UNION ALL
        SELECT user_id, usage_time FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
        UNION ALL
        SELECT user_id, usage_time FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
    )
    GROUP BY user_id
)
SELECT
    u.name          AS user_name,
    u.email         AS email,
    f.first_usage   AS first_used_at
FROM first_use f
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u
  ON f.user_id = u.user_id
WHERE f.first_usage >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND u.deleted_on IS NULL
ORDER BY f.first_usage DESC;
```

### Query 11 — Inference region distribution (regional vs global routing)

```sql
SELECT
    COALESCE(metadata:inference_region::VARCHAR, 'unknown') AS inference_region,
    COUNT(request_id)    AS requests,
    SUM(token_credits)   AS credits
FROM (
    SELECT metadata, request_id, token_credits, usage_time
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT metadata, request_id, token_credits, usage_time
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
    UNION ALL
    SELECT metadata, request_id, token_credits, usage_time
      FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
) h
WHERE usage_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY inference_region
ORDER BY credits DESC;
```

---

## Gotchas and FAQ

### Secondary roles bypass restrictions

A user with `ACCOUNTADMIN` as a **secondary role** can still access Cortex Code even if their primary role lacks `CORTEX_USER`. To test restrictions accurately:

```sql
USE SECONDARY ROLES NONE;
USE ROLE <role_to_test>;
SELECT AI_COMPLETE('llama3.1-70b', 'test');
```

### Default role matters for Cortex Agents

Cortex Agents evaluate permissions against the user's **default role**, not their active session role. If a user's default role lacks CORTEX_USER, agent calls fail — even if the user switches to a privileged role in their session. Ensure the CoCo role is either set as users' default role or granted to it.

### Don't revoke IMPORTED PRIVILEGES on SNOWFLAKE unless you mean it

You may see guidance elsewhere to run `REVOKE IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE FROM ROLE PUBLIC`. This removes PUBLIC access to **everything** in the shared SNOWFLAKE database — including the ACCOUNT_USAGE views these observability queries depend on. Revoking `CORTEX_USER` from PUBLIC is sufficient to block CoCo; don't revoke IMPORTED PRIVILEGES unless you're prepared to selectively re-grant ACCOUNT_USAGE access to every role that needs it.

### View latency

- ACCOUNT_USAGE views: up to **1 hour** latency
- ORGANIZATION_USAGE views: up to **24 hours** latency
- Retention: **365 days** for both

Don't expect real-time visibility. If you just revoked access and want to confirm it worked, test with a direct `AI_COMPLETE` call rather than waiting for the usage views to update.

### The unified view

`SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COCO_USAGE_HISTORY` combines CLI, Desktop, and Snowsight into a single view. If available in your account, use it instead of UNION ALL across the three individual views. The queries above use the individual views for maximum compatibility.

### CORTEX_AGENT_USER is narrower than CORTEX_USER

If your goal is to only allow Cortex **Agents** (not CoCo, not AI functions), use `SNOWFLAKE.CORTEX_AGENT_USER` instead of `SNOWFLAKE.CORTEX_USER`. This grants access to agents only.

### Model RBAC revocation requires a stored procedure

A plain `REVOKE APPLICATION ROLE SNOWFLAKE."CORTEX-MODEL-ROLE-ALL" FROM ROLE PUBLIC` does NOT remove the **bootstrap grant** from `SNOWFLAKE.PUBLIC`. You must use:

```sql
CALL SNOWFLAKE.LOCAL.REVOKE_FROM_PUBLIC_APPLICATION_ROLE(
  'APP_ROLE',
  'CORTEX-MODEL-ROLE-ALL'
);
```

Verify with: `SHOW GRANTS TO APPLICATION ROLE SNOWFLAKE.PUBLIC;`

---

## Related Guides

- [Privileges and model access for Cortex AI Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-privileges-and-access) — full reference for CORTEX_USER, USE AI FUNCTIONS, model RBAC
- [Cortex Agents access control and authentication](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-setup) — agent-specific privileges and default role requirements
- [CORTEX_CODE_CLI_USAGE_HISTORY view](https://docs.snowflake.com/en/sql-reference/account-usage/cortex_code_cli_usage_history) — column reference
- [CORTEX_CODE_DESKTOP_USAGE_HISTORY view](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/cortex-code-desktop-usage-history-view) — column reference
- [CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY view](https://docs.snowflake.com/en/sql-reference/account-usage/cortex_code_snowsight_usage_history) — column reference
- [Using SNOWFLAKE database roles](https://docs.snowflake.com/en/sql-reference/snowflake-db) — why database roles can't be granted directly to users
