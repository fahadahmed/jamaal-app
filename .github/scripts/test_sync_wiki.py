import tempfile
import unittest
from pathlib import Path

import sync_wiki

REPO = Path(__file__).resolve().parents[2]


class SyncWikiTests(unittest.TestCase):
    def make(self, files):
        root = Path(tempfile.mkdtemp())
        for rel, content in files.items():
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content if isinstance(content, bytes) else content.encode())
        (root / "wiki").mkdir()
        return root

    def run_sync(self, root):
        return sync_wiki.sync(root / "docs", root / "wiki")

    def test_page_links_are_flattened(self):
        root = self.make({"docs/Home.md": "[Task](schema/task)", "docs/schema/task.md": "[Back](../Home)"})
        self.assertEqual(self.run_sync(root), [])
        self.assertEqual((root / "wiki/Home.md").read_text(), "[Task](schema-task)")
        self.assertEqual((root / "wiki/schema-task.md").read_text(), "[Back](Home)")

    def test_an_image_is_copied_and_its_link_rewritten(self):
        root = self.make({
            "docs/journeys/today.md": "![Today](../../mockups/screens/a/TD-01.png)",
            "mockups/screens/a/TD-01.png": b"PNG",
        })
        self.assertEqual(self.run_sync(root), [])
        self.assertEqual((root / "wiki/journeys-today.md").read_text(), "![Today](images/mockups-screens-a-TD-01.png)")
        self.assertEqual((root / "wiki/images/mockups-screens-a-TD-01.png").read_bytes(), b"PNG")

    def test_an_img_tag_is_copied_and_keeps_its_width(self):
        root = self.make({
            "docs/journeys/g.md": '<img src="../../mockups/screens/a/TD-01.png" width="240" alt="x">',
            "mockups/screens/a/TD-01.png": b"PNG",
        })
        self.assertEqual(self.run_sync(root), [])
        self.assertEqual((root / "wiki/journeys-g.md").read_text(), '<img src="images/mockups-screens-a-TD-01.png" width="240" alt="x">')
        self.assertTrue((root / "wiki/images/mockups-screens-a-TD-01.png").exists())

    def test_a_missing_img_tag_source_is_reported(self):
        root = self.make({"docs/Home.md": '<img src="nope.png" width="10">'})
        self.assertEqual(self.run_sync(root), ["Home.md: missing image nope.png"])

    def test_images_inside_docs_work_too(self):
        root = self.make({"docs/Home.md": "![x](images/shot.png)", "docs/images/shot.png": b"PNG"})
        self.assertEqual(self.run_sync(root), [])
        self.assertTrue((root / "wiki/images/docs-images-shot.png").exists())

    def test_a_missing_image_is_reported_not_published_silently(self):
        root = self.make({"docs/Home.md": "![x](nope.png)"})
        self.assertEqual(self.run_sync(root), ["Home.md: missing image nope.png"])

    def test_a_link_to_a_missing_page_is_reported(self):
        root = self.make({"docs/Home.md": "[x](schema/missing)"})
        self.assertEqual(self.run_sync(root), ["Home.md: link to a missing page schema/missing"])

    def test_a_link_outside_docs_points_at_the_file_on_github(self):
        root = self.make({
            "docs/design/x.md": "[a](../../mockups/README) [b](../../assets/icon) [c](../../mockups/README#top)",
            "mockups/README.md": "x", "assets/icon/one.svg": "x",
        })
        self.assertEqual(self.run_sync(root), [])
        base = "https://github.com/fahadahmed/jamaal-app"
        self.assertEqual((root / "wiki/design-x.md").read_text(),
                         f"[a]({base}/blob/main/mockups/README.md) [b]({base}/tree/main/assets/icon) [c]({base}/blob/main/mockups/README.md#top)")

    def test_a_link_to_a_missing_file_outside_docs_is_reported(self):
        root = self.make({"docs/design/x.md": "[a](../../nowhere/README)"})
        self.assertEqual(self.run_sync(root), ["design/x.md: link to a missing file ../../nowhere/README"])

    def test_external_links_and_images_are_left_alone(self):
        text = "[a](https://example.com/x) ![b](https://example.com/y.png)"
        root = self.make({"docs/Home.md": text})
        self.assertEqual(self.run_sync(root), [])
        self.assertEqual((root / "wiki/Home.md").read_text(), text)

    def test_code_fences_are_left_exactly_as_written(self):
        text = "```mermaid\nflowchart LR\n  A[x](y) --> B\n```\n[Task](schema/task)"
        root = self.make({"docs/Home.md": text, "docs/schema/task.md": "x"})
        self.assertEqual(self.run_sync(root), [])
        self.assertEqual((root / "wiki/Home.md").read_text(), "```mermaid\nflowchart LR\n  A[x](y) --> B\n```\n[Task](schema-task)")

    def test_anchors_on_a_page_link_survive(self):
        root = self.make({"docs/Home.md": "[x](schema/task#presets)", "docs/schema/task.md": "x"})
        self.assertEqual(self.run_sync(root), [])
        self.assertEqual((root / "wiki/Home.md").read_text(), "[x](schema-task#presets)")

    def test_the_real_docs_sync_with_no_problems(self):
        wiki = Path(tempfile.mkdtemp())
        problems = sync_wiki.sync(REPO / "docs", wiki)
        self.assertEqual(problems, [], "every image and page link in docs/ resolves")


if __name__ == "__main__":
    unittest.main()
