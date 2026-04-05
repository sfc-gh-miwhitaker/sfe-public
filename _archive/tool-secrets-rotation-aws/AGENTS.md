# Secrets Rotation Workbook

Snowflake Native Notebook for rotating key-pair credentials and Programmatic Access Tokens (PATs)
for service accounts using AWS Secrets Manager. Creates a purpose-built example service user
(`SFE_SVC_ROTATION_EXAMPLE`) with full supporting infrastructure.

## Project Structure
- `deploy_all.sql` -- Creates schema + imports notebook from Git stage
- `teardown_all.sql` -- Drops all example objects, notebook, and schema
- `secrets_rotation_workbook.ipynb` -- PRIMARY DELIVERABLE: interactive Snowflake Notebook
- `README.md` -- Landing page with deploy instructions
- `diagrams.md` -- Mermaid architecture diagrams (GitHub rendering)
- `.claude/skills/secrets-rotation-aws/SKILL.md` -- Project-specific AI skill

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: SECRETS_ROTATION
- Warehouse: SFE_TOOLS_WH (shared)
- Notebook: SECRETS_ROTATION_WORKBOOK

## Snowflake Objects Created by Notebook
- User: `SFE_SVC_ROTATION_EXAMPLE` (TYPE=SERVICE)
- Role: `SFE_SVC_ROTATION_ROLE` (service role)
- Role: `SFE_SVC_ROTATION_ROTATOR_ROLE` (rotation privileges)
- Network Rule: `SFE_SVC_ROTATION_NETWORK_RULE`
- Network Policy: `SFE_SVC_ROTATION_NETWORK_POLICY`
- Auth Policy: `SFE_SVC_ROTATION_AUTH_POLICY`
- PAT: `SFE_ROTATION_EXAMPLE_PAT`

## Key Technical Constraints
- PAT rotation CANNOT be performed from a PAT-authenticated session
- PAT `token_secret` only appears once in the ALTER USER ROTATE PAT output
- Service users require a network policy to generate/use PATs
- Service users require ROLE_RESTRICTION on PATs (unless auth policy lifts it)
- Max 15 PATs per user (includes disabled, excludes expired)
- CREDENTIALS view has up to 2-hour latency; use SHOW USER PROGRAMMATIC ACCESS TOKENS for real-time

## When Helping with This Project
- The notebook is the primary deliverable -- all executable content lives there
- deploy_all.sql only creates the schema and imports the notebook; it does NOT create the example user
- The notebook cells create/manipulate the example user step by step
- teardown_all.sql drops EVERYTHING including objects created by notebook cells
- All object names use SFE_ prefix and include COMMENT with expiration
- AWS-side instructions (CLI commands, Lambda code, IAM policies) appear as markdown cells since they cannot execute inside Snowflake
- Pattern 2 (PAT) depends on Pattern 1 (key-pair) -- the PAT rotation Lambda authenticates via key-pair

## Helping New Users

If the user seems confused or asks basic questions:

1. **Greet them warmly** and explain this is a workbook for learning credential rotation
2. **Check deployment** -- ask if they've run `deploy_all.sql` in Snowsight
3. **Guide to the notebook** -- Snowsight > Projects > Notebooks > SECRETS_ROTATION_WORKBOOK
4. **Run cells in order** -- the notebook is designed to be run top-to-bottom
5. **Remind about teardown** -- run `teardown_all.sql` when done to clean up all example objects

## Related Projects
- [`guide-cortex-anthropic-redirect`](../guide-cortex-anthropic-redirect/) -- PAT and key-pair JWT auth patterns
- [`guide-api-agent-context`](../guide-api-agent-context/) -- Key-pair JWT auth for Agent Run API
- [`tool-api-data-fetcher`](../tool-api-data-fetcher/) -- External access integration requiring secrets
- [`demo-api-quickbooks-medallion`](../demo-api-quickbooks-medallion/) -- OAuth secrets in practice
