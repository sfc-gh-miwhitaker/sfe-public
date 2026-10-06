#!/usr/bin/env python3
"""Pair-programmed by SE Community + Cortex Code.

Validate verification-based deadlines and archive due projects, never renew them.
"""

import argparse
import os
import re
import shutil
import json
from pathlib import Path
from datetime import date, datetime, timedelta, timezone


MAX_AGE_DAYS = 60


def utc_today():
    return datetime.now(timezone.utc).date()


def active_projects():
    return sorted(entry for entry in Path('.').iterdir()
                  if entry.is_dir() and not entry.is_symlink()
                  and entry.name.startswith(('guide-', 'demo-', 'tool-'))
                  and (entry / 'README.md').is_file())


def validate_policy(today=None, proposed_texts=None):
    """Check public date metadata before archival; review evidence stays private."""
    today = today or utc_today()
    errors = []
    for project in active_projects():
        try:
            text = (proposed_texts[project.name] if proposed_texts is not None
                    else (project / 'README.md').read_text())
            matches = re.findall(r'\*\*(Last verified|Review baseline):\*\*\s*(\d{4}-\d{2}-\d{2})', text)
            if len(matches) != 1:
                raise ValueError('README needs exactly one Last verified or Review baseline date')
            label, reviewed_text = matches[0]
            reviewed = date.fromisoformat(reviewed_text)
            if reviewed > today:
                raise ValueError('review date is in the future')
            if label == 'Review baseline' and reviewed > date(2026, 10, 6):
                raise ValueError('legacy baselines cannot be advanced past policy adoption')
            dates = re.findall(r'\*\*Expires:\*\*\s*(\d{4}-\d{2}-\d{2})', text)
            if len(dates) != 1:
                raise ValueError('README needs exactly one Expires date')
            deadline = date.fromisoformat(dates[0])
            if not reviewed <= deadline <= reviewed + timedelta(days=MAX_AGE_DAYS):
                raise ValueError('expiry must be between review date and review date + 60 days')
            badges = re.findall(r'badge/[Ee]xpires-(\d{4}--\d{2}--\d{2})-', text)
            if badges != [deadline.isoformat().replace('-', '--')]:
                raise ValueError('README expiry badge must match the deadline')
        except (KeyError, ValueError, TypeError) as error:
            errors.append(f'{project.name}: {error}')
    if errors:
        raise ValueError('Expiration policy errors; fix metadata before archival:\n' + '\n'.join(errors))


def find_expired_projects(today=None):
    today = today or utc_today()
    expired = []
    for project in active_projects():
        entry = project.name
        readme = project / 'README.md'
        with open(readme) as f:
            text = f.read()
        m = re.search(r"\*\*Expires:\*\*\s*(\d{4}-\d{2}-\d{2})", text)
        if not m:
            continue
        if datetime.strptime(m.group(1), "%Y-%m-%d").date() <= today:
            expired.append(entry)
    return expired


def sync_headers():
    """Cap expiry from existing README dates; never invent a review or renewal."""
    updates = []
    for project in active_projects():
        readme = project / 'README.md'
        text = readme.read_text()
        matches = re.findall(r'\*\*(?:Last verified|Review baseline):\*\*\s*(\d{4}-\d{2}-\d{2})', text)
        if len(matches) != 1:
            raise ValueError(f'{project.name}: supply exactly one review date before syncing')
        reviewed = date.fromisoformat(matches[0])
        old = re.search(r'\*\*Expires:\*\*\s*(\d{4}-\d{2}-\d{2})', text).group(1)
        deadline = min(date.fromisoformat(old), reviewed + timedelta(days=MAX_AGE_DAYS)).isoformat()
        text = text.replace(f'**Expires:** {old}', f'**Expires:** {deadline}', 1)
        text = text.replace(old.replace('-', '--'), deadline.replace('-', '--'))
        updates.append((readme, text))
    validate_policy(proposed_texts={readme.parent.name: text for readme, text in updates})
    for readme, text in updates:
        readme.write_text(text)


def archive_projects(projects, preserve_previous=False):
    os.makedirs("_archive", exist_ok=True)
    destinations = {}
    for proj in projects:
        destination = Path('_archive') / proj
        if destination.exists() and preserve_previous:
            destination = Path('_archive') / f'{proj}-{utc_today().isoformat()}'
        if destination.exists():
            raise RuntimeError(f"Archive already exists for {proj}; preserve it and resolve manually.")
        destinations[proj] = destination
    record_retired_routes(projects)
    for proj in projects:
        dest = destinations[proj]
        shutil.move(proj, dest)
        readme = Path(dest) / 'README.md'
        text = readme.read_text()
        text = re.sub(r'(\*\*Status:\*\*\s*)ACTIVE', r'\1ARCHIVED', text, flags=re.I)
        text = re.sub(r'(badge/[Ss]tatus-)[^-/)]+-[^/)]+', r'\1Archived-inactive', text)
        readme.write_text('> **Archived:** This project is retired and is no longer maintained.\n\n' + text)
        print(f"  moved {proj}/ → {dest}/")
    return destinations


def record_retired_routes(projects):
    manifest = Path("site/retired.json")
    if not manifest.exists():
        return
    data = json.loads(manifest.read_text())
    for project in projects:
        routes = {f"/{project}/", f"/{project}/README.html"}
        for file in Path(project).rglob("*"):
            if not file.is_file() or file.is_symlink():
                continue
            if any(part.startswith(".") or part in {"tests", "node_modules", "app"} for part in file.parts):
                continue
            if file.name in {"AGENTS.md", "CLAUDE.md", "SKILL.md"}:
                continue
            if file.suffix.lower() not in {".md", ".html", ".sql", ".yaml", ".yml"}:
                continue
            routes.add("/" + file.as_posix())
            if file.suffix == ".md":
                routes.add("/" + file.with_suffix(".html").as_posix())
        previous = data['projects'].get(project, {})
        routes.update(previous.get('routes', []))
        data["projects"][project] = {**previous, "date": utc_today().isoformat(),
                                     "reason": "Verification lease expired; no renewal approved.",
                                     "routes": sorted(routes)}
    manifest.write_text(json.dumps(data, indent=2) + "\n")


def update_readme(archived):
    content = Path("README.md").read_text()
    for project in archived:
        slug = re.escape(project)
        content = re.sub(rf"^\|\s*\[[^\]]+\]\({slug}/\)\s*\|.*\n?", "", content, flags=re.MULTILINE)
        content = re.sub(rf"\[([^\]]+)\]\({slug}/?(?:#[^)]*)?\)", r"\1 (retired; see current catalog)", content)
    count = len(active_projects())
    content = re.sub(r"Projects-\d+", f"Projects-{count}", content)
    Path("README.md").write_text(content)
    agents = Path("AGENTS.md")
    if agents.exists():
        lines = agents.read_text().splitlines(keepends=True)
        kept = []
        dropping = False
        for line in lines:
            if re.match(r'^(?:- |\d+\. )', line):
                dropping = any(f'`{project}`' in line for project in archived)
            elif line.strip() and not line.startswith((' ', '\t')):
                dropping = False
            if not dropping:
                kept.append(line)
        agents.write_text(''.join(kept))
    publication = Path('site/publication.json')
    if publication.exists():
        settings = json.loads(publication.read_text())
        settings['pilot'] = [name for name in settings.get('pilot', []) if name not in archived]
        settings['extraFiles'] = [name for name in settings.get('extraFiles', [])
                                  if name.split('/')[0] not in archived]
        publication.write_text(json.dumps(settings, indent=2) + '\n')


def write_summary(archived, destinations=None):
    """Write a Markdown summary to the GitHub Actions job summary."""
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    with open(path, "a") as f:
        f.write("## Expired Projects Archived\n\n")
        f.write("| Project | Destination |\n|---|---|\n")
        for proj in archived:
            destination = destinations[proj] if destinations else Path('_archive') / proj
            f.write(f"| `{proj}` | `{destination}/` |\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--check', action='store_true', help='Validate metadata without archiving')
    modes.add_argument('--dry-run', action='store_true', help='Validate and list due projects without writing')
    modes.add_argument('--sync-headers', action='store_true', help='Sync recorded review metadata and shorten deadlines; never renew')
    parser.add_argument('--preserve-previous', action='store_true', help='Use a dated archive directory when an older archive exists; never overwrite')
    args = parser.parse_args()
    if args.sync_headers:
        sync_headers()
        validate_policy()
        print('Headers synchronized; no project was renewed or archived.')
        return
    validate_policy()
    expired = find_expired_projects()
    if args.check or args.dry_run:
        print(f'Expiration policy valid: {len(active_projects())} active projects; {len(expired)} due.')
        if args.dry_run:
            for project in expired:
                print(f'Would archive: {project}')
        return
    if not expired:
        print("No expired projects found.")
        return

    print(f"Found {len(expired)} expired project(s):")
    destinations = archive_projects(expired, preserve_previous=args.preserve_previous)
    update_readme(expired)
    write_summary(expired, destinations)

    summary = ", ".join(expired)
    print(f"\nArchived: {summary}")

    gh_output = os.environ.get("GITHUB_OUTPUT")
    if gh_output:
        with open(gh_output, "a") as f:
            f.write(f"archived={summary}\n")
            f.write(f"count={len(expired)}\n")


if __name__ == "__main__":
    main()
