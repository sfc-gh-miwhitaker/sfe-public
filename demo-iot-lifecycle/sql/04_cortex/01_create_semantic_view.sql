USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA SEMANTIC_MODELS;
USE WAREHOUSE SFE_IOT_LIFECYCLE_WH;

CREATE OR REPLACE SEMANTIC VIEW SV_IOT_FINANCIAL

  TABLES (
    actuals AS SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.FINANCIAL_ACTUALS
      PRIMARY KEY (PERIOD_ID)
      WITH SYNONYMS = ('actuals', 'P&L', 'income statement', 'financials')
      COMMENT = 'Monthly actual financial results by GL code',

    budget AS SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.FINANCIAL_BUDGET
      PRIMARY KEY (PERIOD_ID)
      WITH SYNONYMS = ('budget', 'plan', 'forecast')
      COMMENT = 'Monthly budget targets by GL code for variance analysis',

    gl_codes AS SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GL_CODES
      PRIMARY KEY (GL_CODE)
      WITH SYNONYMS = ('chart of accounts', 'GL', 'account codes')
      COMMENT = 'General ledger code taxonomy with categories and types',

    customers AS SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.CUSTOMERS
      PRIMARY KEY (CUSTOMER_ID)
      WITH SYNONYMS = ('clients', 'accounts')
      COMMENT = 'Customer locations across Atlanta metro area',

    invoices AS SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.INVOICES
      PRIMARY KEY (INVOICE_ID)
      WITH SYNONYMS = ('bills', 'AR', 'accounts receivable')
      COMMENT = 'Customer invoices with payment status tracking',

    garment_costs AS SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENT_COSTS
      PRIMARY KEY (GARMENT_TYPE)
      WITH SYNONYMS = ('replacement costs', 'item costs')
      COMMENT = 'Garment replacement and laundering cost benchmarks'
  )

  RELATIONSHIPS (
    actuals_to_gl AS
      actuals (GL_CODE) REFERENCES gl_codes,
    budget_to_gl AS
      budget (GL_CODE) REFERENCES gl_codes,
    invoices_to_customers AS
      invoices (CUSTOMER_ID) REFERENCES customers
  )

  FACTS (
    actuals.actual_amount AS actuals.AMOUNT
      COMMENT = 'Actual monthly amount in dollars for this GL code',

    budget.budget_amount AS budget.BUDGET_AMOUNT
      COMMENT = 'Budget target amount in dollars for this GL code',

    invoices.invoice_amount AS invoices.TOTAL_AMOUNT
      COMMENT = 'Total invoice amount in dollars',

    customers.monthly_contract_value AS customers.MONTHLY_VALUE
      COMMENT = 'Monthly contract value in dollars for the customer',

    garment_costs.replacement_cost AS garment_costs.REPLACEMENT_COST
      COMMENT = 'Cost to replace one unit of this garment type',

    garment_costs.laundering_cost AS garment_costs.AVG_LAUNDERING_COST_LB
      COMMENT = 'Average laundering cost per pound for this garment type'
  )

  DIMENSIONS (
    actuals.fiscal_year AS actuals.FISCAL_YEAR
      WITH SYNONYMS = ('year', 'FY')
      COMMENT = 'Fiscal year (FY starts Feb 1)',

    actuals.fiscal_quarter AS actuals.FISCAL_QUARTER
      WITH SYNONYMS = ('quarter', 'Q')
      COMMENT = 'Fiscal quarter: Q1=Feb-Apr, Q2=May-Jul, Q3=Aug-Oct, Q4=Nov-Jan',

    actuals.fiscal_month AS actuals.FISCAL_MONTH
      WITH SYNONYMS = ('month', 'period')
      COMMENT = 'First day of the fiscal month',

    gl_codes.gl_name AS gl_codes.GL_NAME
      WITH SYNONYMS = ('account name', 'line item')
      COMMENT = 'GL account name (e.g., Uniform Rental Revenue, Laundry Processing)',

    gl_codes.gl_category AS gl_codes.GL_CATEGORY
      WITH SYNONYMS = ('category', 'section')
      COMMENT = 'GL category: Revenue, COGS, or Operating Expense',

    gl_codes.gl_type AS gl_codes.GL_TYPE
      COMMENT = 'GL type: REVENUE or EXPENSE',

    customers.customer_name AS customers.CUSTOMER_NAME
      WITH SYNONYMS = ('client name', 'account name')
      COMMENT = 'Customer business name',

    customers.industry AS customers.INDUSTRY
      WITH SYNONYMS = ('sector', 'vertical')
      COMMENT = 'Customer industry: Healthcare, Hospitality, Food Service, Industrial, etc.',

    customers.city AS customers.CITY
      WITH SYNONYMS = ('location')
      COMMENT = 'Customer city in the Atlanta metro area',

    invoices.invoice_date AS invoices.INVOICE_DATE
      COMMENT = 'Date the invoice was issued',

    invoices.payment_status AS invoices.PAYMENT_STATUS
      WITH SYNONYMS = ('status', 'paid status')
      COMMENT = 'Payment status: PAID, PENDING, or OVERDUE',

    garment_costs.garment_type AS garment_costs.GARMENT_TYPE
      WITH SYNONYMS = ('item type', 'product')
      COMMENT = 'Type of garment or linen product',

    garment_costs.useful_life AS garment_costs.USEFUL_LIFE_CYCLES
      COMMENT = 'Number of wash cycles before garment reaches end of life'
  )

  METRICS (
    actuals.total_actual AS SUM(actuals.actual_amount)
      WITH SYNONYMS = ('total spend', 'total actual')
      COMMENT = 'Sum of actual amounts across selected GL codes and periods',

    budget.total_budget AS SUM(budget.budget_amount)
      WITH SYNONYMS = ('total budget', 'total plan')
      COMMENT = 'Sum of budget amounts across selected GL codes and periods',

    invoices.total_invoiced AS SUM(invoices.invoice_amount)
      WITH SYNONYMS = ('total billed', 'total AR')
      COMMENT = 'Sum of all invoice amounts',

    invoices.invoice_count AS COUNT(invoices.INVOICE_ID)
      COMMENT = 'Number of invoices',

    invoices.avg_invoice_value AS AVG(invoices.invoice_amount)
      COMMENT = 'Average invoice dollar amount',

    customers.customer_count AS COUNT(DISTINCT customers.CUSTOMER_ID)
      COMMENT = 'Number of unique customers',

    invoices.overdue_count AS COUNT_IF(invoices.PAYMENT_STATUS = 'OVERDUE')
      WITH SYNONYMS = ('late invoices', 'past due')
      COMMENT = 'Number of overdue invoices'
  )

  COMMENT = 'DEMO: Financial semantic view for CFO Agent -- Metro Textile Services (Expires: 2026-06-11)'

  AI_SQL_GENERATION
    'This semantic view covers financial data for Metro Textile Services, a uniform rental
     and linen supply company operating in the Atlanta, GA metro area.
     FINANCIAL_ACTUALS contains monthly P&L data by GL code with fiscal year/quarter/month.
     FINANCIAL_BUDGET contains corresponding budget targets for variance analysis.
     GL_CODES maps account codes to names, categories (Revenue, COGS, Operating Expense), and types.
     INVOICES tracks customer billing with payment status (PAID, PENDING, OVERDUE).
     CUSTOMERS contains location and contract data for 20 Atlanta-area clients.
     GARMENT_COSTS provides replacement cost and useful life benchmarks by garment type.
     Fiscal calendar: FY starts Feb 1. Q1=Feb-Apr, Q2=May-Jul, Q3=Aug-Oct, Q4=Nov-Jan.
     To calculate revenue: filter GL_TYPE = REVENUE and SUM the amounts.
     To calculate COGS: filter GL_CATEGORY = COGS and SUM the amounts.
     To calculate gross margin: Revenue minus COGS.
     To calculate net income: Revenue minus all expenses.
     Budget variance = Actual minus Budget (positive means over budget for expenses, under for revenue).
     Garment replacement cost impact = zombie_count * replacement_cost per type.
     Round all currency values to 2 decimal places.
     When asked about margins, express as percentages.'

  AI_VERIFIED_QUERIES (
    monthly_pnl AS (
      QUESTION 'What is our monthly P&L summary?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT actuals.FISCAL_MONTH, gl_codes.GL_CATEGORY, SUM(actuals.AMOUNT) AS TOTAL_AMOUNT FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.FINANCIAL_ACTUALS actuals JOIN SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GL_CODES gl_codes ON actuals.GL_CODE = gl_codes.GL_CODE GROUP BY actuals.FISCAL_MONTH, gl_codes.GL_CATEGORY ORDER BY actuals.FISCAL_MONTH DESC, gl_codes.GL_CATEGORY'
    ),
    budget_variance AS (
      QUESTION 'Where are we vs budget this quarter?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT gl_codes.GL_NAME, SUM(actuals.AMOUNT) AS ACTUAL, SUM(budget.BUDGET_AMOUNT) AS BUDGET, SUM(actuals.AMOUNT) - SUM(budget.BUDGET_AMOUNT) AS VARIANCE FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.FINANCIAL_ACTUALS actuals JOIN SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GL_CODES gl_codes ON actuals.GL_CODE = gl_codes.GL_CODE JOIN SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.FINANCIAL_BUDGET budget ON actuals.FISCAL_MONTH = budget.FISCAL_MONTH AND actuals.GL_CODE = budget.GL_CODE WHERE actuals.FISCAL_QUARTER = (SELECT MAX(FISCAL_QUARTER) FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.FINANCIAL_ACTUALS WHERE FISCAL_YEAR = (SELECT MAX(FISCAL_YEAR) FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.FINANCIAL_ACTUALS)) GROUP BY gl_codes.GL_NAME ORDER BY ABS(SUM(actuals.AMOUNT) - SUM(budget.BUDGET_AMOUNT)) DESC'
    ),
    top_customers AS (
      QUESTION 'Who are our top customers by revenue?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT c.CUSTOMER_NAME, c.INDUSTRY, COUNT(DISTINCT i.INVOICE_ID) AS INVOICE_COUNT, SUM(i.TOTAL_AMOUNT) AS TOTAL_REVENUE FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.CUSTOMERS c JOIN SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.INVOICES i ON c.CUSTOMER_ID = i.CUSTOMER_ID GROUP BY c.CUSTOMER_NAME, c.INDUSTRY ORDER BY TOTAL_REVENUE DESC LIMIT 10'
    )
  );

GRANT SELECT ON SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_IOT_FINANCIAL
  TO ROLE PUBLIC;

CREATE OR REPLACE SEMANTIC VIEW SV_IOT_OPERATIONS

  TABLES (
    garments AS SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENTS
      PRIMARY KEY (GARMENT_ID)
      WITH SYNONYMS = ('items', 'inventory', 'textiles')
      COMMENT = 'RFID-tagged garment inventory with lifecycle state and location tracking',

    customers AS SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.CUSTOMERS
      PRIMARY KEY (CUSTOMER_ID)
      WITH SYNONYMS = ('clients', 'accounts', 'sites')
      COMMENT = 'Customer sites with CSAT scores, return rates, and dispute counts',

    routes AS SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.ROUTES
      PRIMARY KEY (ROUTE_ID)
      WITH SYNONYMS = ('delivery routes', 'runs')
      COMMENT = 'Delivery routes with fuel cost and mileage data',

    garment_costs AS SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENT_COSTS
      PRIMARY KEY (GARMENT_TYPE)
      WITH SYNONYMS = ('replacement costs', 'item costs', 'benchmarks')
      COMMENT = 'Industry benchmark costs per garment type',

    retention_alerts AS SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.RETENTION_ALERTS
      PRIMARY KEY (ALERT_ID)
      WITH SYNONYMS = ('alerts', 'driver alerts', 'recovery alerts')
      COMMENT = 'Active retention alerts with driver talking points and financial save values'
  )

  RELATIONSHIPS (
    garments_to_customers AS
      garments (CUSTOMER_ID) REFERENCES customers,
    retention_alerts_to_customers AS
      retention_alerts (CUSTOMER_ID) REFERENCES customers,
    customers_to_routes AS
      customers (ROUTE_ID) REFERENCES routes
  )

  FACTS (
    garments.wash_count AS garments.WASH_COUNT
      COMMENT = 'Number of completed wash cycles for this garment',

    garments.useful_life_cycles AS garments.USEFUL_LIFE_CYCLES
      COMMENT = 'Total wash cycles before garment reaches end of useful life',

    garments.replacement_cost AS garments.REPLACEMENT_COST
      COMMENT = 'Dollar cost to replace this specific garment',

    garments.days_at_location AS garments.DAYS_AT_LOCATION
      COMMENT = 'Number of days garment has been at current location without moving',

    customers.monthly_value AS customers.MONTHLY_VALUE
      COMMENT = 'Monthly contract value in dollars',

    customers.csat_score AS customers.CSAT_SCORE
      COMMENT = 'Customer satisfaction score (1.0-5.0 scale)',

    customers.return_rate AS customers.RETURN_RATE_PCT
      COMMENT = 'Percentage of garments returned on schedule (higher is better)',

    customers.dispute_count AS customers.INVOICE_DISPUTE_COUNT
      COMMENT = 'Number of invoice disputes filed by this customer',

    routes.fuel_cost AS routes.FUEL_COST_USD
      COMMENT = 'Actual fuel cost for this route in dollars',

    routes.avg_fuel_cost AS routes.AVG_FUEL_COST_USD
      COMMENT = 'Average/benchmark fuel cost for routes of this distance',

    routes.estimated_miles AS routes.ESTIMATED_MILES
      COMMENT = 'Estimated round-trip miles for this route',

    retention_alerts.missing_tags AS retention_alerts.MISSING_TAG_COUNT
      COMMENT = 'Number of RFID tags not returned within threshold',

    retention_alerts.financial_save AS retention_alerts.FINANCIAL_SAVE_USD
      COMMENT = 'Dollar value recoverable if items are retrieved'
  )

  DIMENSIONS (
    garments.garment_type AS garments.GARMENT_TYPE
      WITH SYNONYMS = ('item type', 'product type')
      COMMENT = 'Type: Scrubs Top, Lab Coat, Bath Towel, Floor Mat, etc.',

    garments.lifecycle_state AS garments.LIFECYCLE_STATE
      WITH SYNONYMS = ('state', 'location state', 'status')
      COMMENT = 'Current state: IN_PLANT, IN_TRANSIT_OUT, AT_CUSTOMER, IN_TRANSIT_BACK, ZOMBIE, RETIRED',

    garments.garment_status AS garments.STATUS
      WITH SYNONYMS = ('condition')
      COMMENT = 'Overall status: IN_SERVICE, LOST, RETIRED',

    customers.customer_name AS customers.CUSTOMER_NAME
      WITH SYNONYMS = ('client', 'site name')
      COMMENT = 'Customer business name',

    customers.industry AS customers.INDUSTRY
      WITH SYNONYMS = ('vertical', 'sector')
      COMMENT = 'Customer vertical: Healthcare, Hospitality, Food Service, Industrial, Automotive, etc.',

    customers.city AS customers.CITY
      COMMENT = 'Customer city in the Atlanta metro area',

    routes.route_name AS routes.ROUTE_NAME
      WITH SYNONYMS = ('route', 'run name')
      COMMENT = 'Named delivery route',

    routes.day_of_week AS routes.DAY_OF_WEEK
      COMMENT = 'Day this route runs',

    retention_alerts.alert_status AS retention_alerts.STATUS
      COMMENT = 'Alert status: PENDING, ACKNOWLEDGED, RESOLVED',

    retention_alerts.alert_date AS retention_alerts.ALERT_DATE
      COMMENT = 'Date the retention alert was generated'
  )

  METRICS (
    garments.zombie_count AS COUNT_IF(garments.LIFECYCLE_STATE = 'ZOMBIE')
      WITH SYNONYMS = ('stalled items', 'unreturned count', 'missing garments')
      COMMENT = 'Number of garments stalled at customer sites beyond 14-day threshold',

    garments.total_garments AS COUNT(garments.GARMENT_ID)
      COMMENT = 'Total number of garments in inventory',

    garments.financial_exposure AS SUM(CASE WHEN garments.LIFECYCLE_STATE = 'ZOMBIE' THEN garments.REPLACEMENT_COST ELSE 0 END)
      WITH SYNONYMS = ('at-risk dollars', 'exposure', 'replacement liability')
      COMMENT = 'Total replacement cost of all zombie garments in dollars',

    garments.near_retirement_count AS COUNT_IF(garments.WASH_COUNT >= garments.USEFUL_LIFE_CYCLES * 0.9)
      WITH SYNONYMS = ('end of life', 'aging out', 'retirement risk')
      COMMENT = 'Garments with 90%+ of useful life consumed',

    garments.avg_days_at_location AS AVG(garments.DAYS_AT_LOCATION)
      COMMENT = 'Average days garments spend at customer location before return',

    customers.avg_csat AS AVG(customers.CSAT_SCORE)
      COMMENT = 'Average customer satisfaction score across sites',

    retention_alerts.pending_alerts AS COUNT_IF(retention_alerts.STATUS = 'PENDING')
      WITH SYNONYMS = ('open alerts', 'unresolved')
      COMMENT = 'Number of retention alerts awaiting driver action',

    retention_alerts.total_recoverable AS SUM(retention_alerts.FINANCIAL_SAVE_USD)
      WITH SYNONYMS = ('save value', 'recoverable dollars')
      COMMENT = 'Total dollars recoverable across all pending alerts'
  )

  COMMENT = 'DEMO: Operations semantic view for garment lifecycle and anomaly detection -- Metro Textile Services (Expires: 2026-06-11)'

  AI_SQL_GENERATION
    'This semantic view covers operational data for Metro Textile Services, a uniform rental
     and linen supply company in Atlanta, GA. It powers anomaly detection and retention alerting.
     GARMENTS tracks RFID-tagged items with lifecycle states: IN_PLANT (at facility), IN_TRANSIT_OUT
     (on delivery truck), AT_CUSTOMER (at client site), IN_TRANSIT_BACK (soiled return), ZOMBIE
     (stalled at customer >14 days), RETIRED (end of life).
     A ZOMBIE garment is one that has been at a customer site for more than 14 days without returning.
     The garment loop is: CLEAN_OUT -> AT_CUSTOMER -> SOILED_RETURN -> WASH -> CLEAN_OUT (repeat).
     USEFUL_LIFE_CYCLES is typically 60-120 washes depending on garment type.
     Industry benchmarks: Lab Coat $16.92, Scrubs $16.70, Floor Mat $65, Bath Towel $5.50, Shop Towel $3.50.
     CUSTOMERS includes CSAT_SCORE (1-5 scale), RETURN_RATE_PCT, and INVOICE_DISPUTE_COUNT for risk correlation.
     ROUTES has FUEL_COST_USD vs AVG_FUEL_COST_USD for efficiency analysis. >15% variance = anomaly.
     RETENTION_ALERTS contain pre-drafted driver talking points with customer-specific recovery value.
     When asked about leaks or anomalies, look for ZOMBIE garments, low RETURN_RATE_PCT, high disputes, and fuel variance.
     Financial exposure = SUM of REPLACEMENT_COST for all ZOMBIE garments at a given customer.
     Round dollar values to 2 decimal places. Express rates as percentages.'

  AI_VERIFIED_QUERIES (
    silent_leaks AS (
      QUESTION 'What are the top 3 silent operational leaks right now?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT c.CUSTOMER_NAME, c.INDUSTRY, COUNT_IF(g.LIFECYCLE_STATE = ''ZOMBIE'') AS ZOMBIE_COUNT, SUM(CASE WHEN g.LIFECYCLE_STATE = ''ZOMBIE'' THEN g.REPLACEMENT_COST ELSE 0 END) AS FINANCIAL_EXPOSURE_USD, c.CSAT_SCORE, c.RETURN_RATE_PCT FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENTS g JOIN SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.CUSTOMERS c ON g.CUSTOMER_ID = c.CUSTOMER_ID WHERE g.STATUS = ''IN_SERVICE'' GROUP BY c.CUSTOMER_NAME, c.INDUSTRY, c.CSAT_SCORE, c.RETURN_RATE_PCT HAVING COUNT_IF(g.LIFECYCLE_STATE = ''ZOMBIE'') > 0 ORDER BY FINANCIAL_EXPOSURE_USD DESC LIMIT 3'
    ),
    zombie_summary AS (
      QUESTION 'How many zombie garments do we have and what is the total exposure?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT COUNT(*) AS TOTAL_ZOMBIES, SUM(REPLACEMENT_COST) AS TOTAL_EXPOSURE_USD, AVG(DAYS_AT_LOCATION) AS AVG_DAYS_STALLED FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENTS WHERE LIFECYCLE_STATE = ''ZOMBIE'''
    ),
    route_inefficiency AS (
      QUESTION 'Which routes have fuel cost anomalies?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT ROUTE_NAME, DAY_OF_WEEK, FUEL_COST_USD, AVG_FUEL_COST_USD, ROUND((FUEL_COST_USD - AVG_FUEL_COST_USD) * 100.0 / NULLIF(AVG_FUEL_COST_USD, 0), 1) AS FUEL_VARIANCE_PCT FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.ROUTES WHERE (FUEL_COST_USD - AVG_FUEL_COST_USD) * 100.0 / NULLIF(AVG_FUEL_COST_USD, 0) > 10 ORDER BY FUEL_VARIANCE_PCT DESC'
    ),
    retention_alerts_pending AS (
      QUESTION 'Show me all pending retention alerts for drivers'
      SQL 'SELECT ra.ALERT_ID, c.CUSTOMER_NAME, ra.MISSING_TAG_COUNT, ra.FINANCIAL_SAVE_USD, ra.DRIVER_TALKING_POINT, ra.STATUS FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.RETENTION_ALERTS ra JOIN SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.CUSTOMERS c ON ra.CUSTOMER_ID = c.CUSTOMER_ID WHERE ra.STATUS = ''PENDING'' ORDER BY ra.FINANCIAL_SAVE_USD DESC'
    ),
    retirement_risk AS (
      QUESTION 'Which garments are approaching retirement?'
      SQL 'SELECT g.GARMENT_TYPE, c.CUSTOMER_NAME, COUNT(*) AS COUNT_NEAR_RETIREMENT, SUM(g.REPLACEMENT_COST) AS TOTAL_REPLACEMENT_COST FROM SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.GARMENTS g JOIN SNOWFLAKE_EXAMPLE.IOT_LIFECYCLE.CUSTOMERS c ON g.CUSTOMER_ID = c.CUSTOMER_ID WHERE g.WASH_COUNT >= g.USEFUL_LIFE_CYCLES * 0.9 AND g.STATUS = ''IN_SERVICE'' GROUP BY g.GARMENT_TYPE, c.CUSTOMER_NAME ORDER BY TOTAL_REPLACEMENT_COST DESC'
    )
  );

GRANT SELECT ON SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_IOT_OPERATIONS
  TO ROLE PUBLIC;
