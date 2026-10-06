# guide-delta-sharing-ip-allowlist — Project Instructions

<!-- Global rules (data integrity, SQL standards, security) apply automatically
     via ~/.claude/CLAUDE.md and ~/.claude/rules/. Do not duplicate them here. -->

## Architecture

Single-file reference guide (README.md) with no deployment artifacts. All SQL,
YAML, and Python is inline in fenced blocks — nothing in this directory is
separately runnable. Readers must adapt and qualify the reference design.

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
- Validate SQL with the required objects and privileges in a disposable environment.
  A permission or name-resolution error is not successful validation. Parse Python
  and YAML locally, then test behavior with an authorized provider. Keep detailed
  execution evidence outside the repository; maintain reader-facing prerequisites
  and the deployment validation checklist instead of an authoring ledger.
- Cloud-provider infrastructure (NAT gateways, IAM, schedulers) is described at the
  **shape level only**. Do not add Terraform or provider-specific CLI recipes — the
  specifics vary enough per organisation that prescriptive IaC would be wrong more
  often than right, and it cannot be validated from here.
- Availability status is stated per cloud every time stable egress IPs come up.
  AWS commercial is GA, Azure is Preview, GCP is undocumented. Never write
  "stable egress IPs are supported" without the qualifier.
- **Headings must be searchable, not editorial.** A reader lands here via Ctrl+F or
  a GitHub anchor and searches for the mechanism — `NAT`, `static IP`, `Elastic IP`,
  `SPCS`. Name the mechanism in the heading so readers can find it.
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
