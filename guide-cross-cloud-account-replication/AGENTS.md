<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

# Cross-Cloud Account Replication Guide

Pair-programmed by SE Community + Cortex Code

## Architecture

README is the admin's ordered five-step path. One failover group (all replicable
object types, every eligible database generated at run time) plus one
client-redirect connection. `01` is read-only; `02` needs the org admin; `03`
runs on the AWS source; `04` and `05` run on the Azure target. Cutover is
commented out in `05`.

## Snowflake Environment

No deployed objects in this repo's test account. The scripts target the
reader's own source and new Azure account.

## Conventions

- Fewest steps is the design goal: one group, one connection, no manual REFRESH.
- Generate account-specific values (database list, org name); never ask the
  reader to type them. Credentials stay as visible placeholders.
- Every unsupported or post-replication fix-up lives in the README table.
- README owns the review date; ELI5 mirrors README.

## Key Commands

```bash
python3 -m unittest discover -s guide-cross-cloud-account-replication/tests -v
python3 .github/scripts/expire-projects.py --check
```

Read `.claude/skills/guide-cross-cloud-account-replication/SKILL.md` before extending.
