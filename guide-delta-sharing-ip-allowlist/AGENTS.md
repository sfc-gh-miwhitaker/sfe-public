# guide-delta-sharing-ip-allowlist — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Single-file reference guide (README.md) with no deployment artifacts. All SQL,
YAML, and Python is inline in fenced blocks — nothing in this directory is
separately runnable, by design, so nothing can be mistaken for tested code.

Structure is answer-first, not a decision tree. The reader does not arrive with a
choice to make — they arrive with a vendor who has already made it for them:

- Section 1: **The answer.** Run the Delta Sharing client in your own cloud account
  behind a NAT gateway with a static IP, land via external stage. Self-contained:
  complete client module, stage DDL, marker-gated load, gotchas. Nothing in this
  section may depend on a later section.
- Section 2: The questions that make Section 1 unnecessary — the three provider
  questions, the internal Databricks question, and the native catalog integration
  DDL you get to use if any of them land
- Section 3: The SPCS alternative, viable **only** if the provider accepts a shared
  `/24`. Opens with the per-cloud availability gate. Its client is expressed as a
  delta against Section 1's, not duplicated
- Section 4: What stable egress IPs actually give you — the argument for why
  Section 1 is the answer and Section 3 usually is not
- Section 5: Operations, lifecycle, and SPCS gotchas

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
- **Headings must be searchable, not editorial.** A reader lands here via Ctrl+F or
  a GitHub anchor and searches for the mechanism — `NAT`, `static IP`, `Elastic IP`,
  `SPCS`. A heading like "The alternative that actually gives the provider one IP"
  is a magazine subhead and hid the load-bearing content for weeks. Name the
  mechanism in the heading.
- **Do not reintroduce Path A/B/C/D letters as the primary naming.** They are kept
  only as a one-line legend in Start Here for people holding old links. Sections are
  named by mechanism.
- Distinguish the *data plane* allowlist entry (Snowflake egress) from the
  *credential retrieval* allowlist entry (a human's corporate egress). Conflating
  them is the single most common onboarding failure, and it applies to every path,
  so it lives in Start Here rather than inside one section.
- Never re-add Databricks provider-to-provider sharing as a headline path. Anyone
  with a Databricks workspace and Unity Catalog is not reading this guide. It stays
  a one-paragraph internal question in Section 2.

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
