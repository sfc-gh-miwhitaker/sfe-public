# AI Governance Workshop

Workshop teaching teams to govern AI coding tools. Links to Anthropic docs for configuration concepts (CLAUDE.md, skills, scopes). Provides original content on enterprise MDM deployment, Snowflake-specific standards, red-team testing, and operational distribution.

## Project Structure
- `README.md` -- Overview with links to Anthropic source docs + workshop entry point
- `WORKSHOP.md` -- 6-step walkthrough (~75 min) with links to source for each concept
- `prompts/` -- Step-by-step guides (CoCo-specific and enterprise content)
- `reference/` -- Templates: managed-settings, CLAUDE.md, setup scripts, MDM examples
- `docs/` -- Dual-surface deployment guide (merged from demo-coco-governance-github)
- `exercises/` -- Red-team checklist and audit worksheet

## Content Principles
- Link to Anthropic docs for hierarchy, CLAUDE.md, skills, and configuration scopes
- Original content only where gaps exist: MDM deployment, Snowflake SQL/RBAC, red-team, distribution
- managed-settings.json examples must match the official schema
- MDM examples are templates requiring customization

## When Helping with This Project
- This is a guide, not a demo -- no deploy_all.sql, no SQL objects (except the optional dual-surface lab)
- Do not duplicate Anthropic docs on CLAUDE.md structure, skills format, or configuration scopes
- Cross-reference Cortex Code CLI docs for install/connect basics

## Related Projects
- [Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) -- Install and connect (prerequisite)
- [`guide-agent-skills`](../guide-agent-skills/) -- Skills resource management framework
- [`demo-campaign-engine`](../demo-campaign-engine/) -- Hands-on workshop using GUIDED_BUILD
