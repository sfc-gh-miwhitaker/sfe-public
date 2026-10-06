# guide-ad-platform-integrations - Project Instructions

<!-- Global rules apply automatically via ~/.claude/CLAUDE.md and ~/.claude/rules/.
     Repo-wide guide conventions live in the root AGENTS.md. -->

Pair-programmed by SE Community + Cortex Code

## Architecture

A reference guide organized by direction and mechanism:

1. Google Ads Data Manager: outbound Customer Match and offline conversions.
2. Meta Conversions API skill: outbound conversion events; Meta ads MCP: campaign
   tools, with access as described in the linked public announcement.
3. Openflow Meta Ads and Google Ads connectors: inbound advertising data.
4. Meta audience-list activation: a separate route from conversion events.

The README owns prerequisites, availability, vendor contradictions, and references.
The two SQL files are copy/paste setup references, not a combined deployment.
Keep ELI5.md consistent with the README.

## Conventions

- Preserve the distinction between platform availability and connector availability.
- Describe prerequisites and limitations, not adoption recommendations or sales positioning.
- Cite public vendor documentation for availability, maturity labels, and dates.
- Keep Meta ads MCP separate from the Openflow Meta Ads connector. Do not describe
  MCP campaign actions as read-only or conversion events as audience-list activation.
- Google Ads Data Manager uses a PAT in its password field and exposes no role field.
  Preserve the PAT role restriction and the connector identity's secondary-role controls.
- Preserve double-quoted Customer Match column headers and the documented hex hashing
  format. Keep the vendor documentation contradictions visible to readers.
- Keep setup identifiers consistent across schema creation, views, grants, and teardown.
  Do not parameterize only part of an object path.
- Part 1's restricted secondary roles and Openflow's documented user setup serve different
  identities. Do not make them identical without checking both workflows.
- Keep optional and teardown sections clearly separated from initial setup.

## Snowflake Environment

Part 1 uses GOOGLE_ADS_DM_ROLE, GOOGLE_ADS_DM_SVC, SFE_ADS_ACTIVATION_WH,
MARKETING.ACTIVATION, and the reader's MARKETING.CORE.CUSTOMER source.

Part 3 uses OPENFLOW_ADMIN, OPENFLOW_MONITOR, OPENFLOW_CONFIG.NETWORKING,
META_ADS_EGRESS, GOOGLE_ADS_EGRESS, META_ADS_EAI, GOOGLE_ADS_EAI, and separate
Meta Ads and Google Ads destination databases.

## Maintenance

Use the README's review and expiry dates and the repository retirement policy.
Keep execution evidence and editorial notes outside the public repository.

At substantive review, check:

- Connector status, supported Meta API version, and configuration-generation changes.
- Google's current authentication, hashing, and import-scheduling documentation.
- Clean-room activation availability and the published legacy-interface sunset dates.
- Public Meta ads MCP access instructions and the CAPI sample's prerequisites and objects.
- Marketplace titles, providers, and listing URLs against current published listings.

## Validation

Use a disposable environment with the required privileges. Confirm both allowed and
blocked operations with the connector identity and secondary roles disabled. Verify
normalization, consent, age filtering, and NULL handling with synthetic records.

For Openflow, validate the deployment, runtime, connector, and source-to-target run;
creating prerequisites alone does not prove ingestion works. A permission or name-resolution
error is not a successful deployment or a substitute for end-to-end testing.

## Key Commands

From the repository root:

```bash
python3 .github/scripts/check-public-content.py
pre-commit run --files guide-ad-platform-integrations/README.md
```
