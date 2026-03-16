# AI Governance Workshop

Workshop teaching teams to govern AI coding tools. Replaces "AI is magic" fear with "AI follows explicit instructions I control."

## Project Structure
- `README.md` -- Quick overview and workshop link
- `WORKSHOP.md` -- Main 6-step walkthrough (~75 min)
- `prompts/` -- Step-by-step guides for each workshop section
- `reference/` -- Templates for managed-settings, CLAUDE.md, setup scripts, MDM examples
- `diagrams/` -- Mermaid visuals for governance hierarchy and distribution
- `exercises/` -- Red-team checklist and audit worksheet

## Content Principles
- Audience is brand-new to governing AI tools (not necessarily new to using them)
- Focus on demystifying: visibility, control, testability
- Three-tier distribution model: org (MDM) → user (curl/ZIP/remote skill) → project (git/share)
- Every claim is testable — if we say a control works, show how to verify it

## When Helping with This Project
- This is a guide, not a demo -- no deploy_all.sql, no SQL objects
- Keep examples tool-agnostic where possible (CoCo, Cursor, Claude Code)
- managed-settings.json examples must match the official schema from Snowflake docs
- MDM examples should be realistic but clearly marked as templates requiring customization
- Cross-reference guide-coco-setup for install/connect basics -- don't duplicate
