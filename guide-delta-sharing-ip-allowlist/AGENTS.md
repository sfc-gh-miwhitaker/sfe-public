# guide-delta-sharing-ip-allowlist — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Single-file reference guide (README.md) with no deployment artifacts. All SQL,
YAML, and Python is inline in fenced blocks — nothing in this directory is
separately runnable, by design, so nothing can be mistaken for tested code.

Structure follows the reader's actual decision sequence:

- Section 1: Which connection path — native catalog integration, provider-side
  direct sharing, or an SPCS-hosted client
- Section 2: The SPCS reference architecture (the path that yields an
  allowlistable egress IP)
- Section 3: What stable egress IPs really give you, and where they fall short
- Section 4: Operations, lifecycle, and gotchas

## Conventions

- **No vendor names.** The data provider is described generically as "a Delta
  Sharing provider using Open Sharing with IP allowlisting." Requirement shapes
  go in tables, not brand names. This keeps the repo's no-customer-names rule
  intact and makes the guide reusable.
- Bearer tokens, endpoints, and hostnames are always angle-bracket placeholders
  (`<delta_sharing_endpoint>`), never realistic-looking values — the repo runs
  `detect-secrets` on commit.
- Every DDL block must compile via `only_compile = true`. Python and YAML cannot
  be validated without a live provider and carry an explicit unvalidated banner.
- Availability status is stated per cloud every time stable egress IPs come up.
  AWS commercial is GA, Azure is Preview, GCP is undocumented. Never write
  "stable egress IPs are supported" without the qualifier.
- Distinguish the *data plane* allowlist entry (Snowflake egress) from the
  *credential retrieval* allowlist entry (a human's corporate egress). Conflating
  them is the single most common onboarding failure.

## Key Commands

```bash
# Verify the guide stays reference-sized (run from this directory)
wc -l README.md

# Confirm no bare hostnames or tokens leaked into content
grep -nE '(eyJ|bearerToken"[[:space:]]*:[[:space:]]*"[A-Za-z0-9])' README.md

# Confirm inline Python and YAML still parse after an edit
python3 -c "$(printf '%s\n' \
  'import re,ast,pathlib' \
  'md=pathlib.Path("README.md").read_text()' \
  '[ast.parse(b) for b in re.findall(r"```python\n(.*?)```",md,re.S)]' \
  'print("python blocks parse OK")')"
```

```sql
-- The one query that must stay correct as the platform changes
SELECT
    t.VALUE:ipv4_prefix::VARCHAR  AS cidr,
    t.VALUE:effective::TIMESTAMP  AS effective_from,
    t.VALUE:expires::TIMESTAMP    AS expires_at
FROM TABLE(FLATTEN(input => PARSE_JSON(SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES()))) AS t
ORDER BY expires_at;
```
