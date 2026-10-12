#!/usr/bin/env python3
"""Per-chunk breakdown of NRCaptureServer session replay blobs (Documents/NRCapture/blob_*.json)."""
import glob, gzip, json, os, sys

ID_KEYS = {"id", "parentId", "nextId", "previousId", "rootId", "start", "end"}
WV_ID = 1_000_000_000

def has_webview_id(v):
    if isinstance(v, dict):
        for k, c in v.items():
            if k == "attributes" and isinstance(c, dict):
                continue
            if k in ID_KEYS and isinstance(c, (int, float)) and not isinstance(c, bool) and c >= WV_ID:
                return True
            if has_webview_id(c):
                return True
    elif isinstance(v, list):
        return any(has_webview_id(c) for c in v)
    return False

def mounts(node, out):
    if isinstance(node, dict):
        attrs = node.get("attributes") or {}
        if node.get("tagName") == "iframe" or (isinstance(attrs, dict) and "data-nr-webview-channel" in attrs):
            out.add(node.get("id"))
        for c in node.get("childNodes") or []:
            mounts(c, out)

def first_webview_id(v):
    if isinstance(v, dict):
        for k, c in v.items():
            if k == "attributes" and isinstance(c, dict):
                continue
            if k in ID_KEYS and isinstance(c, (int, float)) and not isinstance(c, bool) and c >= WV_ID:
                return int(c)
            r = first_webview_id(c)
            if r is not None:
                return r
    elif isinstance(v, list):
        for c in v:
            r = first_webview_id(c)
            if r is not None:
                return r
    return None

def document_key(e):
    """Which document a WebView event belongs to: the plugin's channel, or the graft's ID block."""
    if e.get("type") == 6:
        return ("channel", (e["data"].get("payload") or {}).get("channelId"))
    i = first_webview_id(e.get("data"))
    return ("block", (i - WV_ID) // 10_000_000) if i is not None else None

def classify(e):
    """('native'|'webview', is_document_copy)"""
    if e.get("type") == 6 and (e.get("data") or {}).get("plugin") == "nr-webview-replay":
        inner = (e["data"].get("payload") or {}).get("innerEvent") or {}
        return "webview", inner.get("type") == 2
    if e.get("type") == 3:
        d = e.get("data") or {}
        if d.get("source") == 0 and any(((a.get("node") or {}).get("type") == 0) for a in d.get("adds") or []):
            return "webview", True
        if has_webview_id(d):
            return "webview", False
    return "native", False

rows = []
for path in sorted(glob.glob(os.path.join(sys.argv[1], "blob_*.json"))):
    raw = open(path, "rb").read()
    events = json.loads(raw)
    compact = json.dumps(events, separators=(",", ":")).encode()
    wv_bytes = docs = wv_events = native_fs = 0
    mount_ids = set()
    attached = set()
    orphans = 0
    for e in events:
        kind, is_doc = classify(e)
        if kind == "webview":
            wv_events += 1
            wv_bytes += len(json.dumps(e, separators=(",", ":")))
            docs += is_doc
            key = document_key(e)
            if is_doc:
                if e.get("type") == 3:   # graft: the document node's own ID names the block
                    root = next(a["node"]["id"] for a in e["data"]["adds"] if (a.get("node") or {}).get("type") == 0)
                    key = ("block", (root - WV_ID) // 10_000_000)
                attached.add(key)
            elif e.get("type") == 6 and ((e["data"].get("payload") or {}).get("innerEvent") or {}).get("type") == 4:
                pass   # Meta precedes its document
            elif key not in attached:
                orphans += 1
        if e.get("type") == 2:
            native_fs += 1
            mounts((e.get("data") or {}).get("node"), mount_ids)
    ts = [e.get("timestamp", 0) for e in events if e.get("timestamp")]
    rows.append({"file": os.path.basename(path), "events": len(events), "raw": len(compact),
                 "gz": len(gzip.compress(compact, compresslevel=6)), "wvEvents": wv_events, "wvBytes": wv_bytes,
                 "docCopies": docs, "orphanWvEvents": orphans, "nativeFS": native_fs, "mountsInFS": len(mount_ids),
                 "spanS": round((max(ts) - min(ts)) / 1000, 1) if ts else 0})
print(json.dumps(rows, indent=1))
