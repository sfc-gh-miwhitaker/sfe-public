# Agent Skills Resource Management Guide

Opinionated guide to managing AI agent extensibility as a resource allocation problem. Frames context window as a finite budget and provides a decision framework for skills, rules, MCP servers, and subagents.

## Project Structure
- `README.md` -- Main guide (4 parts: Context Is the Currency, Right Tool for the Job, Pulling Skills, Keeping It Lean)
- `diagrams/right-tool.md` -- Mermaid decision-tree for choosing the right extensibility mechanism

## Content Principles
- Original content only -- does not re-document skill repos or installation commands already covered elsewhere
- Client-agnostic: CoCo, Cursor, Claude Code treated equally
- Resource management framing: every decision is a budget allocation tradeoff
- Cross-references guide-coco-setup for hierarchy details and guide-coco-governance-general for org controls

## When Helping with This Project
- This is a guide, not a demo -- no SQL objects, no deploy_all.sql, no expiration dates
- Do not add a catalog of skill repos -- that's what GitHub search and VoltAgent's directory are for
- Keep the resource management framing consistent: context window as currency, not "tips and tricks"
- Mermaid diagrams follow the conventions in `~/.claude/skills/architecture-diagrams/SKILL.md`
- Compatibility claims must be accurate to current client behavior (verify before stating)
