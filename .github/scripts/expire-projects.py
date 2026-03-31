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
        dest = os.path.join("_archive", proj)
        if os.path.exists(dest):
            shutil.rmtree(dest)
        shutil.move(proj, dest)
        print(f"  moved {proj}/ → _archive/{proj}/")


def update_readme(archived):
    with open("README.md") as f:
        content = f.read()

    # 1. Remove project-table rows (project link is the first cell).
    lines = content.split("\n")
    kept = []
    for line in lines:
        drop = False
        for proj in archived:
            if re.match(
                rf"^\|\s*\[{re.escape(proj)}\]\({re.escape(proj)}/?(\))?\s*\|",
                line,
            ):
                drop = True
                break
        if not drop:
            kept.append(line)
    content = "\n".join(kept)

    # 2. Clean learning-journey path column.
    for proj in archived:
        content = content.replace(f"{proj} → ", "")
        content = content.replace(f" → {proj}", "")

    # 3. Fix Start Here links that now point to an archived project.
    lines = content.split("\n")
    final = []
    for line in lines:
        for proj in archived:
            link = f"[{proj}]({proj}/)"
            if link not in line or "| **" not in line:
                continue
            cells = line.split("|")
            if len(cells) < 6:
                continue
            path_col = cells[3].strip()
            parts = [p.strip() for p in path_col.split("→") if p.strip()]
            if parts:
                first = parts[0]
                cells[4] = f" [{first}]({first}/) "
                line = "|".join(cells)
            else:
                line = None
            break
        if line is not None:
            final.append(line)
    content = "\n".join(final)

    # 4. Remove journey rows left with an empty path.
    content = re.sub(
        r"\n\|[^|]+\|[^|]+\|\s+\|[^|]+\|", "", content
    )

    # 5. Decrement the Projects badge.
    m = re.search(r"Projects-(\d+)", content)
    if m:
        cur = int(m.group(1))
        content = content.replace(
            f"Projects-{cur}", f"Projects-{max(0, cur - len(archived))}"
        )

    with open("README.md", "w") as f:
        f.write(content)


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
