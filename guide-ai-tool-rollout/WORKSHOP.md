# Governance Workshop: Take Control of AI Coding Tools

Learn to govern AI pair-programming by building a complete control stack -- from org-level policy to project-specific guardrails.

**Time:** ~75 minutes | **Steps:** 6 | **Result:** Governance stack + distribution playbook

## Prerequisites

- [ ] Cortex Code CLI installed and connected (see [Cortex Code CLI docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli))
- [ ] Access to a Snowflake account (for testing)
- [ ] Admin access to your machine (for managed-settings exercise)
- [ ] Read the official docs on configuration scopes: [Claude Code Settings](https://docs.anthropic.com/en/docs/claude-code/settings)
- [ ] ~75 minutes of focused time

## The 6 Steps

### [Step 1: Visibility](prompts/01_visibility.md)
**Time:** 10 min | **Build:** Nothing (inspection only)

Inspect where Cortex Code gets its instructions. This step focuses on CoCo-specific paths that extend the Claude Code model (`~/.snowflake/cortex/`, `.cortex/skills/`, Cortex managed-settings locations).

For the base hierarchy concept, see [Claude Code Settings: Configuration scopes](https://docs.anthropic.com/en/docs/claude-code/settings).

---

### [Step 2: Org Policy](prompts/02_org_policy.md)
**Time:** 15 min | **Build:** `managed-settings.json`

Create organization-level guardrails deployed via MDM (Jamf, Intune, SCCM) or config management (Ansible, Chef). This is the highest-priority layer -- users cannot override it.

For Claude Code's managed settings schema, see [Claude Code Settings: Managed settings](https://docs.anthropic.com/en/docs/claude-code/settings). This step covers the **Cortex Code-specific** schema additions and enterprise MDM deployment patterns.

---

### [Step 3: User Standards](prompts/03_user_standards.md)
**Time:** 15 min | **Build:** `~/.claude/CLAUDE.md` + team-standards skill

Create user-level standards with Snowflake-specific rules (SQL quality, credentials, naming conventions). For how CLAUDE.md and skills work, see [Claude Code Memory](https://docs.anthropic.com/en/docs/claude-code/memory) and [Claude Code Skills](https://docs.anthropic.com/en/docs/claude-code/skills).

---

### [Step 4: Project Scope](prompts/04_project_scope.md)
**Time:** 10 min | **Build:** `AGENTS.md` with guardrails

Add project-specific constraints: Snowflake RBAC, schema governance, and business logic rules. For how AGENTS.md / CLAUDE.md files work at the project level, see [Claude Code Memory](https://docs.anthropic.com/en/docs/claude-code/memory).

---

### [Step 5: Assurance](prompts/05_assurance.md)
**Time:** 15 min | **Build:** Test results

Red team your governance stack. Systematically attempt to bypass each layer.

---

### [Step 6: Distribution Playbook](prompts/06_distribution_playbook.md)
**Time:** 10 min | **Build:** Operational documentation

Create a playbook for onboarding, updates, and emergency procedures.

---

## After the Workshop

### Immediate Next Steps
1. **Deploy managed-settings.json** to your test machines via MDM
2. **Share the user setup script** with your team
3. **Create AGENTS.md templates** for common project types
4. **Schedule a red-team session** with security team

### Continue Learning
- [Dual-Surface Deployment](docs/dual-surface-deployment.md) -- Same standards on CLI and Snowsight via GitHub
- [Campaign Engine Workshop](../demo-campaign-engine/GUIDED_BUILD.md) -- apply governance in a real 7-step build
- [Data Governance Skills](https://docs.snowflake.com/en/user-guide/governance-skills) -- built-in Snowflake governance capabilities
