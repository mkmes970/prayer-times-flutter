"""Build an offline-ready static Flutter web app.

Only Flutter's compiled web output is written to --output. The source tree,
Android build files and local credentials are not copied into the release.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "mobile" / "prayer_times"
WORKER = ROOT / "scripts" / "pwa" / "offline-sw.js"
WORKER_FILES = {"offline-sw.js", "flutter_service_worker.js"}
EXCLUDED = {".last_build_id", ".nojekyll", "release-files.json"}


def _release_files(site: Path) -> list[dict]:
    files = []
    for path in sorted(site.rglob("*")):
        if not path.is_file():
            continue
        if path.name in EXCLUDED or path.name.endswith(".symbols"):
            continue
        data = path.read_bytes()
        files.append({
            "path": path.relative_to(site).as_posix(),
            "size": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
        })
    return files


def prepare(site: Path) -> dict:
    # Same user-approved recording as Android; web-only build copy.
    audio = site / "audio" / "adhan.mp3"
    audio.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(
        APP / "android_template/app/src/main/res/raw/adhan.mp3", audio)
    for name in EXCLUDED:
        (site / name).unlink(missing_ok=True)
    for symbol in site.rglob("*.symbols"):
        symbol.unlink()
    (site / ".nojekyll").touch()
    precache_files = _release_files(site)
    content_files = [
        entry for entry in precache_files
        if entry["path"].split("/")[-1] not in WORKER_FILES
    ]
    precache_paths = [entry["path"] for entry in content_files]
    if not precache_paths:
        raise ValueError("The Flutter PWA release has no files to cache.")
    version = hashlib.sha256(
        json.dumps(
            {
                "files": content_files,
                "worker": hashlib.sha256(WORKER.read_bytes()).hexdigest(),
            },
            sort_keys=True,
        ).encode("utf-8")
    ).hexdigest()[:16]
    worker = WORKER.read_text(encoding="utf-8")
    worker = worker.replace("__CACHE_NAME__", f"mwaqit-offline-{version}")
    worker = worker.replace(
        "__PRECACHE_URLS__",
        json.dumps(precache_paths, ensure_ascii=True, separators=(",", ":")),
    )
    if "__CACHE_NAME__" in worker or "__PRECACHE_URLS__" in worker:
        raise ValueError("Offline worker release placeholders were not expanded.")
    (site / "offline-sw.js").write_text(worker, encoding="utf-8")
    # Preserve Flutter's previous worker URL so existing installs can migrate.
    (site / "flutter_service_worker.js").write_text(worker, encoding="utf-8")

    files = _release_files(site)
    required = {
        "index.html", "flutter.js", "flutter_bootstrap.js", "offline-setup.js",
        "offline-sw.js", "flutter_service_worker.js", "main.dart.js", "manifest.json",
        "install-app.js", "install-app.css",
        "update-app.html", "update-app.js",
        "audio/adhan.mp3",
        "canvaskit/canvaskit.wasm",
    }
    paths = {file["path"] for file in files}
    if not required.issubset(paths) or not any("/data/" in path for path in paths):
        raise ValueError("The Flutter PWA release is missing required files.")
    # The integrity manifest is for CI; it does not enter the offline cache.
    (site / "release-files.json").write_text(json.dumps(files), encoding="utf-8")
    return {"version": version, "files": len(files),
            "bytes": sum(file["size"] for file in files)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-href", default="/")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"/(?:[A-Za-z0-9_.-]+/)*", args.base_href) or ".." in args.base_href:
        parser.error("Base href must be an absolute /-delimited site path.")
    output = Path(args.output).resolve()
    if not (
        output == APP / "build" / "web"
        or ROOT / "generated-artifacts" in output.parents
        or output == ROOT / "artifacts" / "prayer-times-preview" / "dist" / "public"
    ):
        parser.error("Output must be the Flutter build, preview dist or a generated-artifacts subdirectory.")
    if hasattr(os, "sched_getaffinity"):
        available = sorted(os.sched_getaffinity(0))
        os.sched_setaffinity(0, available[:2])
    subprocess.run([
        "flutter", "build", "web", "--release", "--no-pub",
        "--no-web-resources-cdn", "--base-href", args.base_href,
    ], cwd=APP, check=True)
    source = APP / "build" / "web"
    result = prepare(source)
    if output != source:
        if output.exists():
            shutil.rmtree(output)
        shutil.copytree(source, output)
    print(f"Offline-ready web release: {result['files']} verified resources, "
          f"{result['bytes']} bytes, version {result['version']}, base {args.base_href}")


if __name__ == "__main__":
    main()
