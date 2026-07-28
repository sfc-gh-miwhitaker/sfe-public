/*=============================================================================
  Multi-Party Clean Rooms — Collaboration API

  Status: GA (April 2026)
  Docs:   https://docs.snowflake.com/en/user-guide/cleanrooms/v2/v2-api-reference

  What this does:
    Replaces the legacy 2-party provider/consumer model with fully symmetric,
    N-party collaboration. Any participant can provide data, contribute logic,
    or run analysis.

  Key change from legacy:
    - Legacy: fixed provider (owns data) + consumer (runs analysis)
    - New: owner orchestrates, but roles are flexible per-party

  Timeline:
    - Apr 2026: Collaboration API GA
    - Oct 2026: No new legacy clean rooms via UI
    - Migration tool available for converting legacy rooms

  Full reference (do not duplicate here):
    https://docs.snowflake.com/en/user-guide/cleanrooms/v2/v2-api-reference
=============================================================================*/

-------------------------------------------------------------------------------
-- Example: 3-party campaign measurement
--
-- Parties:
--   advertiser_acct (owner + analysis runner)
--   publisher_acct  (data provider — impressions)
--   identity_partner (data provider — identity graph)
--
-- The advertiser wants to measure campaign overlap using the publisher's
-- impression data joined via the identity partner's graph.
-------------------------------------------------------------------------------

-- Run this in the OWNER's account (advertiser_acct):

CALL SAMOOHA_BY_SNOWFLAKE_LOCAL_DB.COLLABORATION.INITIALIZE(
$$
api_version: 2.0.0
spec_type: collaboration
name: campaign_measurement_q2
owner: advertiser_acct
collaborator_identifier_aliases:
  advertiser_acct: org1.acct1
  publisher_acct: org2.acct2
  identity_partner: org3.acct3
analysis_runners:
  advertiser_acct:
data_providers:
  publisher_acct:
  identity_partner:
data_offerings:
  - id: publisher_impressions_v1
  - id: identity_graph_v1
templates:
  - id: campaign_overlap_template_v1
$$,
'ANALYSIS_WH'
);

-------------------------------------------------------------------------------
-- Architecture notes:
--
-- 1. Each party installs the Snowflake Data Clean Rooms native app
-- 2. The INITIALIZE call creates the collaboration definition
-- 3. Each data provider links their data offering to the collaboration
-- 4. The analysis runner executes approved templates
-- 5. Results are returned without exposing raw PII
--
-- Key capabilities:
--   - Any party can be both a data provider AND analysis runner
--   - Templates define allowed computations (overlap, attribution, etc.)
--   - Fine-grained data access controls per party
--   - Full audit trail of all operations
--
-- For full setup including data offerings, templates, and execution:
--   https://docs.snowflake.com/en/user-guide/cleanrooms/v2/v2-api-reference
--
-- For migration from legacy clean rooms:
--   https://docs.snowflake.com/en/user-guide/cleanrooms/getting-started
-------------------------------------------------------------------------------
