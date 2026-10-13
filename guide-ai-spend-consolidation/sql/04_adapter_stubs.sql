/* Cross-platform AI spend consolidation — adapter build specifications
   Pair-programmed by SE Community + Cortex Code
   Expires: 2026-11-09

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
   worked for ONE organization and exercises the publication contract. Register
   every required feed in REPORT_REGISTRY; leave its platform inactive and task
   suspended until controlled qualification. The typed extension views in sql/06
   return no rows until replaced by qualified parsers. A registry flag is not an
   implementation.

   Every external report must publish REPORT_SNAPSHOT manifests per COMPLETE
   partition (including zero records), carry RUN_ID on every landing row, and
   write SUCCEEDED only after all files/pages/partitions have loaded and reconciled.
   Failed runs never publish partial rows. Select the latest successful partition,
   preserving ALL records within it before aggregation, not one row per person/day.
   Event feeds deduplicate on event identity and reconstruct complete partitions.
   Current keys assume one source scope per platform/report per deployment.

   COST_BASIS separates ACTIVITY_ONLY, BILLABLE_NATIVE, REPORTED_CURRENCY and UNKNOWN.
   Only qualified billable-only quantities use PLATFORM_RATE; reported currency
   bypasses rates. Missing/ambiguous rates fail closed with NULL cost and a visible
   COST_STATUS, never a $1 conversion. Currency-bearing outputs retain currency.
   Map identities at usage date and classify non-person subjects with ENTITY_KIND.
   DORMANT requires closed-month, explicit complete ACTIVITY_COVERAGE, resolved
   identity and actual billed entitlement, not a missing activity row.

   GitHub's users-1-day API returns all download_links as NDJSON, not a paged bare
   JSON user array. Signed downloads carry no API auth and only exact approved
   hosts from sql/02 and the handler allowlist. Organization seats require complete
   pagination/count reconciliation. The scheduler projects current-month seats
   using exactly one SEAT_RATE; roster estimates are not invoice actuals.
   ai_credits_used is consumption analysis, NOT invoicing.
   https://docs.github.com/en/rest/copilot/copilot-usage-metrics
   https://docs.github.com/en/copilot/reference/copilot-usage-metrics/copilot-usage-metrics

   Verify endpoint fields, permission scopes, version and billing meaning against
   official vendor documentation before implementation. Specifications below do
   not claim live integration tests.
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
     MEMBERS        workspace roster -> subjects to match to IdP/HR identity

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
-- Reuse publication, failure logging and per-statement QUERY_TAG patterns, NOT
-- GitHub-specific envelopes, watermark policy or date grain. Qualify the actual
-- billable credit quantity before BILLABLE_NATIVE; consumption alone is not cash.
-- Members supply vendor subjects, not authoritative corporate identity mappings.

/* ===========================================================================
   2. Box AI
   ===========================================================================

   GRANULARITY: dated user-level chargeable quantities; currency requires a
   qualified rate. AI Insights has agent-oriented views, but the documented CSV
   does not promise a unique agent key.
     Registry: SUPPORTS_USER_GRAIN = TRUE, SUPPORTS_USER_COST = TRUE
     Cost model: METERED, native unit AI_UNITS

   CORRECT A COMMON ASSUMPTION FIRST: Box AI has been metered in AI Units since
   2025-10-20. Anyone modelling it as bundled seat cost is describing the old model.

   THREE SURFACES, AND THEY ARE NOT INTERCHANGEABLE:

     AI Insights dashboard   AI Units by user, agent, and capability. Console only.
                             Good for a screenshot, not for a pipeline.
     AI Units Admin Report   DATED CSV export, not a monthly-only JSON endpoint.
                             Date, User, User Email, AI Capability, Product,
                             Category, AI Units. Supports Last Day/Week/Month/Year
                             and Custom Range; dashboard-card download is current
                             month only. Saved reports can be scheduled to a folder.
                             Units are not currency: qualify the contracted rate.
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

     AI_UNITS_REPORT   poll the scheduled report folder; retrieve ALL CSV pages for
                       its complete date range. Preserve the original files and
                       headers, including fractional and zero AI Units. This is
                       the quantity source to qualify first.
     AI_EVENTS         Enterprise Events API with stream_type = admin_logs, filtered
                       to AI event types. Event granularity and agent attribution,
                       but NOT the chargeable unit.

   AI_EVENTS is ACTIVITY_ONLY, with no BILLABLE_NATIVE_QTY or reported money.
   Do not price it again alongside the AI Units report. Preserve multiple events
   and product/capability/category breakdowns; deduplicate events by event ID, not
   by person/day. A zero-unit record is real non-chargeable activity, not missing
   data. Use a decimal quantity, not an integer cast.
   https://docs.box.com/en/box-admin-tools/reporting-and-insights/ai-units-report

   AUTH: Box Platform App with Client Credentials Grant. The service account needs
   the "Run new reports and access existing reports" permission -- without it the
   events endpoints fail in a way that reads like a bad token rather than a missing
   privilege. sql/02 has the secret template.

   Required fields for normalization:
     AI_UNITS_REPORT   Date, User Email, AI Units and the documented breakdowns
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
     - API file downloads return a redirect, documented with dl.boxcloud.com.
       Approve the exact HTTPS download host in sql/02 and the adapter; do not
       forward API credentials to the signed download or auto-follow other hosts.
       https://developer.box.com/guides/downloads/file
     - Preserve the export's actual dimensions. The documented CSV has a Box
       Agents capability, not a promised unique agent identifier. Agent-level
       reporting needs a separately qualified source with an agent key.
   =========================================================================== */

/* ===========================================================================
   3. Microsoft 365 Copilot
   ===========================================================================

   GRANULARITY CEILING -- READ THIS BEFORE REQUESTING A CREDENTIAL:
     Registry: SUPPORTS_USER_GRAIN = TRUE, SUPPORTS_USER_COST = FALSE
     SUPPORTS_ACTIVITY_DEPTH = TRUE; cost model SEAT, native unit PROMPTS

   Two hard limits, both structural rather than fixable in code:

   (a) IDENTITY IS PSEUDONYMIZED BY DEFAULT.
       getMicrosoft365CopilotUsageUserDetail returns HASHED values in
       userPrincipalName and displayName unless the tenant has disabled report
       concealment. The hashes are stable, so you can trend an anonymous
       individual over time -- but you CANNOT join them to a department, which is
       the whole point of the exercise.

       Confirm the setting with an Entra administrator FIRST. In some organizations
       concealment is deliberate and a privacy office will decline to change it.
       That removes corporate-person attribution unless an approved mapping is
       available; anonymous per-subject activity analysis can still be useful.
       Do not equate concealed identity with absent activity depth.

   (b) V2 HAS ACTIVITY DEPTH, BUT AT REPORT-PERIOD GRAIN.
       The default v2 report adds prompts submitted (all apps, Copilot Chat work
       and web) and active usage days, as well as last-activity dates. It covers
       licensed Microsoft 365 Copilot users, not unlicensed Copilot Chat.
       It supports period-based activity-depth analysis, not measured token cost.
       https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/api/admin-settings/reports/copilotreportroot-getmicrosoft365copilotusageuserdetail

   Preserve the report refresh date, version and period. Do not assign the entire
   D28 prompt count to one daily fact, spread it across fabricated days, or sum
   overlapping rolling reports. The current daily gold tables need a qualified
   period-aware extension; V_SHRED_M365_COPILOT is intentionally inert meanwhile.
   Seat fees remain in SEAT_ENTITLEMENT. A rolling D28 window is not proof of a
   complete calendar billing month; do not mark ACTIVITY_COVERAGE complete from it.

   AUTH: client credentials against an Entra app registration with an
   admin-consented application permission to read usage reports. Requires the
   login.microsoftonline.com token host in addition to graph.microsoft.com --
   sql/02 includes both, because omitting the token host produces an
   authentication failure that looks exactly like a bad credential.

   Suggested reports:
     USAGE_USER_DETAIL  v2 per-user prompts/active days/last activity over a period
     LICENSE_DETAIL     assigned licences -> SEAT_ENTITLEMENT

   Required fields: Report Refresh Date, User Principal Name, Report Period and
   the chosen v2 activity fields. A concealed subject remains unresolved without
   an approved mapping: normalized IDENTITY_CONFIDENCE = NONE, not invented LOW.

   Implementation notes:
     - GET /v1.0/copilot/reports/getMicrosoft365CopilotUsageUserDetail(
         period='D28', version='v2') returns a 200 CSV stream. Use a CSV parser;
       do not invent a JSON format option or @odata.nextLink pagination.
     - v2 periods: D7, D28, D90, D180, ALL. D30 belongs to v1, not v2.
       Prefer one period per report identity; ALL contains overlapping windows.
       Period-aware publication keys must distinguish window/version before use.
     - Application permission Reports.Read.All requires admin consent. Verify
       entitlement population separately from usage and retain pseudonymization
       unless an approved privacy decision authorizes corporate identity joins.
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

   Analytics and Console Admin key types are not interchangeable. Console usage
   and cost reports have different grouping dimensions; do not assume cost is
   available at every usage dimension. The separate Claude Code Analytics API
   reports per-user estimated costs, not a measured general per-user API bill.

   Keep billing scopes separate. Reconcile Enterprise per-user values against
   Enterprise organization totals from the Analytics API, not Console billing.
   Enterprise parent organizations do not appear in Console and have no Console
   Admin API keys. Ingest Console only for a separately identified API scope.
   Do not add organization totals to their per-user breakdowns in the same fact.
   https://platform.claude.com/docs/en/manage-claude/usage-cost-api

   THE OPERATIONAL FACT THAT DICTATES THE LOAD PATTERN:
     Cost/usage may revise until about SEVEN DAYS AFTER CALENDAR MONTH-END.
     October 1 can change through about November 7; rolling 30 days is inadequate.
     Reload every open month until settlement, partitioning requests to the
     endpoint range limit. For invoicing-grade comparison, use months ended at
     least seven days ago and reconcile to the finance statement.
     Preserve data_refreshed_at and bound ending_at at or before a previously
     returned value to exclude the incomplete tail.
     https://platform.claude.com/docs/en/manage-claude/analytics-api

   Plan qualification is mandatory: cost/usage endpoints represent monetary
   amounts on usage-based Enterprise plans, but usage credits on seat-based
   Enterprise plans. Never label the latter billed currency. Keep effective and
   list cost distinct; use qualified reported amounts plus explicit currency,
   not one token rate across models, products and cost types.

   Also hard-limiting: NO DATA EXISTS BEFORE 2026-01-01 on the Analytics API. There
   is no backfill conversation to have. A Snowflake-side accumulator is the history.

   Suggested reports:
     USER_COST      per-user cost. Returns BOTH effective and list amounts -- keep
                    both, because the gap between them is the discount and someone
                    will eventually ask to see it.
     USER_USAGE     per-user tokens
     USER_ACTIVITY  per-user per-product activity -> engagement tiers
     ORG_COST       Enterprise organization totals -> reconciliation, not additive
     MEMBERS        roster -> vendor subjects to match to IdP/HR

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
     - Enterprise Analytics defaults to 60 requests per minute per organization,
       shared across its endpoints. Respect each endpoint's range/page limits;
       do not transfer Console limits or credentials to Enterprise Analytics.
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

   DO NOT SEED PLATFORM_RATE FOR REPORTED CURRENCY. Cursor is not the only source
   of currency: qualified Claude cost and Cloud Billing amounts also bypass rates.
   Cast documented decimal cents / 100 in shredding, retaining currency and the
   billable-only meaning. Activity counters and total consumption do not qualify
   as overage simply because a platform is METERED.

   THREE ENDPOINTS, THREE JOBS:
     members             email <-> user id and role. Match to approved IdP/HR.
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
     - Verify endpoint entitlement, credential scope and billing fields against
       current vendor documentation and the actual plan before activating.
       https://cursor.com/docs/account/teams/admin-api
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

   PRIVACY FILTER BEFORE LANDING, NOT LATER IN SQL:
     resource.type = cloudaicompanion.googleapis.com/Instance
     labels.product = code_assist
     jsonPayload.@type =
       type.googleapis.com/google.cloud.cloudaicompanion.logging.v1.MetadataLog
     logName = approved project log ending
       cloudaicompanion.googleapis.com%2Fmetadata
   Require both the MetadataLog type AND metadata logName, plus product. RequestLog
   and ResponseLog streams contain prompts, responses and source-file context.
   A product-only filter violates this pipeline's no-content boundary. Apply the
   filter to retrieval/export and assert it again before staging every record;
   reject unexpected types without persisting their bodies. Derive activity from
   the qualified metadata event kinds, not a count of all log entries.
   https://docs.cloud.google.com/gemini/docs/log-gemini

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

   QUALIFICATION -- Keep the task suspended. After registering required reports
   and implementing the parser, activate the platform only in a qualification
   environment for controlled pulls: inactive platforms do not publish facts.
   Check complete/empty snapshots, pricing, coverage, and unresolved identity:

     SELECT PLATFORM_KEY, ENTITY_KIND, CURRENCY_CODE, UNRESOLVED_PCT, UNPRICED_ROWS
     FROM AI_SPEND.SHAPED.V_IDENTITY_QUALITY;

   Then approve scheduled operation. Use V_REPORT_HEALTH for each required report
   and V_PIPELINE_HEALTH for fact health. Do not count a registered but unimplemented
   parser as healthy, and never use absence of usage to establish DORMANT.
   =========================================================================== */

-- Show what is registered, what it can honestly deliver, and what is live.
SELECT
    PLATFORM_KEY,
    COST_MODEL,
    NATIVE_UNIT,
    SUPPORTS_USER_GRAIN,
    SUPPORTS_USER_COST,
    SUPPORTS_ACTIVITY_DEPTH,
    IS_ACTIVE,
    NOTES
FROM AI_SPEND.CONTROL.PLATFORM_REGISTRY
ORDER BY IS_ACTIVE DESC, SUPPORTS_USER_COST DESC, PLATFORM_KEY;
