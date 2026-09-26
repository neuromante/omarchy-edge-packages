import datetime as dt
import io
import json
import tempfile
import tarfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch

import feed_builder
import zstandard


class ParseDescTests(unittest.TestCase):
    def test_extracts_package_metadata(self):
        result = feed_builder.parse_desc(
            b"%NAME%\nexample\n\n%VERSION%\n1.2-3\n\n%DESC%\nA package\n"
        )
        self.assertEqual(result["NAME"], "example")
        self.assertEqual(result["VERSION"], "1.2-3")
        self.assertEqual(result["DESC"], "A package")

    def test_reads_package_metadata_from_zstandard_pacman_database(self):
        desc = b"%NAME%\nexample\n\n%VERSION%\n1.2-3\n\n%DESC%\nA package\n"
        tar_bytes = io.BytesIO()
        with tarfile.open(fileobj=tar_bytes, mode="w") as archive:
            info = tarfile.TarInfo("example-1.2-3/desc")
            info.size = len(desc)
            archive.addfile(info, io.BytesIO(desc))
        compressed = zstandard.ZstdCompressor().compress(tar_bytes.getvalue())

        class Response:
            status = 200

            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def read(self):
                return compressed

        with patch.object(feed_builder.urllib.request, "urlopen", return_value=Response()):
            packages = feed_builder.fetch_repository("core", "https://repo.invalid/core.db")
        self.assertEqual(packages["example"]["version"], "1.2-3")
        self.assertEqual(packages["example"]["description"], "A package")


class EventTests(unittest.TestCase):
    def test_only_new_packages_and_version_changes_are_events(self):
        previous = {
            "core": {"existing": {"version": "1-1"}},
            "extra": {},
            "multilib": {},
            "omarchy": {},
        }
        current = {
            "core": {
                "existing": {"version": "1-2", "description": "updated", "builddate": "200"},
                "unchanged": {"version": "2-1", "description": "new", "builddate": "100"},
            },
            "extra": {},
            "multilib": {},
            "omarchy": {},
        }
        events = feed_builder.build_events(
            previous, current, dt.datetime(2026, 9, 26, tzinfo=dt.timezone.utc)
        )
        self.assertEqual([(e["name"], e["kind"]) for e in events], [
            ("existing", "updated"),
            ("unchanged", "added"),
        ])
        self.assertEqual(events[0]["old_version"], "1-1")
        self.assertEqual(events[0]["name"], "existing")

    def test_same_name_in_different_repos_is_distinct(self):
        current = {
            repo: {"shared": {"version": "1-1"}}
            for repo in feed_builder.REPOSITORIES
        }
        events = feed_builder.build_events(
            {}, current, dt.datetime(2026, 9, 26, tzinfo=dt.timezone.utc)
        )
        self.assertEqual(len(events), 4)
        self.assertEqual({event["repo"] for event in events}, set(feed_builder.REPOSITORIES))


class RenderTests(unittest.TestCase):
    def test_renders_valid_rss_and_limits_to_one_hundred(self):
        observed = "2026-09-26T10:00:00+00:00"
        events = [
            {
                "id": str(index),
                "repo": "extra",
                "name": f"pkg-{index}",
                "kind": "added",
                "old_version": "",
                "version": "1-1",
                "description": "A & B",
                "url": "",
                "observed": observed,
            }
            for index in range(105)
        ]
        root = ET.fromstring(feed_builder.render_rss(events))
        items = root.findall("./channel/item")
        self.assertEqual(len(items), 100)
        self.assertIn("A & B", items[0].findtext("description", ""))


class RunTests(unittest.TestCase):
    def test_first_scan_is_baseline_then_version_changes_publish(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state = root / "state.json"
            events = root / "events.json"
            feed = root / "site" / "feed.xml"
            baseline = {
                repo: {"example": {"version": "1-1", "description": "Example", "url": ""}}
                for repo in feed_builder.REPOSITORIES
            }
            with patch.object(feed_builder, "fetch_all_repositories", return_value=baseline):
                count, was_baseline = feed_builder.run(state, events, feed)
            self.assertEqual(count, 0)
            self.assertTrue(was_baseline)
            self.assertEqual(ET.fromstring(feed.read_bytes()).findall("./channel/item"), [])

            changed = json.loads(json.dumps(baseline))
            changed["core"]["example"]["version"] = "1-2"
            with patch.object(feed_builder, "fetch_all_repositories", return_value=changed):
                count, was_baseline = feed_builder.run(state, events, feed)
            self.assertEqual(count, 1)
            self.assertFalse(was_baseline)
            self.assertEqual(len(ET.fromstring(feed.read_bytes()).findall("./channel/item")), 1)


if __name__ == "__main__":
    unittest.main()
