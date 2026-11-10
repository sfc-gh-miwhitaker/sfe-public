---
name: guide-strong-auth-network-policies
description: "Maintain the admin guide that builds per-user network policies from LOGIN_HISTORY so service users can move off passwords (PAT network policy requirement) before strong authentication enforcement."
---

# Strong Auth Network Policies Guide

Pair-programmed by SE Community + Cortex Code

## Purpose

Give an administrator facing the single-factor password deprecation a tested,
read-first path from sign-in history to one reviewed network policy per
service user, then a migration order that isolates failures.

## Architecture

LOGIN_HISTORY + USERS + POLICY_REFERENCES -> 01 at-risk users -> 02 per-user
IP inventory with review flags -> 03 draft DDL (STABLE/REVIEW only) plus
RECOMMEND/EVALUATE calls -> 04 runbook: inspect, dry run, attach user policy,
canary, PAT/key pair, TYPE=SERVICE, verify -> 05 monitor (390422 blocks, PAT
expiry, unprotected service users).

## Key Files

| File | Role |
| --- | --- |
| `README.md` | Decision table, ordered steps, gotchas |
| `ELI5.md` | Plain-language version |
| `sql/01..03, 05` | Read-only analysis and generated SQL text |
| `sql/00, 04, 99` | Practice user, per-user runbook, teardown |
| `tests/test_guide.py` | Documentation and SQL invariants |

## Extension Playbook

1. Re-read security-mfa-rollout, strong-authentication-hub,
   network-policy-advisor, programmatic-access-tokens, network-policies.
2. Check phase dates and whether new procedures or columns exist.
3. Change SQL, run 01, 02, 03, 05 against mwhitaker_aws, then 00, 04, 99,
   then 00 and 99 a second time (idempotency).
4. Run tests and `expire-projects.py --check`.

## Snowflake Objects

Practice only: SFE_NETPOL_PRACTICE_ROLE, SFE_NETPOL_PRACTICE_SVC,
SNOWFLAKE_EXAMPLE.SFE_NETPOL_PRACTICE (rule SFE_NETPOL_PRACTICE_SVC_INGRESS),
policy SFE_NETPOL_PRACTICE_SVC_NETWORK_POLICY.

## Gotchas

- Sign-ins from the test workstation are recorded with CLIENT_IP 0.0.0.0
  (internal), so network policies never block them; a user policy that
  excluded the address still allowed the PAT (verified 2026-11-10). Do not
  claim tested blocking behavior; external blocks show as 390422
  INCOMING_REQUEST_BLOCKED in the same account's history.
- RECOMMEND_NETWORK_POLICY output always names RECOMMENDED_INGRESS_NETWORK_RULE
  / _POLICY with CREATE OR REPLACE, unqualified, and includes every address
  with a successful sign-in (6 proposed vs 1 STABLE in testing).
- CREATE OR REPLACE NETWORK RULE fails with 098509 while a policy references
  it; use ALTER NETWORK RULE SET VALUE_LIST.
- EXECUTE IMMEDIATE rejects a string expression; SET a variable first.
- QUALIFY without a window function fails; filter in an outer query.
- Temp tables need a current database; use CTEs in read-only scripts.
- IDENTIFIER($var) works for ALTER/DESCRIBE/SHOW ... IN USER; SET
  NETWORK_POLICY = $var works; PAT ROLE_RESTRICTION needs a literal.
- Observed FIRST_AUTHENTICATION_FACTOR values: PASSWORD, RSA_KEYPAIR,
  PROGRAMMATIC_ACCESS_TOKEN, OAUTH_ACCESS_TOKEN, WORKLOAD_IDENTITY.
