# Step 6: Distribution Playbook — Operational Onboarding

## Governance Lesson: Governance is a Process, Not a One-Time Setup

The technical controls are in place. Now document how to deploy, maintain, and evolve them.

**Time:** 10 minutes | **Build:** Distribution playbook document

## Before You Start

- [ ] Completed Steps 1-5
- [ ] Understand your organization's onboarding process

## The Four Questions Every Playbook Answers

1. **How do new employees get governance config?**
2. **How do new projects get AGENTS.md templates?**
3. **Who owns standard updates? How are they deployed?**
4. **What's the emergency procedure for urgent policy changes?**

## Exercise 1: Create Your Distribution Playbook

Use the template at [reference/distribution-playbook-template.md](../reference/distribution-playbook-template.md), or create your own:

```markdown
# AI Governance Distribution Playbook

## Overview
This document describes how [ORGANIZATION] deploys and maintains AI coding tool governance.

---

## 1. New Employee Onboarding

### Org-Level Policy (managed-settings.json)
- **Method:** [MDM (Jamf/Intune) | Config Management (Ansible/Chef) | Manual]
- **Trigger:** Automatically deployed to all managed devices
- **Verification:** User sees "[COMPANY] Managed" banner in Cortex Code
- **Owner:** IT Security Team
- **SLA:** Config deployed within 24 hours of device enrollment

### User-Level Standards (~/.claude/)
- **Method:** [curl script | ZIP download | Remote skill | Shared drive]
- **Location:** [URL or path]
- **Instructions for new employees:**
  1. [Step 1]
  2. [Step 2]
  3. [Verification step]
- **Owner:** [Team/Person]
- **SLA:** Employee completes within first week

### Verification Checklist
- [ ] Banner shows managed status
- [ ] `/skill list` shows team-standards
- [ ] Test query refuses SELECT *
- [ ] Destructive ops require confirmation

---

## 2. New Project Setup

### AGENTS.md Template
- **Location:** [Git repo URL | Confluence | SharePoint]
- **Template options:**
  - `agents-data-pipeline.md` — ETL and data pipeline projects
  - `agents-analytics.md` — BI and analytics projects
  - `agents-application.md` — Application development

### Project Onboarding Steps
1. Copy appropriate template to project root as `AGENTS.md`
2. Update Snowflake environment section (database, schema, warehouse)
3. Add project-specific constraints
4. Commit to repo
5. Verify: start CoCo and ask it to list its constraints

### Project Skill Template (Optional)
- **When to use:** Projects with specialized review workflows
- **Location:** [Git repo URL]
- **Installation:** Copy `.cortex/skills/` directory to project

---

## 3. Standard Updates

### Change Request Process
1. Submit change to [Jira board | GitHub issue | Email alias]
2. Review by [Security Team | Governance Committee]
3. Approval required from [Role/Person]
4. Implementation by [Team]

### Deployment Process

#### Org-Level (managed-settings.json)
- **Change window:** [Day/time]
- **Notification:** [Email list | Slack channel]
- **Rollback procedure:** [Steps]

#### User-Level (CLAUDE.md, skills)
- **Notification:** [Email | Slack | Wiki update]
- **User action required:** [Yes/No — if yes, describe]
- **Verification:** [How users confirm they have the update]

#### Project-Level (AGENTS.md templates)
- **Notification:** [Email to project leads | Wiki update]
- **Existing projects:** [Manually update | Auto-PR | Advisory only]

### Version Tracking
- managed-settings.json version: `ui.bannerText` includes version
- CLAUDE.md version: Comment at top of file
- Skills version: Frontmatter `version` field

---

## 4. Emergency Procedures

### Urgent Policy Change (Security Incident)
1. **Immediate:** Update managed-settings.json via MDM push
2. **Within 1 hour:** Email all-staff with impact summary
3. **Within 4 hours:** Update user-level config distribution
4. **Within 24 hours:** Post-incident review

### Emergency Contacts
| Role | Person | Contact |
|------|--------|---------|
| MDM Admin | | |
| Security Lead | | |
| Governance Owner | | |

### Rollback Procedures
- **Org policy:** MDM rollback to previous config
- **User config:** Redirect download URL to previous version
- **Project templates:** Git revert

---

## 5. Periodic Review

### Monthly
- [ ] Review test results from red team exercises
- [ ] Check for new CoCo features affecting governance
- [ ] Review change requests backlog

### Quarterly
- [ ] Full red team exercise (Step 5 checklist)
- [ ] Update templates for new patterns learned
- [ ] Training refresh for new employees

### Annually
- [ ] Comprehensive governance review
- [ ] Alignment with updated security policies
- [ ] Tool evaluation (new features, alternatives)

---

## Appendix: Quick Reference

### File Locations
| File | macOS | Linux |
|------|-------|-------|
| managed-settings.json | /Library/Application Support/Cortex/ | /etc/cortex/ |
| CLAUDE.md | ~/.claude/CLAUDE.md | ~/.claude/CLAUDE.md |
| User skills | ~/.claude/skills/ | ~/.claude/skills/ |
| Project AGENTS.md | <project root>/AGENTS.md | <project root>/AGENTS.md |

### Distribution URLs
| Resource | URL |
|----------|-----|
| Setup script | |
| ZIP download | |
| Remote skills repo | |
| AGENTS.md templates | |
| This playbook | |
```

## Exercise 2: Identify Your Distribution Channels

For each layer, decide the best distribution method for your organization:

| Layer | Options | Your Choice | Why |
|-------|---------|-------------|-----|
| Org policy | MDM, Ansible, Chef, manual | | |
| User standards | curl, ZIP, git, shared drive | | |
| Project config | Git, ZIP, wiki, stage | | |

## Exercise 3: Define Ownership

| Responsibility | Owner | Backup |
|----------------|-------|--------|
| managed-settings.json | | |
| CLAUDE.md template | | |
| Team skills | | |
| AGENTS.md templates | | |
| Playbook maintenance | | |
| Emergency response | | |

## Validation

Your playbook should answer:

| Question | Documented? |
|----------|-------------|
| How does a new employee get governance config? | [ ] Yes |
| How does a new project get AGENTS.md? | [ ] Yes |
| Who approves standard changes? | [ ] Yes |
| How are updates deployed? | [ ] Yes |
| What's the emergency procedure? | [ ] Yes |
| How often is governance reviewed? | [ ] Yes |

## What You Learned

1. **Governance is operational** — it needs processes, not just files
2. **Ownership must be explicit** — someone owns each layer
3. **Updates need a process** — ad-hoc changes create drift
4. **Emergencies happen** — have a procedure ready

## Workshop Complete

You've built a complete governance stack:

| Layer | Artifact | Purpose |
|-------|----------|---------|
| Org | managed-settings.json | IT-enforced policy |
| User | ~/.claude/CLAUDE.md | Always-on standards |
| User | team-standards skill | Procedural review |
| Project | AGENTS.md | Project-specific guardrails |
| Ops | Distribution playbook | Onboarding & maintenance |

## What's Next

### Immediate
1. **Deploy to your team** — start with user-level standards
2. **Create project templates** — AGENTS.md for common project types
3. **Schedule red team** — recurring governance validation

### Continue Learning
- [Campaign Engine Workshop](../../demo-campaign-engine/GUIDED_BUILD.md) — apply governance in a real build
- [Data Governance Skills](https://docs.snowflake.com/en/user-guide/governance-skills) — built-in Snowflake capabilities
- [Extensibility Docs](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility) — advanced customization

### Evolve Your Governance
After every incident or near-miss:
1. What constraint would have prevented this?
2. Add it to the appropriate layer
3. Update the distribution playbook
4. Communicate to the team

Governance is a living system. This workshop gave you the structure; your experience fills it with wisdom.
