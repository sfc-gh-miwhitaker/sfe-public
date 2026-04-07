# Workshop Overview

## Learning Objectives

By the end of this workshop, you will:

1. **Inspect the CoCo-specific configuration extensions** beyond the Claude Code base model
2. **Create org-level policy** -- managed-settings.json deployed via MDM
3. **Build Snowflake-specific user standards** -- CLAUDE.md + team skill
4. **Add project constraints** -- AGENTS.md guardrails with Snowflake RBAC
5. **Test your controls** -- red team exercise proving governance works
6. **Document distribution** -- operational playbook for onboarding

## Prerequisites

| Requirement | Why |
|-------------|-----|
| Cortex Code CLI installed | Required for all exercises |
| Snowflake account access | Testing SQL governance rules |
| Admin access on your machine | Creating managed-settings.json |
| Read [Claude Code Settings](https://docs.anthropic.com/en/docs/claude-code/settings) | Base hierarchy and scopes |
| ~75 minutes | Focused workshop time |

**New to Cortex Code?** [Install the CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) first.

## What This Workshop Is NOT

- **Not an explanation of CLAUDE.md, skills, or configuration scopes** -- [read the Anthropic docs](https://docs.anthropic.com/en/docs/claude-code/overview) for those concepts
- **Not a Cortex Code tutorial** -- assumes you can already use CoCo
- **Not production-ready** -- templates require customization for your org

## What This Workshop IS

Content the official docs don't cover:
- Enterprise MDM deployment (Intune, Jamf, Ansible) of managed-settings.json
- Snowflake-specific SQL standards and RBAC constraints
- Red-team testing methodology for AI governance layers
- Operational distribution playbooks for teams
- Dual-surface enforcement patterns (CLI + Snowsight)

## Time Breakdown

| Step | Activity | Time |
|------|----------|------|
| 1 | Visibility -- CoCo-specific paths | 10 min |
| 2 | Org Policy -- managed-settings.json + MDM | 15 min |
| 3 | User Standards -- Snowflake CLAUDE.md + skill | 15 min |
| 4 | Project Scope -- AGENTS.md with Snowflake RBAC | 10 min |
| 5 | Assurance -- red team exercise | 15 min |
| 6 | Distribution -- operational playbook | 10 min |
| **Total** | | **~75 min** |
