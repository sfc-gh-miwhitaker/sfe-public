# Get Started with Cortex Code CLI

A curated on-ramp for AI pair-programming with Snowflake. Install the CLI, understand how it finds its instructions, and build your first custom skill.

**Time:** ~45 minutes | **Result:** Working CLI + your first custom skill

## Who This Is For

Anyone new to AI pair-programming who wants to use Cortex Code with Snowflake. You don't need prior experience with AI coding tools, prompt engineering, or skills. You do need a Snowflake account.

## Part 1: The Learning Path

These official resources cover install, connect, and basic usage. Read them in this order -- each builds on the previous.

| # | Resource | What You'll Get | Time |
|---|----------|-----------------|------|
| 1 | [What is Cortex Code?](https://medium.com/snowflake/snowflake-cortex-code-what-it-is-why-it-matters-and-when-to-use-it-35152de8edca) | Big picture: what CoCo is, why it exists, when to use it vs Cursor/Claude Code | 9 min |
| 2 | [Install + Connect](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) | One-liner install, setup wizard, first prompt | 2 min |
| 3 | [CLI Reference](https://docs.snowflake.com/en/user-guide/cortex-code/cli-reference) | Bookmark this -- every slash command, keyboard shortcut, exit code | skim 5 min |
| 4 | [Workflow Examples](https://docs.snowflake.com/en/user-guide/cortex-code/workflows) | Try data discovery, synthetic data, Streamlit, Cortex Agents | 15 min |
| 5 | [Skills + Extensibility](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility) | Reference for skills, subagents, hooks, MCP -- you'll need this for Part 3 | skim 10 min |
| 6 | [How to Create a Skill](https://medium.com/snowflake/how-to-create-a-skill-for-cortex-code-55bc5b38a223) | Step-by-step skill creation walkthrough | 5 min |
| 7 | [Advanced Skill Techniques](https://medium.com/snowflake/advanced-techniques-for-creating-skills-in-cortex-code-cli-38f768eb2dcf) | Front-load research, build validators, iterate continuously | 8 min |

**After Step 2, come back here.** The rest of this guide covers concepts the official docs don't.

---

## Part 2: How CoCo Finds Its Instructions

This is the single most important concept for getting good results from AI pair-programming: the AI is only as good as the context you give it. Cortex Code (and compatible tools like Cursor and Claude Code) look for instructions in multiple places, layered from broadest to narrowest scope.

### The Guidance Hierarchy

See [diagrams/guidance-hierarchy.md](diagrams/guidance-hierarchy.md) for the full visual, but here's the summary:

| Priority | Scope | Location | Loaded When |
|----------|-------|----------|-------------|
| 1 (highest) | Organization | `/Library/Application Support/Cortex/managed-settings.json` (macOS) | Always (if exists) |
| 2 | User | `~/.claude/CLAUDE.md` + `~/.claude/skills/` + `~/.snowflake/cortex/skills/` | Always |
| 3 | Project | `AGENTS.md` (or `CLAUDE.md`) at project root + `.cortex/skills/` or `.claude/skills/` | When working in that project |
| 4 | Session | Temporary skills, `/plan` mode, model overrides | Current session only |
| 5 (lowest) | Built-in | ~11 bundled skills (semantic views, dbt, etc.) | Always available |

Higher-priority layers override lower ones. This means your project-level `AGENTS.md` can specialize the behavior defined in your user-level `CLAUDE.md`.

### Always-On vs On-Demand

There are two kinds of guidance, and confusing them is a common mistake:

**Always-on (loaded automatically):**
- `AGENTS.md` or `CLAUDE.md` at your project root
- `~/.claude/CLAUDE.md` (user-level)
- Managed settings (org-level)

These are read by the AI at the start of every conversation. Put your non-negotiable standards here -- naming conventions, security rules, project context.

**On-demand (invoked explicitly):**
- Skills (in `.cortex/skills/`, `.claude/skills/`, or `~/.claude/skills/`)
- Subagents
- MCP tools

These are loaded when you reference them by name or when the AI recognizes a matching trigger. Put specialized workflows here -- things you need sometimes, not always.

### AGENTS.md Explained

`AGENTS.md` is a markdown file at the root of your project that tells the AI what it needs to know. Think of it as a briefing document: project structure, environment details, coding standards, and guardrails.

**What goes in it:**

```markdown
# Project Name

One-sentence description.

## Project Structure
- Where the code lives, what each directory does

## Environment
- Database, schema, warehouse, roles
- External dependencies or integrations

## Development Standards
- SQL rules, naming conventions, testing expectations
- Patterns to follow, anti-patterns to avoid

## When Helping with This Project
- Specific guardrails (e.g., "never drop the production schema")
- Project-specific vocabulary or domain context
```

**When to update it:**
- After adding a major new component (new table, new feature, new integration)
- When the AI gets something wrong that it should know about
- When onboarding a new team member who will use AI tools on this project

**The evolution pattern:** AGENTS.md starts sparse and grows as the project grows. After Step 1 of a project, it might only have the database and schema names. By Step 7, it contains every naming convention, every feature pattern, and every gotcha the AI needs to know. See the [campaign-engine GUIDED_BUILD](../demo-campaign-engine/GUIDED_BUILD.md) for a worked example of this evolution across 7 steps.

### CoCo + Cursor: What's Shared, What's Not

If you use both Cortex Code CLI and Cursor (or Claude Code), several files are shared between them:

| File / Directory | Cortex Code CLI | Cursor | Claude Code |
|-----------------|-----------------|--------|-------------|
| `AGENTS.md` (project root) | Read automatically | Read automatically (as rule) | Read automatically |
| `.claude/skills/` (project) | Read as skills | Read as skills | Read as skills |
| `~/.claude/CLAUDE.md` | Read automatically | Read via rules | Read automatically |
| `~/.claude/skills/` | Read as skills | Read as skills | Read as skills |
| `~/.snowflake/connections.toml` | Snowflake connection | Not used | Not used |
| `~/.snowflake/cortex/settings.json` | CoCo settings | Not used | Not used |
| `.cortex/skills/` (project) | Read as skills | Not used | Not used |
| `~/.snowflake/cortex/skills/` | Read as skills | Not used | Not used |

The practical takeaway: if you write your project guidance in `AGENTS.md` and your skills in `.claude/skills/`, they work in all three tools. Use `.cortex/`-specific paths only for CoCo-only functionality.

---

## Part 3: Build Your First Skill -- Team Standards

Most skill tutorials show you how to automate a task (CSV ingestion, test running, etc.). That's useful, but it's not the highest-leverage first skill. The highest-leverage first skill encodes your team's standards so that every session, in every project, starts with the right guardrails.

### Why Standards First

Without a standards skill, you repeat the same corrections across sessions: "don't use SELECT \*", "use QUALIFY instead of subqueries", "don't commit credentials." A standards skill eliminates this by front-loading your non-negotiable rules into every conversation.

### Create the Skill

The example skill lives in [`reference/first-skill/SKILL.md`](reference/first-skill/SKILL.md). Here's how to install it:

**Step 1: Create the directory**

```bash
mkdir -p ~/.claude/skills/team-standards
```

This puts it at user-level scope -- it applies to every project you work on.

**Step 2: Copy the skill**

```bash
cp reference/first-skill/SKILL.md ~/.claude/skills/team-standards/SKILL.md
```

Or open [`reference/first-skill/SKILL.md`](reference/first-skill/SKILL.md) and customize it before copying. The example covers:

- **SQL standards** -- no SELECT \*, sargable predicates, QUALIFY for window functions, explicit columns
- **Security rules** -- no credentials in code, use Snowflake secrets, no account IDs in output
- **Naming conventions** -- SFE\_ prefix patterns, COMMENT on all objects
- **Operational best practices** -- reload core context on compaction, search docs before answering Snowflake syntax from memory, when to start a new session vs continue

**Step 3: Verify**

In Cortex Code CLI:

```text
/skill list
```

You should see `team-standards` in the output. If using Cursor or Claude Code, the skill will appear in their respective skill listings since it's in `~/.claude/skills/`.

**Step 4: Test it**

Ask CoCo something that should trigger your standards:

```text
Write a query that finds the top 10 customers by revenue from the ORDERS table
```

With the skill loaded, the AI should use explicit columns (not SELECT \*), use QUALIFY if window functions are involved, and follow your naming conventions.

### Project-Level vs User-Level: When to Use Which

| Scope | Path | Use When |
|-------|------|----------|
| User-level | `~/.claude/skills/` | Standards that apply to ALL your projects (SQL rules, security, attribution) |
| Project-level | `.claude/skills/` in the project | Standards specific to ONE project (schema names, domain vocabulary, project patterns) |

Start with user-level. Move things to project-level when they're project-specific or when you're sharing a repo with others who have different standards.

---

## Part 4: What's Next

You now have a working Cortex Code CLI, an understanding of how it finds instructions, and a team-standards skill that improves every session. Here's where to go from here:

**Build a project-specific skill.** Follow [Jacob Prall's guide](https://medium.com/snowflake/how-to-create-a-skill-for-cortex-code-55bc5b38a223) to create a skill that automates a workflow you repeat often (data ingestion, test scaffolding, deployment).

**Add MCP servers.** Connect CoCo to GitHub, Jira, or other tools via [Model Context Protocol](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility). Run `/mcp` in CoCo to see what's configured.

**Create custom subagents.** Define specialized agents for code review, testing, or exploration. See [Extensibility docs](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility) for the agent definition format.

**Try the full AI-pair workshop.** The [Campaign Engine GUIDED_BUILD](../demo-campaign-engine/GUIDED_BUILD.md) walks through building a complete ML-powered application from scratch using 7 focused prompts. It's the best way to see AGENTS.md evolution in action.

**Write an AGENTS.md for your next project.** Start with the template in [Part 2](#agentsmd-explained) and let it grow as you build.

---

## References

| Resource | URL |
|----------|-----|
| Cortex Code CLI docs | https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli |
| CLI Reference | https://docs.snowflake.com/en/user-guide/cortex-code/cli-reference |
| CLI Settings | https://docs.snowflake.com/en/user-guide/cortex-code/settings |
| Extensibility (skills, hooks, MCP) | https://docs.snowflake.com/en/user-guide/cortex-code/extensibility |
| Workflow Examples | https://docs.snowflake.com/en/user-guide/cortex-code/workflows |
| "What is Cortex Code?" (Daniel Myers) | https://medium.com/snowflake/snowflake-cortex-code-what-it-is-why-it-matters-and-when-to-use-it-35152de8edca |
| "How to Create a Skill" (Jacob Prall) | https://medium.com/snowflake/how-to-create-a-skill-for-cortex-code-55bc5b38a223 |
| "Advanced Skill Techniques" (Jacob Prall) | https://medium.com/snowflake/advanced-techniques-for-creating-skills-in-cortex-code-cli-38f768eb2dcf |
