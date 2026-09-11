# Reader Site

Pair-programmed by SE Community + Cortex Code

This is a presentation layer over the existing guides, not a second documentation
tree. `build.mjs` stages approved files, converts Markdown and Mermaid, and then
Jekyll applies the pinned Just the Docs theme. Do not edit `.build/` output.

Just the Docs 0.12.0 still uses deprecated Sass imports, global built-ins, and color
functions. `_config.yml` silences only those three upstream deprecation categories
while the pinned theme awaits modernization. This does not fix the upstream Sass;
compiler errors and other warning categories remain visible. Reassess the list
when upgrading the theme rather than suppressing all Sass warnings.

## Build and Preview

Requires Node.js 22+, Ruby 4.0, Bundler, and Google Chrome. On macOS, the default
Chrome application path is detected. Elsewhere set `CHROME_PATH` to its executable.
From the repository root:

```bash
npm --prefix site ci --ignore-scripts
export BUNDLE_GEMFILE="$PWD/site/Gemfile"
export BUNDLE_PATH="$PWD/site/vendor/bundle"
bundle install
npm --prefix site run stage
bundle exec jekyll build --source "$PWD/site/.build/source" --destination "$PWD/site/.build/public"
npm --prefix site run check
npm --prefix site test
npm --prefix site run preview
```

Open `http://127.0.0.1:4173/sfe-public/`. With that server running:

```bash
npm --prefix site run test:browser
python3 -m unittest discover -s shared/tests -v
node --test guide-ai-spend-consolidation/tests/workbook.test.cjs
node guide-ai-spend-consolidation/tests/workbook.browser.cjs
```

## Publication Boundary

`publication.json` is the allowlist. Git-tracked root-level reader Markdown, docs/diagrams,
and SQL example files in guide/demo directories are permitted by explicit patterns;
the workbook, CoWork action menu, and selected example files are named exceptions. Agent instructions,
hidden paths, tests, applications, and dependencies are not published. Links to
excluded source files point to their GitHub viewer instead. `.build/inventory.json`
records exactly which source files were included and any inherited broken links.

All projects retain directory URLs and Markdown source downloads. README.html
aliases preserve heading fragments. The sidebar includes every project under its
root README catalog category. Search indexes the full text of every published
project Markdown page, plus catalog titles, summaries, and topics; SQL downloads
and the standalone workbook are not indexed. Pilot projects retain their expanded
page TOCs and verification notices. Search data is embedded and stays in the browser. Mermaid is
rendered to inline SVG at build time with strict security and network blocked.
The workbook is copied unchanged, including its local save/load behavior.

Remote static Shields badges become local label/value text without network calls.
The header remains visible independently of the mobile navigation toggle. Browser
regressions check catalog navigation, non-pilot full-text search, keyboard dismissal,
header containment, and light/dark contrast at mobile and desktop breakpoints.

Do not infer technical verification from a Git modification date. Created and
review-due dates come from the source. Publishing does not revalidate technical
claims or execute example SQL.

## Publish and Roll Back

The prepared workflow does not require changing source guide paths. After review
and an explicitly approved commit/push, a repository administrator can change
Settings > Pages > Build and deployment > Source to **GitHub Actions** and set the
repository Actions variable `PAGES_PILOT_ENABLED` to `true`. Until then deployment
jobs are disabled; the current branch-based site remains in place. Run the Pages
workflow manually after activation. PRs build and validate but never deploy.

To roll back, disable `PAGES_PILOT_ENABLED`, restore Pages to **Deploy from a branch**,
`main` / root, and trigger a branch build. No guide/workbook source restoration is
needed. Avoid simultaneous branch and Actions publishing during the cutover.

The archive workflow records old routes in `retired.json` before moving a project.
The Pages workflow listens for successful archive-workflow completion and rebuilds
the latest main commit, rather than relying on a bot push to trigger another build.
Retired routes display a notice and disappear from active navigation and search.

## Adding Content

Add an active guide/demo and its one-sentence root README catalog row. Project
retrieval discovers it without an allowlist edit. Update AGENTS.md intent paths.
Only add publication patterns when the files are intended for readers. Add a pilot
slug to `publication.json` only after checking its diagrams, links, and formatting.
Run link checks and browser checks before publishing. Keep dependency lockfiles
tracked; generated assets and local browser caches remain ignored.
