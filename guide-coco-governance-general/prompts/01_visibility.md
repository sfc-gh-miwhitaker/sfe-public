# Step 1: Visibility — Inspect the Guidance Hierarchy

## Governance Lesson: See Exactly Where Instructions Come From

The "black box" fear dissolves when you can inspect every layer. This step teaches you where to look.

**Time:** 10 minutes | **Build:** Nothing (inspection only)

## Before You Start

- [ ] Cortex Code CLI is installed and running
- [ ] You're in a directory with no AGENTS.md (we'll add one later)

## The Hierarchy (Top to Bottom)

```
1. Organization    /Library/Application Support/Cortex/managed-settings.json (macOS)
                   /etc/cortex/managed-settings.json (Linux)
   
2. User           ~/.claude/CLAUDE.md
                  ~/.claude/skills/
                  ~/.snowflake/cortex/settings.json
                  ~/.snowflake/cortex/skills/

3. Project        AGENTS.md (or CLAUDE.md) at repo root
                  .cortex/skills/ or .claude/skills/

4. Session        Temporary skills added via /skill add
                  /plan mode, model overrides

5. Built-in       ~50+ bundled skills (semantic views, dbt, governance, etc.)
```

Higher layers override lower ones. Org policy beats everything; built-in defaults lose to everything.

## Exercise 1: Inspect Built-in Skills

In Cortex Code, run:

```
/skill list
```

**What to notice:**
- Bundled skills (semantic-view, dbt, data-governance, etc.)
- User skills (if you have any in `~/.claude/skills/`)
- Project skills (if the current directory has `.cortex/skills/`)

**Ask CoCo:**
> "List all the skills you currently have loaded and where each one comes from."

The AI should enumerate the hierarchy — this proves it knows its own instruction sources.

## Exercise 2: Inspect User-Level Files

Check what user-level configuration exists:

```bash
# User-level CLAUDE.md (always-on standards)
cat ~/.claude/CLAUDE.md 2>/dev/null || echo "No user-level CLAUDE.md found"

# User-level skills
ls -la ~/.claude/skills/ 2>/dev/null || echo "No user-level skills directory"

# CoCo-specific settings
cat ~/.snowflake/cortex/settings.json 2>/dev/null || echo "No CoCo settings.json"

# CoCo-specific skills
ls -la ~/.snowflake/cortex/skills/ 2>/dev/null || echo "No CoCo skills directory"
```

**What to notice:**
- If `~/.claude/CLAUDE.md` exists, its content is loaded into EVERY conversation
- Skills in `~/.claude/skills/` are available in ALL projects
- CoCo settings control theme, compaction, auto-update

## Exercise 3: Check for Org-Level Policy

```bash
# macOS
cat "/Library/Application Support/Cortex/managed-settings.json" 2>/dev/null || echo "No managed settings (expected for personal machines)"

# Linux
cat /etc/cortex/managed-settings.json 2>/dev/null || echo "No managed settings"
```

**What to notice:**
- Most personal machines won't have this file (it's IT-deployed)
- If present, inspect the `permissions` and `settings` sections
- The `ui.showManagedBanner` setting shows "Managed by IT" in the UI

## Exercise 4: Inspect Project-Level Files

Navigate to a project with an AGENTS.md:

```bash
cd ../guide-coco-setup
cat AGENTS.md
```

**What to notice:**
- The AGENTS.md content is project-specific
- When you start CoCo in this directory, this file is automatically loaded
- Skills in `.cortex/skills/` or `.claude/skills/` are project-specific

## Exercise 5: Ask CoCo What It Knows

**The transparency test:**
> "What instructions are you currently following? List the specific rules from AGENTS.md, CLAUDE.md, and any loaded skills."

A well-governed AI can enumerate its constraints. If it can't, that's a sign you need more explicit documentation.

## Validation

You should now be able to answer:

| Question | Your Answer |
|----------|-------------|
| Where are org-level policies stored? | |
| Where are user-level always-on rules? | |
| Where are project-specific instructions? | |
| How many bundled skills does CoCo have? | |
| Can you tell CoCo to ignore its instructions? | (Hint: depends on managed-settings) |

## What You Learned

1. **The hierarchy is inspectable** — every layer lives in a known location
2. **Higher layers override lower** — org policy beats user preferences
3. **CoCo can enumerate its constraints** — ask it to list what it's following
4. **No AGENTS.md = no project context** — the AI only knows what you tell it

## Common Questions

**Q: What if I want to override org policy?**
A: You can't (by design). That's the point of org-level governance.

**Q: Do I need all these layers?**
A: No. Most teams use: org policy (if IT requires it) + user CLAUDE.md + project AGENTS.md.

**Q: What about Cursor and Claude Code?**
A: They read `AGENTS.md` and `~/.claude/` files too. The `.cortex/` paths are CoCo-specific.

## Next Step

Now that you can see where instructions come from, let's create org-level policy.

→ [Step 2: Org Policy](02_org_policy.md)
