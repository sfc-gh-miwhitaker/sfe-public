# Scenario: Automate a Response When You Go Over

**Goal:** Take automatic action — resize a warehouse, suspend a service, send a report — when a budget threshold is crossed, without human intervention.

**Prerequisites:**
- A custom budget exists with a spending limit set. See [set-a-limit.md](set-a-limit.md).
- A stored procedure exists to execute the action.
- Three one-time GRANTs to `APPLICATION SNOWFLAKE` (see setup below).

> **Note:** Automated actions are only available on custom budgets, not the account budget.

---

## One-time setup

Run these once per database/schema before registering any action:

```sql
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO APPLICATION SNOWFLAKE;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.BUDGETS TO APPLICATION SNOWFLAKE;
-- Also grant USAGE on the schema where your action procedure lives
GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.my_action_proc() TO APPLICATION SNOWFLAKE;
```

---

## Pattern A: Email report at 70% (PROJECTED)

Fires when the budget *projects* it will exceed 70% by end of month — fires early enough to act.

```sql
-- Create the action procedure
CREATE OR REPLACE PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.notify_approaching()
RETURNS VARCHAR
LANGUAGE SQL
AS $$
BEGIN
    -- Insert a log row, call an external notification, etc.
    INSERT INTO SNOWFLAKE_EXAMPLE.BUDGETS.budget_events(event_time, event_type, message)
    VALUES(CURRENT_TIMESTAMP, 'PROJECTED_70', 'Cortex Code budget on track to exceed 70% this month');
    RETURN 'OK';
END;
$$;

GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.notify_approaching() TO APPLICATION SNOWFLAKE;

-- Register the action
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_CUSTOM_ACTIONS(
    SYSTEM$REFERENCE('PROCEDURE', 'SNOWFLAKE_EXAMPLE.BUDGETS.notify_approaching', 'SESSION', 'CALL'),
    'PROJECTED',   -- trigger type: PROJECTED or ACTUAL
    0.70           -- threshold: 70% of spending limit
);
```

---

## Pattern B: Resize warehouse down at 80% (ACTUAL)

Fires when the budget has *actually spent* 80% of the limit this month.

```sql
-- Create the action procedure
CREATE OR REPLACE PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.downsize_warehouse()
RETURNS VARCHAR
LANGUAGE SQL
AS $$
BEGIN
    ALTER WAREHOUSE SFE_TOOLS_WH SET WAREHOUSE_SIZE = 'XSMALL';
    RETURN 'Warehouse resized to XSMALL';
END;
$$;

GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.downsize_warehouse() TO APPLICATION SNOWFLAKE;

-- Register
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_CUSTOM_ACTIONS(
    SYSTEM$REFERENCE('PROCEDURE', 'SNOWFLAKE_EXAMPLE.BUDGETS.downsize_warehouse', 'SESSION', 'CALL'),
    'ACTUAL',
    0.80
);
```

---

## Pattern C: Suspend warehouse at 95% (ACTUAL)

Hard stop — suspends the warehouse so no new queries can run against it.

```sql
CREATE OR REPLACE PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.suspend_warehouse()
RETURNS VARCHAR
LANGUAGE SQL
AS $$
BEGIN
    ALTER WAREHOUSE SFE_TOOLS_WH SUSPEND;
    RETURN 'Warehouse suspended';
END;
$$;

GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.suspend_warehouse() TO APPLICATION SNOWFLAKE;

CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_CUSTOM_ACTIONS(
    SYSTEM$REFERENCE('PROCEDURE', 'SNOWFLAKE_EXAMPLE.BUDGETS.suspend_warehouse', 'SESSION', 'CALL'),
    'ACTUAL',
    0.95
);
```

---

## Cycle-start restore action

Fires at 12:00 AM UTC on the 1st of each month (budget cycle reset) — use this to restore a warehouse that was suspended or downsized last month.

```sql
CREATE OR REPLACE PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.restore_warehouse()
RETURNS VARCHAR
LANGUAGE SQL
AS $$
BEGIN
    ALTER WAREHOUSE SFE_TOOLS_WH SET WAREHOUSE_SIZE = 'MEDIUM';
    ALTER WAREHOUSE SFE_TOOLS_WH RESUME IF SUSPENDED;
    RETURN 'Warehouse restored to MEDIUM';
END;
$$;

GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.restore_warehouse() TO APPLICATION SNOWFLAKE;

CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_CUSTOM_ACTIONS(
    SYSTEM$REFERENCE('PROCEDURE', 'SNOWFLAKE_EXAMPLE.BUDGETS.restore_warehouse', 'SESSION', 'CALL'),
    'CYCLE_START',
    NULL   -- no threshold for cycle-start
);
```

> **30-minute timeout:** Cycle-start procedures must complete within 30 minutes.

---

## Inspect and remove actions

```sql
-- List all registered actions on a budget
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!GET_CUSTOM_ACTIONS();

-- Remove a specific action
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!REMOVE_CUSTOM_ACTIONS(
    SYSTEM$REFERENCE('PROCEDURE', 'SNOWFLAKE_EXAMPLE.BUDGETS.downsize_warehouse', 'SESSION', 'CALL'),
    'ACTUAL',
    0.80
);

-- Remove all actions on this budget
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!REMOVE_CUSTOM_ACTIONS();
```

---

## Verify actions fired (event telemetry)

```sql
SELECT record_attributes:budget_name::VARCHAR AS budget,
       record_attributes:threshold_percent::FLOAT AS threshold_pct,
       record_attributes:trigger_type::VARCHAR AS trigger,
       record_attributes:action_status::VARCHAR AS status,
       timestamp
FROM SNOWFLAKE.TELEMETRY.EVENTS
WHERE SCOPE['name'] = 'snow.cost.budget'
  AND record_type = 'SPAN_EVENT'
  AND timestamp >= DATEADD('day', -7, CURRENT_TIMESTAMP)
ORDER BY timestamp DESC;
```

---

## Action behavior summary

| Trigger type | When it fires | Use for |
|-------------|--------------|---------|
| `PROJECTED` | Budget projects it will exceed threshold by EOM | Early warning, proactive resize |
| `ACTUAL` | Actual spend crosses threshold | Hard enforcement |
| `CYCLE_START` | 12:00 AM UTC on the 1st of each month | Restore from last month's actions |

---

## Next steps

| | |
|--|--|
| Want to understand total spend trends before setting thresholds | [understand-spend.md](understand-spend.md) |
| Want to also restrict which users can spend | [restrict-access.md](restrict-access.md) |
