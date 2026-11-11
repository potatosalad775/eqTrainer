#!/usr/bin/env python3
"""Adds a version's CHANGELOG.md entry to the top of appcast.xml.

The build workflow runs this once a release's downloads are attached, and commits
the result: appcast.xml on master is what tells installed copies about a release,
so it must not change before there is something to download.

    python3 tool/update_appcast.py <X.Y.Z>

Does nothing when appcast.xml already has the version, so a re-run is safe. Python
rather than Dart so the job that runs it needs no Flutter SDK.
"""

import re
import sys
from datetime import datetime, timezone
from email.utils import format_datetime
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
REPO = "https://github.com/potatosalad775/eqTrainer"


def changelog_notes(text: str, version: str) -> list[str]:
    """The lines of the `## vX.Y.Z [YYYY-MM-DD]` entry, without list markers."""
    lines: list[str] = []
    inside = False
    for line in text.splitlines():
        if line.startswith("## "):
            if inside:
                break
            inside = re.fullmatch(
                rf"## v{re.escape(version)} \[\d{{4}}-\d{{2}}-\d{{2}}\]\s*", line
            ) is not None
        elif inside and line.strip():
            lines.append(re.sub(r"^[-*]\s+", "", line.strip()))
    return lines


def add_item(appcast: str, version: str, notes: list[str], now: datetime) -> str:
    first = re.search(r"^[ \t]*<item>", appcast, re.MULTILINE)
    if first is None:
        raise SystemExit("appcast.xml has no <item> to add one above")
    newline = "\r\n" if "\r\n" in appcast else "\n"
    item = [
        "        <item>",
        f"            <title>v{version}</title>",
        f"            <link>{REPO}</link>",
        "            <description>",
        *(f"                <p>{escape(line)}</p>" for line in notes),
        "            </description>",
        f"            <pubDate>{format_datetime(now)}</pubDate>",
        f'            <enclosure url="{REPO}/releases/tag/v{version}" sparkle:version="{version}" />',
        "        </item>",
        "",
        "",
    ]
    return appcast[: first.start()] + newline.join(item) + appcast[first.start() :]


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 tool/update_appcast.py <X.Y.Z>")
    version = sys.argv[1].removeprefix("v")
    path = ROOT / "appcast.xml"
    # newline="": keep the file's own line endings.
    appcast = path.read_text(encoding="utf-8", newline="")
    if f'sparkle:version="{version}"' in appcast:
        print(f"appcast.xml already has v{version}")
        return
    notes = changelog_notes((ROOT / "CHANGELOG.md").read_text(encoding="utf-8"), version)
    if not notes:
        raise SystemExit(f"CHANGELOG.md has no entry for v{version}")
    updated = add_item(appcast, version, notes, datetime.now(timezone.utc))
    path.write_text(updated, encoding="utf-8", newline="")
    print(f"Added v{version} to appcast.xml")


if __name__ == "__main__":
    main()
