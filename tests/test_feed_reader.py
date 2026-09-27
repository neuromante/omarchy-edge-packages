import importlib.util
import io
import unittest
from pathlib import Path
from unittest.mock import patch


MODULE_PATH = (
    Path(__file__).parents[1]
    / "bin"
    / "read-feed.py"
)
SPEC = importlib.util.spec_from_file_location("read_feed", MODULE_PATH)
read_feed = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(read_feed)


class FeedReaderTests(unittest.TestCase):
    def test_reads_rss_and_extracts_repository_and_kind(self):
        rss = b"""<rss version='2.0'><channel><title>Edge</title>
        <item><title>[extra] app: 1-1 -> 1-2</title><description>Updated</description>
        <category>extra</category><category>updated</category><pubDate>Sat, 26 Sep 2026 10:00:00 +0000</pubDate>
        <guid isPermaLink='false'>event-1</guid>
        </item><item><title>[core] New: another 1-1</title><description>Added</description>
        <category>core</category><category>added</category><pubDate>Sat, 26 Sep 2026 11:00:00 +0000</pubDate>
        <guid isPermaLink='false'>event-2</guid>
        </item></channel></rss>"""

        class Response:
            status = 200

            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def read(self, _size):
                return rss

        with patch.object(read_feed.urllib.request, "urlopen", return_value=Response()):
            result = read_feed.read_feed("https://feed.invalid/feed.xml", 1)
        self.assertEqual(result["title"], "Edge")
        self.assertEqual(result["total"], 2)
        self.assertEqual(len(result["items"]), 1)
        self.assertEqual(len(result["allItems"]), 2)
        self.assertEqual(result["items"][0]["repo"], "extra")
        self.assertEqual(result["items"][0]["kind"], "updated")
        self.assertEqual(result["items"][0]["id"], "event-1")
        self.assertEqual(result["allItems"][0]["id"], "event-1")

    def test_rejects_non_https_feed_url(self):
        with self.assertRaises(ValueError):
            read_feed.read_feed("http://feed.invalid/feed.xml", 10)


if __name__ == "__main__":
    unittest.main()
