# Cortex Agent Image Tool Guide — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Single-document guide. No Snowflake objects deployed — this is a reference and
inspiration guide only.

Two patterns covered:
1. SPCS path — Docker container running image gen model, exposed as SPCS service,
   wrapped in a Snowflake UDF, registered as a Cortex Agent generic tool.
2. External API path — External Function calling an image gen API (DALL-E, Stability AI),
   Snowflake Secret for the API key, registered the same way.

## Snowflake Environment

None — guide only, no required objects.

## Conventions

- README.md is the complete guide
- ELI5.md is the plain-language companion
- No SQL deploy scripts (this is a guide, not a demo)

## Key Commands

None — read-only reference guide.
