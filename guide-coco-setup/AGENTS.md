# Cortex Code CLI Onboarding Guide

Curated on-ramp for AI pair-programming with Cortex Code CLI. Links to official resources for install/connect/commands, then provides original content on the guidance hierarchy, AGENTS.md for beginners, and building a first custom skill.

## Project Structure
- `README.md` -- Main guide (single walkthrough, 4 parts + troubleshooting)
- `reference/first-skill/SKILL.md` -- Procedural team-standards skill (review workflow)
- `reference/first-skill/references/standards.md` -- Detailed standards reference (loaded on demand via progressive disclosure)
- `reference/claudemd-snippet.md` -- Template for ~/.claude/CLAUDE.md (always-on standards)
- `diagrams/guidance-hierarchy.md` -- Mermaid diagram of CoCo's context lookup order

## Content Principles
- Curate, don't rewrite: link to official docs for install/connect/commands
- Original content only where gaps exist: guidance hierarchy, AGENTS.md concept, CoCo+Cursor interplay, operational best practices
- Audience is brand-new to AI pair-programming
- Tone is direct and practical, matching `demo-campaign-engine/GUIDED_BUILD.md`
- Template approach: use `{PLACEHOLDER}` patterns users customize, not opinionated prefixes

## When Helping with This Project
- This is a guide, not a demo -- no SQL objects, no deploy_all.sql, no expiration dates
- All external links should point to official Snowflake docs or Snowflake Builders Blog posts
- The first-skill SKILL.md in `reference/` must be a fill-in-the-blank template with `{PLACEHOLDER}` values
- Keep the guidance hierarchy accurate to the extensibility docs: managed settings > user-level > project-level > session > bundled
- Mermaid diagrams follow the conventions in `~/.claude/skills/architecture-diagrams/SKILL.md`
- Keep React-focused examples; do not add Streamlit alternatives
