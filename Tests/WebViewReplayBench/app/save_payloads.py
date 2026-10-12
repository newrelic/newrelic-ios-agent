#!/usr/bin/env python3
"""Saves each harvest's session replay payload from a run as payloads/harvest_NN.json, plus an index.

Usage: save_payloads.py <run-dir>
The payload is the upload body exactly as the agent sent it, un-gzipped (NRCaptureServer decodes it).
"""
import datetime
import gzip
import json
import os
import shutil
import sys

run = sys.argv[1]
blobs = sorted(f for f in os.listdir(os.path.join(run, "blobs")) if f.startswith("blob_"))
chunks = {c["file"]: c for c in json.load(open(os.path.join(run, "chunks.json")))}
out = os.path.join(run, "payloads")
shutil.rmtree(out, ignore_errors=True)
os.makedirs(out)

index = []
for n, name in enumerate(blobs, 1):
    src = os.path.join(run, "blobs", name)
    data = open(src, "rb").read()
    dst = f"harvest_{n:02d}.json"
    open(os.path.join(out, dst), "wb").write(data)
    received_ms = int(name.removeprefix("blob_").removesuffix(".json"))
    events = json.loads(data)
    stamps = [e["timestamp"] for e in events if e.get("timestamp")]
    row = {
        "harvest": n,
        "file": dst,
        "receivedAt": datetime.datetime.fromtimestamp(received_ms / 1000).isoformat(timespec="seconds"),
        "firstEventAt": datetime.datetime.fromtimestamp(min(stamps) / 1000).isoformat(timespec="seconds") if stamps else None,
        "lastEventAt": datetime.datetime.fromtimestamp(max(stamps) / 1000).isoformat(timespec="seconds") if stamps else None,
        "bytes": len(data),
        "gzipBytes": len(gzip.compress(data, compresslevel=6)),
    }
    c = chunks.get(name, {})
    for key in ("events", "wvEvents", "wvBytes", "docCopies", "orphanWvEvents", "nativeFS", "mountsInFS"):
        row[key] = c.get(key)
    index.append(row)

json.dump(index, open(os.path.join(out, "index.json"), "w"), indent=1)
print(f"saved {len(index)} harvest payload(s) to {out}")
