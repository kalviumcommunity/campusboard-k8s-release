import json
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            payload = {"service": "campusboard", "status": "ok"}
        elif self.path in ("/", "/info"):
            payload = {
                "service": "campusboard",
                "environment": os.getenv("APP_ENV", "unset"),
                "banner": os.getenv("BANNER", "unset"),
                "token_present": bool(os.getenv("DEMO_TOKEN")),
                "pod": socket.gethostname(),
            }
        else:
            self.send_response(404)
            self.end_headers()
            return
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 5000), Handler).serve_forever()
