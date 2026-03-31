# Cortex Code CLI Onboarding Guide

Curated on-ramp for AI pair-programming with Cortex Code CLI. Links to Anthropic and Snowflake docs for configuration concepts; provides original content only where Cortex Code differs from Claude Code.

## Project Structure
- `README.md` -- Main guide (4 parts: download, install links, hierarchy delta, first Snowflake skill)
- `reference/first-skill/` -- Template skill with Snowflake SQL standards (`{PLACEHOLDER}` values)
- `reference/claudemd-snippet.md` -- Template for ~/.claude/CLAUDE.md with Snowflake-specific rules
- `diagrams/guidance-hierarchy.md` -- CoCo-specific paths that extend the Claude Code model

## Content Principles
- Link to Anthropic docs for hierarchy, CLAUDE.md, skills format, and settings concepts
- Link to Snowflake docs for install, CLI reference, and extensibility
- Original content only where Cortex Code adds to or differs from Claude Code
- Template approach: `{PLACEHOLDER}` patterns users customize

## When Helping with This Project
- This is a guide, not a demo -- no SQL objects, no deploy_all.sql
- Do not duplicate Anthropic docs on CLAUDE.md structure, skills format, or configuration scopes
- Do not duplicate Snowflake docs on install, CLI commands, or workflows
- The first-skill SKILL.md in `reference/` must use `{PLACEHOLDER}` values

## Related Projects
- [`demo-campaign-engine`](../demo-campaign-engine/) -- Hands-on agent-building workshop (GUIDED_BUILD -- best next step)
- [`guide-agent-skills`](../guide-agent-skills/) -- Skills architecture after learning the basics
- [`guide-coco-governance-general`](../guide-coco-governance-general/) -- AI coding governance for teams
