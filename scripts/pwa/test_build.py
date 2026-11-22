"""Inspect the compiled release without publishing or altering Android."""

import hashlib
import json
import os
import unittest
from pathlib import Path

SITE = Path(os.environ.get(
    "PWA_TEST_SITE", "generated-artifacts/pwa-site")).resolve()


class OfflineReleaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not (SITE / "offline-sw.js").exists():
            raise FileNotFoundError(f"Build the web site first: {SITE}")
        cls.worker = (SITE / "offline-sw.js").read_text(encoding="utf-8")
        cls.files = json.loads((SITE / "release-files.json").read_text())

    def test_every_release_file_matches_integrity_manifest(self):
        entries = {item["path"]: item for item in self.files}
        actual = {
            file.relative_to(SITE).as_posix()
            for file in SITE.rglob("*") if file.is_file() and
            file.name not in {"release-files.json", ".nojekyll"} and
            not file.name.endswith(".symbols")
        }
        self.assertEqual(actual, set(entries))
        for path, entry in entries.items():
            data = (SITE / path).read_bytes()
            self.assertEqual(len(data), entry["size"], path)
            self.assertEqual(hashlib.sha256(data).hexdigest(), entry["sha256"], path)

    def test_essential_content_is_in_release_and_offline_cache(self):
        paths = {item["path"] for item in self.files}
        data_files = list((SITE / "assets" / "assets" / "data").glob("*"))
        themes = list((SITE / "assets" / "assets" / "themes").glob("*.webp"))
        for file in data_files:
            self.assertIn(f"assets/assets/data/{file.name}", paths)
        self.assertEqual(len(themes), 30)
        self.assertGreaterEqual(len(data_files), 20)
        for path in (
            "index.html", "main.dart.js", "flutter_bootstrap.js",
            "flutter.js", "offline-setup.js", "manifest.json",
            "install-app.js", "install-app.css",
            "assets/assets/fonts/Amiri-Regular.ttf",
            "assets/assets/fonts/Amiri-Bold.ttf",
            "assets/assets/images/no-phone.png",
            "canvaskit/canvaskit.wasm",
            "canvaskit/chromium/canvaskit.wasm",
        ):
            self.assertIn(path, paths)
        bootstrap = (SITE / "flutter_bootstrap.js").read_text()
        self.assertIn("fontFallbackBaseUrl: new URL('fallback-fonts/'", bootstrap)
        self.assertIn('"useLocalCanvasKit":true', bootstrap)
        self.assertIn("flutter_service_worker.js", paths)
        self.assertIn("offline-sw.js", paths)
        legacy_worker = (SITE / "flutter_service_worker.js").read_text()
        self.assertEqual(legacy_worker, self.worker)
        self.assertIn("respondWith", legacy_worker)
        self.assertIn("cache.addAll(requests)", legacy_worker)
        self.assertIn("CHECK_OFFLINE_CACHE", legacy_worker)
        self.assertTrue((SITE / ".nojekyll").is_file())
        self.assertEqual(len(list((SITE / "fallback-fonts").rglob("*.woff2"))), 3)
        worker = (SITE / "offline-sw.js").read_text()
        cache_name = worker.split("const CACHE_NAME = '", 1)[1].split("'", 1)[0]
        self.assertRegex(cache_name, r"^mwaqit-offline-[0-9a-f]{16}$")
        precache_json = worker.split("const PRECACHE_URLS = ", 1)[1].split(";", 1)[0]
        precache_paths = set(json.loads(precache_json))
        self.assertEqual(
            precache_paths,
            paths - {"offline-sw.js", "flutter_service_worker.js"},
        )

    def test_pwa_audio_and_no_private_source_in_release(self):
        for private in (".git", ".env", "pubspec.yaml", "lib", "android"):
            self.assertFalse((SITE / private).exists(), private)
        self.assertFalse(any(SITE.rglob("*.dart")))
        self.assertFalse(any(SITE.rglob("*.map")))
        self.assertEqual(
            [p.relative_to(SITE).as_posix() for p in SITE.rglob("*.mp3")],
            ["audio/adhan.mp3"],
        )
        approved = Path("mobile/prayer_times/android_template/app/src/main/res/raw/adhan.mp3")
        self.assertEqual((SITE / "audio/adhan.mp3").read_bytes(), approved.read_bytes())
        html = (SITE / "index.html").read_text()
        self.assertIn('href="manifest.json"', html)
        self.assertIn('src="offline-setup.js"', html)
        self.assertIn('src="install-app.js"', html)
        self.assertIn('href="install-app.css"', html)
        self.assertNotIn('id="offline-status"', html)
        self.assertIn("يعمل التطبيق دون إنترنت", html)
        self.assertIn("serviceWorker.register", (SITE / "offline-setup.js").read_text())
        self.assertIn("registration.update()", (SITE / "offline-setup.js").read_text())
        self.assertNotIn("localStorage", self.worker)
        self.assertNotIn("indexedDB", self.worker)
        self.assertEqual(
            json.loads((SITE / "manifest.json").read_text())["display"],
            "standalone",
        )


if __name__ == "__main__":
    unittest.main()
