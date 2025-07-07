from http.server import BaseHTTPRequestHandler, HTTPServer

class DumpHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        print("\n--- HTTP REQUEST START ---")
        print(f"{self.command} {self.path} {self.request_version}")
        for k, v in self.headers.items():
            print(f"{k}: {v}")
        print("--- HTTP REQUEST END ---\n")
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK\n")

    def do_POST(self):
        self.do_GET()

server = HTTPServer(('localhost', 5000), DumpHandler)
print("Serving on http://localhost:5000 ...")
server.serve_forever()