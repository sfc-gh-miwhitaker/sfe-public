<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

# Strong Auth Network Policies Guide

Pair-programmed by SE Community + Cortex Code

## Architecture

README is an administrator's ordered path for the single-factor password
deprecation: decide the credential per service user, find at-risk users,
inventory client IPs from LOGIN_HISTORY, draft one network rule and policy per
service user, dry run with EVALUATE_CANDIDATE_NETWORK_POLICY, attach, canary,
issue a PAT or key pair, cut over to TYPE=SERVICE, monitor. Scripts 01, 02,
03, and 05 are read-only. 00 and 99 create and remove practice objects. 04 is
the per-user runbook and defaults to the practice user.

## Snowflake Environment

Test account only (`sfsenorthamerica-mwhitaker_aws`), never Snowhouse.
Practice objects: role SFE_NETPOL_PRACTICE_ROLE, user SFE_NETPOL_PRACTICE_SVC,
schema SNOWFLAKE_EXAMPLE.SFE_NETPOL_PRACTICE, network policy
SFE_NETPOL_PRACTICE_SVC_NETWORK_POLICY.

## Conventions

- Read-only scripts use CTEs, never temporary tables, so they need no current
  database and create nothing.
- Never put a real IP address, user, or account in committed files; generated
  output stays in the reader's worksheet.
- Blocking behavior is stated from documentation; see the SKILL Gotchas for
  why the test workstation cannot exercise it.
- README owns the review date; ELI5 and SQL headers mirror it.

## Key Commands

```bash
python3 -m unittest discover -s guide-strong-auth-network-policies/tests -v
snow sql -c sfsenorthamerica-mwhitaker_aws -f guide-strong-auth-network-policies/sql/01_find_at_risk_users.sql
python3 .github/scripts/expire-projects.py --check
```

Read `.claude/skills/guide-strong-auth-network-policies/SKILL.md` before extending.
