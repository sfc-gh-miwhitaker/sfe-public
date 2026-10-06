#!/usr/bin/env python3
"""Check publication boundaries, not just secrets.

Pair-programmed by SE Community + Cortex Code
"""

import argparse
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys


PRIVATE_DIRS = {"_archive", "audit_reports", ".cursor", ".vscode", ".idea"}
PRIVATE_NAMES = {".builddemo-state.json", ".demo-config", ".DS_Store", "AUDIT_REPORT.md"}
KEY_SUFFIXES = {".pem", ".key", ".p8", ".p12", ".pfx"}
ENV_TEMPLATES = {".env.example", ".env.template", ".env.sample"}
PERSONAL_STATE = {"settings.json", "settings.local.json", "projects", "conversations",
                  "logs", "memory", "mcp.json", "mcp_oauth", "permissions.json"}
HOST = re.compile(r"(?<![\w<>${}-])(?:[a-z0-9_-]+\.)+snowflakecomputing\.com\b", re.I)
PUBLIC_HOSTS = {"xy12345.snowflakecomputing.com", "account.snowflakecomputing.com",
                "orgname-accountname.snowflakecomputing.com"}
RULES = {
    "personal workstation path": re.compile(r"/(?:Users|home)/[a-z][a-z0-9._-]*/", re.I),
    "internal service link": re.compile(
        r"https?://(?:[\w.-]+\.)?(?:snowflake\.slack\.com|snowflake\.atlassian\.net|"
        r"snowflake\.seismic\.com|go\.snowflake\.com)(?:[/\s]|$)", re.I),
    "private source narrative": re.compile(
        r"internal\s+(?:material\s+describes|launch\s+signals)|"
        r"(?:came|sourced)\s+from\s+internal\s+channels|"
        r"before\s+discussing\s+(?:them\s+)?externally", re.I),
    "authoring ledger": re.compile(
        r"^#{1,6}\s+What\s+Was\s+Verified\b|"
        r"\b(?:authoring|validation)\s+account\b|\ban\s+earlier\s+draft\b", re.I),
}


def path_problem(name):
    path = PurePosixPath(name)
    if PRIVATE_DIRS.intersection(path.parts) or path.name in PRIVATE_NAMES:
        return "private local artifact"
    if path.suffix.lower() in KEY_SUFFIXES:
        return "key or certificate container"
    if (path.name == ".env" or path.name.startswith(".env.")) and path.name not in ENV_TEMPLATES:
        return "environment file"
    for index, part in enumerate(path.parts[:-1]):
        if part in {".claude", ".cortex"} and path.parts[index + 1] in PERSONAL_STATE:
            return "personal assistant state"
        if part == ".snowflake" and path.parts[index + 1] == "cortex":
            return "personal Cortex state"
    return None


def scan_text(text):
    findings = []
    for number, line in enumerate(text.splitlines(), 1):
        for label, pattern in RULES.items():
            if pattern.search(line):
                findings.append((number, label))
        for match in HOST.finditer(line):
            # Exceptions apply to the exact hostname, never its surrounding file or line.
            if match.group().lower() not in PUBLIC_HOSTS:
                findings.append((number, "literal Snowflake account hostname"))
    return findings


def candidate_paths(root):
    output = subprocess.check_output(
        ["git", "-C", str(root), "ls-files", "--cached", "--others", "--exclude-standard", "-z"]
    )
    return sorted(set(output.decode("utf-8").rstrip("\0").split("\0")) - {""})


def check_paths(root, names):
    failures = []
    binaries = []
    for name in names:
        relative = PurePosixPath(name)
        if relative.is_absolute() or ".." in relative.parts:
            failures.append((name, 0, "path outside repository"))
            continue
        path = root / name
        if any(root.joinpath(*relative.parts[:index]).is_symlink()
               for index in range(1, len(relative.parts) + 1)):
            failures.append((name, 0, "symlink requires removal from publication"))
            continue
        if not path.exists():  # Preserve pending retirement deletions.
            continue
        problem = path_problem(name)
        if problem:
            failures.append((name, 0, problem))
        try:
            data = path.read_bytes()
            if b"\0" in data:
                binaries.append(name)
                continue
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            binaries.append(name)
            continue
        except OSError:
            failures.append((name, 0, "cannot read file"))
            continue
        failures.extend((name, number, label) for number, label in scan_text(text))
    return failures, binaries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="*", help="Hook paths; default scans tracked and nonignored new files")
    args = parser.parse_args()
    root = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
    names = args.files or candidate_paths(root)
    failures, binaries = check_paths(root, names)
    for name, number, label in failures:
        # Never reproduce matched confidential content in CI logs.
        print(f"FAIL {name}:{number}: {label}")
    for name in binaries:
        print(f"REVIEW {name}: binary content requires visual/provenance review")
    print(f"Public-content check: {len(names)} paths, {len(failures)} failures, {len(binaries)} binary review items")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
