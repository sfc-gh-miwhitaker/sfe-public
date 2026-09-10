/* Cross-platform AI spend consolidation — adapter build specifications
   Pair-programmed by SE Community + Cortex Code
   Expires: 2027-03-10

   ChatGPT Enterprise, Box AI, and Microsoft 365 Copilot.

   These are SPECIFICATIONS, not implementations, and that is a design decision
   rather than an omission.

   Every vendor here changed a relevant endpoint during 2026: GitHub retired its
   legacy Copilot metrics API in April, OpenAI removed a conversation log route in
   June, and Box switched Box AI to metered AI Units in October 2025 with the
   per-user report arriving mid-2026. Five hand-maintained connectors would be
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
