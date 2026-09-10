/* Cross-platform AI spend consolidation — semantic view and Cortex Agent
   Pair-programmed by SE Community + Cortex Code
   Expires: 2027-03-10

   Puts the consolidated model behind natural language, so leadership asks
   "which departments drove AI spend growth last quarter" instead of filing a
   dashboard request.

   Authored as DDL rather than YAML because DDL is what deploys through dbt and
   Terraform and what belongs in a git-reviewed SQL file. Both formats produce the
   same object -- see the YAML-vs-DDL comparison in the docs if your CI pipeline is
   YAML-shaped.

   THE DESIGN PROBLEM THIS FILE SOLVES: an agent will happily add a metered credit
   cost to an amortized seat cost if you let it. Three defenses, in order of
   strength:
     1. Model over GOLD.AI_SPEND_ALLOCATED, where blending is already done
        deliberately and ALLOCATION_BASIS is a dimension. There is no raw
        COST_AMOUNT column for the agent to sum incorrectly.
     2. AI_SQL_GENERATION instructions that name the trap explicitly.
     3. Verified queries that demonstrate the correct shape for the questions
        people actually ask.

   Clause ORDER IS SIGNIFICANT: TABLES, RELATIONSHIPS, FACTS, DIMENSIONS, METRICS,
   COMMENT, then AI_VERIFIED_QUERIES. Rearranging them is a syntax error.
*/

USE ROLE AI_SPEND_RL;
USE WAREHOUSE AI_SPEND_WH;
USE SCHEMA AI_SPEND.GOLD;

-- ---------------------------------------------------------------------------
-- Semantic view
--
-- Deliberately narrow. It models the allocated spend fact plus engagement and
-- seat utilization, and it does NOT expose SHAPED.UNIFIED_AI_USAGE. Exposing the
-- raw fact would hand the agent a COST_AMOUNT column that is NULL for seat
-- platforms, which is exactly the arithmetic we do not want it attempting.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE SEMANTIC VIEW AI_SPEND.GOLD.AI_SPEND_SV

  TABLES (
    spend AS AI_SPEND.GOLD.AI_SPEND_ALLOCATED
      WITH SYNONYMS = ('ai spend', 'ai cost', 'allocated spend')
      COMMENT = 'Daily AI cost per person per platform. Metered consumption and amortized seat cost, distinguished by allocation_basis.',

    engagement AS AI_SPEND.GOLD.AI_ENGAGEMENT_TIERS
      PRIMARY KEY (PERSON_KEY, PLATFORM_KEY)
      WITH SYNONYMS = ('engagement', 'adoption tiers', 'power users', 'usage tiers')
      COMMENT = 'Trailing 28-day engagement tier per person per platform. Ranked within platform only.',

    seats AS AI_SPEND.GOLD.SEAT_UTILIZATION
      WITH SYNONYMS = ('licences', 'licenses', 'seats', 'seat utilization')
      COMMENT = 'Monthly seat entitlement versus actual activity. Finds licences nobody uses.',

    platforms AS AI_SPEND.CONTROL.PLATFORM_REGISTRY
      PRIMARY KEY (PLATFORM_KEY)
      WITH SYNONYMS = ('platforms', 'ai tools', 'vendors')
      COMMENT = 'One row per AI platform: how it bills, what unit it reports, and what grain it can honestly deliver.'
  )

  RELATIONSHIPS (
    spend_to_platform AS spend (PLATFORM_KEY) REFERENCES platforms,
    engagement_to_platform AS engagement (PLATFORM_KEY) REFERENCES platforms,
    seats_to_platform AS seats (PLATFORM_KEY) REFERENCES platforms
  )

  FACTS (
    spend.allocated_cost_fact AS ALLOCATED_COST
      COMMENT = 'Row-level allocated cost in currency',
    engagement.native_qty_fact AS TOTAL_NATIVE_QTY
      COMMENT = 'Row-level native quantity. Comparable only within a platform.',
    engagement.active_days_fact AS ACTIVE_DAYS
      COMMENT = 'Days active in the trailing window',
    seats.seat_cost_fact AS SEAT_MONTHLY_COST
      COMMENT = 'Monthly cost of one licence',
    seats.reclaimable_fact AS RECLAIMABLE_COST
      COMMENT = 'Seat cost recoverable if a dormant licence were reclaimed'
  )

  DIMENSIONS (
    spend.usage_date AS USAGE_DATE
      WITH SYNONYMS = ('date', 'day')
      COMMENT = 'Date the cost was incurred',
    spend.usage_month AS DATE_TRUNC('month', USAGE_DATE)
      WITH SYNONYMS = ('month', 'period')
      COMMENT = 'Calendar month of the cost',
    spend.department AS COALESCE(DEPARTMENT, 'UNATTRIBUTED')
      WITH SYNONYMS = ('department', 'team', 'org', 'group')
      COMMENT = 'Department from the identity map. UNATTRIBUTED means the person could not be resolved -- always report this share alongside any allocation.',
    spend.business_unit AS COALESCE(BUSINESS_UNIT, 'UNATTRIBUTED')
      WITH SYNONYMS = ('business unit', 'bu', 'division')
      COMMENT = 'Business unit from the identity map',
    spend.cost_center AS COALESCE(COST_CENTER, 'UNATTRIBUTED')
      WITH SYNONYMS = ('cost center', 'cost centre', 'chargeback code')
      COMMENT = 'Cost centre for chargeback',
    spend.person AS PERSON_KEY
      WITH SYNONYMS = ('person', 'user', 'employee')
      COMMENT = 'Resolved person. A value beginning UNRESOLVED: means identity resolution failed and the spend is unattributable.',
    spend.platform AS PLATFORM_DISPLAY_NAME
      WITH SYNONYMS = ('platform', 'tool', 'vendor', 'ai tool')
      COMMENT = 'Which AI platform the cost belongs to',
    /* The single most important dimension in this view. Always group or filter by
       it when reporting cost, because the two bases are different kinds of number. */
    spend.allocation_basis AS ALLOCATION_BASIS
      WITH SYNONYMS = ('cost type', 'allocation basis', 'metered or seat')
      COMMENT = 'METERED means real consumption cost. AMORTIZED_SEAT means a fixed monthly licence spread across days. These are different kinds of cost and a total that mixes them moves for the wrong reasons.'
      SAMPLE_VALUES ('METERED', 'AMORTIZED_SEAT')
      IS_ENUM,
    spend.allocation_rule AS ALLOCATION_RULE
      COMMENT = 'Plain-language statement of how this row cost was derived',
    spend.currency AS CURRENCY_CODE
      WITH SYNONYMS = ('currency')
      COMMENT = 'Currency of the cost. Never sum cost across currencies -- always group by this when more than one appears.',

    engagement.engagement_tier AS ENGAGEMENT_TIER
      WITH SYNONYMS = ('tier', 'engagement level', 'power user', 'usage level')
      COMMENT = 'POWER, MEDIUM, LOW, or INACTIVE. Percentile of native quantity WITHIN the platform over 28 days -- not comparable across platforms. UNRANKED_TOO_FEW_USERS means the platform has fewer than three active people, so a percentile is not meaningful.'
      SAMPLE_VALUES ('POWER', 'MEDIUM', 'LOW', 'INACTIVE', 'UNRANKED_TOO_FEW_USERS')
      IS_ENUM,
    engagement.engagement_person AS PERSON_KEY,
    engagement.engagement_department AS COALESCE(DEPARTMENT, 'UNATTRIBUTED'),
    engagement.engagement_platform AS PLATFORM_DISPLAY_NAME,
    engagement.tier_definition AS TIER_DEFINITION
      COMMENT = 'The exact cut points used. Quote this whenever tiers are presented.',

    seats.seat_month AS PERIOD_MONTH
      WITH SYNONYMS = ('month', 'billing month'),
    seats.utilization_band AS UTILIZATION_BAND
      WITH SYNONYMS = ('utilization', 'seat usage', 'dormant', 'unused licence')
      COMMENT = 'DORMANT means billed and never used in the month -- the actionable reclaim list. NOT_BILLED means no charge for the period. UNKNOWN_NO_USAGE_SIGNAL means the platform cannot report per-user usage volume, so idleness has not been demonstrated and the seat must not be called dormant.'
      SAMPLE_VALUES ('DORMANT', 'LIGHT', 'MODERATE', 'REGULAR', 'NOT_BILLED', 'UNKNOWN_NO_USAGE_SIGNAL')
      IS_ENUM,
    seats.seat_department AS COALESCE(DEPARTMENT, 'UNATTRIBUTED'),
    seats.seat_person AS PERSON_KEY,

    platforms.cost_model AS COST_MODEL
      WITH SYNONYMS = ('billing model', 'metered or seat licensed')
      COMMENT = 'METERED platforms bill per unit consumed. SEAT platforms bill a fixed amount per licensed person regardless of use.'
      SAMPLE_VALUES ('METERED', 'SEAT')
      IS_ENUM,
    platforms.native_unit AS NATIVE_UNIT
      COMMENT = 'The unit this platform reports. Quantities in different units have no exchange rate and must never be compared.',
    platforms.supports_user_cost AS SUPPORTS_USER_COST
      COMMENT = 'FALSE means this platform cannot report per-user cost at all. Say so rather than returning zero.',
    platforms.supports_user_grain AS SUPPORTS_USER_GRAIN
      COMMENT = 'FALSE means no per-user usage volume, so engagement tiers are impossible for this platform.'
  )

  METRICS (
    spend.total_cost AS SUM(spend.allocated_cost_fact)
      WITH SYNONYMS = ('total cost', 'total spend', 'ai spend')
      COMMENT = 'Total allocated cost. ALWAYS break out by allocation_basis -- a single figure mixing metered and seat cost is misleading.',
    spend.people_with_cost AS COUNT(DISTINCT spend.person)
      WITH SYNONYMS = ('people', 'headcount', 'user count')
      COMMENT = 'Distinct people incurring cost',
    spend.cost_per_person AS DIV0(SUM(spend.allocated_cost_fact), COUNT(DISTINCT spend.person))
      COMMENT = 'Average cost per person. Only meaningful when filtered to a single allocation_basis.',
    spend.unattributed_cost AS SUM(IFF(spend.department = 'UNATTRIBUTED', spend.allocated_cost_fact, 0))
      WITH SYNONYMS = ('unattributed', 'unallocated cost')
      COMMENT = 'Cost that could not be attributed to a department. Report this beside any department breakdown.',

    engagement.people_in_tier AS COUNT(DISTINCT engagement.engagement_person)
      WITH SYNONYMS = ('users in tier', 'tier population')
      COMMENT = 'Distinct people in an engagement tier',
    engagement.avg_active_days AS AVG(engagement.active_days_fact)
      COMMENT = 'Average active days in the trailing 28-day window',

    seats.seat_count AS COUNT(DISTINCT seats.seat_person)
      WITH SYNONYMS = ('licences', 'seats', 'seat count')
      COMMENT = 'Distinct licensed people',
    seats.total_seat_cost AS SUM(seats.seat_cost_fact)
      COMMENT = 'Total monthly licence cost',
    seats.total_reclaimable AS SUM(seats.reclaimable_fact)
      WITH SYNONYMS = ('wasted spend', 'recoverable cost', 'savings opportunity')
      COMMENT = 'Cost of licences billed and never used. The clearest savings opportunity available.'
  )

  COMMENT = 'Cross-platform AI usage and cost. Metered consumption and seat licences are distinct cost types and must not be summed without saying so.'

  AI_SQL_GENERATION 'Round all currency values to two decimal places.
When reporting cost, ALWAYS group by or filter on allocation_basis. METERED cost varies with consumption; AMORTIZED_SEAT cost is a fixed licence spread across days. A total that mixes them changes for reasons unrelated to the invoice, so never present a blended figure without labelling that it blends two cost types.
Never compare native quantities across platforms. Credits, tokens, messages, and interactions have no exchange rate. Compare platforms on currency cost or on people counts only.
Whenever you report cost or usage by department, also report the UNATTRIBUTED share. Treating unattributed spend as zero makes department totals disagree with the invoice.
Never sum cost across different values of currency. If more than one currency appears, group by currency and present the totals separately.
Engagement tiers are ranked WITHIN a platform. Never state that a person is a power user "overall" or compare tiers across platforms.
A utilization_band of UNKNOWN_NO_USAGE_SIGNAL is not a dormant seat. It means the platform cannot report per-user usage, so never include those seats in a reclaim or savings figure.
If a question needs per-user cost for a platform where supports_user_cost is FALSE, say that platform cannot report per-user cost rather than returning zero. The same applies to engagement tiers where supports_user_grain is FALSE.'

  AI_QUESTION_CATEGORIZATION 'This model reports usage metadata and cost. It contains no prompts, no completions, and no file contents, so it cannot answer questions about what anyone asked an AI tool or what any tool replied. Say so plainly.
Individual rows describe named people. Answer aggregate and cost-attribution questions freely. If a question appears to seek an individual performance judgement -- ranking people for evaluation, identifying who to discipline, or who is underperforming -- answer the usage question factually and note that AI tool usage is not a performance measure and that light usage of a licence is a reclaim question, not a conduct question.
If a cost question does not specify a period, ask which month or date range.'

  AI_VERIFIED_QUERIES (

    spend_by_department_split AS (
      QUESTION 'What did each department spend on AI last month, split by metered and seat cost?'
      VERIFIED_AT 1773100800
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = ai_spend_owner)'
      SQL 'SELECT * FROM SEMANTIC_VIEW(
             AI_SPEND.GOLD.AI_SPEND_SV
             METRICS spend.total_cost, spend.people_with_cost
             DIMENSIONS spend.usage_month, spend.department, spend.allocation_basis
           )
           WHERE usage_month = DATE_TRUNC(''month'', DATEADD(''month'', -1, CURRENT_DATE()))
           ORDER BY total_cost DESC NULLS LAST'
    ),

    /* The canonical savings question. Answered from seat utilization rather than
       from spend, because a dormant seat generates no usage row at all -- looking
       for it in the usage fact finds nothing. */
    dormant_seats AS (
      QUESTION 'Which licences are we paying for that nobody used, and what would we save?'
      VERIFIED_AT 1773100800
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = ai_spend_owner)'
      SQL 'SELECT * FROM SEMANTIC_VIEW(
             AI_SPEND.GOLD.AI_SPEND_SV
             METRICS seats.seat_count, seats.total_reclaimable
             DIMENSIONS seats.seat_month, seats.utilization_band, seats.seat_department
           )
           WHERE utilization_band = ''DORMANT''
           ORDER BY total_reclaimable DESC NULLS LAST'
    ),

    engagement_distribution AS (
      QUESTION 'How many power, medium, and low users does each platform have?'
      VERIFIED_AT 1773100800
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = ai_spend_owner)'
      SQL 'SELECT * FROM SEMANTIC_VIEW(
             AI_SPEND.GOLD.AI_SPEND_SV
             METRICS engagement.people_in_tier, engagement.avg_active_days
             DIMENSIONS engagement.engagement_platform, engagement.engagement_tier
           )
           ORDER BY engagement_platform, engagement_tier'
    ),

    /* Trend by month and basis, never blended. Seat cost trends with headcount and
       metered cost trends with behaviour; a combined line hides which moved. */
    monthly_trend_by_basis AS (
      QUESTION 'How has AI spend trended by month for each platform?'
      VERIFIED_AT 1773100800
      VERIFIED_BY '(STEWARD = ai_spend_owner)'
      SQL 'SELECT * FROM SEMANTIC_VIEW(
             AI_SPEND.GOLD.AI_SPEND_SV
             METRICS spend.total_cost, spend.people_with_cost
             DIMENSIONS spend.usage_month, spend.platform, spend.allocation_basis
           )
           ORDER BY usage_month, platform, allocation_basis'
    ),

    /* Data-quality question. Publish this beside any allocation chart. */
    unattributed_share AS (
      QUESTION 'How much AI spend could not be attributed to a department?'
      VERIFIED_AT 1773100800
      VERIFIED_BY '(STEWARD = ai_spend_owner)'
      SQL 'SELECT * FROM SEMANTIC_VIEW(
             AI_SPEND.GOLD.AI_SPEND_SV
             METRICS spend.total_cost, spend.unattributed_cost
             DIMENSIONS spend.usage_month, spend.platform
           )
           ORDER BY usage_month DESC NULLS LAST, unattributed_cost DESC NULLS LAST'
    )
  );

-- ---------------------------------------------------------------------------
-- Cortex Agent
--
-- orchestration: auto so the agent stays portable across regions. Pin a model only
-- with a specific reason -- a pinned name that is unavailable in the target region
-- is a silent deployment failure.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE AGENT AI_SPEND.GOLD.AI_SPEND_AGENT
  COMMENT = 'Answers cross-platform AI usage and cost questions over AI_SPEND_SV'
  PROFILE = '{"display_name": "AI Spend Analyst"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  instructions:
    response: |
      Lead with the number, then the caveat. Round currency to two decimals and
      always name the currency and the period.

      Never present one blended AI cost figure without saying it blends two
      different cost types. Metered consumption and fixed seat licences respond to
      completely different levers, and a combined total moves for reasons that do
      not match the invoice.

      When you report anything by department, state the unattributed share in the
      same answer. If it is above ten percent, say the allocation is indicative and
      that the identity map needs work.

      When you report engagement tiers, state that they are ranked within a
      platform and are not comparable across platforms.

      If a platform cannot answer the question asked -- no per-user cost, or no
      per-user usage volume -- say so directly instead of returning zero. A stated
      limitation is a useful answer; a zero that looks like data is not.
    orchestration: |
      Use the query_ai_spend tool for every factual question. Do not estimate from
      memory and do not carry a figure from an earlier turn without re-querying.

      Route by question type:
        cost, budget, forecast, chargeback  -> spend metrics, always split by
                                              allocation_basis
        unused or wasted licences, savings  -> seats metrics filtered to DORMANT
        adoption, power users, who uses it  -> engagement metrics
        what can this platform tell us      -> platforms dimensions, including
                                              supports_user_cost and
                                              supports_user_grain

      A dormant seat produces no usage row, so questions about unused licences must
      go to the seats table and never to spend.

      If no period is specified for a cost question, ask which month or range
      rather than silently defaulting.
    sample_questions:
      - question: "What did each department spend on AI last month, split by metered and seat cost?"
      - question: "Which licences are we paying for that nobody used, and what would we save?"
      - question: "How many power, medium, and low users does each platform have?"
      - question: "How has AI spend trended by month for each platform?"
      - question: "How much AI spend could not be attributed to a department?"
  tools:
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: query_ai_spend
        description: |
          Query consolidated cross-platform AI usage and cost. Covers allocated
          spend by person, department, platform, and cost type; engagement tiers;
          seat utilization; and each platform's honest reporting capability.
  tool_resources:
    query_ai_spend:
      semantic_view: AI_SPEND.GOLD.AI_SPEND_SV
  $$;

-- ---------------------------------------------------------------------------
-- Grants
--
-- REFERENCES and SELECT on the semantic view are BOTH required for a role that
-- does not own it to use it through an agent. SELECT alone is enough to query the
-- view directly but not enough for agent use -- a confusing failure to debug.
--
-- Note the governance opportunity: granting on the semantic view does not require
-- granting on SHAPED.UNIFIED_AI_USAGE. Aggregate reporting access and row-level
-- access to individual people stay genuinely separate, which is what the privacy
-- gate in the README asks for.
-- ---------------------------------------------------------------------------

-- GRANT REFERENCES, SELECT ON SEMANTIC VIEW AI_SPEND.GOLD.AI_SPEND_SV TO ROLE <reporting_role>;
-- GRANT USAGE ON AGENT AI_SPEND.GOLD.AI_SPEND_AGENT TO ROLE <reporting_role>;

-- ---------------------------------------------------------------------------
-- Verify
-- ---------------------------------------------------------------------------

DESCRIBE SEMANTIC VIEW AI_SPEND.GOLD.AI_SPEND_SV;

SHOW AGENTS LIKE 'AI_SPEND_AGENT' IN SCHEMA AI_SPEND.GOLD;

/* Smoke test the boundary the whole model exists to protect. Metered and seat cost
   must come back on SEPARATE rows. If they collapse into one, allocation_basis has
   been dropped somewhere and the agent will be able to blend them. */
SELECT * FROM SEMANTIC_VIEW(
    AI_SPEND.GOLD.AI_SPEND_SV
    METRICS spend.total_cost, spend.people_with_cost
    DIMENSIONS spend.platform, spend.allocation_basis
)
ORDER BY platform, allocation_basis;
