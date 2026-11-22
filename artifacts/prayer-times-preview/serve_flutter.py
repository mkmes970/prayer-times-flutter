"""Serve the existing Flutter application through its managed preview route."""

import os
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
WEB = (
    HERE / "dist" / "public"
    if "--production" in sys.argv
    else ROOT / "mobile" / "prayer_times" / "build" / "web"
)


class PreviewHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        # Preview must show the latest compiled Flutter files after a refresh.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    if not (WEB / "index.html").is_file():
        raise SystemExit(
            "Flutter web build is missing. Run: "
            "pnpm --filter @workspace/prayer-times-preview run build"
        )
    port = int(os.environ["PORT"])
    handler = partial(PreviewHandler, directory=str(WEB))
    with ThreadingHTTPServer(("0.0.0.0", port), handler) as server:
        print(f"Flutter prayer-times preview serving {WEB} on port {port}", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
