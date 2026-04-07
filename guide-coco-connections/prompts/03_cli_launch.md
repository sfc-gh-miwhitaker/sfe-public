# Part 3: Launch Patterns

**Time:** ~10 minutes
**Goal:** Learn every way to launch Cortex Code with a specific connection. Leave with a reliable one-liner per project.

---

## The Four Launch Patterns

### Pattern A — CLI Flag (explicit, one-off)

```bash
cortex --connection acme-prod
# or short form:
cortex -c acme-prod
```

Use when: quick one-off sessions, testing a connection, scripts.

---

### Pattern B — Environment Variable (session-scoped)

```bash
export SNOWFLAKE_CONNECTION=acme-prod
cortex
```

Use when: you're working in the `acme-prod` project for the whole shell session and want every `cortex` invocation to default to that connection without typing `-c` each time.

Clear it when you're done:

```bash
unset SNOWFLAKE_CONNECTION
```

---

### Pattern C — Shell Alias (fastest, recommended for daily use)

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
alias coco-acme='cortex -c acme-prod --workdir ~/projects/acme'
alias coco-globex='cortex -c globex-dev --workdir ~/projects/globex'
alias coco-internal='cortex -c internal --workdir ~/projects/internal'
```

Reload and use:

```bash
source ~/.zshrc
coco-acme          # opens CoCo connected to acme-prod, in the right directory
```

> **Why `--workdir`?** CoCo reads `AGENTS.md` from the working directory. Passing `--workdir` ensures the right project instructions are loaded, even if you run the alias from a different location.

---

### Pattern D — Per-project .env (for repo-based projects)

Create a `.env` file at the project root (git-ignored):

```bash
# ~/projects/acme/.env
SNOWFLAKE_CONNECTION=acme-prod
```

Load it before launching:

```bash
source ~/projects/acme/.env && cortex
```

Or add a `Makefile` target:

```makefile
coco:
	@source .env && cortex
```

Then: `make coco`

---

## Combining Flags

You can combine connection, workdir, and model in one command:

```bash
cortex -c acme-prod --workdir ~/projects/acme --model auto
```

Non-interactive (print) mode with a specific connection:

```bash
cortex -c acme-prod -p "SELECT CURRENT_ACCOUNT(), CURRENT_ROLE();"
```

This is useful in scripts to verify which account a session is targeting before doing real work.

---

## Priority Order

When multiple sources set the connection, Cortex Code resolves in this order:

| Priority | Source | Example |
|----------|--------|---------|
| 1 (highest) | CLI flag | `cortex -c acme-prod` |
| 2 | `SNOWFLAKE_CONNECTION` env var | `export SNOWFLAKE_CONNECTION=acme-prod` |
| 3 | `settings.json` `env.SNOWFLAKE_CONNECTION` | Persistent default |
| 4 (lowest) | `default_connection_name` in `config.toml` | Fallback when no `-c` or env var is set |

---

## Recommended Daily Workflow

1. `coco-acme` — launches CoCo connected to acme-prod with project context loaded
2. CoCo reads `AGENTS.md` from the workdir automatically
3. Start your session — you're in the right account, right context
4. When switching customers: `exit` → `coco-globex`

---

## Checkpoint

- [ ] You can launch `cortex -c <name>` for at least two different connections
- [ ] You have at least one alias in `~/.zshrc` / `~/.bashrc`
- [ ] You understand the priority order if multiple sources are set

**Next:** [Part 4 — Per-project AGENTS.md](04_project_agents.md)
