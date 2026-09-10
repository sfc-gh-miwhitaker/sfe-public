---
name: guide-snowflake-mcp-role-controls
description: "Project skill for Snowflake-managed MCP OAuth roles, secondary roles, session policies, ALLOWED_ROLES_LIST, and OAUTH_USE_SECONDARY_ROLES."
---

# Snowflake MCP Role Controls

Pair-programmed by SE Community + Cortex Code

## Purpose

Maintain the guide that explains Snowflake-managed MCP role selection and secondary-role restrictions.

## Architecture

Static guide with copy-ready SQL templates.

## Key Files

| File | Role |
| --- | --- |
| `README.md` | Customer-facing guide |
| `ELI5.md` | Plain-language explanation |
| `sql/` | Ordered configuration and validation templates |

## Extension Playbook: Add a Client-Specific Pattern

1. Verify the client's requested OAuth scope in current documentation.
2. Add the behavior to the client matrix in `README.md`.
3. Add SQL only when Snowflake configuration differs.
4. Update Gotchas and external references.

## Snowflake Objects

- MCP access role selected by the reader
- Existing Snowflake-managed MCP server and its tools
- Snowflake OAuth security integration
- Optional session policy for secondary-role restrictions

## Gotchas

- OAuth role allowlists and session-policy secondary-role allowlists solve different problems.
- Client support determines whether an advertised named role is requested.
- Preview role-selection behavior must remain explicitly labeled.
