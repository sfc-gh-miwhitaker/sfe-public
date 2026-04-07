/*==============================================================================
  WORKSHEET: Account Budget — Setup & Inspection

  Purpose:    Activate, configure, and monitor the account-level budget.
              The account budget covers ALL credits (AI, compute, storage).
              AI credits (Cortex Code) appear here under service type AI_SERVICES.
  Requires:   ACCOUNTADMIN (for setup) or SNOWFLAKE.BUDGET_VIEWER (for inspection)
  Note:       Only one account budget exists per account — it cannot be created,
              only activated.
==============================================================================*/

/* ── SECTION 1: Check current status ───────────────────────────────────────
   Run this first to understand what's already configured.                   */

-- View the budget object
SHOW SNOWFLAKE.CORE.BUDGET INSTANCES IN ACCOUNT;

-- Get current spending limit and activation status
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_CONFIGURATION();

-- Get spending history this month
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_SPENDING_HISTORY(
    TIME_LOWER_BOUND => DATE_TRUNC('month', CURRENT_DATE),
    TIME_UPPER_BOUND => CURRENT_TIMESTAMP
);


/* ── SECTION 2: Activate and set limit ────────────────────────────────────
   Run these if the budget is not yet activated.
   Limit is in Snowflake credits. $2.00/credit on-demand.
   Example: 500 credits = $1,000/month limit at on-demand rates.             */

CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ACTIVATE();

CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_SPENDING_LIMIT(500);
-- ^^^ Change 500 to your desired monthly credit cap


/* ── SECTION 3: Check AI_SERVICES spend specifically ─────────────────────
   Expected: rows with service_type, usage_date, usage_in_currency (credits).
   This shows Cortex Code and other AI service credit consumption.           */

SELECT *
FROM TABLE(
    SNOWFLAKE.CORE.GET_SERVICE_TYPE_USAGE_V2(
        SERVICE_TYPE => 'AI_SERVICES',
        TIME_LOWER_BOUND => DATE_TRUNC('month', CURRENT_DATE),
        TIME_UPPER_BOUND => CURRENT_TIMESTAMP
    )
)
ORDER BY USAGE_DATE DESC;


/* ── SECTION 4: Add email notification ─────────────────────────────────── */

-- Create email integration (run once, ACCOUNTADMIN)
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS budgets_email_int
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('finops@example.com');
-- ^^^ Replace with real verified email address

-- Add 80% alert
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ADD_EMAIL_NOTIFICATION_INTEGRATION(
    'budgets_email_int',
    0.80,
    'Alert',
    'finops@example.com'
);

-- Add 95% critical alert
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ADD_EMAIL_NOTIFICATION_INTEGRATION(
    'budgets_email_int',
    0.95,
    'Critical',
    'finops@example.com'
);


/* ── SECTION 5: Add Slack webhook notification ──────────────────────────── */

CREATE NOTIFICATION INTEGRATION IF NOT EXISTS slack_budget_int
  TYPE = WEBHOOK
  ENABLED = TRUE
  WEBHOOK_URL = 'https://hooks.slack.com/services/REPLACE/WITH/REAL_TOKEN'
  WEBHOOK_BODY_TEMPLATE = '{
    "text": "Account budget alert: SNOWFLAKE_BUDGET_NAME reached SNOWFLAKE_BUDGET_THRESHOLD_PERCENTAGE% — SNOWFLAKE_BUDGET_SPENT_AMOUNT of SNOWFLAKE_BUDGET_LIMIT_AMOUNT credits used."
  }';

CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ADD_WEBHOOK_NOTIFICATION_INTEGRATION(
    'slack_budget_int',
    0.80,
    'Alert'
);


/* ── SECTION 6: Verify notifications ───────────────────────────────────── */

CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_NOTIFICATION_INTEGRATIONS();


/* ── SECTION 7: Delegate budget management ───────────────────────────────
   Let a FinOps role manage the account budget without ACCOUNTADMIN.         */

GRANT DATABASE ROLE SNOWFLAKE.BUDGET_VIEWER TO ROLE finops_role;
GRANT DATABASE ROLE SNOWFLAKE.BUDGET_ADMIN  TO ROLE finops_role;


/* ── SECTION 8: Deactivate (removes alerts but does not stop spending) ─── */

-- CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!DEACTIVATE();
-- ^^^ Uncommented only when you want to disable all budget monitoring
