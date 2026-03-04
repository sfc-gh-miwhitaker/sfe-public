![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--05--01-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Agent Config Diff Tool

> DEMONSTRATION PROJECT - EXPIRES: 2026-05-01
> This tool uses Snowflake features current as of March 2026.

Extract Cortex Agent specifications for configuration management, comparison, and version control.

**Author:** SE Community
**Last Updated:** 2026-03-02 | **Expires:** 2026-05-01 | **Status:** ACTIVE

## Quick Start

**Use in Snowsight (no clone needed):**
Copy [`extract_agent_spec.sql`](extract_agent_spec.sql) into a Snowsight worksheet and update the `agent_fqn` variable.

**Develop with Cortex Code:**
```bash
bash <(curl -sL https://raw.githubusercontent.com/sfc-gh-miwhitaker/sfe-public/main/shared/get-project.sh) tool-agent-config-diff
cd sfe-public/tool-agent-config-diff && cortex
```

## What This Creates

This tool runs ad-hoc SQL queries -- no persistent objects are created. It reads agent metadata via `DESCRIBE AGENT` and formats output for diff workflows.

## Usage

1. Open `extract_agent_spec.sql` in Snowsight
2. Update the `agent_fqn` variable to your agent's fully qualified name:
   ```sql
   SET agent_fqn = 'YOUR_DATABASE.YOUR_SCHEMA.YOUR_AGENT';
   ```
3. Run the desired option (see below)

## Output Options

### Option 1: Full Agent Metadata
Returns all agent properties with parsed profile JSON. Best for comprehensive config management.

**Output columns:**
- `agent_name` - Agent identifier
- `agent_fqn` - Fully qualified name (DB.SCHEMA.NAME)
- `owner` - Owning role
- `comment` - Agent description
- `profile_json` - Parsed profile (display_name, avatar, color)
- `spec_yaml` - Complete YAML specification
- `created_on` - Creation timestamp

### Option 2: Spec YAML Only
Returns just the agent specification. Best for diff tools and line-by-line comparison.

### Option 3: Export-Ready Format
Single JSON document with all configuration data. Best for version control commits.

**JSON structure:**
```json
{
  "extracted_at": "2025-01-09T...",
  "agent_fqn": "DB.SCHEMA.AGENT",
  "metadata": {
    "name": "...",
    "database": "...",
    "schema": "...",
    "owner": "...",
    "comment": "...",
    "created_on": "..."
  },
  "profile": { "display_name": "...", "avatar": "...", "color": "..." },
  "spec_yaml": "..."
}
```

## Comparison Workflow

To compare two agent configurations:

1. Extract spec from Agent A → save to `agent_a_spec.yaml`
2. Extract spec from Agent B → save to `agent_b_spec.yaml`
3. Use your preferred diff tool:
   ```bash
   diff agent_a_spec.yaml agent_b_spec.yaml
   # or
   code --diff agent_a_spec.yaml agent_b_spec.yaml
   ```

## DESCRIBE AGENT Output Reference

Per [Snowflake docs](https://docs.snowflake.com/en/sql-reference/sql/desc-agent), `DESCRIBE AGENT` returns:

| Column | Description |
|--------|-------------|
| name | Agent identifier |
| database_name | Containing database |
| schema_name | Containing schema |
| owner | Owner role |
| comment | Agent description |
| profile | JSON: display_name, avatar, color |
| agent_spec | Complete YAML specification |
| created_on | Creation timestamp |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| "Object does not exist" | Verify the agent FQN is correct: `SHOW AGENTS IN SCHEMA <db>.<schema>`. |
| Empty `agent_spec` | Agent may have been created without a spec. Check with `DESC AGENT`. |
| `TRY_PARSE_JSON` returns NULL | Profile field may be empty. This is normal for agents without custom profiles. |

## Cleanup

No cleanup required -- this tool creates no persistent objects.

## Development Tools

This project is designed for AI-pair development.

- **AGENTS.md** -- Project instructions for Cortex Code and compatible AI tools
- **.claude/skills/** -- Project-specific AI skills (Cursor + Claude Code)
- **Cortex Code in Snowsight** -- Open this project in a Workspace for AI-assisted development
- **Cursor** -- Open locally with Cursor for AI-pair coding

> New to AI-pair development? See [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)

## Notes

- The `agent_spec` is returned as **YAML text**, not JSON
- Each option runs `DESC AGENT` separately to ensure `RESULT_SCAN(LAST_QUERY_ID())` captures the correct result
- Profile is stored as JSON string and parsed with `TRY_PARSE_JSON()`
