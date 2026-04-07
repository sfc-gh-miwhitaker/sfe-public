# Part 5: Environment Isolation

**Time:** ~10 minutes
**Goal:** Prevent cross-project bleed by separating memory, sessions, and context per customer engagement.

---

## What Can Bleed Between Projects?

| Risk | Default Behavior | Fix |
|------|-----------------|-----|
| Memory | Global memory in `~/.snowflake/cortex/memory/` | Set `SNOVA_MEMORY_LOCATION` per project |
| Session history | All sessions in `~/.snowflake/cortex/conversations/` | Use `--resume` with named sessions |
| Context window | CoCo may carry context from previous messages | Start fresh sessions for new projects |
| Settings | Global `settings.json` applies everywhere | Use `--config` flag for project overrides |

Most partner SE work is fine with shared sessions and global memory. The steps below are for engagements where you want hard isolation (regulated customers, competing engagements, NDAs).

---

## Step 5.1 — Per-project Memory Location

Set `SNOVA_MEMORY_LOCATION` to a project-specific path in your launch alias:

```bash
alias coco-acme='SNOVA_MEMORY_LOCATION=~/projects/acme/.coco-memory \
  cortex -c acme-prod --workdir ~/projects/acme'
```

CoCo will read and write memory files only in `~/projects/acme/.coco-memory/` for this session. Add `.coco-memory/` to your project's `.gitignore`.

```bash
echo ".coco-memory/" >> ~/projects/acme/.gitignore
```

---

## Step 5.2 — Named Sessions for Context Separation

Start a named session so you can resume the exact right context:

```bash
cortex -c acme-prod --workdir ~/projects/acme
# Inside CoCo:
# /fork acme-sprint3-data-pipeline
```

Resume it later:

```bash
cortex --resume last         # most recent session regardless of project
cortex -r <session-id>       # specific session by ID
```

List sessions to find the right one:

```bash
ls ~/.snowflake/cortex/conversations/
```

> **Tip:** Use `/fork` at the start of each sprint or feature to keep sessions scoped. Use `/compact` when a session gets long to save token budget without losing important context.

---

## Step 5.3 — Per-project Settings Override

If a customer project needs different defaults (e.g., a specific model, different timeout):

```bash
# ~/projects/acme/.coco-settings.json
{
  "env": {
    "CORTEX_AGENT_MODEL": "auto",
    "SNOVA_MEMORY_LOCATION": "/Users/you/projects/acme/.coco-memory"
  },
  "bashDefaultTimeoutMs": 300000
}
```

Launch with:

```bash
cortex -c acme-prod --config ~/projects/acme/.coco-settings.json --workdir ~/projects/acme
```

Add this to your alias:

```bash
alias coco-acme='cortex -c acme-prod \
  --config ~/projects/acme/.coco-settings.json \
  --workdir ~/projects/acme'
```

---

## Step 5.4 — Skills Isolation

By default, CoCo loads global skills from `~/.snowflake/cortex/skills/`. If you have customer-specific skills, either:

**Option A: Project-local skills (recommended)**
Put skills in `~/projects/acme/.claude/skills/`. CoCo reads `.claude/skills/` from the workdir automatically.

**Option B: Custom skills path**
```bash
cortex -c acme-prod --skills ~/projects/acme/.claude/skills/ --workdir ~/projects/acme
```

---

## Step 5.5 — The Full Isolation Alias

Putting it all together for a fully isolated customer session:

```bash
alias coco-acme='cortex \
  -c acme-prod \
  --workdir ~/projects/acme \
  --config ~/projects/acme/.coco-settings.json'
```

Where `~/projects/acme/.coco-settings.json` contains:
```json
{
  "env": {
    "SNOVA_MEMORY_LOCATION": "/Users/yourname/projects/acme/.coco-memory"
  }
}
```

---

## Isolation Level Guide

| Situation | What You Need |
|-----------|--------------|
| Two internal accounts, no NDAs | Connection flag only — no special isolation needed |
| Two customer accounts, light work | Connection flag + AGENTS.md connection hint |
| Competing customers or regulated data | Full isolation: separate memory + settings + skills |
| Long-running engagement (months) | Full isolation + named sessions with `/fork` per sprint |

---

## Checkpoint

- [ ] You know where CoCo stores memory by default
- [ ] You can set `SNOVA_MEMORY_LOCATION` per project if needed
- [ ] At least one alias in `~/.zshrc` uses `--workdir` to auto-load the right AGENTS.md
- [ ] You know how to resume a specific session with `--resume`

---

## You're Done

You now have:
- Named connections per customer in `connections.toml`
- Launch patterns for every situation (`-c` flag, env var, alias)
- AGENTS.md connection hints locking each project to the right account
- Isolation controls for memory, sessions, and settings

See [`reference/connections-template.toml`](../reference/connections-template.toml) and [`reference/aliases.sh`](../reference/aliases.sh) for copy-paste ready templates.
