# Contributing

Pair-programmed by SE Community + Cortex Code

Reading guides and downloading examples does not require contributor tooling.
Corrections are welcome; this repository does not provide production support.
Keep customer data, account identifiers, credentials, and meeting details out of
issues, pull requests, fixtures, and screenshots.

## Developer Setup

Install Git, [pre-commit](https://pre-commit.com/#install), and
[gitleaks](https://github.com/gitleaks/gitleaks#installing). From your repository
checkout, inspect existing hook configuration before installing local hooks:

```bash
git config --show-origin --get core.hooksPath || true
pre-commit install
pre-commit run --all-files
```

`pre-commit install` normally installs hooks only in this checkout. If an existing
`core.hooksPath` is configured, it may refuse installation. Do not unset a managed
hook path just for this project; use the existing dispatcher if appropriate, or
run `pre-commit run --all-files` explicitly before proposing changes.

### Optional Machine-Wide Dispatcher

`shared/setup-dev.sh` is an optional advanced setup, not a prerequisite. Review it
before running `bash shared/setup-dev.sh`. It installs missing tools, writes a
dispatcher under your home directory, and **replaces the global `core.hooksPath`**.
That affects every repository on your machine. Record any existing value first;
do not use this option on a managed machine without approval.

## Making Changes

Read [AGENTS.md](AGENTS.md) for repository conventions. Keep edits scoped to the
guide or example being corrected. Preserve the attribution, reference-only notice,
and honest feature-availability caveats. Do not advance a verification or expiry
date merely because formatting changed.

When adding or retiring a project, update the root catalog and the intent paths
in AGENTS.md. Keep catalog descriptions to one sentence; detailed gotchas belong
in the guide. Every active project needs a top-level `guide-*` or `demo-*`
directory and a README.md so project retrieval can discover it.

## Verification and Retirement

Projects expire at most **60 calendar days after substantive verification**.
Retirement is the default. An expiry is not an invitation to automatically add
another 60 days. Choose keep, merge, or archive; a keep decision must include a
review of the core technical claims, feature availability, security boundaries,
and documented workflows against current authoritative sources. Run the relevant
safe checks, record results and limitations, and check links and entry points.
A narrow correction, formatting, a commit, or a successful site build alone is
not substantive verification. Merging does not reset inherited review dates.

Keep detailed review evidence and maintenance decisions outside this public
repository. Git timestamps alone are not evidence of substantive verification.
Set the README's `Last verified` and `Expires` fields and expiry badge consistently.
The expiry may be shorter than 60 days; do not extend a shorter deadline merely
to use the full allowance. Automation checks date consistency, not technical correctness.

Existing `Review baseline` dates are conservative retirement deadlines, not
verification claims. Do not advance them. Renewal requires substantive review
and a `Last verified` date; new projects must use `Last verified`.

From the repository root:

```bash
python3 .github/scripts/expire-projects.py --check
python3 .github/scripts/expire-projects.py --dry-run
```

The daily archive job retires a project **on its expiry date** (UTC) or later.
It records old reader routes before moving files into `_archive/`, marks the
archived README, removes active catalog/intent entries and publication settings,
and rebuilds the reader site. It never deletes deployed Snowflake objects.
Before publishing an archival change, check remaining references and run the
lifecycle, retrieval, site, and browser tests. `_archive/` stays local and
gitignored. Published source remains available in Git history, not as a second
catalog of retired guides.

If an older archive already exists, the default is to stop rather than overwrite
it. Use `--preserve-previous` for a deliberate retirement into a dated directory;
an existing dated directory also blocks the operation. During metadata migration,
`--sync-headers` uses README review dates and only shortens expiry; it does not grant
a renewal. Invalid proposed metadata is rejected before any README is written.

## Validation

Run the relevant project checks plus the repository's scoped pre-commit checks.
Run `python3 .github/scripts/check-public-content.py` to inspect all tracked and
nonignored new files, including Markdown and committed assistant instructions.
The same check runs in CI without depending on staged changes. It reports paths
and rule names, not matched confidential text. Binary review items need manual
visual inspection and confirmation that their data and sources may be published.
Secret and text scanners do not certify screenshots, product availability, or
customer-data provenance. Use explicit placeholders and public primary sources.

In a pull request, describe what changed, the evidence for technical corrections,
what you tested, and anything you could not verify. Do not execute example SQL in
a shared account just to validate a documentation-only change.

The Pages build and preview instructions live in [site/README.md](site/README.md).
