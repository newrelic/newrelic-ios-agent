#!/usr/bin/env python3
"""A fake New Relic collector that saves raw analytics events for mobileview_flow.py.

The simulator shares the Mac's network, so an agent pointed at "localhost:8080" harvests to this
process. That exact address matters: it is the string that makes the agent drop TLS (see
NRMAAgentConfiguration.m). Every /data harvest is decoded and its analyticsEvents -- element [9] of
the payload -- appended to one JSON array, which is exactly the input mobileview_flow.py takes.

No app code changes are needed:

  * HomeSearch: launch with `-NR_MODE capture`. Its in-app stub fails to bind 8080 because this
    process already holds it, so the agent harvests here instead.
  * NRTestApp: pass --nrtestapp-plist. The collector addresses in NRAPI-Info.plist are pointed at
    localhost for the run and restored on exit, including Ctrl-C and SIGTERM.

Examples:
    ./scripts/mobileview_capture_collector.py --out /tmp/mv/events.json
    ./scripts/mobileview_capture_collector.py --out /tmp/mv/events.json --nrtestapp-plist
"""

from __future__ import annotations

import argparse
import atexit
import gzip
import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import threading
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 8080
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NRTESTAPP_PLIST = os.path.join(REPO, "Test Harness", "NRTestApp", "NRAPI-Info.plist")

# Copied from HomeSearch's NRCollectorStub: the fields the agent reads before it starts harvesting.
CONNECT_RESPONSE = {
    "server_timestamp": 1656525980, "data_report_period": 15, "report_max_transaction_count": 1000,
    "report_max_transaction_age": 600, "collect_network_errors": True, "error_limit": 50,
    "response_body_limit": 2048, "stack_trace_limit": 100, "at_capture": [50, []],
    "data_token": [111111111, 222222222], "cross_process_id": "AAAAAAAAAAAAAAAAAAAAAA==",
    "encoding_key": "0000000000000000000000000000000000000000", "account_id": "1",
    "application_id": "1", "entity_guid": "AAAAAAAAAAAAAAAAAAAAAA==", "configuration": {},
}


def decode_body(body, encoding):
    """Harvest bodies may be gzip, zlib (deflate), or plain."""
    decoders = [zlib.decompress, lambda b: b]
    if encoding == "gzip":
        decoders.insert(0, gzip.decompress)
    for decode in decoders:
        try:
            return decode(body)
        except Exception:
            continue
    return body


def make_handler(out_path, events, lock):
    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            length = int(self.headers.get("Content-Length", 0))
            body = decode_body(self.rfile.read(length), self.headers.get("Content-Encoding"))
            response = {}
            if self.path.endswith("/connect"):
                response = CONNECT_RESPONSE
                print("connect", flush=True)
            elif "/data" in self.path:
                self.record_harvest(body)
            data = json.dumps(response).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def record_harvest(self, body):
            try:
                root = json.loads(body)
            except ValueError:
                print(f"harvest: not JSON ({len(body)} bytes)", flush=True)
                return
            harvested = root[9] if isinstance(root, list) and len(root) > 9 else []
            kinds = {}
            for event in harvested:
                kind = event.get("eventType", "?")
                kinds[kind] = kinds.get(kind, 0) + 1
            with lock:
                events.extend(harvested)
                with open(out_path, "w", encoding="utf-8") as fh:
                    json.dump(events, fh, indent=1)
                total = len(events)
            print(f"harvest {len(harvested):3d} {kinds}  total={total}", flush=True)

        def log_message(self, *args):
            pass

    return Handler


def point_nrtestapp_at_localhost():
    """Swap NRTestApp's collector addresses for this run; returns the backup path."""
    backup = NRTESTAPP_PLIST + ".capture-backup"
    if os.path.exists(backup):
        sys.exit(f"error: {backup} exists -- a previous run did not restore. "
                 f"Inspect it, move it back over NRAPI-Info.plist, then retry.")
    shutil.copy2(NRTESTAPP_PLIST, backup)

    def restore():
        if os.path.exists(backup):
            shutil.move(backup, NRTESTAPP_PLIST)
            print("restored NRAPI-Info.plist", flush=True)

    atexit.register(restore)
    for field in ("collectorAddress", "crashCollectorAddress"):
        subprocess.run(["/usr/libexec/PlistBuddy", "-c", f"Set :{field} localhost:{PORT}",
                        NRTESTAPP_PLIST], check=True)
    print("NRAPI-Info.plist -> localhost:8080 (rebuild NRTestApp to pick it up)", flush=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter,
                                 epilog=__doc__)
    ap.add_argument("--out", required=True, help="JSON array file the events are written to")
    ap.add_argument("--nrtestapp-plist", action="store_true",
                    help="point NRTestApp's NRAPI-Info.plist at this collector; restored on exit")
    args = ap.parse_args()

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump([], fh)

    # atexit does not run on a signal death, so turn signals into a normal exit.
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *_: sys.exit(0))

    if args.nrtestapp_plist:
        point_nrtestapp_at_localhost()

    events, lock = [], threading.Lock()
    handler = make_handler(args.out, events, lock)

    # The agent may resolve localhost to either family, so listen on both.
    class IPv6Server(ThreadingHTTPServer):
        address_family = socket.AF_INET6

    try:
        v6 = IPv6Server(("::1", PORT), handler)
        v4 = ThreadingHTTPServer(("127.0.0.1", PORT), handler)
    except OSError as exc:
        sys.exit(f"error: cannot listen on {PORT} ({exc}); `lsof -nP -iTCP:{PORT}` shows who has it")

    threading.Thread(target=v6.serve_forever, daemon=True).start()
    print(f"listening on 127.0.0.1:{PORT} and [::1]:{PORT} -> {args.out}", flush=True)
    v4.serve_forever()


if __name__ == "__main__":
    main()
