![Guide](https://img.shields.io/badge/Type-Guide-blue)
![No Deploy](https://img.shields.io/badge/Deploy-None-lightgrey)
![Status](https://img.shields.io/badge/Status-Active-success)

# Get Started with Cortex Code CLI

A curated on-ramp for AI pair-programming with Snowflake. Install the CLI, connect to your account, and build your first custom skill with Snowflake-specific standards.

**Author:** SE Community
**Time:** ~30 minutes | **Result:** Working CLI + your first custom skill

> **No support provided.** This content is for reference only. Review and validate before applying to any production workflow.

---

## Who This Is For

Anyone new to AI pair-programming who wants to use Cortex Code with Snowflake. You need a Snowflake account.

---

## Part 0: Getting the Code

<details>
<summary><strong>Downloading from GitHub (No Experience Required)</strong></summary>

1. Click the link you were given -- you'll see the project name and a list of files
2. Find the green **"Code"** button (right side, above the file list)
3. Click it and select **"Download ZIP"**
4. Find the ZIP in your Downloads folder and unzip it
5. Move the folder somewhere memorable

</details>

**Already comfortable with terminal?**

```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) <project-name>
cd sfe-public/<project-name>
```

---

## Part 1: Install and Learn

| # | Resource | What You Get | Time |
|---|----------|-------------|------|
| 1 | [What is Cortex Code?](https://medium.com/snowflake/snowflake-cortex-code-what-it-is-why-it-matters-and-when-to-use-it-35152de8edca) | Big picture: what, why, when | 9 min |
| 2 | [Install + Connect](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) | One-liner install, first prompt | 2 min |
| 3 | [CLI Reference](https://docs.snowflake.com/en/user-guide/cortex-code/cli-reference) | Every slash command | 5 min |
| 4 | [Workflow Examples](https://docs.snowflake.com/en/user-guide/cortex-code/workflows) | Data discovery, Streamlit, Agents | 15 min |

---

## Part 2: Understand the Context Hierarchy

Cortex Code follows the same configuration model as Claude Code. The AI finds its instructions from multiple layers, with higher layers overriding lower ones. Understanding this hierarchy is the single most important concept for getting good results.

**Read the source:** [Claude Code Memory and CLAUDE.md](https://docs.anthropic.com/en/docs/claude-code/memory) covers the full hierarchy, file locations, and best practices for writing effective instructions.

### What Cortex Code adds

Cortex Code reads all the same files as Claude Code (`CLAUDE.md`, `AGENTS.md`, `.claude/skills/`) plus Snowflake-specific locations:

| Scope | Claude Code | Cortex Code adds |
|-------|-------------|------------------|
| Organization | `/Library/Application Support/ClaudeCode/` | `/Library/Application Support/Cortex/managed-settings.json` |
| User | `~/.claude/CLAUDE.md`, `~/.claude/skills/` | `~/.snowflake/cortex/settings.json`, `~/.snowflake/cortex/skills/` |
| Project | `AGENTS.md`, `.claude/skills/` | `.cortex/skills/` |

For the full extensibility model (skills, hooks, MCP, subagents), see [Cortex Code Extensibility](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility).

---

## Part 3: Build Your First Skill -- Snowflake Standards

Skills are on-demand extensions that load when triggered. For how skills work in general, see [Claude Code Skills](https://docs.anthropic.com/en/docs/claude-code/skills). This section focuses on what to put in a Snowflake-specific skill.

```bash
mkdir -p ~/.claude/skills/team-standards
cp reference/first-skill/SKILL.md ~/.claude/skills/team-standards/SKILL.md
cp -r reference/first-skill/references ~/.claude/skills/team-standards/
```

Verify: `/skill list` should show `team-standards`.

Test: *"Write a query that finds the top 10 customers by revenue from the ORDERS table"* -- the skill should prevent SELECT * and enforce QUALIFY for window function filtering.

The template uses `{PLACEHOLDER}` values for database, schema, and warehouse names. Customize them for your environment.

---

## Part 4: What's Next

- [Campaign Engine GUIDED_BUILD](../demo-campaign-engine/GUIDED_BUILD.md) -- apply everything in a real 7-prompt build (~90 min)
- [Skills as Resource Management](../guide-agent-skills/) -- context budgeting and when to use skills vs rules vs MCP
- [AI Coding Governance](../guide-coco-governance-general/) -- org-level policy, MDM deployment, and team distribution

---

## References

| Resource | URL |
|----------|-----|
| Cortex Code CLI docs | https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli |
| Cortex Code Extensibility | https://docs.snowflake.com/en/user-guide/cortex-code/extensibility |
| Claude Code Memory (CLAUDE.md) | https://docs.anthropic.com/en/docs/claude-code/memory |
| Claude Code Skills | https://docs.anthropic.com/en/docs/claude-code/skills |
| Claude Code Settings | https://docs.anthropic.com/en/docs/claude-code/settings |
| "What is Cortex Code?" | https://medium.com/snowflake/snowflake-cortex-code-what-it-is-why-it-matters-and-when-to-use-it-35152de8edca |
| "How to Create a Skill" | https://medium.com/snowflake/how-to-create-a-skill-for-cortex-code-55bc5b38a223 |
