#!/usr/bin/env python3
"""Build an RSS feed from Omarchy edge's four pacman repositories."""

from __future__ import annotations

import argparse
import concurrent.futures
import contextlib
import datetime as dt
import email.utils
import gzip
import hashlib
import io
import json
import os
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

import tarfile
import zstandard


REPOSITORIES = {
    "core": "https://mirror.omarchy.org/core/os/x86_64/core.db",
    "extra": "https://mirror.omarchy.org/extra/os/x86_64/extra.db",
    "multilib": "https://mirror.omarchy.org/multilib/os/x86_64/multilib.db",
    "omarchy": "https://pkgs.omarchy.org/edge/x86_64/omarchy.db",
}
FEED_URL = "https://neuromante.github.io/omarchy-edge-packages/feed.xml"
FEED_TITLE = "Packages arriving in Omarchy edge"
FEED_DESCRIPTION = (
    "New packages and version updates detected in Omarchy edge's core, extra, "
    "multilib, and omarchy repositories."
)
MAX_ITEMS = 100


def parse_desc(raw: bytes) -> dict[str, str]:
    """Parse the simple key/value fields in one pacman repository desc file."""
    lines = raw.decode("utf-8", errors="replace").splitlines()
    fields: dict[str, str] = {}
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not (line.startswith("%") and line.endswith("%") and len(line) > 2):
            i += 1
            continue
        key = line[1:-1]
        i += 1
        values: list[str] = []
        while i < len(lines) and lines[i].strip():
            candidate = lines[i].strip()
            if candidate.startswith("%") and candidate.endswith("%"):
                break
            values.append(candidate)
            i += 1
        if values:
            fields[key] = "\n".join(values)
    return fields


def fetch_repository(repo: str, url: str) -> dict[str, dict[str, str]]:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "omarchy-edge-rss/1.0 (+https://github.com/neuromante/omarchy-edge-packages)"},
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        archive = response.read()

    packages: dict[str, dict[str, str]] = {}
    with contextlib.ExitStack() as stack:
        source = io.BytesIO(archive)
        if archive.startswith(b"\x1f\x8b"):
            uncompressed = stack.enter_context(gzip.GzipFile(fileobj=source))
        elif archive.startswith(b"\x28\xb5\x2f\xfd"):
            uncompressed = stack.enter_context(zstandard.ZstdDecompressor().stream_reader(source))
        else:
            raise RuntimeError(
                f"Formato del database {repo} non riconosciuto: {archive[:4].hex()}"
            )
        with tarfile.open(fileobj=uncompressed, mode="r|") as tar:
            for member in tar:
                if not member.isfile() or not member.name.endswith("/desc"):
                    continue
                stream = tar.extractfile(member)
                if stream is None:
                    continue
                fields = parse_desc(stream.read())
                name = fields.get("NAME", "")
                version = fields.get("VERSION", "")
                if not name or not version:
                    continue
                packages[name] = {
                    "version": version,
                    "description": fields.get("DESC", ""),
                    "url": fields.get("URL", ""),
                    "builddate": fields.get("BUILDDATE", "0"),
                }

    if not packages:
        raise RuntimeError(f"The {repo} database is empty or could not be parsed")
    return packages


def fetch_all_repositories() -> dict[str, dict[str, dict[str, str]]]:
    snapshots: dict[str, dict[str, dict[str, str]]] = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(REPOSITORIES)) as executor:
        futures = {
            executor.submit(fetch_repository, repo, url): repo
            for repo, url in REPOSITORIES.items()
        }
        for future in concurrent.futures.as_completed(futures):
            repo = futures[future]
            snapshots[repo] = future.result()
    return {repo: snapshots[repo] for repo in REPOSITORIES}


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0)


def make_event(
    repo: str,
    name: str,
    current: dict[str, str],
    previous: dict[str, str] | None,
    observed: dt.datetime,
) -> dict[str, str]:
    old_version = previous["version"] if previous else ""
    version = current["version"]
    kind = "updated" if previous else "added"
    identity = "\0".join((repo, name, old_version, version, observed.isoformat()))
    event_id = hashlib.sha256(identity.encode("utf-8")).hexdigest()
    return {
        "id": event_id,
        "repo": repo,
        "name": name,
        "kind": kind,
        "old_version": old_version,
        "version": version,
        "description": current.get("description", ""),
        "url": current.get("url", ""),
        "builddate": current.get("builddate", "0"),
        "observed": observed.isoformat(),
    }


def build_events(
    previous: dict[str, Any],
    current: dict[str, dict[str, dict[str, str]]],
    observed: dt.datetime,
) -> list[dict[str, str]]:
    events: list[dict[str, str]] = []
    for repo in REPOSITORIES:
        old_repo = previous.get(repo, {})
        new_repo = current[repo]
        for name, package in new_repo.items():
            old_package = old_repo.get(name)
            if old_package is None or old_package.get("version") != package["version"]:
                events.append(make_event(repo, name, package, old_package, observed))
    def event_order(event: dict[str, str]) -> tuple[int, str, str]:
        try:
            builddate = int(event.get("builddate", "0"))
        except ValueError:
            builddate = 0
        return builddate, event["repo"], event["name"]

    events.sort(key=event_order, reverse=True)
    return events


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as tmp:
        tmp.write(encoded)
        tmp_path = Path(tmp.name)
    os.replace(tmp_path, path)


def render_rss(events: list[dict[str, str]]) -> bytes:
    rss = ET.Element("rss", {"version": "2.0"})
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = FEED_TITLE
    ET.SubElement(channel, "link").text = FEED_URL
    ET.SubElement(channel, "description").text = FEED_DESCRIPTION
    ET.SubElement(channel, "language").text = "en-US"
    ET.SubElement(channel, "ttl").text = "15"

    for event in events[:MAX_ITEMS]:
        item = ET.SubElement(channel, "item")
        if event["kind"] == "added":
            title = f'[{event["repo"]}] New: {event["name"]} {event["version"]}'
            change = f'New package, version {event["version"]}.'
        else:
            title = (
                f'[{event["repo"]}] {event["name"]}: '
                f'{event["old_version"]} → {event["version"]}'
            )
            change = (
                f'Updated from {event["old_version"]} '
                f'to {event["version"]}.'
            )
        ET.SubElement(item, "title").text = title
        ET.SubElement(item, "description").text = " ".join(
            part for part in (change, event.get("description", "")) if part
        )
        if event.get("url", "").startswith(("https://", "http://")):
            ET.SubElement(item, "link").text = event["url"]
        ET.SubElement(item, "category").text = event["repo"]
        ET.SubElement(item, "category").text = event["kind"]
        published = dt.datetime.fromisoformat(event["observed"])
        ET.SubElement(item, "pubDate").text = email.utils.format_datetime(published)
        ET.SubElement(item, "guid", {"isPermaLink": "false"}).text = event["id"]

    return ET.tostring(rss, encoding="utf-8", xml_declaration=True)


def run(state_path: Path, events_path: Path, feed_path: Path) -> tuple[int, bool]:
    current = fetch_all_repositories()
    first_run = not state_path.exists()
    previous: dict[str, Any] = {}
    if not first_run:
        previous = json.loads(state_path.read_text(encoding="utf-8"))
        if not isinstance(previous, dict):
            raise ValueError("Package snapshot must be a JSON object")

    event_history: list[dict[str, str]] = []
    if events_path.exists():
        loaded_events = json.loads(events_path.read_text(encoding="utf-8"))
        if not isinstance(loaded_events, list):
            raise ValueError("RSS event history must be a JSON list")
        event_history = loaded_events

    new_events = [] if first_run else build_events(previous, current, utc_now())
    new_ids = {event["id"] for event in new_events}
    event_history = new_events + [
        event for event in event_history if event.get("id") not in new_ids
    ]
    event_history = event_history[:MAX_ITEMS]

    write_json(state_path, current)
    write_json(events_path, event_history)
    feed_path.parent.mkdir(parents=True, exist_ok=True)
    feed_path.write_bytes(render_rss(event_history))

    # The first successful scan establishes a baseline; existing packages are
    # intentionally not announced as if they had just arrived.
    print(
        json.dumps(
            {
                "baseline": first_run,
                "new_events": len(new_events),
                "packages_by_repository": {
                    repo: len(packages) for repo, packages in current.items()
                },
            },
            ensure_ascii=False,
        )
    )
    return len(new_events), first_run


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", type=Path, default=Path("data/snapshot.json"))
    parser.add_argument("--events", type=Path, default=Path("data/events.json"))
    parser.add_argument("--feed", type=Path, default=Path("site/feed.xml"))
    args = parser.parse_args()
    run(args.state, args.events, args.feed)


if __name__ == "__main__":
    main()
