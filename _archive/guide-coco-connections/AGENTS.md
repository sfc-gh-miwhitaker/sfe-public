# guide-coco-connections — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md. Do not duplicate them here. -->

## Architecture

This is a documentation-only guide. No Snowflake objects are created.

```
guide-coco-connections/
├── README.md              ← Entry point and workshop overview
├── WORKSHOP.md            ← Workshop driver — CoCo reads this to facilitate
├── prompts/               ← One file per workshop part (01–05)
└── reference/             ← Copy-paste ready config files
    ├── connections-template.toml
    └── aliases.sh
```

## Conventions

- All config snippets use `[acme-prod]` and `[globex-dev]` as placeholder customer names
- Authentication examples default to `externalbrowser` (SSO) — the most common partner SE setup
- No real account identifiers, usernames, or credentials appear anywhere

## Key Commands

```bash
# Start the workshop
cortex                           # CoCo reads WORKSHOP.md automatically

# Verify your connections after setup
cortex connections list

# Test a specific connection
cortex -c <connection-name> -p "SELECT CURRENT_ACCOUNT(), CURRENT_USER();"
```
