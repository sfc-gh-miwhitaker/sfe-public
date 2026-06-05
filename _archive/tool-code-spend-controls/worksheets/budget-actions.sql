/*==============================================================================
  WORKSHEET: Budget Automated Actions — Setup & Telemetry

  Purpose:    Register stored procedures to fire at budget thresholds.
              Covers PROJECTED (early warning), ACTUAL (enforcement),
              and CYCLE_START (monthly restore).
  Requires:   ACCOUNTADMIN (or custom budget ADMIN role)
  Note:       Custom budgets only — account budget does not support actions.
==============================================================================*/

/* ── SECTION 1: One-time privilege grants (run once per schema) ───────────
   Snowflake's budget engine runs as APPLICATION SNOWFLAKE.
   It must have USAGE on the schema containing your action procedures.       */

GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO APPLICATION SNOWFLAKE;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.BUDGETS TO APPLICATION SNOWFLAKE;


/* ── SECTION 2: Create action procedures ──────────────────────────────────
   Each procedure must be GRANTed to APPLICATION SNOWFLAKE individually.    */

-- Action A: Log a warning event (70% PROJECTED)
CREATE OR REPLACE PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.log_approaching_limit()
RETURNS VARCHAR
LANGUAGE SQL
AS $$
BEGIN
    -- In production: INSERT into an audit table or call a webhook stored proc
    RETURN 'Budget on track to exceed 70% — logged at ' || CURRENT_TIMESTAMP::VARCHAR;
END;
$$;

GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.log_approaching_limit()
    TO APPLICATION SNOWFLAKE;


-- Action B: Resize warehouse down (80% ACTUAL)
CREATE OR REPLACE PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.downsize_warehouse()
RETURNS VARCHAR
LANGUAGE SQL
AS $$
BEGIN
    ALTER WAREHOUSE SFE_TOOLS_WH SET WAREHOUSE_SIZE = 'XSMALL';
    RETURN 'Warehouse SFE_TOOLS_WH resized to XSMALL at ' || CURRENT_TIMESTAMP::VARCHAR;
END;
$$;

GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.downsize_warehouse()
    TO APPLICATION SNOWFLAKE;


-- Action C: Suspend warehouse (95% ACTUAL — hard stop)
CREATE OR REPLACE PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.suspend_warehouse()
RETURNS VARCHAR
LANGUAGE SQL
AS $$
BEGIN
    ALTER WAREHOUSE SFE_TOOLS_WH SUSPEND;
    RETURN 'Warehouse SFE_TOOLS_WH suspended at ' || CURRENT_TIMESTAMP::VARCHAR;
END;
$$;

GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.suspend_warehouse()
    TO APPLICATION SNOWFLAKE;


-- Action D: Restore warehouse at cycle start (1st of month, 12:00 AM UTC)
CREATE OR REPLACE PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.restore_warehouse()
RETURNS VARCHAR
LANGUAGE SQL
AS $$
BEGIN
    ALTER WAREHOUSE SFE_TOOLS_WH SET WAREHOUSE_SIZE = 'MEDIUM';
    ALTER WAREHOUSE SFE_TOOLS_WH RESUME IF SUSPENDED;
    RETURN 'Warehouse SFE_TOOLS_WH restored to MEDIUM at cycle start ' || CURRENT_TIMESTAMP::VARCHAR;
END;
$$;

GRANT USAGE ON PROCEDURE SNOWFLAKE_EXAMPLE.BUDGETS.restore_warehouse()
    TO APPLICATION SNOWFLAKE;


/* ── SECTION 3: Register actions on the budget ───────────────────────────
   Run after procedures are created and GRANTed.                             */

-- Action A: 70% PROJECTED (fires when on track to hit 70% by EOM)
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_CUSTOM_ACTIONS(
    SYSTEM$REFERENCE('PROCEDURE',
        'SNOWFLAKE_EXAMPLE.BUDGETS.log_approaching_limit', 'SESSION', 'CALL'),
    'PROJECTED',
    0.70
);

-- Action B: 80% ACTUAL (fires when spend crosses 80%)
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_CUSTOM_ACTIONS(
    SYSTEM$REFERENCE('PROCEDURE',
        'SNOWFLAKE_EXAMPLE.BUDGETS.downsize_warehouse', 'SESSION', 'CALL'),
    'ACTUAL',
    0.80
);

-- Action C: 95% ACTUAL (hard stop)
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_CUSTOM_ACTIONS(
    SYSTEM$REFERENCE('PROCEDURE',
        'SNOWFLAKE_EXAMPLE.BUDGETS.suspend_warehouse', 'SESSION', 'CALL'),
    'ACTUAL',
    0.95
);

-- Action D: CYCLE_START (monthly restore — no threshold)
CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!ADD_CUSTOM_ACTIONS(
    SYSTEM$REFERENCE('PROCEDURE',
        'SNOWFLAKE_EXAMPLE.BUDGETS.restore_warehouse', 'SESSION', 'CALL'),
    'CYCLE_START',
    NULL
);


/* ── SECTION 4: Inspect registered actions ────────────────────────────────
   Expected: one row per registered action with trigger type and threshold.  */

CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!GET_CUSTOM_ACTIONS();


/* ── SECTION 5: Remove a specific action ───────────────────────────────── */

-- Remove the 80% downsize action
-- CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!REMOVE_CUSTOM_ACTIONS(
--     SYSTEM$REFERENCE('PROCEDURE',
--         'SNOWFLAKE_EXAMPLE.BUDGETS.downsize_warehouse', 'SESSION', 'CALL'),
--     'ACTUAL',
--     0.80
-- );

-- Remove ALL actions on this budget
-- CALL SNOWFLAKE_EXAMPLE.BUDGETS.TEAM_BUDGET!REMOVE_CUSTOM_ACTIONS();


/* ── SECTION 6: Event telemetry — did actions fire? ───────────────────────
   Expected: one row per budget event (threshold crossed, action fired).
   If empty: no thresholds have been crossed yet, or telemetry latency.
   budget scope: snow.cost.budget                                            */

SELECT record_attributes:budget_name::VARCHAR AS budget,
       record_attributes:threshold_percent::FLOAT AS threshold_pct,
       record_attributes:trigger_type::VARCHAR AS trigger,
       record_attributes:action_status::VARCHAR AS action_status,
       record_attributes:action_name::VARCHAR AS action_name,
       record_attributes:error_message::VARCHAR AS error_message,
       timestamp
FROM SNOWFLAKE.TELEMETRY.EVENTS
WHERE SCOPE['name'] = 'snow.cost.budget'
  AND record_type = 'SPAN_EVENT'
  AND timestamp >= DATEADD('day', -30, CURRENT_TIMESTAMP)
ORDER BY timestamp DESC;


/* ── SECTION 7: Summarize action fire history ─────────────────────────────
   Expected: counts per budget + trigger type. Useful for capacity planning. */

SELECT record_attributes:budget_name::VARCHAR AS budget,
       record_attributes:trigger_type::VARCHAR AS trigger_type,
       record_attributes:threshold_percent::FLOAT AS threshold_pct,
       COUNT(*) AS times_fired,
       MIN(timestamp) AS first_fired,
       MAX(timestamp) AS last_fired
FROM SNOWFLAKE.TELEMETRY.EVENTS
WHERE SCOPE['name'] = 'snow.cost.budget'
  AND record_type = 'SPAN_EVENT'
GROUP BY 1, 2, 3
ORDER BY 4 DESC;
