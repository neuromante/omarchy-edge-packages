#!/usr/bin/env python3
"""Read a public RSS feed and return the newest entries as JSON."""

from __future__ import annotations

import json
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET


ALLOWED_LIMITS = {10, 50, 100}
MAX_FEED_BYTES = 1_000_000


def read_feed(url: str, limit: int) -> dict[str, object]:
    if not url.startswith("https://"):
        raise ValueError("The feed URL must use HTTPS")
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "omarchy-edge-packages-widget/1.2.0", "Accept": "application/rss+xml, application/xml, text/xml"},
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        if response.status != 200:
            raise RuntimeError(f"The feed returned HTTP {response.status}")
        payload = response.read(MAX_FEED_BYTES + 1)
    if len(payload) > MAX_FEED_BYTES:
        raise RuntimeError("The RSS feed exceeds the maximum allowed size")

    root = ET.fromstring(payload)
    channel = root.find("channel")
    if channel is None:
        raise ValueError("The response is not a valid RSS feed")

    entries = []
    for item in channel.findall("item"):
        categories = [
            (category.text or "").strip()
            for category in item.findall("category")
        ]
        entries.append(
            {
                "title": item.findtext("title", default="Pacchetto edge"),
                "description": item.findtext("description", default=""),
                "pubDate": item.findtext("pubDate", default=""),
                "link": item.findtext("link", default=""),
                "repo": next(
                    (category for category in categories if category in {"core", "extra", "multilib", "omarchy"}),
                    "",
                ),
                "kind": next(
                    (category for category in categories if category in {"added", "updated"}),
                    "updated",
                ),
            }
        )

    return {
        "title": channel.findtext("title", default="Omarchy Edge Packages"),
        "items": entries[:limit],
        "total": len(entries),
        "checked": int(time.time()),
        "error": "",
    }


def main() -> None:
    if len(sys.argv) != 3:
        print(json.dumps({"items": [], "total": 0, "error": "Missing arguments"}))
        return
    try:
        limit = int(sys.argv[2])
        if limit not in ALLOWED_LIMITS:
            raise ValueError("Invalid selection: choose 10, 50, or 100")
        result = read_feed(sys.argv[1], limit)
    except Exception as exc:  # Emit an error state for the panel, never a traceback.
        result = {"items": [], "total": 0, "checked": int(time.time()), "error": str(exc)}
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
