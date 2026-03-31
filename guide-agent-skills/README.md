![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Status](https://img.shields.io/badge/Status-Active-success)

# Agent Skills: Right Tool, Right Budget

Inspired by the question every AI-pair user hits after week two: *"I installed a bunch of skills and now the agent feels slower and less focused -- what did I do wrong?"*

**Author:** SE Community
**Read time:** ~5 minutes | **Result:** A mental model for context budget management

> **No support provided.** This content is for reference only. Review and validate before applying to any production workflow.

---

## Who This Is For

Anyone using AI pair-programming tools who has hit one of these walls:

- Installed a bunch of skills and the agent feels slower or less focused
- Standards drift between sessions because the AI "forgets" your rules
- Unsure whether something belongs in CLAUDE.md, AGENTS.md, a skill, or an MCP server

**New to AI pair-programming?** Install [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli), [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), or [Cursor](https://www.cursor.com/) first.

---

## Read the Source First

Anthropic's documentation covers the core concepts this guide used to explain in detail:

- **[Claude Code Memory (CLAUDE.md)](https://docs.anthropic.com/en/docs/claude-code/memory)** -- How CLAUDE.md files work, where to put them, how to write effective instructions, and how context loading works
- **[Claude Code Skills](https://docs.anthropic.com/en/docs/claude-code/skills)** -- Skill format, creation, sharing, invocation control, progressive disclosure with `references/`, and bundled skills
- **[Claude Code Settings](https://docs.anthropic.com/en/docs/claude-code/settings)** -- Configuration scopes (managed, user, project, local) and how they interact

These apply directly to Cortex Code, Cursor, and Claude Code. The rest of this guide covers what those docs don't: the **resource allocation mental model** and **common misplacements**.

---

## The Resource Mental Model

Every AI coding agent has a fixed token budget. Your conversation, the files it reads, the rules it loads, the skills it activates -- all draw from the same pool.

**Always-on files** (`CLAUDE.md`, `AGENTS.md`) survive context compaction and permanently consume budget. Put non-negotiable rules here -- but keep them lean.

**On-demand extensions** (skills, MCP tools) load when triggered and release after use. Put multi-step procedures here, not in CLAUDE.md.

**Subagents** get a separate context window entirely. Use for parallel, isolated work.

See [diagrams/right-tool.md](diagrams/right-tool.md) for the visual decision tree.

---

## Common Misplacements

| Symptom | What's Wrong | Fix |
|---------|-------------|-----|
| CLAUDE.md is 500+ lines | Procedures crammed into always-on rules | Extract procedures into skills |
| Agent "forgets" conventions mid-session | Conventions are in conversation, not a file | Move to AGENTS.md |
| Skill fires but agent ignores half the steps | Skill is 400 lines | Split into focused skill + `references/` |
| Agent loads a skill you never use | Description is too broad | Narrow the `description` field |

---

## References

| Resource | URL |
|----------|-----|
| Claude Code Memory (CLAUDE.md) | https://docs.anthropic.com/en/docs/claude-code/memory |
| Claude Code Skills | https://docs.anthropic.com/en/docs/claude-code/skills |
| Claude Code Settings | https://docs.anthropic.com/en/docs/claude-code/settings |
| Cortex Code Extensibility | https://docs.snowflake.com/en/user-guide/cortex-code/extensibility |
| Agent Skills Specification | https://agentskills.io/specification |
| Cortex Code CLI | https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli |
| Governance Workshop | [guide-coco-governance-general](../guide-coco-governance-general/) |
