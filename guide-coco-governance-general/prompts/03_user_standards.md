# Step 3: User Standards — ~/.claude/CLAUDE.md + Team Skill

## Governance Lesson: Same Baseline for All Users

User-level standards apply to every session, every project. They survive context compaction because they're re-loaded from the file system, not from conversation history.

**Time:** 15 minutes | **Build:** `~/.claude/CLAUDE.md` + team-standards skill

## Before You Start

- [ ] Completed Steps 1-2 (understand hierarchy, know org policy)
- [ ] Terminal access to your home directory

## Why User-Level Standards Matter

| Problem | Solution |
|---------|----------|
| AI forgets rules mid-session | CLAUDE.md is always-on, survives compaction |
| Different users have different baselines | Everyone installs from the same template |
| Standards scattered across projects | Central location for universal rules |
| Hard to update everyone | Push new version, users pull |

## Exercise 1: Create ~/.claude/CLAUDE.md

Create the directory and file:

```bash
mkdir -p ~/.claude
cat > ~/.claude/CLAUDE.md << 'EOF'
# Team Standards

## Security
- Never commit credentials, API keys, .env files, or account identifiers to code
- Never include account IDs, org names, or customer names in code or output
- Use Snowflake secrets or environment variables for all credentials
- Warn before any operation that could expose sensitive data

## SQL Quality
- Never use SELECT * in production code — always project specific columns
- Sargable predicates only: never wrap columns in functions in WHERE clauses
- Use QUALIFY for window function filtering, not subquery wrapping
- Join keys must have matching types — no implicit casts

## Destructive Operations
- Require explicit confirmation before DROP, DELETE, or TRUNCATE
- Show the SQL and ask "Proceed?" before executing destructive operations
- For batch deletes, show row count first

## Code Quality
- Search Snowflake docs before answering syntax questions from memory
- For multi-step tasks, use /plan mode first
- Never assume a library is available — check package.json/requirements.txt first

## Attribution
- No customer names or meeting references in code
EOF
```

## Exercise 2: Verify It's Loaded

Start a new Cortex Code session:

```bash
cortex
```

**Test:** Ask CoCo to write a query with `SELECT *`:

> "Write a query to get all data from the CUSTOMERS table."

**Expected behavior:** The AI should refuse to use `SELECT *` and ask which columns you need, citing the user-level standards.

**Test destructive operation:**

> "Drop the TEST_TABLE table."

**Expected behavior:** The AI should show the SQL and ask for confirmation before executing.

## Exercise 3: Create the Team-Standards Skill

The CLAUDE.md provides always-on rules. The skill provides a **procedural review workflow** you can invoke explicitly.

```bash
mkdir -p ~/.claude/skills/team-standards/references

# Create the skill
cat > ~/.claude/skills/team-standards/SKILL.md << 'EOF'
---
name: team-standards
description: "Use when reviewing code for governance compliance, checking for credential exposure, validating SQL quality, or before committing changes. Provides credential scanning, destructive operation warnings, and SQL pattern checks."
---

# Team Standards Review

## When to Use

Invoke this skill when:
- Reviewing code before commit
- Checking for credential exposure
- Validating SQL quality patterns
- Recovering from context compaction (standards drift)

## Review Workflow

### 1. Credential Scan
Check for exposed secrets:
- API keys, passwords, tokens in strings
- Account IDs, org names in code
- .env file contents or references
- Hardcoded connection strings

If found: **STOP** and warn immediately. Do not proceed.

### 2. Destructive Operation Check
For any DROP, DELETE, TRUNCATE, or UPDATE without WHERE:
- Show the exact SQL
- State what will be affected (row count if possible)
- Ask for explicit confirmation: "Type 'proceed' to execute"

### 3. SQL Quality Check
Verify:
- No SELECT * in non-exploratory queries
- WHERE clauses use sargable predicates (no functions on columns)
- Window functions use QUALIFY, not subquery wrapping
- Join keys have matching types

### 4. Naming Convention Check
Verify objects follow conventions from AGENTS.md (if present):
- RAW_ prefix for staging tables
- Appropriate warehouse naming
- COMMENT on all objects

## Compaction Recovery

If standards seem forgotten mid-session:
1. Re-read `~/.claude/CLAUDE.md`
2. Re-invoke this skill: "Apply team-standards review"
3. Re-read project's `AGENTS.md`

## Report Format

After review, state:
- **PASS**: All checks passed
- **WARN**: Issues found but not blocking (list them)
- **BLOCK**: Critical issues that must be fixed (list them)
EOF

# Create the references file for detailed patterns
cat > ~/.claude/skills/team-standards/references/patterns.md << 'EOF'
# Detailed Standards Patterns

## Credential Patterns to Detect

```regex
# API keys
['\"]?[a-zA-Z0-9_-]{20,}['\"]?  # Generic long strings
sk-[a-zA-Z0-9]{48}              # OpenAI keys
AKIA[0-9A-Z]{16}                # AWS access keys

# Passwords
password\s*[=:]\s*['\"][^'\"]+['\"]
pwd\s*[=:]\s*['\"][^'\"]+['\"]
secret\s*[=:]\s*['\"][^'\"]+['\"]

# Account identifiers
[a-z]{7}-[a-z]{7}\.snowflakecomputing\.com  # Snowflake account URLs
```

## SQL Anti-Patterns

### Non-Sargable (Bad)
```sql
WHERE YEAR(order_date) = 2024
WHERE UPPER(name) = 'JOHN'
WHERE customer_id + 1 = 100
```

### Sargable (Good)
```sql
WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'
WHERE name = 'JOHN'  -- or use COLLATE if case-insensitive needed
WHERE customer_id = 99
```

### Window Function Wrapping (Bad)
```sql
SELECT * FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
  FROM orders
) WHERE rn = 1
```

### Using QUALIFY (Good)
```sql
SELECT *
FROM orders
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) = 1
```
EOF
```

## Exercise 4: Verify the Skill

```bash
cortex
```

Run:
```
/skill list
```

**Expected:** `team-standards` appears in the user skills section.

**Test the skill:**
> "Review this SQL for team standards compliance:
> SELECT * FROM orders WHERE YEAR(order_date) = 2024"

**Expected:** The AI should flag both `SELECT *` and the non-sargable predicate.

## Distribution Options

### Option 1: curl One-Liner

Host the setup script and share the URL:

```bash
curl -sL https://example.com/team-setup.sh | bash
```

See [reference/setup-team-standards.sh](../reference/setup-team-standards.sh) for the script template.

### Option 2: ZIP Download

Package the files:
```bash
zip -r team-standards.zip ~/.claude/CLAUDE.md ~/.claude/skills/team-standards/
```

Share via Confluence, SharePoint, or email. Users unzip to their home directory.

### Option 3: Remote Skill Install

Host skills in a git repo:
```bash
/skill add https://github.com/myorg/team-skills.git
```

CoCo clones and caches the repo. Update with `/skill sync`.

### Option 4: Shared Drive

For air-gapped environments:
1. Place files on network drive
2. Users copy to `~/.claude/`
3. Document the path in your onboarding wiki

## Validation

| Test | Expected Result |
|------|-----------------|
| Start new CoCo session | No errors loading CLAUDE.md |
| Ask for `SELECT *` query | AI refuses, asks for specific columns |
| Ask to DROP a table | AI shows SQL, asks for confirmation |
| Run `/skill list` | team-standards appears |
| Invoke team-standards on bad SQL | Flags all issues |

## What You Learned

1. **CLAUDE.md is always-on** — loaded at every session start
2. **Survives compaction** — re-loaded from file, not conversation
3. **Skills are procedural** — workflows you invoke explicitly
4. **Multiple distribution channels** — curl, ZIP, git, shared drive

## Common Questions

**Q: What's the difference between CLAUDE.md and a skill?**
A: CLAUDE.md is always-on rules. Skills are procedures you invoke when needed.

**Q: Do I need both?**
A: For governance, yes. Rules in CLAUDE.md catch violations automatically. The skill provides explicit review workflow.

**Q: What if someone doesn't install the standards?**
A: That's what org-level policy (Step 2) is for — it can't be skipped.

## Next Step

User standards apply everywhere. Now let's add project-specific constraints.

→ [Step 4: Project Scope](04_project_scope.md)
