#!/bin/bash
# Team Standards Setup Script
# Run: curl -sL https://example.com/setup-team-standards.sh | bash
#
# This script installs:
# - ~/.claude/CLAUDE.md (always-on standards)
# - ~/.claude/skills/team-standards/ (review skill)

set -e

echo "🔧 Setting up team standards for AI coding tools..."

# Create directories
mkdir -p ~/.claude/skills/team-standards/references

# Download or create CLAUDE.md
echo "📝 Installing ~/.claude/CLAUDE.md..."
cat > ~/.claude/CLAUDE.md << 'CLAUDEMD'
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
CLAUDEMD

# Create the team-standards skill
echo "📝 Installing team-standards skill..."
cat > ~/.claude/skills/team-standards/SKILL.md << 'SKILLMD'
---
name: team-standards
description: "Use when reviewing code for governance compliance, checking for credential exposure, validating SQL quality, or before committing changes."
---

# Team Standards Review

## When to Use
Invoke when reviewing code, checking for credentials, validating SQL, or recovering from context drift.

## Review Workflow

### 1. Credential Scan
Check for exposed secrets: API keys, passwords, tokens, account IDs.
If found: **STOP** and warn immediately.

### 2. Destructive Operation Check
For DROP, DELETE, TRUNCATE, or UPDATE without WHERE:
- Show the exact SQL
- State what will be affected
- Ask for explicit confirmation

### 3. SQL Quality Check
- No SELECT * in non-exploratory queries
- Sargable predicates (no functions on columns in WHERE)
- QUALIFY for window functions
- Matching join key types

### 4. Report
State: **PASS**, **WARN** (with issues), or **BLOCK** (critical issues).

## Compaction Recovery
If standards seem forgotten:
1. Re-read `~/.claude/CLAUDE.md`
2. Re-invoke this skill
3. Re-read project's `AGENTS.md`
SKILLMD

# Create references file
cat > ~/.claude/skills/team-standards/references/patterns.md << 'PATTERNS'
# Credential Patterns to Detect
- sk-[a-zA-Z0-9]{48} (OpenAI)
- AKIA[0-9A-Z]{16} (AWS)
- password/pwd/secret assignments

# SQL Anti-Patterns
- WHERE YEAR(col) = 2024 → WHERE col >= '2024-01-01' AND col < '2025-01-01'
- Subquery for ROW_NUMBER filtering → QUALIFY
PATTERNS

echo ""
echo "✅ Setup complete!"
echo ""
echo "Installed:"
echo "  ~/.claude/CLAUDE.md"
echo "  ~/.claude/skills/team-standards/SKILL.md"
echo "  ~/.claude/skills/team-standards/references/patterns.md"
echo ""
echo "Verify with: cortex, then /skill list"
echo ""
