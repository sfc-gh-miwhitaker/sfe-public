---
name: tool-agent-config-diff
description: "Extract and compare Cortex Agent specifications for version control. Triggers: agent config, agent diff, agent specification, DESC AGENT, RESULT_SCAN, agent export, agent version control, agent comparison, config hashing."
---

# Agent Config Diff

## Purpose

Extract Cortex Agent specifications for configuration management, comparison, and version control. Provides SQL and Python approaches with three output formats (full, spec-only, export) and MD5 config hashing for change detection.

## When to Use

- Extracting an agent's YAML specification for review
- Comparing agent configurations across environments
- Building version control workflows for agent specs
- Debugging agent configuration issues

## Architecture

```
DESC AGENT <name>
       │
       ▼
RESULT_SCAN (last query ID)
       │
       ├── SQL approach (interactive session)
       │   ├── Full detail (all columns)
       │   ├── Spec only (YAML specification)
       │   └── Export (JSON with config hash)
       │
       └── Python approach (programmatic)
           ├── Same 3 output formats
           ├── File export capability
           └── Config hashing for diff
```

## Key Files

| File | Purpose |
|------|---------|
| `extract_agent_spec.sql` | Interactive SQL with session variables, temp table, 3 output modes |
| `extract_agent_spec.py` | Python script with argparse, 3 output modes, JSON export |

## SQL Extraction Pattern

```sql
DESC AGENT <agent_name>;
SET qid = LAST_QUERY_ID();
CREATE OR REPLACE TEMP TABLE agent_spec AS SELECT * FROM TABLE(RESULT_SCAN($qid));
SELECT * FROM agent_spec;
```

## Python Extraction Pattern

```python
cursor.execute(f"DESC AGENT {agent_name}")
spec = cursor.fetchall()
config_hash = hashlib.md5(json.dumps(spec).encode()).hexdigest()
```

## Extension Playbook: Adding a New Output Format

1. Add a new `--format` option in `extract_agent_spec.py` (argparse)
2. Add a corresponding SQL block in `extract_agent_spec.sql` gated by session variable
3. Format the RESULT_SCAN output as needed (Markdown, CSV, etc.)
4. Include the MD5 config hash for change detection

## Extension Playbook: Building an Automated Diff Pipeline

1. Schedule extraction with a Snowflake Task (call Python procedure)
2. Store specs in a version history table with timestamps and config hashes
3. Compare consecutive hashes to detect configuration drift
4. Alert on changes via notification integration

## Gotchas

- `RESULT_SCAN` requires the same session -- cannot be used across sessions or in stored procedures that open new sessions
- `DESC AGENT` not `DESCRIBE CORTEX AGENT`
- Agent profile is JSON stored as string -- use `TRY_PARSE_JSON` for structured access
- The YAML specification is in the `specification` column of DESC output
- SQL approach requires interactive execution (session variables with `SET`)
- No persistent Snowflake objects -- this tool is stateless
