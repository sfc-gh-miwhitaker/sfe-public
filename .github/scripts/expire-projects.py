#!/usr/bin/env python3
"""Auto-archive expired projects and update root README.

Scans every top-level project directory for an **Expires:** date in its
README.md.  When the date is today or earlier the directory is moved to
_archive/ and the root README tables, learning-journey paths, and badge
count are updated in place.
"""

import os
import re
import shutil
import json
from pathlib import Path
from datetime import date, datetime


def find_expired_projects():
    today = date.today()
    expired = []
    for entry in sorted(os.listdir(".")):
        if not os.path.isdir(entry) or entry.startswith((".", "_", "shared")):
            continue
        readme = os.path.join(entry, "README.md")
        if not os.path.isfile(readme):
            continue
        with open(readme) as f:
            text = f.read()
        m = re.search(r"\*\*Expires:\*\*\s*(\d{4}-\d{2}-\d{2})", text)
        if not m:
            continue
        if datetime.strptime(m.group(1), "%Y-%m-%d").date() <= today:
            expired.append(entry)
    return expired


def archive_projects(projects):
    os.makedirs("_archive", exist_ok=True)
    for proj in projects:
        if os.path.exists(os.path.join("_archive", proj)):
            raise RuntimeError(f"Archive already exists for {proj}; preserve it and resolve manually.")
    record_retired_routes(projects)
    for proj in projects:
        dest = os.path.join("_archive", proj)
        shutil.move(proj, dest)
        print(f"  moved {proj}/ → _archive/{proj}/")


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
        data["projects"][project] = {"date": date.today().isoformat(), "routes": sorted(routes)}
    manifest.write_text(json.dumps(data, indent=2) + "\n")


def update_readme(archived):
    content = Path("README.md").read_text()
    for project in archived:
        slug = re.escape(project)
        content = re.sub(rf"^\|\s*\[[^\]]+\]\({slug}/\)\s*\|.*\n?", "", content, flags=re.MULTILINE)
        content = re.sub(rf"\[([^\]]+)\]\({slug}/?(?:#[^)]*)?\)", r"\1 (retired; see current catalog)", content)
    count = sum(1 for entry in Path('.').iterdir() if entry.is_dir()
                and entry.name.startswith(('guide-', 'demo-')) and (entry / 'README.md').is_file())
    content = re.sub(r"Projects-\d+", f"Projects-{count}", content)
    Path("README.md").write_text(content)
    agents = Path("AGENTS.md")
    if agents.exists():
        lines = agents.read_text().splitlines(keepends=True)
        agents.write_text(''.join(line for line in lines if not any(f'`{project}`' in line for project in archived)))


def write_summary(archived):
    """Write a Markdown summary to the GitHub Actions job summary."""
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    with open(path, "a") as f:
        f.write("## Expired Projects Archived\n\n")
        f.write("| Project | Destination |\n|---|---|\n")
        for proj in archived:
            f.write(f"| `{proj}` | `_archive/{proj}/` |\n")


def main():
    expired = find_expired_projects()
    if not expired:
        print("No expired projects found.")
        return

    print(f"Found {len(expired)} expired project(s):")
    archive_projects(expired)
    update_readme(expired)
    write_summary(expired)

    summary = ", ".join(expired)
    print(f"\nArchived: {summary}")

    gh_output = os.environ.get("GITHUB_OUTPUT")
    if gh_output:
        with open(gh_output, "a") as f:
            f.write(f"archived={summary}\n")
            f.write(f"count={len(expired)}\n")


if __name__ == "__main__":
    main()
