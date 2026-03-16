# Prerequisites

Before starting this demo, ensure you have:

## Snowflake

- [ ] ACCOUNTADMIN role access (for creating objects)
- [ ] Cortex AI enabled in your account
- [ ] Cortex Agents enabled (check with `SHOW AGENTS IN ACCOUNT`)

## GitHub

- [ ] GitHub Personal Access Token with `repo` and `read:org` scopes
- [ ] **OR** 1Password CLI installed and configured (`op` command available)

## Prior Knowledge

- [ ] Completed the [general governance workshop](../../guide-coco-governance-general/) — or understand:
  - Governance hierarchy: Organization > User > Project > Session > Built-in
  - managed-settings.json deployed at OS-level paths
  - CLAUDE.md for user-level standards
  - AGENTS.md for project-level constraints

## Cortex Code CLI

- [ ] Installed and connected to your Snowflake account
- [ ] Familiar with `/skill list` and basic commands

## Estimated Time

| Phase | Time |
|-------|------|
| Deploy Snowflake objects | 5 min |
| Configure governance | 10 min |
| Configure GitHub MCP | 10 min |
| Scope toolsets + test | 5 min |
| **Total** | **~30 min** |
