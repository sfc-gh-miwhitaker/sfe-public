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
      COMMENT = 'Customer invoices with payment status tracking'
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
      COMMENT = 'Monthly contract value in dollars for the customer'
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
      COMMENT = 'Payment status: PAID, PENDING, or OVERDUE'
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
     Fiscal calendar: FY starts Feb 1. Q1=Feb-Apr, Q2=May-Jul, Q3=Aug-Oct, Q4=Nov-Jan.
     To calculate revenue: filter GL_TYPE = REVENUE and SUM the amounts.
     To calculate COGS: filter GL_CATEGORY = COGS and SUM the amounts.
     To calculate gross margin: Revenue minus COGS.
     To calculate net income: Revenue minus all expenses.
     Budget variance = Actual minus Budget (positive means over budget for expenses, under for revenue).
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
