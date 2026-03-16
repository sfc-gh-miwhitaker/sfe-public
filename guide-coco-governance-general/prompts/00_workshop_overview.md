# Workshop Overview

## Learning Objectives

By the end of this workshop, you will:

1. **See where AI instructions come from** — inspect every layer of the guidance hierarchy
2. **Create org-level policy** — managed-settings.json deployed via MDM
3. **Build user-level standards** — CLAUDE.md + team skill distributed via curl/ZIP
4. **Add project constraints** — AGENTS.md guardrails
5. **Test your controls** — red team exercise proving governance works
6. **Document distribution** — operational playbook for onboarding

## Prerequisites

| Requirement | Why |
|-------------|-----|
| Cortex Code CLI installed | Required for all exercises |
| Snowflake account access | Testing SQL governance rules |
| Admin access on your machine | Creating managed-settings.json (even locally) |
| ~75 minutes | Focused workshop time |

**New to Cortex Code?** Complete [guide-coco-setup](../../guide-coco-setup/README.md) first.

## What You'll Build

```
Your Governance Stack
├── /Library/Application Support/Cortex/managed-settings.json  (org policy)
├── ~/.claude/CLAUDE.md                                        (user standards)
├── ~/.claude/skills/team-standards/SKILL.md                   (team skill)
├── <project>/AGENTS.md                                        (project constraints)
└── distribution-playbook.md                                   (ops documentation)
```

## The Core Narrative

Each step addresses one "AI is magic" fear:

| Step | Fear | Reality You'll Prove |
|------|------|----------------------|
| 1 | "It's a black box" | You can inspect every instruction layer |
| 2 | "IT can't control this" | managed-settings.json is standard MDM deployment |
| 3 | "Standards drift" | CLAUDE.md survives context compaction |
| 4 | "Projects have different needs" | AGENTS.md provides scoped constraints |
| 5 | "I can't prove it works" | Red team exercise validates controls |
| 6 | "Onboarding is chaos" | Distribution playbook systematizes it |

## Time Breakdown

| Step | Activity | Time |
|------|----------|------|
| 1 | Visibility — inspect hierarchy | 10 min |
| 2 | Org Policy — managed-settings.json + MDM | 15 min |
| 3 | User Standards — CLAUDE.md + team skill | 15 min |
| 4 | Project Scope — AGENTS.md constraints | 10 min |
| 5 | Assurance — red team exercise | 15 min |
| 6 | Distribution — operational playbook | 10 min |
| **Total** | | **~75 min** |

## How to Use This Workshop

### Option 1: Guided Mode (Recommended)
```bash
cd guide-coco-governance
cortex
```
Then: *"Walk me through the governance workshop step by step, starting with Step 1."*

### Option 2: Self-Paced
Open each `prompts/0X_*.md` file in order and follow the exercises.

### Option 3: Team Facilitation
One person shares screen and runs exercises while team discusses governance decisions. Pause after each step to decide how it applies to your organization.

## What This Workshop Is NOT

- **Not a Cortex Code tutorial** — assumes you can already use CoCo
- **Not a security audit** — teaches governance patterns, not security certification
- **Not production-ready** — templates require customization for your org
- **Not comprehensive** — covers the 80% case, not every edge case

## Next Steps After Workshop

1. **Customize templates** for your organization's naming conventions and policies
2. **Test in staging** before deploying managed-settings.json to production
3. **Schedule review** — governance evolves with your team's experience
4. **Build on this** — the [campaign-engine workshop](../../demo-campaign-engine/GUIDED_BUILD.md) uses these patterns in a real build
