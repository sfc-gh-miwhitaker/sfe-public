/* Cross-platform AI spend consolidation — adapter build specifications
   Pair-programmed by SE Community + Cortex Code
   Expires: 2027-03-10

   ChatGPT Enterprise, Box AI, Microsoft 365 Copilot, Anthropic Claude, Cursor,
   and the three Google surfaces.

   These are SPECIFICATIONS, not implementations, and that is a design decision
   rather than an omission.

   Every vendor here changed a relevant endpoint during 2026: GitHub retired its
   legacy Copilot metrics API in April, OpenAI removed a conversation log route in
   June, Box switched Box AI to metered AI Units in October 2025 with the per-user
   report arriving mid-2026, Anthropic began requiring a version header on surfaces
   that previously tolerated its absence, Cursor tightened its usage range cap from
   90 days to 30 and rebuilt Teams pricing in June, and Google renamed Vertex AI to
   Gemini Enterprise Agent Platform. Nine hand-maintained connectors would be
   confidently wrong within two quarters -- and confidently wrong is worse than
   obviously incomplete, because someone runs it and trusts the output.

   So each section below gives you what actually survives vendor churn:
     - which surface answers which question, and which one holds the billing number
     - the auth shape and the privilege that is easy to miss
     - the reports to pull and the fields normalization requires
     - the granularity ceiling, stated honestly
     - the trap that costs a day if you meet it cold

   Plug those into the shape of sql/03_pull_github_copilot.sql, which is fully
   worked and exercises all six contract obligations. Verify endpoint paths against
   current vendor documentation before your first run -- the response shapes here
   are the illustrative target, not a guarantee.
*/

USE ROLE AI_SPEND_RL;
USE WAREHOUSE AI_SPEND_WH;

/* ===========================================================================
   1. ChatGPT Enterprise
   ===========================================================================

   GRANULARITY: user-level rows and per-user cost are both available.
     Registry: SUPPORTS_USER_GRAIN = TRUE, SUPPORTS_USER_COST = TRUE
     Cost model: METERED, native unit CREDITS

   THREE SURFACES, THREE JOBS. Picking the wrong one costs a week:
     - Workspace analytics / Analytics API -> adoption and engagement. USE THIS.
     - Cost API                            -> credits by user, product, and model.
                                               USE THIS for spend.
     - Compliance Logs Platform            -> raw auditable records for legal,
                                               security, and eDiscovery. DO NOT use
                                               this for adoption reporting.

   The counts from analytics and compliance legitimately DISAGREE. Compliance
   returns raw system data, including internal messages and records without
   timestamps; analytics returns cleaned data. Neither is wrong. Someone will
   eventually ask why two numbers differ -- this is the answer.

   This pipeline deliberately uses analytics and cost only. That keeps it to usage
   metadata with no prompt or completion content, which is a far easier boundary to
   defend in a privacy review than "we ingest compliance logs and promise not to
   look" -- and it is sufficient for all five decisions in the README.

   THE BILLING TRAP: a ChatGPT Enterprise workspace and an OpenAI API Platform
   organization are separate products, separate contracts, separate meters. They are
   registered as two platforms in sql/01 so that a blended "OpenAI spend" figure --
   which reconciles to neither invoice -- is structurally hard to produce.

   Suggested reports:
     USER_ACTIVITY  per-user message and tool activity -> engagement tiers
     CREDIT_USAGE   per-user credits by product and model -> cost
     MEMBERS        workspace roster -> seeds IDENTITY_MAP, finds inactive seats

   Required fields for normalization:
     USER_ACTIVITY  a date and a workspace member identifier
     CREDIT_USAGE   a date, a member identifier, and a credit quantity

   Implementation notes:
     - Scope every request to an explicit workspace ID and land it in
       BILLING_CONTEXT = 'CHATGPT_WORKSPACE'. Never leave it implicit.
     - Timestamps must be ISO 8601 WITH a timezone offset. Naive timestamps are
       rejected or, worse, silently reinterpreted.
     - Do not adopt OpenAI's power-user definition as your own. It is top-20-percent
       by message volume using three or more tools -- specific to their product
       surface and not portable to Copilot or Cortex. sql/07 computes portable
       tiers and documents the cut points.
   =========================================================================== */

-- Adapt sql/03_pull_github_copilot.sql. The changes are confined to:
--   PLATFORM_KEY    = 'CHATGPT_ENTERPRISE'
--   BILLING_CONTEXT = 'CHATGPT_WORKSPACE'
--   API_ROOT        = 'https://api.openai.com'
--   SECRETS         = ('openai_token' = AI_SPEND.CONTROL.OPENAI_ADMIN_CREDENTIALS)
--   REPORTS         = USER_ACTIVITY | CREDIT_USAGE | MEMBERS
--   REQUIRED_FIELDS per the list above
-- Everything else -- watermarking, staging, COPY, run logging, QUERY_TAG -- is
-- unchanged. That reuse is the entire point of the contract.

/* ===========================================================================
   2. Box AI
   ===========================================================================

   GRANULARITY: user-level rows and per-user cost are both available, and Box adds
   a dimension most platforms do not -- cost per AGENT.
     Registry: SUPPORTS_USER_GRAIN = TRUE, SUPPORTS_USER_COST = TRUE
     Cost model: METERED, native unit AI_UNITS

   CORRECT A COMMON ASSUMPTION FIRST: Box AI has been metered in AI Units since
   2025-10-20. Anyone modelling it as bundled seat cost is describing the old model.

   THREE SURFACES, AND THEY ARE NOT INTERCHANGEABLE:

     AI Insights dashboard   AI Units by user, agent, and capability. Console only.
                             Good for a screenshot, not for a pipeline.
     AI Units Admin Report   AI Units per user and per agent, monthly. EXPORT, not a
                             JSON endpoint -- but it can be scheduled to deliver into
                             a Box folder, which is what makes it automatable.
                             THIS IS THE BILLING NUMBER FINANCE WANTS.
     Enterprise Events API   Individual AI events. Genuinely programmatic:
                             stream_type = admin_logs (1 year) or
                             admin_logs_streaming (2 weeks, near real time).

   THE RETENTION CLIFF -- the most important operational fact about this platform:
     admin_logs_streaming     2 weeks
     admin_logs               1 year
     Console exported reports 7 years
   A pipeline that breaks over a holiday loses streaming data PERMANENTLY. Watermark
   recovery is not sufficient protection on its own; the health view must alarm well
   inside the window. This is the strongest case in the guide for landing raw
   payloads immutably -- it is the only copy you will ever have.

   THE AWKWARD SPLIT, STATED PLAINLY: the billing unit lives in a report and the
   granularity lives in an API. Two adapters, not one:

     AI_UNITS_MONTHLY  poll the Box folder Box delivers the report into, fetch the
                       file, land it. Cost-bearing. This is the one to build first.
     AI_EVENTS         Enterprise Events API with stream_type = admin_logs, filtered
                       to AI event types. Event granularity and agent attribution,
                       but NOT the chargeable unit.

   Do not sum both into cost. Land AI_EVENTS with NATIVE_QTY = NULL and treat it as
   activity, or you double count against the AI_UNITS report.

   AUTH: Box Platform App with Client Credentials Grant. The service account needs
   the "Run new reports and access existing reports" permission -- without it the
   events endpoints fail in a way that reads like a bad token rather than a missing
   privilege. sql/02 has the secret template.

   Required fields for normalization:
     AI_UNITS_MONTHLY  a period, a user identifier, and an AI Unit quantity
     AI_EVENTS         an event created_at and the acting user

   Implementation notes:
     - Paginate events with the returned stream position, not an offset. Box
       explicitly does not support long polling on the enterprise feed.
     - Filter to AI event types SERVER-SIDE via event_type. Pulling all admin
       activity and filtering in SQL will exhaust your rate budget on a large
       tenant, and there is no second chance inside a two-week window.
     - Chargeable API calls and interactive user queries are tracked as distinct
       things by Box. Keep them separable -- put them in different REPORT_NAMEs
       rather than adding them together.
     - Box AI Units are consumed by AGENTS as well as by people. That is a genuinely
       useful attribution axis and the base model does not carry it; see
       "Extending the Model" in the README for the three-step change.
   =========================================================================== */

/* ===========================================================================
   3. Microsoft 365 Copilot
   ===========================================================================

   GRANULARITY CEILING -- READ THIS BEFORE REQUESTING A CREDENTIAL:
     Registry: SUPPORTS_USER_GRAIN = FALSE, SUPPORTS_USER_COST = FALSE
     Cost model: SEAT, native unit ACTIVE_DAYS

   Two hard limits, both structural rather than fixable in code:

   (a) IDENTITY IS PSEUDONYMIZED BY DEFAULT.
       getMicrosoft365CopilotUsageUserDetail returns HASHED values in
       userPrincipalName and displayName unless the tenant has disabled report
       concealment. The hashes are stable, so you can trend an anonymous
       individual over time -- but you CANNOT join them to a department, which is
       the whole point of the exercise.

       Confirm the setting with an Entra administrator FIRST. In some organizations
       concealment is deliberate and a privacy office will decline to change it.
       That is a legitimate answer, and it removes Copilot from user-level scope
       entirely. Finding out after ingestion wastes the credential request and
       produces a dashboard nobody can use.

   (b) THE PAYLOAD IS LAST-ACTIVITY DATES, NOT VOLUME.
       You get per-app last-activity dates -- Teams, Word, Excel, PowerPoint,
       Outlook, OneNote, Loop, Chat. There is no message count and no token count.

       Consequence: THIS PLATFORM CANNOT SUPPORT ENGAGEMENT TIERS. A light user and
       a power user both show a recent date. Do not build a tier chart that
       includes Copilot; say the platform cannot answer it. The registry flags
       exist so the monitoring layer states that rather than rendering an empty
       panel that reads like a bug.

   WHAT IT IS GOOD FOR, AND IT IS NOT NOTHING: seat utilization. An assigned
   licence with no activity in 28 days is money leaving with nothing in return, and
   it is the cheapest saving in this entire guide. Model Copilot as SEAT cost from
   CONTROL.SEAT_ENTITLEMENT and use the activity dates purely as a
   touched / not-touched signal.

   AUTH: client credentials against an Entra app registration with an
   admin-consented application permission to read usage reports. Requires the
   login.microsoftonline.com token host in addition to graph.microsoft.com --
   sql/02 includes both, because omitting the token host produces an
   authentication failure that looks exactly like a bad credential.

   Suggested reports:
     USAGE_USER_DETAIL  per-user last-activity dates -> touched / not touched
     LICENSE_DETAIL     assigned licences -> SEAT_ENTITLEMENT

   Required fields: a report refresh date and a user principal name -- hashed is
   acceptable, and the normalization layer records LOW identity confidence for it.

   Implementation notes:
     - Response defaults to CSV. Request JSON explicitly with
       ?$format=application/json, or write a CSV branch. Do not assume JSON.
     - Paginate on @odata.nextLink until absent.
     - Reports are period-based (D7, D30, D90) rather than an arbitrary window, so
       the watermark selects a PERIOD rather than a time range. This is the one
       adapter whose watermark semantics genuinely differ -- note it in the run log
       so a future reader does not think it is a bug.
     - Prefer the /copilot path segment over older /reports equivalents.
   =========================================================================== */

/* ===========================================================================
   4. Anthropic Claude -- TWO platforms, and the seat includes nothing
   ===========================================================================

   CORRECT THE MENTAL MODEL FIRST, because it is the one fact here that changes the
   design rather than just the endpoint list:

     On current Anthropic Enterprise plans the seat fee buys ACCESS AND NO USAGE.
     Every token is billed separately at API rates. Enterprise seats carry no
     individual token allowance.

   So Claude Enterprise is a seat AND a meter, and the meter is the larger, more
   volatile half. Anyone modelling it as a flat per-person cost -- the way M365
   Copilot genuinely is -- will forecast the wrong number and be wrong in the
   direction that hurts, because metered spend grows with adoption.

   Registry consequence: ANTHROPIC_CLAUDE_ENTERPRISE is COST_MODEL = 'METERED'
   (that is what its usage rows measure) with the seat fee in SEAT_ENTITLEMENT.

   Expect THREE billing generations in one tenant's history, and do not assume the
   current one applies to older periods:
     (1) usage-based single Enterprise seat  -- current
     (2) legacy Chat / Chat+Claude Code seats -- usage-based
     (3) legacy Standard/Premium seats -- allowance plus usage-credit overage
   The legacy shapes are closed to new contracts and auto-transition at renewal,
   which silently changes what a cost column means mid-history.

   TWO PLATFORMS, TWO CREDENTIALS, AND THEY CANNOT SUBSTITUTE:

     ANTHROPIC_CLAUDE_ENTERPRISE   the claude.ai seats. Analytics API, key scope
                                   read:analytics, PRIMARY OWNER ONLY.
                                   THE ONLY SURFACE WITH PER-USER COST.
     ANTHROPIC_API_CONSOLE         the metered API platform. Admin API, sk-ant-admin
                                   key, org-scoped (a workspace-scoped key fails).
                                   NO USER DIMENSION AT ALL.

   An Admin key cannot call the Analytics API and an Analytics key cannot call the
   Admin API, even though both are documented under one "Admin API" heading.

   YOU NEED BOTH, and this is not belt-and-braces. The per-user endpoints include
   only cost attributable to a SEAT USER; direct API-key and automation traffic is
   excluded by design. Per-user cost will therefore not sum to the invoice, and the
   bucketed organization-level cost report is what closes the gap. Ingest one and
   finance finds the discrepancy for you.

   THE OPERATIONAL FACT THAT DICTATES THE LOAD PATTERN:
     A value for a given date can be REVISED FOR UP TO 30 DAYS as late events and
     reconciliation arrive. Responses carry data_refreshed_at.

   That makes this the one platform in the guide where append-only ingestion is
   simply wrong. Restate a rolling 30-day window on every run, key stability on
   data_refreshed_at rather than on the date you asked for, and treat only dates
   older than 30 days as invoicing-grade. An append-only load here produces a
   number that was right when captured and disagrees with the vendor a week later.

   Also hard-limiting: NO DATA EXISTS BEFORE 2026-01-01 on the Analytics API. There
   is no backfill conversation to have. A Snowflake-side accumulator is the history.

   Suggested reports:
     USER_COST      per-user cost. Returns BOTH effective and list amounts -- keep
                    both, because the gap between them is the discount and someone
                    will eventually ask to see it.
     USER_USAGE     per-user tokens
     USER_ACTIVITY  per-user per-product activity -> engagement tiers
     ORG_COST       bucketed organization cost -> the invoice reconciliation half
     MEMBERS        roster -> seeds IDENTITY_MAP

   Required fields for normalization:
     USER_COST   a date, a user identifier, and a cost amount
     USER_USAGE  a date, a user identifier, and a token quantity
     ORG_COST    a date bucket and a cost amount

   Implementation notes:
     - Amounts are DECIMAL STRINGS IN CENTS. Divide by 100 and parse as decimal,
       never as a binary float. Land the string verbatim and cast in SQL.
     - The actor object carries BOTH an email and a stable user id. Join on the id
       and carry the email for humans -- an email is a rename waiting to happen.
       Note the asymmetry: the Console-side Claude Code endpoint returns email ONLY,
       so cross-joining the two surfaces is an email join whether you like it or not.
     - anthropic-version is required on every request across both families.
     - Pagination cursors are bound to the exact query. Changing any filter, date
       range, or grouping mid-sequence returns a 400 rather than resuming. Restart.
     - The per-request row limit is not a hard row cap: cost-type and token-type
       fan-out rows do not count against it, so a page can return more than asked.
     - Rate limit is per ORGANIZATION, not per key -- roughly 60 requests a minute
       shared across every endpoint. Combined with a 31-day maximum range per call,
       that sets your backfill wall-clock budget. Two adapters running concurrently
       compete with each other.
     - Engagement-endpoint rollups may use approximate distinct counts. Fine for a
       tier chart, wrong for anything reconciled.
     - There is a separate Compliance API with a separate key that returns prompts,
       responses, and session transcripts. This pipeline deliberately does NOT use
       it -- see gotcha 7 in the README. Usage metadata only is a far easier
       boundary to defend, and it answers all five decisions.
   =========================================================================== */

/* ===========================================================================
   5. Cursor -- the seat and the meter OVERLAP
   ===========================================================================

   GRANULARITY: user-level rows and per-user cost are both available, keyed by email.
     Registry: SUPPORTS_USER_GRAIN = TRUE, SUPPORTS_USER_COST = TRUE
     Cost model: METERED usage rows, with the seat fee in SEAT_ENTITLEMENT

   THE TRAP, AND IT IS THE OPPOSITE OF ANTHROPIC'S: a Cursor seat INCLUDES a usage
   pool, then bills on-demand in arrears once the pool is exhausted. So seat cost
   and metered cost are not additive -- part of the metered number is already paid
   for by the seat.

   The API hands you both halves and it is easy to pick the wrong one:
     spendCents         ON-DEMAND ONLY, excludes included usage. USE THIS.
     overallSpendCents  includes the seat's included usage. Adding this to seat cost
                        DOUBLE COUNTS the allowance.

   Pools are allocated PER USER and do not transfer between members, so an unused
   allowance is not recoverable elsewhere -- which makes seat utilization a real
   saving here rather than a rounding note.

   DO NOT SEED PLATFORM_RATE FOR THIS PLATFORM. Cursor reports cost already in
   currency. Every other platform reports a native quantity that PLATFORM_RATE
   converts; applying a rate here multiplies cents by a rate and produces a
   plausible wrong number in the right column.

   THREE ENDPOINTS, THREE JOBS:
     members             email <-> user id, and role. Seeds IDENTITY_MAP.
     daily-usage-data    per user per day activity. NO COST FIELDS AT ALL.
     filtered-usage-events  per REQUEST, with tokens and cost. This is the cost feed.

   A cycle-to-date spend endpoint also exists. It is a snapshot, useful for
   reconciliation, useless as a time series -- do not build history from it.

   Suggested reports:
     MEMBERS       roster and email/id mapping
     DAILY_USAGE   activity -> engagement tiers, seat utilization
     USAGE_EVENTS  per-request cost -> spend

   Required fields for normalization:
     DAILY_USAGE   a day, an email, and activity counters
     USAGE_EVENTS  a timestamp, an email, and a charged amount

   Implementation notes:
     - ALWAYS PAGINATE daily-usage-data. Without explicit paging parameters it
       returns ACTIVE USERS ONLY -- silently omitting exactly the zero-activity
       seats that a seat-utilization metric exists to find. This is the single
       easiest way to build a wrong dashboard here.
     - Date parameters are EPOCH MILLISECONDS and both bounds are INCLUSIVE. End a
       window at 23:59:59.999 or you count the boundary day twice.
     - Range cap is 30 days per request, tightened from 90 -- older sample code and
       blog posts request a range the API now rejects.
     - Store cost as DECIMAL, not integer cents. Values became fractional in 2026
       to match invoices, so an integer column silently truncates.
     - The activity endpoint's request counters count usage EVENTS, not billable
       units. Sum the cost feed for anything chargeable.
     - The numeric user id on the activity feed is NOT the same namespace as the
       encoded id on the members and spend endpoints. Resolve identity on EMAIL.
     - Data is aggregated hourly; polling faster than hourly buys nothing and burns
       a 20-requests-per-minute budget.
     - Privacy Mode governs TRAINING, not analytics. Per-user metrics still flow
       with it enabled, so it is not the reason a user is missing. The real
       attribution gaps are functional: old client versions collect no analytics,
       and removed members are omitted from the activity feed while still appearing
       in the cost feed -- which will make your two feeds disagree on population.
     - Verify plan gating against the actual tenant. Cursor's own documentation is
       inconsistent about whether the Admin API requires Enterprise; assume it does
       and be pleasantly surprised.
   =========================================================================== */

/* ===========================================================================
   6. Google -- three platforms, because they share nothing but a brand
   ===========================================================================

   THE ONE-LINE SUMMARY TO GIVE LEADERSHIP: Google offers user-level USAGE nearly
   everywhere and user-level COST almost nowhere. Every disappointment below is a
   consequence of that sentence.

   ---------------------------------------------------------------------------
   6a. GOOGLE_WORKSPACE_GEMINI -- usage yes, cost structurally absent
   ---------------------------------------------------------------------------
     Registry: SUPPORTS_USER_GRAIN = TRUE, SUPPORTS_USER_COST = FALSE
     Cost model: SEAT, native unit FEATURE_EVENTS

   THERE IS NO GEMINI USER USAGE REPORT. The Workspace user usage report covers six
   application types and Gemini is not among them. Per-user Gemini data is an AUDIT
   ACTIVITY feed: an actor and an action string, with NO token count and NO cost.
   Anyone who has promised token-level Workspace Gemini reporting has promised
   something that does not exist.

   BASELINE GEMINI HAS NO SEPARABLE COST. It is inside the Workspace plan price
   following the 2025 bundling, so there is no honest per-user figure to compute --
   only plan cost divided by headcount, which is arithmetic rather than measurement.

   The ONE legitimate Workspace AI line item: the AI Expanded Access and AI Ultra
   Access ADD-ON SEATS, reintroduced in February 2026. Those are assigned to named
   users, so they belong in SEAT_ENTITLEMENT and they are genuinely attributable.
   If someone tells you Workspace AI has no separate SKU any more, they are
   describing the 2025 state.

   RETENTION IS THE HARD CONSTRAINT: 180 days rolling, with nothing at all before
   2025-06-20. There is no long backfill available, so the Snowflake-side history IS
   the history. Start accumulating before anyone asks for a year-over-year trend.

   TWO ROUTES, AND THE OBVIOUS ONE IS THE WRONG ONE AT SCALE:
     Reports API activities   convenient, but filtered queries are capped and Google
                              states plainly it is not intended for high-volume
                              audit retrieval. Fine for a pilot.
     BigQuery log export      Google's own recommendation at scale. ~10 minute lag
                              for activity, 180 days activity / 450 days usage.
                              USE THIS for anything ongoing.

   Two BigQuery-export gotchas that will cost a day each:
     - Day partitions are aligned to PACIFIC TIME, not UTC. Google overrides the
       BigQuery default. A UTC-assumed daily boundary misplaces rows.
     - The export carries NO org-unit column, so you cannot filter by OU in SQL the
       way the API lets you. Departmental allocation has to come from your own
       directory join -- which is what IDENTITY_MAP is for anyway.

   Also: the Admin console's per-user Gemini report buckets users into High/Medium/
   Low/Zero LEVELS rather than counts, over a fixed 28-day window. Do not adopt
   those buckets as your engagement tiers -- they are a different definition on a
   different window, and sql/07 computes portable tiers with documented cut points.
   And the "Gemini last usage" column in the user directory is documented by Google
   as potentially inaccurate. Do not build on it.

   ---------------------------------------------------------------------------
   6b. GOOGLE_CODE_ASSIST -- the best per-user signal Google has
   ---------------------------------------------------------------------------
     Registry: SUPPORTS_USER_GRAIN = TRUE, SUPPORTS_USER_COST = FALSE
     Cost model: SEAT, native unit IDE_INTERACTIONS

   Cloud Logging entries carry a user id label that is a PLAIN EMAIL. That makes
   this the one Google surface that behaves like GitHub Copilot or Cursor: real
   per-user code and chat exposure and acceptance, joinable to a person.

   PICK THE RIGHT SURFACE. Cloud Monitoring exposes tempting metrics for the same
   product -- active users, suggestions, lines accepted -- and they are AGGREGATE
   ONLY, with no user dimension. Building on Monitoring and then being asked to
   break it down by team is a rewrite, not a filter.

   Cost is a seat, so per-user cost here is ALLOCATION from SEAT_ENTITLEMENT, not
   measurement. Which is fine: the question this platform answers well is seat
   utilization, and that is the cheapest saving available.

   Two enablement facts that are not optional and have no backfill:
     - Code Assist logging is OFF BY DEFAULT. Nothing accumulates until it is on.
     - IDE extension telemetry must be enabled for entries to be produced, and
       recording covers IDE interactions ONLY.
   Turning both on is step zero, weeks before the first pull.

   Filter on the product label. Gemini in BigQuery writes to the same log stream
   under a different product value, and conflating them inflates developer-AI
   adoption with analyst activity.

   ---------------------------------------------------------------------------
   6c. GOOGLE_VERTEX_AI -- metered, and per-user cost is NOT ACHIEVABLE
   ---------------------------------------------------------------------------
     Registry: SUPPORTS_USER_GRAIN = FALSE, SUPPORTS_USER_COST = FALSE
     Cost model: METERED, native unit TOKENS, subject key PROJECT_LABEL

   State this before anyone builds a slide that assumes otherwise. Cloud Billing
   attribution stops at PROJECT, SERVICE, and SKU. There is no user dimension.

   Labels are the only request-level attribution mechanism, and they are NOT a
   workaround for per-user cost, for two independent reasons:
     - Google explicitly warns against putting personally identifiable information
       in labels; they are not designed for it.
     - A label key supports a capped number of distinct values FOR THE LIFE OF THE
       BILLING ACCOUNT -- roughly a thousand -- and may be dropped without notice
       beyond that. Labelling by user email breaks permanently above that headcount,
       and "permanently" is the operative word: the ceiling is lifetime, not
       concurrent.

   The defensible design is a pseudonymous team or cost-centre bucket well under
   the ceiling. That gives TEAM-level metered cost, which is a real answer -- just
   not the one that was asked for. Say so in the gold layer rather than dividing a
   project total by headcount and calling it per-user cost.

   Per-user USAGE is separately available from Data Access audit logs, which carry
   the acting principal's email. So the honest shape is per-user usage joined to
   team-level cost. Do not multiply one by the other and present the result.

   Two more facts worth carrying:
     - Billing export lag is typically under a day but can exceed 24 hours. This
       surface cannot support real-time enforcement, only reporting.
     - AI spend is scattered across several service and SKU descriptions rather
       than grouped under one AI category. Budget for a SKU classification mapping
       table, and treat it as something to maintain, not to write once.

   NAME COLLISIONS THAT WILL CORRUPT A DIMENSION TABLE:
     - "Gemini Enterprise" means two unrelated things: the retired 2024 Workspace
       add-on SKU, which still appears in reports as a legacy license type, and the
       current Google Cloud agentic platform formerly called Agentspace.
     - Vertex AI was renamed to Gemini Enterprise Agent Platform in 2026. The API
       endpoint is UNCHANGED, so this breaks documentation links and console
       navigation, not code. Do not "fix" working calls because the brand moved.
     - Google Ads Data Manager and similar advertising features are Gemini-POWERED
       but expose no AI usage or cost telemetry. They are not in scope.
   =========================================================================== */

/* ===========================================================================
   Adding any of these: the order that saves you time
   ===========================================================================

   Full checklist in docs/adapter-contract.md. The two steps people skip:

   STEP 1 -- Confirm the grain BEFORE requesting credentials. It is the step that
   kills projects, and finding out after the security review is the expensive
   order of operations.

   STEP 8 -- Check the unresolved-identity rate BEFORE activating. A new platform
   landing entirely in the UNRESOLVED bucket produces correct platform totals and a
   department breakdown silently missing an entire tool:

     SELECT PLATFORM_KEY,
            COUNT_IF(PERSON_KEY LIKE 'UNRESOLVED:%') / COUNT(*) AS unresolved_rate
     FROM AI_SPEND.SHAPED.UNIFIED_AI_USAGE
     GROUP BY PLATFORM_KEY;

   Then, and only then:
     UPDATE AI_SPEND.CONTROL.PLATFORM_REGISTRY
       SET IS_ACTIVE = TRUE WHERE PLATFORM_KEY = '<platform>';
   =========================================================================== */

-- Show what is registered, what it can honestly deliver, and what is live.
SELECT
    PLATFORM_KEY,
    COST_MODEL,
    NATIVE_UNIT,
    SUPPORTS_USER_GRAIN,
    SUPPORTS_USER_COST,
    IS_ACTIVE,
    NOTES
FROM AI_SPEND.CONTROL.PLATFORM_REGISTRY
ORDER BY IS_ACTIVE DESC, SUPPORTS_USER_COST DESC, PLATFORM_KEY;
