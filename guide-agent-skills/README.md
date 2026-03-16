# Agent Skills: Right Tool, Right Budget

> [!CAUTION]
> **No support provided.** This content is for reference only. Review and validate before applying to any production workflow.

An opinionated guide to managing AI agent extensibility -- skills, rules, MCP servers, subagents -- as a resource allocation problem. Works with Cortex Code, Cursor, Claude Code, or any client that reads the `.claude/skills/` convention.

**Read time:** ~12 minutes | **Result:** A mental model for what to load, where to put it, and when to let go

## Who This Is For

Anyone using AI pair-programming tools who has hit one of these walls:

- Installed a bunch of skills and the agent feels slower or less focused
- Standards drift between sessions because the AI "forgets" your rules
- Unsure whether something belongs in CLAUDE.md, AGENTS.md, a skill, or an MCP server
- Want to share a capability with teammates who use a different client

**New to AI pair-programming?** Start with the [setup guide](../guide-coco-setup/) to install Cortex Code and understand the guidance hierarchy. This guide assumes you know what skills and AGENTS.md are.

---

## Part 1: Context Is the Currency

Every AI coding agent has a context window -- a fixed budget of tokens it can hold in working memory at once. Your conversation, the files it reads, the rules it loads, the skills it activates -- all of it draws from the same pool. When the pool fills, the agent compacts: it summarizes older content to make room, and summaries lose detail.

This means every file you make "always-on" is a permanent line item in your budget. Every skill that fires is a withdrawal. The question isn't "is this useful?" -- it's "is this useful enough to justify what it displaces?"

### What Consumes Budget

| Source | When It Loads | Budget Impact |
|--------|--------------|---------------|
| `~/.claude/CLAUDE.md` | Every session, every project | Permanent -- survives compaction (re-injected from system prompt) |
| `AGENTS.md` | Every session in that project | Permanent per-project |
| Skill (`SKILL.md`) | On-demand when triggered | Temporary -- but a 300-line skill is a large withdrawal |
| MCP server | On tool call | Minimal (schema loads once; data streams per call) |
| Conversation history | Accumulates | Largest consumer -- compacted automatically |

### What Survives Compaction

When context fills up, the agent summarizes to free space. Not everything survives equally:

1. **System prompt** (CLAUDE.md, managed settings) -- re-injected in full after compaction. Your most durable layer.
2. **Recent conversation** -- preserved in detail.
3. **Earlier conversation** -- summarized. Specific column names, exact error messages, and nuanced instructions degrade here.
4. **Skill content** -- if a skill was loaded 2,000 tokens ago and compaction hits, the procedure details get summarized. The skill file still exists on disk, but the agent's memory of it is now a summary.

The practical takeaway: put non-negotiable rules in CLAUDE.md (they survive). Put procedures in skills (they reload on demand). Don't put procedures in CLAUDE.md -- they'll survive compaction but permanently consume budget even when you don't need them.

---

## Part 2: Right Tool for the Job

Five extensibility mechanisms exist, each with a different cost model. The [decision diagram](diagrams/right-tool.md) visualizes this as a flowchart; here's the logic:

### The Decision Framework

**Need it every session, in every project?**
Use `~/.claude/CLAUDE.md`. This is your global always-on layer. SQL standards, security rules, naming conventions -- things that apply regardless of what you're building. Cost: permanent budget allocation, but survives compaction, so the cost is justified for true invariants.

**Need it every session, but only in one project?**
Use `AGENTS.md` at the project root. Database names, schema conventions, domain vocabulary, project-specific guardrails. Cost: permanent while working in that project, zero in every other project.

**Need a multi-step procedure sometimes?**
Use a skill (`.claude/skills/<name>/SKILL.md`). Review workflows, build checklists, data ingestion patterns, report generation. The agent reads the description in YAML frontmatter on every message to decide whether to activate -- but only loads the full body when it matches. Cost: trivial evaluation overhead per message, meaningful budget only when activated.

**Need live data from an external system?**
Use an MCP server. GitHub issues, Jira tickets, database queries, API calls. MCP tools load their schema once and stream data per call -- they don't bloat the context with static instructions. Cost: schema occupies a small permanent footprint; actual data loads on demand.

**Need parallel isolated work?**
Use a subagent. Code review while tests run. Exploration of two different directories simultaneously. Each subagent gets its own context window -- it doesn't compete with your main session. Cost: separate billing, but zero impact on your primary context.

### Common Misplacements

| Symptom | What's Wrong | Fix |
|---------|-------------|-----|
| CLAUDE.md is 500+ lines | Procedures crammed into always-on rules | Extract procedures into skills; keep CLAUDE.md to reference rules only |
| Agent "forgets" project conventions mid-session | Conventions are in conversation, not in a file | Move to AGENTS.md (survives compaction) |
| Skill fires but agent ignores half the steps | Skill is 400 lines; agent summarized it | Split into focused skill + `references/` subdirectory |
| Agent loads a skill you never use | Description is too broad ("Use when writing code") | Narrow the `description` field to specific trigger conditions |

---

## Part 3: Pulling Skills Into Any Client

The `.claude/skills/` directory is the universal skill format. A skill is a markdown file with YAML frontmatter that tells the agent what the skill does and when to use it. The same file works across clients.

### The Universal Path

```
.claude/skills/<name>/SKILL.md      # Project-level (travels with the repo)
~/.claude/skills/<name>/SKILL.md    # User-level (available in every project)
```

Both paths are read by Cortex Code, Cursor, and Claude Code. Write once, use everywhere.

### Three Ways to Get a New Skill

**1. One-liner install** (Cortex Code / Claude Code)

```bash
/skill add https://github.com/anthropics/skills.git
```

Clones the repo and installs all skills it contains. Done.

**2. Clone and copy** (any client)

```bash
git clone https://github.com/anthropics/skills.git /tmp/skills
cp -r /tmp/skills/skills/pdf ~/.claude/skills/
```

Works in Cursor, Codex, or any tool that reads `~/.claude/skills/`.

**3. Write your own** (any client)

```bash
mkdir -p ~/.claude/skills/my-skill
```

Create `SKILL.md` with frontmatter and instructions. No toolchain, no build step, no registry.

### Try Before You Buy

Don't install skills globally on first encounter. Use the scope escalation ladder:

1. **Session** -- `/skill add <url>` in a session to test. Evaluate whether it actually helps.
2. **Project** -- If useful, copy to `.claude/skills/` in the project. Teammates get it via git.
3. **User** -- After it proves valuable across 3+ projects, promote to `~/.claude/skills/`.

This prevents the "just in case" accumulation that bloats your toolkit.

### Sharing With Teammates

Commit `.claude/skills/` to your repo. When teammates clone and open the project, their agent discovers the skills automatically. No install step, no coordination, no "did you add the skill?" Slack messages.

### Client-Specific Paths

| Path | Cortex Code | Cursor | Claude Code |
|------|:-----------:|:------:|:-----------:|
| `.claude/skills/` | Yes | Yes | Yes |
| `.cortex/skills/` | Yes | -- | -- |
| `.cursor/skills/` | -- | Yes | -- |

Use `.claude/skills/` for portability. Use client-specific paths only for functionality that genuinely differs between tools. For the full compatibility matrix, see the [setup guide](../guide-coco-setup/README.md#coco--cursor-whats-shared-whats-not).

---

## Part 4: Keeping Your Toolkit Lean

### One Skill, One Job

A skill should do one thing well. If your SKILL.md is over 200 lines, it's trying to do too much. Split it, or use progressive disclosure: keep the procedure in SKILL.md and move heavy reference material to a `references/` subdirectory that the skill reads only when it needs specifics.

```
.claude/skills/team-standards/
├── SKILL.md              # ~80 lines: when to activate, review procedure
└── references/
    └── standards.md      # ~200 lines: detailed rules (loaded on demand)
```

The agent reads SKILL.md to decide activation. It reads `references/` only when executing the procedure. Two context loads instead of one -- and the second only happens when needed.

### The Pruning Signal

After a few weeks, audit your `~/.claude/skills/` directory. For each skill, ask: *when was the last time this actually fired and helped?* If you can't remember, remove it. It's still on GitHub if you need it later.

User-level skills are evaluated (by description) on every message in every session. Ten unused skills means ten wasted evaluations per message. Individually trivial; collectively, it's attention budget spent on nothing.

### Scope Escalation Ladder

| Level | Path | Promote When |
|-------|------|-------------|
| Session | `/skill add` (temporary) | Just discovered it; evaluating |
| Project | `.claude/skills/` in repo | Useful for this project; teammates should have it |
| User | `~/.claude/skills/` | Proven across 3+ projects; part of your personal workflow |

Gravity pulls toward the lowest viable scope. A project-level skill that only one project needs should never be promoted to user-level.

### The Description Is the Gatekeeper

The `description` field in YAML frontmatter is the most important line in your skill. The agent reads every installed skill's description on every message to decide what to activate. A vague description ("Helps with coding") wastes evaluation cycles and may trigger false activations. A precise description ("Use when reviewing SQL for data quality violations against team standards") triggers only when relevant.

```yaml
---
name: team-standards
description: "Procedural SQL and security review against team conventions. Use when: reviewing code quality, checking naming compliance, auditing credentials handling."
---
```

### Don't Duplicate What's Already On

If a rule is in CLAUDE.md, don't repeat it in a skill. The agent already has it. Skills should reference CLAUDE.md rules ("verify against the SQL standards in CLAUDE.md"), not restate them. Duplication wastes budget and creates drift when one copy is updated but the other isn't.

---

## References

| Resource | URL |
|----------|-----|
| Cortex Code Extensibility | https://docs.snowflake.com/en/user-guide/cortex-code/extensibility |
| Skill Specification | https://agentskills.io/specification |
| Anthropic Official Skills | https://github.com/anthropics/skills |
| VoltAgent Skill Directory (500+) | https://github.com/VoltAgent/awesome-agent-skills |
| Setup Guide (install + guidance hierarchy) | [guide-coco-setup](../guide-coco-setup/) |
| Governance Workshop (org-level controls) | [guide-coco-governance-general](../guide-coco-governance-general/) |
