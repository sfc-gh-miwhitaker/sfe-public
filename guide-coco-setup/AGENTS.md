# Cortex Code CLI Onboarding Guide

Curated on-ramp for AI pair-programming with Cortex Code CLI. Links to official resources for install/connect/commands, then provides original content on the guidance hierarchy, AGENTS.md for beginners, and building a first custom skill.

## Project Structure
- `README.md` -- Main guide (single walkthrough, 4 parts)
- `reference/first-skill/SKILL.md` -- Copy-paste-ready team-standards skill example
- `diagrams/guidance-hierarchy.md` -- Mermaid diagram of CoCo's context lookup order

## Content Principles
- Curate, don't rewrite: link to official docs for install/connect/commands
- Original content only where gaps exist: guidance hierarchy, AGENTS.md concept, CoCo+Cursor interplay, operational best practices
- Audience is brand-new to AI pair-programming
- Tone is direct and practical, matching `demo-campaign-engine/GUIDED_BUILD.md`

## When Helping with This Project
- This is a guide, not a demo -- no SQL objects, no deploy_all.sql, no expiration dates
- All external links should point to official Snowflake docs or Snowflake Builders Blog posts
- The first-skill SKILL.md in `reference/` must be copy-paste ready (no placeholders)
- Keep the guidance hierarchy accurate to the extensibility docs: managed settings > user-level > project-level > session > bundled
- Mermaid diagrams follow the conventions in `~/.claude/skills/architecture-diagrams/SKILL.md`
