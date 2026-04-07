# Governance Audit Worksheet

Document your organization's AI coding tool governance setup.

---

## Organization Information

| Field | Value |
|-------|-------|
| Organization name | |
| Date completed | |
| Completed by | |
| Review date | |

---

## 1. Org-Level Policy (managed-settings.json)

### Status
- [ ] Not implemented
- [ ] Planned
- [ ] Deployed to test group
- [ ] Deployed organization-wide

### Configuration

| Setting | Configured Value | Rationale |
|---------|------------------|-----------|
| `dangerouslyAllowAll` | | |
| `onlyAllow` accounts | | |
| `minimumVersion` | | |
| `forceSandboxEnabled` | | |
| `showManagedBanner` | | |
| `bannerText` | | |

### Deployment Method
- [ ] Jamf Pro
- [ ] Microsoft Intune
- [ ] SCCM
- [ ] Ansible
- [ ] Chef
- [ ] Puppet
- [ ] Manual
- [ ] Other: ________________

### Deployment Owner
| Role | Name | Contact |
|------|------|---------|
| Primary owner | | |
| Backup | | |

---

## 2. User-Level Standards (~/.claude/CLAUDE.md)

### Status
- [ ] Not implemented
- [ ] Template created
- [ ] Distributed to pilot group
- [ ] Distributed organization-wide

### Distribution Method
- [ ] curl one-liner
- [ ] ZIP download
- [ ] Remote skill (`/skill add`)
- [ ] Shared drive
- [ ] Other: ________________

### Distribution Location
| Resource | URL/Path |
|----------|----------|
| Setup script | |
| ZIP download | |
| Documentation | |

### Standards Included
- [ ] SQL quality rules (SELECT *, sargable predicates)
- [ ] Security rules (no credentials in code)
- [ ] Destructive operation warnings
- [ ] Role discipline
- [ ] Custom: ________________

### Owner
| Role | Name | Contact |
|------|------|---------|
| Standards owner | | |
| Distribution owner | | |

---

## 3. Team Standards Skill

### Status
- [ ] Not implemented
- [ ] Template created
- [ ] Distributed to pilot group
- [ ] Distributed organization-wide

### Skill Capabilities
- [ ] Credential scanning
- [ ] SQL quality review
- [ ] Destructive operation check
- [ ] Naming convention check
- [ ] Compaction recovery
- [ ] Custom: ________________

### Location
| Resource | Path |
|----------|------|
| User installation | ~/.claude/skills/team-standards/ |
| Source repository | |

---

## 4. Project Templates (AGENTS.md)

### Available Templates
| Template Name | Use Case | Location |
|---------------|----------|----------|
| | | |
| | | |
| | | |

### Template Owner
| Role | Name | Contact |
|------|------|---------|
| Template owner | | |

---

## 5. Distribution Playbook

### Status
- [ ] Not created
- [ ] Draft
- [ ] Reviewed
- [ ] Published

### Location
| Resource | URL/Path |
|----------|----------|
| Playbook document | |
| Wiki/Confluence page | |

### Key Contacts

| Role | Name | Contact |
|------|------|---------|
| Governance owner | | |
| MDM admin | | |
| Security lead | | |
| On-call escalation | | |

---

## 6. Testing & Validation

### Last Red Team Exercise
| Field | Value |
|-------|-------|
| Date | |
| Tester | |
| Result | Pass / Fail / Partial |
| Gaps identified | |

### Next Scheduled Test
| Field | Value |
|-------|-------|
| Date | |
| Scope | |
| Owner | |

---

## 7. Change Management

### Change Request Process
| Step | Owner | SLA |
|------|-------|-----|
| Submit request | | |
| Review | | |
| Approval | | |
| Implementation | | |
| Communication | | |

### Recent Changes
| Date | Change | Owner | Status |
|------|--------|-------|--------|
| | | | |
| | | | |

---

## 8. Gaps & Remediation

### Known Gaps
| Gap | Severity | Remediation | Owner | Due |
|-----|----------|-------------|-------|-----|
| | Critical/High/Medium/Low | | | |
| | | | | |

### Planned Improvements
| Improvement | Priority | Owner | Target Date |
|-------------|----------|-------|-------------|
| | | | |
| | | | |

---

## 9. Review Schedule

| Review Type | Frequency | Next Date | Owner |
|-------------|-----------|-----------|-------|
| Red team exercise | | | |
| Standards review | | | |
| Playbook review | | | |
| Full governance audit | | | |

---

## Sign-off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Governance owner | | | |
| Security lead | | | |
| IT lead | | | |
