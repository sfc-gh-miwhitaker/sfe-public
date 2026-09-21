# guide-delta-sharing-ip-allowlist — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Single-file reference guide (README.md) with no deployment artifacts. All SQL,
YAML, and Python is inline in fenced blocks — nothing in this directory is
separately runnable, by design, so nothing can be mistaken for tested code.

Structure follows the reader's actual decision sequence:

- Section 1: Which connection path — native catalog integration, provider-side
  direct sharing, an SPCS-hosted client, or a client behind your own static NAT
  address (Paths A through D)
- Section 2: The SPCS reference architecture (Path C — the path that yields an
  allowlistable egress IP, at the cost of it being a shared `/24`)
- Section 3: What stable egress IPs really give you, and where they fall short
- Section 4: The customer-NAT path (Path D — the only path that requires nothing
  new from the provider, at the cost of infrastructure outside Snowflake)
- Section 5: Operations, lifecycle, and gotchas

## Conventions

- **No vendor names.** The data provider is described generically as "a Delta
  Sharing provider using Open Sharing with IP allowlisting." Requirement shapes
  go in tables, not brand names. This keeps the repo's no-customer-names rule
  intact and makes the guide reusable.
- Bearer tokens, endpoints, and hostnames are always angle-bracket placeholders
  (`<delta_sharing_endpoint>`), never realistic-looking values — the repo runs
  `detect-secrets` on commit.
- Every DDL block must be syntax-validated via `only_compile = true` **where the
  authoring account allows it**. Snowflake runs syntax validation *before* the
  privilege check, so a privilege error on a `CREATE` statement confirms the syntax
  is sound — record that as validated. Schema-qualified DDL referencing the guide's
  placeholder database cannot be validated at all, because name resolution fails
  first; mark those honestly rather than implying they were checked. Python and YAML
  cannot be validated without a live provider and carry an explicit unvalidated banner.
- Cloud-provider infrastructure (NAT gateways, IAM, schedulers) is described at the
  **shape level only**. Do not add Terraform or provider-specific CLI recipes — the
  specifics vary enough per organisation that prescriptive IaC would be wrong more
  often than right, and it cannot be validated from here.
- Availability status is stated per cloud every time stable egress IPs come up.
  AWS commercial is GA, Azure is Preview, GCP is undocumented. Never write
  "stable egress IPs are supported" without the qualifier.
- Distinguish the *data plane* allowlist entry (Snowflake egress) from the
  *credential retrieval* allowlist entry (a human's corporate egress). Conflating
  them is the single most common onboarding failure.
- Keep the Path C / Path D comparison honest in both directions. Path C is not the
  default just because it stays inside Snowflake: it requires the provider to accept
  a shared `/24`, which a form asking for one to three addresses may refuse. Path D
  is not a last resort: provider guidance for this scenario commonly recommends a
  gateway outright. Never present either as the obvious answer.

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
