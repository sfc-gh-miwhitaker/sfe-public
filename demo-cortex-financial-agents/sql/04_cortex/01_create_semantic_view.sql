/*==============================================================================
01 - Semantic View for Cortex Analyst
Pair-programmed by SE Community + Cortex Code | Expires: 2026-04-09
Structured portfolio analytics across borrowers, facilities, covenants,
and time-series metrics.
==============================================================================*/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA SEMANTIC_MODELS;
USE WAREHOUSE SFE_FINANCIAL_AGENTS_WH;

CREATE OR REPLACE SEMANTIC VIEW SV_FINANCIAL_PORTFOLIO

  TABLES (
    borrowers AS SNOWFLAKE_EXAMPLE.FINANCIAL_AGENTS.RAW_BORROWERS
      PRIMARY KEY (borrower_id)
      WITH SYNONYMS = ('borrowers', 'companies', 'clients', 'obligors')
      COMMENT = 'Middle-market borrower company profiles with industry, revenue, EBITDA, and risk rating',

    facilities AS SNOWFLAKE_EXAMPLE.FINANCIAL_AGENTS.RAW_FACILITIES
      PRIMARY KEY (facility_id)
      WITH SYNONYMS = ('facilities', 'loans', 'credit lines', 'deals')
      COMMENT = 'Credit facilities including ABL, term loans, equipment finance, bridge loans, and revolvers',

    covenants AS SNOWFLAKE_EXAMPLE.FINANCIAL_AGENTS.RAW_COVENANTS
      PRIMARY KEY (covenant_id)
      WITH SYNONYMS = ('covenants', 'covenant tests', 'compliance tests', 'financial covenants')
      COMMENT = 'Quarterly covenant test results with threshold vs actual values and compliance status',

    metrics AS SNOWFLAKE_EXAMPLE.FINANCIAL_AGENTS.RAW_PORTFOLIO_METRICS
      PRIMARY KEY (metric_id)
      WITH SYNONYMS = ('metrics', 'portfolio metrics', 'facility health', 'performance data')
      COMMENT = 'Time-series facility health metrics including DSCR, leverage, coverage, and delinquency'
  )

  RELATIONSHIPS (
    facilities_to_borrowers AS
      facilities (borrower_id) REFERENCES borrowers,
    covenants_to_facilities AS
      covenants (facility_id) REFERENCES facilities,
    metrics_to_facilities AS
      metrics (facility_id) REFERENCES facilities
  )

  FACTS (
    facilities.commitment_amount AS commitment_amount
      COMMENT = 'Total committed facility size in dollars',

    facilities.outstanding_balance AS facility_outstanding
      COMMENT = 'Current drawn amount on the facility in dollars',

    facilities.interest_rate AS interest_rate
      COMMENT = 'Annual interest rate as a percentage (e.g. 8.250 means 8.25%)',

    facilities.advance_rate AS advance_rate
      COMMENT = 'Maximum advance rate on eligible collateral as a percentage (ABL facilities only)',

    facilities.ltv_ratio AS facility_ltv
      COMMENT = 'Loan-to-value ratio as a percentage at origination',

    borrowers.annual_revenue AS annual_revenue
      COMMENT = 'Borrower annual revenue in dollars',

    borrowers.ebitda AS ebitda
      COMMENT = 'Borrower earnings before interest, taxes, depreciation, and amortization in dollars',

    borrowers.employee_count AS employee_count
      COMMENT = 'Number of employees at the borrower company',

    borrowers.risk_rating AS risk_rating
      COMMENT = 'Internal risk rating from 1 (Superior) to 5 (Loss). 1=Superior, 2=Satisfactory, 3=Watch, 4=Substandard, 5=Loss',

    covenants.threshold_value AS covenant_threshold
      COMMENT = 'Covenant limit or minimum requirement. For leverage ratio this is the maximum allowed; for coverage ratios this is the minimum required',

    covenants.actual_value AS covenant_actual
      COMMENT = 'Actual measured value for the covenant test',

    metrics.outstanding_balance AS metrics_outstanding
      COMMENT = 'Outstanding balance at the reporting date snapshot',

    metrics.collateral_value AS collateral_value
      COMMENT = 'Appraised or calculated collateral value at reporting date',

    metrics.dscr AS dscr
      COMMENT = 'Debt service coverage ratio -- ratio of cash flow to debt service obligations. Below 1.0 means unable to cover payments',

    metrics.leverage_ratio AS leverage_ratio
      COMMENT = 'Total debt divided by EBITDA. Lower is better. Typical covenant maximum is 3.0-4.5x',

    metrics.interest_coverage AS interest_coverage
      COMMENT = 'EBITDA divided by interest expense. Higher is better. Typical covenant minimum is 1.5-2.5x',

    metrics.days_past_due AS days_past_due
      COMMENT = 'Number of days the facility payment is overdue. 0 means current'
  )

  DIMENSIONS (
    borrowers.borrower_id AS borrower_id
      COMMENT = 'Unique borrower identifier (e.g. B-001)',

    borrowers.company_name AS company_name
      WITH SYNONYMS = ('borrower name', 'company', 'client name')
      COMMENT = 'Legal name of the borrower company',

    borrowers.industry AS industry
      WITH SYNONYMS = ('sector', 'business type', 'industry segment')
      COMMENT = 'Industry classification: manufacturing, healthcare, technology, logistics, energy, etc.',

    borrowers.state AS borrower_state
      WITH SYNONYMS = ('location', 'state', 'geography')
      COMMENT = 'US state where the borrower is headquartered',

    facilities.facility_id AS facility_id
      COMMENT = 'Unique facility identifier (e.g. F-2024-001)',

    facilities.facility_type AS facility_type
      WITH SYNONYMS = ('loan type', 'product type', 'facility kind')
      COMMENT = 'Type of credit facility: asset_based_line, term_loan, equipment_finance, real_estate_bridge, working_capital_revolver',

    facilities.status AS facility_status
      WITH SYNONYMS = ('loan status', 'facility condition', 'performance status')
      COMMENT = 'Current facility status: performing, watchlist, default, paid_off',

    facilities.origination_date AS origination_date
      COMMENT = 'Date the facility was originated',

    facilities.maturity_date AS maturity_date
      COMMENT = 'Date the facility matures and must be repaid or refinanced',

    covenants.covenant_type AS covenant_type
      WITH SYNONYMS = ('covenant name', 'test type', 'financial test')
      COMMENT = 'Type of financial covenant: leverage_ratio, interest_coverage, fixed_charge_coverage, min_ebitda, max_capex, reporting',

    covenants.reporting_period AS reporting_period
      WITH SYNONYMS = ('quarter', 'test period', 'period')
      COMMENT = 'Reporting period for the covenant test (e.g. 2024-Q4)',

    covenants.in_compliance AS in_compliance
      WITH SYNONYMS = ('compliant', 'passing', 'within covenant')
      COMMENT = 'Whether the borrower is in compliance with the covenant (TRUE/FALSE)',

    covenants.waiver_granted AS waiver_granted
      WITH SYNONYMS = ('waived', 'covenant waiver')
      COMMENT = 'Whether the lender granted a waiver for this covenant breach (TRUE/FALSE)',

    metrics.reporting_date AS reporting_date
      COMMENT = 'Date of the portfolio metrics snapshot',

    metrics.payment_status AS payment_status
      WITH SYNONYMS = ('payment condition', 'delinquency status')
      COMMENT = 'Payment status: current, past_due_30, past_due_60, past_due_90, default'
  )

  METRICS (
    facilities.total_commitment AS SUM(facilities.commitment_amount)
      COMMENT = 'Total committed facility amounts across the portfolio',

    facilities.total_outstanding AS SUM(facilities.outstanding_balance)
      COMMENT = 'Total outstanding drawn balances across the portfolio',

    facilities.facility_count AS COUNT(facilities.facility_id)
      COMMENT = 'Number of credit facilities',

    facilities.avg_interest_rate AS AVG(facilities.interest_rate)
      COMMENT = 'Average interest rate across facilities (weighted by count not balance)',

    borrowers.borrower_count AS COUNT(DISTINCT borrowers.borrower_id)
      COMMENT = 'Number of unique borrower companies',

    covenants.covenant_breach_count AS COUNT_IF(covenants.in_compliance = FALSE)
      COMMENT = 'Number of covenant test failures (non-compliant results)',

    covenants.waiver_count AS COUNT_IF(covenants.waiver_granted = TRUE)
      COMMENT = 'Number of covenant waivers granted',

    metrics.avg_dscr AS AVG(metrics.dscr)
      COMMENT = 'Average debt service coverage ratio across the portfolio',

    metrics.avg_leverage AS AVG(metrics.leverage_ratio)
      COMMENT = 'Average leverage ratio across the portfolio'
  )

  COMMENT = 'DEMO: Specialty finance portfolio semantic view -- borrowers, facilities, covenants, and metrics (Expires: 2026-04-09)'

  AI_SQL_GENERATION
    'This semantic view covers a specialty finance direct lending portfolio with four interconnected tables:
     RAW_BORROWERS contains middle-market company profiles (industry, revenue, EBITDA, risk rating).
     RAW_FACILITIES contains credit facilities (ABL, term loans, equipment finance, bridge, revolvers) with status (performing/watchlist/default/paid_off).
     RAW_COVENANTS contains quarterly covenant test results with threshold vs actual values and compliance flags.
     RAW_PORTFOLIO_METRICS contains time-series facility health snapshots (DSCR, leverage, coverage, delinquency).
     Facilities link to borrowers via borrower_id. Covenants and metrics link to facilities via facility_id.
     When asked about covenant breaches, filter where in_compliance = FALSE.
     When asked about watchlist or troubled credits, filter on facility status or high leverage/low coverage metrics.
     Risk ratings: 1=Superior, 2=Satisfactory, 3=Watch, 4=Substandard, 5=Loss.
     For portfolio totals, use SUM on outstanding_balance or commitment_amount from the facilities table.
     For time-series analysis, use the reporting_date from portfolio_metrics and compare across snapshots.';

GRANT SELECT ON SEMANTIC VIEW SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_FINANCIAL_PORTFOLIO
  TO ROLE PUBLIC;
