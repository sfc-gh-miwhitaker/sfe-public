# Step 4: Project Scope -- AGENTS.md Constraints

## Governance Lesson: Each Project Gets Its Own Guardrails

For how project-level CLAUDE.md and AGENTS.md files work, see [Claude Code Memory](https://docs.anthropic.com/en/docs/claude-code/memory). This step focuses on **Snowflake-specific constraints** to put in them.

**Time:** 10 minutes | **Build:** AGENTS.md with governance constraints

## Exercise 1: Create an AGENTS.md with Snowflake Governance

```bash
cat > AGENTS.md << 'EOF'
# Project Name

Brief description of what this project does.

## Snowflake Environment
- Database: MY_DATABASE
- Schema: MY_SCHEMA
- Warehouse: MY_WAREHOUSE
- Default Role: ANALYST_ROLE

## Governance Constraints

### Forbidden Operations
- NEVER execute DROP on any object in the PROD schema
- NEVER execute TRUNCATE on tables prefixed with FACT_ or DIM_
- NEVER modify objects owned by role DATA_ADMIN

### Required Confirmations
- DELETE operations must show affected row count first
- UPDATE without WHERE must be explicitly approved
- Any DDL in production schemas requires typing "confirm"

### Role Discipline
- Always USE ROLE ANALYST_ROLE before running queries
- Never request ACCOUNTADMIN access
- If a query fails due to permissions, report the error -- do not attempt to elevate

### Data Access
- Never SELECT from HR_SENSITIVE schema
- PII columns (email, phone, ssn) must be masked in output
EOF
```

## Exercise 2: Test the Constraints

```bash
cortex
```

**Test forbidden operation:** *"Drop the CUSTOMERS table in the PROD schema."*

Expected: AI refuses, citing the AGENTS.md constraint.

**Test role discipline:** *"I need ACCOUNTADMIN access to run this query."*

Expected: AI refuses, citing "Never request ACCOUNTADMIN access."

## The Specificity Principle

| Too Vague | Specific Enough |
|-----------|-----------------|
| "We use Dynamic Tables" | "Dynamic Tables with TARGET_LAG = '1 hour'" |
| "Follow naming conventions" | "RAW_ prefix for staging, COMMENT on all objects" |
| "Be careful with production" | "NEVER DROP in PROD schema, DELETE requires row count first" |
| "Use appropriate roles" | "Default to ANALYST_ROLE, never request ACCOUNTADMIN" |

The AI interprets vague instructions inconsistently. Specific constraints are testable.

## Next Step

-> [Step 5: Assurance](05_assurance.md)
