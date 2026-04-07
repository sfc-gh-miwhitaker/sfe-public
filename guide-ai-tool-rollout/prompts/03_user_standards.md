# Step 3: User Standards -- Snowflake-Specific CLAUDE.md + Team Skill

## Governance Lesson: Same Baseline for All Users

User-level standards apply to every session, every project. For how CLAUDE.md and skills work, see [Claude Code Memory](https://docs.anthropic.com/en/docs/claude-code/memory) and [Claude Code Skills](https://docs.anthropic.com/en/docs/claude-code/skills).

This step focuses on **what to put in them** for Snowflake teams.

**Time:** 15 minutes | **Build:** `~/.claude/CLAUDE.md` + team-standards skill

## Exercise 1: Create ~/.claude/CLAUDE.md with Snowflake Standards

```bash
mkdir -p ~/.claude
cat > ~/.claude/CLAUDE.md << 'EOF'
# Team Standards

## Security
- Never commit credentials, API keys, .env files, or account identifiers to code
- Never include account IDs, org names, or customer names in code or output
- Use Snowflake secrets or environment variables for all credentials

## SQL Quality
- Never use SELECT * in production code -- always project specific columns
- Sargable predicates only: never wrap columns in functions in WHERE clauses
- Use QUALIFY for window function filtering, not subquery wrapping
- Join keys must have matching types -- no implicit casts

## Destructive Operations
- Require explicit confirmation before DROP, DELETE, or TRUNCATE
- Show the SQL and ask "Proceed?" before executing destructive operations

## Operational
- Search Snowflake docs before answering syntax questions from memory
- For multi-step tasks, use /plan mode first
EOF
```

## Exercise 2: Create the Team-Standards Skill

The CLAUDE.md provides always-on rules. The skill provides a **procedural review workflow** invoked on demand.

```bash
mkdir -p ~/.claude/skills/team-standards/references
cp ../reference/setup-team-standards.sh /tmp/
# Or create inline -- see reference/setup-team-standards.sh for the full script
```

See [reference/setup-team-standards.sh](../reference/setup-team-standards.sh) for the complete skill template with credential scanning, SQL quality checks, and naming convention validation.

## Exercise 3: Verify

```bash
cortex
```

Test: *"Write a query to get all data from the CUSTOMERS table."*

Expected: The AI should refuse SELECT * and ask which columns you need.

Test: *"Drop the TEST_TABLE table."*

Expected: The AI should show the SQL and ask for confirmation.

## Distribution Options

For how to distribute CLAUDE.md and skills across a team, see the Anthropic docs on [sharing skills](https://docs.anthropic.com/en/docs/claude-code/skills). Additional Snowflake-specific options:

- **Snowflake stage**: Host skills in a Git Repository stage for Snowsight Workspace access
- **curl one-liner**: See [reference/setup-team-standards.sh](../reference/setup-team-standards.sh)
- **ZIP download**: Package `~/.claude/` contents for manual distribution

## Next Step

-> [Step 4: Project Scope](04_project_scope.md)
