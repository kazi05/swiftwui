"""Local-only echo and delayed-response endpoints for real Fetch cancellation."""
import argparse
import http.server
import pathlib
import time


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_PUT(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        if self.path == "/__blob/slow-headers":
            time.sleep(1)
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            if self.path == "/__blob/slow-body":
                self.wfile.write(body[:1])
                self.wfile.flush()
                time.sleep(1)
                self.wfile.write(body[1:])
            else:
                self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass  # The cancellation tests deliberately close these responses.


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parent
    server = http.server.ThreadingHTTPServer(
        ("127.0.0.1", args.port),
        lambda *arguments, **keywords: Handler(*arguments, directory=str(root), **keywords),
    )
    server.serve_forever()
