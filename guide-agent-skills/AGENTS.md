# Agent Skills Resource Management Guide

Slim guide framing AI agent extensibility as a resource allocation problem. Links to Anthropic docs for skill format, CLAUDE.md, and configuration scopes. Provides original content on the resource mental model and common misplacements.

## Project Structure
- `README.md` -- Main guide (links to Anthropic source + resource mental model + misplacements table)
- `diagrams/right-tool.md` -- Mermaid decision-tree for choosing the right extensibility mechanism

## Content Principles
- Link to Anthropic docs for skill format, CLAUDE.md structure, and settings scopes
- Original content only: resource mental model and common misplacements
- Client-agnostic: CoCo, Cursor, Claude Code treated equally

## When Helping with This Project
- This is a guide, not a demo -- no SQL objects, no deploy_all.sql
- Do not duplicate Anthropic docs on skill format, CLAUDE.md, or configuration scopes
- Keep the resource management framing consistent

## Related Projects
- [Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) -- Install and connect (prerequisite)
- [`guide-coco-governance-general`](../guide-coco-governance-general/) -- Org-level AI coding governance
