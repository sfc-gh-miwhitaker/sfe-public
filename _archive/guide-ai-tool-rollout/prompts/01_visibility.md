# Step 1: Visibility -- Inspect the Configuration Hierarchy

## Governance Lesson: See Exactly Where Instructions Come From

**Time:** 10 minutes | **Build:** Nothing (inspection only)

## Before You Start

- [ ] Cortex Code CLI is installed and running
- [ ] Read [Claude Code Settings: Configuration scopes](https://docs.anthropic.com/en/docs/claude-code/settings) for the base hierarchy model

## What Cortex Code Adds

The base hierarchy (managed -> user -> project -> local) is documented in the Claude Code settings docs. Cortex Code extends it with additional paths:

| Scope | Shared with Claude Code | Cortex Code adds |
|-------|------------------------|------------------|
| Organization | `/Library/Application Support/ClaudeCode/` (macOS) | `/Library/Application Support/Cortex/managed-settings.json` |
| User | `~/.claude/CLAUDE.md`, `~/.claude/skills/` | `~/.snowflake/cortex/settings.json`, `~/.snowflake/cortex/skills/` |
| Project | `AGENTS.md`, `.claude/skills/` | `.cortex/skills/` |
| Session | Temporary skills, model overrides | Same |
| Built-in | Bundled skills | CoCo-specific bundled skills (semantic views, dbt, governance) |

## Exercise 1: Inspect Your Current Configuration

```bash
cat ~/.claude/CLAUDE.md 2>/dev/null || echo "No user-level CLAUDE.md"
ls ~/.claude/skills/ 2>/dev/null || echo "No user-level skills"
cat ~/.snowflake/cortex/settings.json 2>/dev/null || echo "No CoCo settings"
ls ~/.snowflake/cortex/skills/ 2>/dev/null || echo "No CoCo-specific skills"
```

## Exercise 2: Check for Org-Level Policy

```bash
# macOS (Cortex Code)
cat "/Library/Application Support/Cortex/managed-settings.json" 2>/dev/null || echo "No Cortex managed settings"

# macOS (Claude Code)
cat "/Library/Application Support/ClaudeCode/managed-settings.json" 2>/dev/null || echo "No Claude Code managed settings"
```

Most personal machines won't have managed settings -- they're IT-deployed via MDM.

## Exercise 3: Ask CoCo What It Knows

> "What instructions are you currently following? List the specific rules from AGENTS.md, CLAUDE.md, and any loaded skills."

A well-governed AI can enumerate its constraints. If it can't, that's a sign you need more explicit documentation.

## What You Learned

1. **Cortex Code extends the Claude Code hierarchy** with Snowflake-specific paths
2. **Higher layers override lower** -- org policy beats user preferences
3. **The AI can enumerate its constraints** -- ask it

## Next Step

-> [Step 2: Org Policy](02_org_policy.md)
