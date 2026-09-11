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

## Validation

Run the relevant project checks plus the repository's scoped pre-commit checks.
In a pull request, describe what changed, the evidence for technical corrections,
what you tested, and anything you could not verify. Do not execute example SQL in
a shared account just to validate a documentation-only change.

The Pages build and preview instructions live in [site/README.md](site/README.md).
