#!/usr/bin/env python3
"""Side-by-side totals for scripted NRTestApp runs: compare.py <run-dir>..."""
import json
import os
import sys

def load(d):
    chunks = json.load(open(os.path.join(d, "chunks.json")))
    cpu = json.load(open(os.path.join(d, "cpu.json")))["byKind"]
    return chunks, cpu

rows = []
for d in sys.argv[1:]:
    chunks, cpu = load(d)
    wv_chunks = [c for c in chunks if c["wvEvents"]]
    rows.append({
        "run": os.path.basename(d.rstrip("/")),
        "chunks": len(chunks),
        "upload gz KB": sum(c["gz"] for c in chunks) / 1024,
        "largest chunk gz KB": max(c["gz"] for c in chunks) / 1024,
        "WebView raw KB": sum(c["wvBytes"] for c in chunks) / 1024,
        "doc copies": sum(c["docCopies"] for c in chunks),
        "orphaned WV events": sum(c["orphanWvEvents"] for c in chunks),
        "WV chunks w/ orphans": sum(1 for c in wv_chunks if c["orphanWvEvents"]),
        "app CPU s": cpu.get("app", {}).get("cpuS"),
        "WebKit CPU s": sum(v["cpuS"] for k, v in cpu.items() if k != "app"),
        "app max RSS MB": cpu.get("app", {}).get("maxRssMB"),
        "WebContent max RSS MB": cpu.get("webcontent", {}).get("maxRssMB"),
    })

keys = list(rows[0].keys())
print("| metric | " + " | ".join(r["run"] for r in rows) + " |")
print("|---|" + "---|" * len(rows))
for k in keys[1:]:
    vals = []
    for r in rows:
        v = r[k]
        vals.append("n/a" if v is None else (f"{v:,.1f}" if isinstance(v, float) else str(v)))
    print(f"| {k} | " + " | ".join(vals) + " |")

print()
for d in sys.argv[1:]:
    chunks, _ = load(d)
    print(f"{os.path.basename(d.rstrip('/'))} per chunk (gz KB / WV KB / docs / orphans / WebViews mounted):")
    print("  " + "  ".join(f"[{c['gz']/1024:.0f}/{c['wvBytes']/1024:.0f}/{c['docCopies']}/{c['orphanWvEvents']}/{c['mountsInFS']}]" for c in chunks))
