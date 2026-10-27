"""Loopback-only synthetic Responses fixture; never contacts Azure."""
import argparse
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

requests = []


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_POST(self):
        payload = self.rfile.read(int(self.headers.get('Content-Length', '0')))
        requests.append({'path': self.path, 'method': 'POST', 'key': self.headers.get('api-key'),
                         'content_type': self.headers.get('Content-Type')})
        mode = self.path.rsplit('/', 1)[-1]
        if mode == 'timeout':
            time.sleep(3)
        status = int(mode) if mode.isdigit() else 200
        if mode == 'redirect':
            status = 302
        body = json.dumps({'id': 'resp_synthetic', 'status': 'completed', 'error': None,
                           'output': [{'type': 'message', 'content': [
                               {'type': 'output_text', 'text': 'Zażółć'}]}],
                           'received': json.loads(payload)}).encode('utf-8')
        if status >= 400:
            body = b'{"error":{"message":"synthetic-private-prompt synthetic-key-only"}}'
        if mode == 'array-json':
            body = b'[{"status":"completed","output":[]}]'
        if mode == 'invalid-json':
            body = b'not-json synthetic-private-prompt synthetic-key-only'
        if mode == 'invalid-utf8':
            body = b'{"secret":"\xff"}'
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        if status == 302:
            self.send_header('Location', '/redirect-target')
        self.end_headers()
        try:
            self.wfile.write(body)
        except BrokenPipeError:
            pass

    def do_GET(self):
        if self.path != '/stats':
            self.send_error(404)
            return
        self.send_response(200)
        self.end_headers()
        self.wfile.write(json.dumps(requests).encode('utf-8'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=0)
    args = parser.parse_args()
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    print(server.server_port, flush=True)
    server.serve_forever()
