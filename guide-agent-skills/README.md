![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Status](https://img.shields.io/badge/Status-Active-success)

# Agent Skills: Right Tool, Right Budget

Inspired by the question every AI-pair user hits after week two: *"I installed a bunch of skills and now the agent feels slower and less focused -- what did I do wrong?"*

An opinionated guide to managing AI agent extensibility -- skills, rules, MCP servers, subagents -- as a resource allocation problem. The core insight: every always-on file is a permanent line item in your context budget. This guide teaches you what to load, where to put it, and when to let go.

**Author:** SE Community
**Read time:** ~12 minutes | **Result:** A mental model for context budget management

> **No support provided.** This content is for reference only. Review and validate before applying to any production workflow.

---

## Who This Is For

Anyone using AI pair-programming tools who has hit one of these walls:

- Installed a bunch of skills and the agent feels slower or less focused
- Standards drift between sessions because the AI "forgets" your rules
- Unsure whether something belongs in CLAUDE.md, AGENTS.md, a skill, or an MCP server

**New to AI pair-programming?** Start with the [setup guide](../guide-coco-setup/) to install Cortex Code and understand the guidance hierarchy.

---

## The Approach

### Part 1: Context Is the Currency

Every AI coding agent has a fixed token budget. Your conversation, the files it reads, the rules it loads, the skills it activates -- all draw from the same pool.

| Source | When It Loads | Budget Impact |
|--------|--------------|---------------|
| `~/.claude/CLAUDE.md` | Every session, every project | Permanent -- survives compaction |
| `AGENTS.md` | Every session in that project | Permanent per-project |
| Skill (`SKILL.md`) | On-demand when triggered | Temporary -- but large skills are large withdrawals |
| MCP server | On tool call | Minimal (schema loads once) |
| Conversation history | Accumulates | Largest consumer -- compacted automatically |

> [!TIP]
> **Core insight:** Put non-negotiable rules in CLAUDE.md (they survive compaction). Put procedures in skills (they reload on demand). Don't put procedures in CLAUDE.md -- they'll survive but permanently consume budget.

### Part 2: Right Tool for the Job

Five extensibility mechanisms, each with a different cost model:

| Need | Use | Cost Model |
|------|-----|------------|
| Every session, every project | `~/.claude/CLAUDE.md` | Permanent budget, survives compaction |
| Every session, one project | `AGENTS.md` | Permanent while in project |
| Multi-step procedure sometimes | Skill (`.claude/skills/`) | Loads on demand |
| Live data from external system | MCP server | Schema once, data per call |
| Parallel isolated work | Subagent | Separate context window |

### Part 3: Pulling Skills Into Any Client

The `.claude/skills/` directory is the universal skill format. Same file works across Cortex Code, Cursor, and Claude Code.

```
.claude/skills/<name>/SKILL.md      # Project-level (travels with repo)
~/.claude/skills/<name>/SKILL.md    # User-level (available everywhere)
```

**Scope escalation ladder:** Session (test) -> Project (useful) -> User (proven across 3+ projects).

### Part 4: Keeping Your Toolkit Lean

- **One skill, one job.** Over 200 lines? Split it or use progressive disclosure with a `references/` subdirectory.
- **The pruning signal.** If you can't remember the last time a skill fired and helped, remove it.
- **The description is the gatekeeper.** Precise trigger conditions ("Use when reviewing SQL for quality violations") beat vague descriptions ("Helps with coding").

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
| Cortex Code Extensibility | https://docs.snowflake.com/en/user-guide/cortex-code/extensibility |
| Skill Specification | https://agentskills.io/specification |
| Anthropic Official Skills | https://github.com/anthropics/skills |
| Setup Guide (prerequisite) | [guide-coco-setup](../guide-coco-setup/) |
| Governance Workshop | [guide-coco-governance-general](../guide-coco-governance-general/) |
