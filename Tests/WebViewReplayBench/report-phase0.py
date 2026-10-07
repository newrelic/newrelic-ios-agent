#!/usr/bin/env python3
"""Phase 0 comparison of one results/<run>/ directory: report-phase0.py <run-dir>

Two views:
- As shipped: each branch fed what its own capture path produces. webview-msr-poc runs the standalone
  rrweb recorder (bare events, 1s batches, fresh document after every harvest); two-streams runs the
  observation agent (events carry `__serialized`, 5s batches, fresh document after every harvest).
- Same input: both branches fed identical payloads, isolating the native merge architecture.
"""
import gzip
import json
import os
import statistics
import sys

RUN = sys.argv[1].rstrip("/")
HERE = os.path.dirname(os.path.abspath(__file__))
BROWSER_AGENT_MAX_PAYLOAD = 1_000_000   # newrelic-browser-agent MAX_PAYLOAD_SIZE, checked on the gzipped body


def load(kind, variant):
    path = os.path.join(RUN, f"{kind}-{variant}.json")
    return json.load(open(path)) if os.path.exists(path) else []


def mean(xs):
    xs = list(xs)
    return statistics.mean(xs) if xs else float("nan")


rev = {v: (load("ingest", v) or [{}])[0].get("rev", "?") for v in ["poc", "twostreams"]}
print("# WebView replay bench -- Phase 0\n")
print(f"- webview-msr-poc @ `{rev['poc']}`, two-streams-webview-msr @ `{rev['twostreams']}`")
print(f"- host: {' / '.join(l.strip() for l in open(os.path.join(RUN, 'host.txt')) if l.strip())}")
print("- times are medians on this Mac; expect a low-end iPhone to be several times slower\n")

# ---------------------------------------------------------------- ingest
ing = {(r["variant"], r["shape"], r["size"]): r for v in ["poc", "twostreams"] for r in load("ingest", v)}
mem = {(r["variant"], r["shape"], r["size"]): r for v in ["poc", "twostreams"] for r in load("mem", v)}

print("## Native ingest (parse queue), per WebView\n")
print("Document = one Meta + FullSnapshot bridge message. CPU/min = one document + one minute of changes at that "
      "branch's batch cadence.\n")
print("| page | view | variant | payload | doc bridge MB | doc ingest ms | peak RSS Δ MB | change batch ms | CPU ms/min |")
print("|---|---|---|---|---|---|---|---|---|")
for size in ["small", "medium", "large"]:
    rows = [("as shipped", "poc", "rrweb"), ("as shipped", "twostreams", "agent"),
            ("same input", "poc", "agent"), ("same input", "twostreams", "agent")]
    for view, v, shape in rows:
        r = ing.get((v, shape, size))
        if not r:
            continue
        m = mem.get((v, shape, size), {})
        if v == "poc":
            batch, per_min = r["ingestMut1"]["median"], r["ingestDoc"]["median"] + 60 * r["ingestMut1"]["median"]
            batch_label = f"{batch:.2f} (1s)"
        else:
            batch, per_min = r["ingestMut5"]["median"], r["ingestDoc"]["median"] + 12 * r["ingestMut5"]["median"]
            batch_label = f"{batch:.2f} (5s)"
        print(f"| {size} ({r['nodes']:,} nodes) | {view} | {v} | {shape} | {r['docBridgeBytes']/1e6:.2f} | "
              f"{r['ingestDoc']['median']:.1f} | {m.get('peakDeltaBytes', 0)/1e6:.1f} | {batch_label} | {per_min:.0f} |")

# ---------------------------------------------------------------- harvest
harv = [r for v in ["poc", "twostreams"] for r in load("harvest", v)]


def harvest_rows(variant, scenario, size):
    rs = sorted((r for r in harv if r["variant"] == variant and r["scenario"] == scenario and r["size"] == size),
                key=lambda r: r["chunk"])
    return rs[1:]   # chunk 0 carries the page's first load; steady state is the rest


AS_SHIPPED = [
    ("normal", "rrweb capture (1s batches + fresh doc/chunk)", "agent+snapshot capture (5s batches + fresh doc/chunk)"),
    ("+3 native FS/chunk", "rrweb capture +3 native FS/chunk", "agent+snapshot capture +3 native FS/chunk"),
    ("+10 iframe moves/chunk", "rrweb capture +10 iframe moves/chunk", "agent+snapshot capture +10 iframe moves/chunk"),
]

print("\n## Harvest, steady state (mean of chunks 1-5, 60s chunks, 1 WebView)\n")
print("| page | native activity | view | variant | doc copies | WebView raw KB | chunk gz KB | docs shed | carried KB | build ms | encode+gzip ms |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
for size in ["medium", "large"]:
    for label, poc_s, two_s in AS_SHIPPED:
        for view, pairs in [("as shipped", [("poc", poc_s), ("twostreams", two_s)]),
                            ("same input", [("poc", two_s), ("twostreams", two_s)])]:
            for v, scen in pairs:
                st = harvest_rows(v, scen, size)
                if not st:
                    continue
                print(f"| {size} | {label} | {view} | {v} | {mean(r['documentCopies'] for r in st):.1f} | "
                      f"{mean(r['webViewRawBytes'] for r in st)/1024:,.0f} | {mean(r['chunkGzBytes'] for r in st)/1024:,.0f} | "
                      f"{sum(r['shed'] for r in st)} | {st[-1]['retainedBytes']/1024:,.0f} | "
                      f"{mean(r['build']['median'] for r in st):.2f} | {mean(r['encode']['median'] for r in st):.1f} |")

# ---------------------------------------------------------------- browser agent payload cap
print("\n## Browser agent `TOO_BIG` exposure (two-streams only)\n")
print("The observation agent gzips each replay harvest without `__serialized` and aborts replay for the rest of the "
      f"session when it exceeds {BROWSER_AGENT_MAX_PAYLOAD:,} bytes. The harvest holding the FullSnapshot is the "
      "largest, so this is the page size at which two-streams stops recording.\n")
print("| page | snapshot JSON MB | gzipped KB | ratio | over cap? |")
print("|---|---|---|---|---|")
ratios = []
for size in ["small", "medium", "large"]:
    path = os.path.join(HERE, "fixtures", f"{size}-doc-rrweb.json")
    raw = open(path, "rb").read()
    gz = len(gzip.compress(raw, 6))
    ratios.append(gz / len(raw))
    print(f"| {size} | {len(raw)/1e6:.2f} | {gz/1024:,.0f} | {gz/len(raw):.1%} | {'**yes**' if gz > BROWSER_AGENT_MAX_PAYLOAD else 'no'} |")
r = mean(ratios)
print(f"\nAt these fixtures' ~{r:.0%} ratio the cap is reached by a ~{BROWSER_AGENT_MAX_PAYLOAD / r / 1e6:.1f} MB snapshot. "
      "Synthetic text compresses differently from real pages (inlined CSS compresses better, base64 images far worse), "
      "so the real threshold must come from Phase 1 captures.")
