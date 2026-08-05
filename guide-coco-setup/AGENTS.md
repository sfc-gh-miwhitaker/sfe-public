# Cortex Code Setup Guide

Curated on-ramp for AI pair-programming with Cortex Code (Desktop and CLI). Links to Snowflake and Anthropic docs for configuration concepts; provides original content only where Cortex Code differs from Claude Code.

## Project Structure
- `README.md` -- Main guide (4 parts: install, hierarchy, first skill, what's next)
- `reference/first-skill/` -- Template skill with Snowflake SQL standards (`{PLACEHOLDER}` values)
- `reference/claudemd-snippet.md` -- Template for ~/.claude/CLAUDE.md with Snowflake-specific rules
- `diagrams/guidance-hierarchy.md` -- CoCo-specific paths that extend the Claude Code model

## Content Principles
- Link to Snowflake docs for install, Desktop onboarding, CLI reference, and extensibility
- Link to Anthropic docs for hierarchy, CLAUDE.md, skills format, and settings concepts
- Original content only where Cortex Code adds to or differs from Claude Code
- Template approach: `{PLACEHOLDER}` patterns users customize

## When Helping with This Project
- This is a guide, not a demo -- no SQL objects, no deploy_all.sql
- Do not duplicate Anthropic docs on CLAUDE.md structure, skills format, or configuration scopes
- Do not duplicate Snowflake docs on install, CLI commands, or Desktop UI walkthrough
- The first-skill SKILL.md in `reference/` must use `{PLACEHOLDER}` values
- CoCo Desktop is the primary surface; CLI is the secondary path
- Do not link to sibling guides in this repo -- use docs.snowflake.com links instead
