# AI Governance Distribution Playbook

> **Template:** Replace all `[PLACEHOLDER]` sections with your organization's details.

## Overview

This document describes how [ORGANIZATION] deploys and maintains AI coding tool governance for Cortex Code, Cursor, and Claude Code.

**Last updated:** [DATE]  
**Owner:** [TEAM/PERSON]  
**Review frequency:** Quarterly

---

## 1. New Employee Onboarding

### Org-Level Policy (managed-settings.json)

| Item | Value |
|------|-------|
| Method | [MDM (Jamf/Intune) / Config Management (Ansible) / Manual] |
| Trigger | [Auto-deploy on device enrollment / Manual IT ticket] |
| Verification | User sees "[COMPANY]" banner in Cortex Code |
| Owner | [IT Security Team] |
| SLA | Config deployed within [24 hours] of device enrollment |

### User-Level Standards (~/.claude/)

| Item | Value |
|------|-------|
| Method | [curl script / ZIP download / Remote skill / Shared drive] |
| Location | [URL or network path] |
| Owner | [Team/Person] |
| SLA | Employee completes within [first week] |

**Instructions for new employees:**
1. [Open Terminal / Download ZIP from...]
2. [Run curl command / Unzip to home directory]
3. [Start Cortex Code and run `/skill list`]
4. [Verify team-standards skill appears]

### Verification Checklist

New employees should confirm:
- [ ] Banner shows managed status (if applicable)
- [ ] `/skill list` shows team-standards skill
- [ ] Test query refuses SELECT *
- [ ] Destructive operations require confirmation

---

## 2. New Project Setup

### AGENTS.md Templates

| Template | Use Case | Location |
|----------|----------|----------|
| `agents-data-pipeline.md` | ETL, data pipelines | [URL] |
| `agents-analytics.md` | BI, dashboards | [URL] |
| `agents-application.md` | Application code | [URL] |

### Project Onboarding Steps

1. Copy appropriate template to project root as `AGENTS.md`
2. Update Snowflake environment section:
   - Database: [YOUR_DATABASE]
   - Schema: [YOUR_SCHEMA]
   - Warehouse: [YOUR_WAREHOUSE]
3. Add project-specific constraints
4. Commit to repository
5. Verify: start CoCo and ask it to list its constraints

### Project Skill (Optional)

For projects needing specialized review workflows:
- **Template location:** [URL]
- **Installation:** Copy `.cortex/skills/` directory to project root

---

## 3. Standard Updates

### Change Request Process

| Step | Action | Owner |
|------|--------|-------|
| 1 | Submit request to [Jira board / GitHub issue / Email] | Requester |
| 2 | Review by [Security / Governance Committee] | Reviewer |
| 3 | Approval from [Role/Person] | Approver |
| 4 | Implementation | [Team] |
| 5 | Communication | [Team] |

### Deployment Process

#### Org-Level (managed-settings.json)
- **Change window:** [Day/time, e.g., Tuesdays 2-4pm PT]
- **Notification:** [Email to all-staff / Slack #it-announcements]
- **Rollback:** MDM rollback to previous version

#### User-Level (CLAUDE.md, skills)
- **Notification:** [Email / Slack / Wiki update]
- **User action:** [Required / Not required]
- **Verification:** [How users confirm update applied]

#### Project-Level (AGENTS.md templates)
- **Notification:** [Email to project leads / Wiki update]
- **Existing projects:** [Auto-PR / Advisory only / Manual update]

### Version Tracking

| Component | Version Location |
|-----------|------------------|
| managed-settings.json | `ui.bannerText` includes version |
| CLAUDE.md | Comment at top: `# v1.2.0 - [DATE]` |
| Skills | Frontmatter: `version: 1.2.0` |

---

## 4. Emergency Procedures

### Urgent Policy Change (Security Incident)

| Timeline | Action | Owner |
|----------|--------|-------|
| Immediate | Update managed-settings.json via MDM push | [IT Security] |
| Within 1 hour | Email all-staff with impact summary | [Communications] |
| Within 4 hours | Update user-level config distribution | [DevOps] |
| Within 24 hours | Post-incident review | [Security Team] |

### Emergency Contacts

| Role | Name | Contact |
|------|------|---------|
| MDM Administrator | [Name] | [Email/Phone] |
| Security Lead | [Name] | [Email/Phone] |
| Governance Owner | [Name] | [Email/Phone] |
| On-call Escalation | [Name] | [Email/Phone] |

### Rollback Procedures

| Component | Rollback Method |
|-----------|-----------------|
| Org policy | MDM rollback to previous config version |
| User config | Redirect download URL to previous version |
| Project templates | Git revert and notify project leads |

---

## 5. Periodic Review

### Monthly
- [ ] Review red team test results
- [ ] Check for new CoCo features affecting governance
- [ ] Process change request backlog

### Quarterly
- [ ] Full red team exercise (Step 5 checklist)
- [ ] Update templates for new patterns
- [ ] Training refresh for recent hires
- [ ] Review this playbook for accuracy

### Annually
- [ ] Comprehensive governance review
- [ ] Alignment with updated security policies
- [ ] Tool evaluation (new features, alternatives)
- [ ] Audit trail review

---

## Appendix A: File Locations

| File | macOS | Linux |
|------|-------|-------|
| managed-settings.json | `/Library/Application Support/Cortex/` | `/etc/cortex/` |
| CLAUDE.md | `~/.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| User skills | `~/.claude/skills/` | `~/.claude/skills/` |
| CoCo settings | `~/.snowflake/cortex/settings.json` | `~/.snowflake/cortex/settings.json` |
| Project AGENTS.md | `<project root>/AGENTS.md` | `<project root>/AGENTS.md` |

## Appendix B: Distribution URLs

| Resource | URL |
|----------|-----|
| Setup script (curl) | [https://...] |
| ZIP download | [https://...] |
| Remote skills repo | [https://github.com/...] |
| AGENTS.md templates | [https://...] |
| This playbook | [https://...] |

## Appendix C: Governance Hierarchy

```
1. Organization (highest priority)
   └── managed-settings.json (IT-deployed, user cannot override)

2. User
   ├── ~/.claude/CLAUDE.md (always-on rules)
   └── ~/.claude/skills/ (procedural skills)

3. Project
   ├── AGENTS.md (project constraints)
   └── .cortex/skills/ (project-specific skills)

4. Session (lowest priority)
   └── Temporary skills, /plan mode, model overrides
```
