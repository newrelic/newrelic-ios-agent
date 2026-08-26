#!/usr/bin/env python3
"""Turn MobileView events into a Mermaid flowchart of the user's screen route.

Every MobileView *appear* event carries both ends of a transition -- `viewName` (where the
user landed) and `previousView` (where they came from) -- so the flow graph is just an
aggregation over those pairs. No derivation, no ordering heuristics.

Input (stdin or a file path) is any one of:

  * a raw agent dump: the JSON array returned by -[NRMAAnalytics analyticsJSONString]
  * a NerdGraph NRQL response: {"facets": [{"name": ["From", "To"], "results": [...]}]}
  * already-aggregated edge rows: [{"previousView": "A", "viewName": "B", "count": 5}]

Output is Mermaid on stdout, ready to paste into GitHub, Confluence, or a PR description.

Examples:
    ./scripts/mobileview_flow.py events.json
    ./scripts/mobileview_flow.py events.json --session 1A2B-3C4D --min-count 2
    pbpaste | ./scripts/mobileview_flow.py - --include-components
    ./scripts/mobileview_flow.py events.json --include-breadcrumbs

    ./scripts/mobileview_flow.py events.json \
    --title "HomeSearch screen flow" \
    --svg /tmp/mv_flow.svg --include-components --include-breadcrumbs
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from collections import Counter, defaultdict

MOBILE_VIEW = "MobileView"
MOBILE_BREADCRUMB = "MobileBreadcrumb"
START = "__start__"


# --------------------------------------------------------------------------- parsing

def load_payload(path):
    raw = sys.stdin.read() if path in ("-", None) else open(path, encoding="utf-8").read()
    raw = raw.strip()
    if not raw:
        sys.exit("error: no input (empty stdin or file)")
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        sys.exit(f"error: input is not valid JSON: {exc}")


def rows_from_payload(payload):
    """Normalize any accepted shape into a list of dicts, plus whether they're pre-aggregated."""
    # NerdGraph facet response: facet values live in `name`, measures in `results`.
    if isinstance(payload, dict):
        facets = payload.get("facets")
        if facets is None and isinstance(payload.get("results"), list):
            return payload["results"], True
        if facets is None:
            sys.exit("error: dict input has neither 'facets' nor 'results'")
        rows = []
        for facet in facets:
            names = facet.get("name")
            names = [names] if isinstance(names, str) else list(names or [])
            if len(names) < 2:
                sys.exit("error: facet response needs two facets (previousView, viewName)")
            measures = facet.get("results") or [{}]
            count = 0
            for measure in measures:
                for key in ("count", "count(*)", "Traversals"):
                    if key in measure:
                        count = measure[key]
                        break
            rows.append({"previousView": names[0], "viewName": names[1], "count": count})
        return rows, True

    if not isinstance(payload, list):
        sys.exit("error: expected a JSON array or object at the top level")

    # Pre-aggregated rows carry a count and no per-event fields.
    if payload and isinstance(payload[0], dict):
        first = payload[0]
        looks_aggregated = any(k in first for k in ("count", "count(*)", "Traversals")) and not any(
            k in first for k in ("eventType", "appeared", "viewInstanceId", "timestamp")
        )
        if looks_aggregated:
            return payload, True

    return payload, False


def component_owners(rows):
    """Map each component segment's view name to the screen it belongs to.

    Built from *every* row, before filtering, because a component can appear as another
    event's `previousView` even when its own row is being dropped.
    """
    owners = {}
    for row in rows:
        if isinstance(row, dict) and row.get("component") and row.get("componentOf"):
            owners[row["viewName"]] = row["componentOf"]
    return owners


def appear_events(rows, session=None, include_components=False):
    """Keep only MobileView appear events.

    Component segments are kept here even when they will not be drawn: the transition *into*
    a screen is recorded on its first segment's row, so dropping those rows loses the edge
    that enters the screen. build_graph folds them onto their owner instead.
    """
    out = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        if row.get("eventType", MOBILE_VIEW) != MOBILE_VIEW:
            continue
        # Only appear events carry previousView and loadTime; disappear events carry timeVisible.
        if row.get("appeared") is False:
            continue
        if not row.get("viewName"):
            continue
        if session and str(row.get("sessionId", "")) != session:
            continue
        out.append(row)
    return out


def breadcrumb_events(rows, session=None):
    """Keep only MobileBreadcrumb events with a name.

    Only meaningful for raw event-list input -- aggregated NerdGraph-facet or pre-aggregated
    rows are edge counts between MobileView transitions and have no room for a third event type.
    """
    out = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        if row.get("eventType") != MOBILE_BREADCRUMB:
            continue
        if not row.get("name"):
            continue
        if session and str(row.get("sessionId", "")) != session:
            continue
        out.append(row)
    return out


# --------------------------------------------------------------------------- aggregation

class Graph:
    def __init__(self):
        self.edges = Counter()          # (from, to) -> traversals
        self.back = Counter()           # (from, to) -> traversals that were back-navigations
        self.load_totals = defaultdict(float)
        self.load_counts = Counter()
        self.component_of = {}          # component view -> owning screen
        self.nodes = set()
        self.breadcrumbs = Counter()    # (view, name) -> occurrences

    def add_edge(self, src, dst, count=1, back=False):
        self.edges[(src, dst)] += count
        if back:
            self.back[(src, dst)] += count
        if src != START:
            self.nodes.add(src)
        self.nodes.add(dst)

    def add_load(self, view, load_ms):
        self.load_totals[view] += load_ms
        self.load_counts[view] += 1

    def avg_load(self, view):
        n = self.load_counts[view]
        return self.load_totals[view] / n if n else None

    def add_breadcrumb(self, view, name):
        self.breadcrumbs[(view, name)] += 1

    def prune(self, min_count):
        if min_count <= 1:
            return
        self.edges = Counter({e: c for e, c in self.edges.items() if c >= min_count})
        self.back = Counter({e: c for e, c in self.back.items() if e in self.edges})
        kept = {n for edge in self.edges for n in edge if n != START}
        self.nodes &= kept


def build_graph(rows, aggregated, ordered_walk=False, collapse=None):
    """collapse maps component view names onto their owning screen.

    Without it, excluding component rows still leaves their names as edge endpoints, so a
    screen's internal segments masquerade as navigation steps between real screens.
    """
    g = Graph()
    collapse = collapse or {}

    def fold(name):
        return collapse.get(name, name)

    if aggregated:
        for row in rows:
            dst = row.get("viewName") or row.get("to")
            if not dst:
                continue
            src = row.get("previousView") or row.get("from") or START
            count = 1
            for key in ("count", "count(*)", "Traversals"):
                if key in row:
                    count = int(row[key] or 0)
                    break
            src, dst = fold(src or START), fold(dst)
            if src == dst:
                continue
            back_count = 0
            for key in ("back", "of which back", "reappeared"):
                if isinstance(row.get(key), (int, float)):
                    back_count = int(row[key])
                    break
                if row.get(key) is True:
                    back_count = count
                    break
            g.add_edge(src, dst, count)
            if back_count:
                g.back[(src, dst)] += back_count
            for key in ("average.loadTime", "Avg load (ms)", "loadTime"):
                if isinstance(row.get(key), (int, float)):
                    g.load_totals[dst] += row[key] * max(count, 1)
                    g.load_counts[dst] += max(count, 1)
                    break
        return g

    if ordered_walk:
        rows = sorted(rows, key=lambda r: r.get("timestamp") or 0)

    for row in rows:
        dst = fold(row["viewName"])
        src = fold(row.get("previousView") or START)
        # A self-loop here means the transition was between two segments of one screen.
        back = bool(row.get("reappeared"))
        if src != dst:
            g.add_edge(src, dst, back=back)
        else:
            g.nodes.add(dst)
        folded = bool(collapse) and bool(row.get("component"))
        if isinstance(row.get("loadTime"), (int, float)) and not folded:
            g.add_load(dst, row["loadTime"])
        # Only meaningful when segments are drawn; a folded segment IS its owner by now.
        owner = row.get("componentOf")
        if row.get("component") and owner and not folded:
            g.component_of[dst] = owner
    return g


def add_breadcrumbs(g, rows, collapse=None):
    """Attach each breadcrumb to the screen that was current when it was recorded.

    Returns the number of breadcrumbs skipped for having no currentView (recorded before any
    view appeared, or with view tracking disabled).
    """
    collapse = collapse or {}
    skipped = 0
    for row in rows:
        view = row.get("currentView")
        if not view:
            skipped += 1
            continue
        g.add_breadcrumb(collapse.get(view, view), row["name"])
    return skipped


# --------------------------------------------------------------------------- rendering

def sanitize(label):
    """Node labels are emitted inside double quotes, so only quotes and pipes need handling."""
    return str(label).replace('"', "'").replace("|", "/").replace("\n", " ")


def sanitize_edge_label(label):
    """Edge labels sit bare between pipes, so Mermaid lexes their punctuation as shape tokens.

    A literal "(" becomes PS and aborts the parse ("3 (2 back)" is a parse error, not a label).
    Keep these to letters, digits and spaces -- there is no quoting form that is safe across
    Mermaid versions.
    """
    text = str(label)
    for ch in '()[]{}<>|"\'`-':
        text = text.replace(ch, " ")
    return " ".join(text.split())


def render(g, slow_ms, title=None, breadcrumbs=False):
    ids = {}
    for i, node in enumerate(sorted(g.nodes)):
        ids[node] = f"v{i}"

    lines = ["flowchart LR"]
    if title:
        lines.insert(0, "---")
        lines.insert(1, f"title: {sanitize(title)}")
        lines.insert(2, "---")

    lines.append("    classDef slow fill:#fde2e2,stroke:#c0392b,stroke-width:2px;")
    lines.append("    classDef entry fill:#eef6ff,stroke:#2c6fbb,stroke-width:1px;")
    if breadcrumbs and g.breadcrumbs:
        lines.append("    classDef breadcrumb fill:#fff8e1,stroke:#c9a227,stroke-dasharray: 3 3;")

    has_start = any(src == START for src, _ in g.edges)
    if has_start:
        lines.append("    start(( )):::entry")

    slow_nodes = []
    grouped = defaultdict(list)
    for node in sorted(g.nodes):
        grouped[g.component_of.get(node)].append(node)

    def emit_node(node, indent="    "):
        avg = g.avg_load(node)
        label = sanitize(node)
        if avg is not None:
            label += f"<br/>{avg:.0f} ms"
        lines.append(f'{indent}{ids[node]}["{label}"]')
        if avg is not None and avg >= slow_ms:
            slow_nodes.append(ids[node])

    for node in grouped.get(None, []):
        emit_node(node)

    # Component segments render nested inside the screen they belong to.
    for owner, members in sorted((o, m) for o, m in grouped.items() if o):
        owner_label = sanitize(owner)
        lines.append(f'    subgraph sg_{abs(hash(owner)) % 100000}["{owner_label}"]')
        lines.append("        direction TB")
        for node in members:
            emit_node(node, indent="        ")
        lines.append("    end")

    for (src, dst), count in sorted(g.edges.items(), key=lambda kv: (-kv[1], kv[0])):
        src_id = "start" if src == START else ids.get(src)
        dst_id = ids.get(dst)
        if not src_id or not dst_id:
            continue
        back = g.back.get((src, dst), 0)
        if back and back >= count:
            # Purely a back-navigation: dashed, so a returning route never reads as a new one.
            label = f"{count} back" if count > 1 else "back"
            arrow = f"-.->|{sanitize_edge_label(label)}|"
        elif back:
            # Mixed pair -- traversed forward and returned along the same edge. Report the two
            # counts separately rather than a total plus a parenthetical.
            label = f"{count - back} fwd {back} back"
            arrow = f"-->|{sanitize_edge_label(label)}|"
        elif count > 1:
            arrow = f"-->|{sanitize_edge_label(count)}|"
        else:
            arrow = "-->"
        lines.append(f"    {src_id} {arrow} {dst_id}")

    for node_id in slow_nodes:
        lines.append(f"    class {node_id} slow;")

    if breadcrumbs:
        crumb_ids = []
        for i, ((view, name), count) in enumerate(sorted(g.breadcrumbs.items())):
            view_id = ids.get(view)
            if not view_id:
                continue  # view was pruned away or never became a node
            label = sanitize(name) + (f" ×{count}" if count > 1 else "")
            crumb_id = f"b{i}"
            lines.append(f'    {crumb_id}(["{label}"])')
            lines.append(f"    {view_id} -.-> {crumb_id}")
            crumb_ids.append(crumb_id)
        for crumb_id in crumb_ids:
            lines.append(f"    class {crumb_id} breadcrumb;")

    return "\n".join(lines)


def mermaid_renderer():
    """Prefer an installed mmdc; fall back to npx so --svg works with no global install."""
    mmdc = shutil.which("mmdc")
    if mmdc:
        return [mmdc]
    npx = shutil.which("npx")
    if npx:
        return [npx, "-y", "-p", "@mermaid-js/mermaid-cli", "mmdc"]
    return None


def write_svg(mermaid, out_path):
    cmd = mermaid_renderer()
    if not cmd:
        print(
            f"note: skipped {out_path} -- no mmdc and no npx on PATH; "
            "copy the Mermaid above instead, or `npm i -g @mermaid-js/mermaid-cli`",
            file=sys.stderr,
        )
        return
    src = out_path + ".mmd"
    with open(src, "w", encoding="utf-8") as fh:
        fh.write(mermaid)
    if cmd[0].endswith("npx"):
        print("note: no mmdc on PATH; rendering via npx (first run downloads Chromium)",
              file=sys.stderr)
    try:
        subprocess.run(cmd + ["-i", src, "-o", out_path], check=True)
    except subprocess.CalledProcessError as exc:
        print(f"error: mermaid render failed ({exc}); the Mermaid source is at {src}",
              file=sys.stderr)
        return
    print(f"wrote {out_path} (source kept at {src})", file=sys.stderr)


# --------------------------------------------------------------------------- cli

def main():
    ap = argparse.ArgumentParser(
        description="Render MobileView events as a Mermaid screen-flow diagram.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument("input", nargs="?", default="-",
                    help="events JSON file, or - for stdin (default: stdin)")
    ap.add_argument("--session", metavar="ID",
                    help="restrict to one sessionId and order the walk by timestamp")
    ap.add_argument("--min-count", type=int, default=1, metavar="N",
                    help="drop edges traversed fewer than N times (default: 1)")
    ap.add_argument("--include-components", action="store_true",
                    help="show component segments nested under their screen "
                         "(default: dropped, since they are not navigation steps)")
    ap.add_argument("--include-breadcrumbs", action="store_true",
                    help="annotate each screen with the breadcrumbs recorded while it was "
                         "current (default: dropped, to keep the flow uncluttered); "
                         "raw event-list input only, ignored for aggregated input")
    ap.add_argument("--slow-ms", type=float, default=500.0, metavar="MS",
                    help="highlight screens whose average loadTime is at least MS (default: 500)")
    ap.add_argument("--title", help="title line for the diagram")
    ap.add_argument("--svg", metavar="PATH", help="also render an SVG here (needs mmdc)")
    args = ap.parse_args()

    payload = load_payload(args.input)
    rows, aggregated = rows_from_payload(payload)

    collapse = {}
    breadcrumb_rows = []
    if not aggregated:
        total = len(rows)
        if not args.include_components:
            collapse = component_owners(rows)
        if args.include_breadcrumbs:
            breadcrumb_rows = breadcrumb_events(rows, session=args.session)
        rows = appear_events(rows, session=args.session,
                             include_components=args.include_components)
        note = f" ({len(collapse)} component segments folded into their screen)" if collapse else ""
        print(f"parsed {total} events -> {len(rows)} MobileView appear events{note}",
              file=sys.stderr)
        if not rows:
            sys.exit("error: no MobileView appear events matched "
                     "(wrong dump, or --session filtered everything out)")
    else:
        if args.session:
            print("note: --session ignored; input is already aggregated", file=sys.stderr)
        if args.include_breadcrumbs:
            print("note: --include-breadcrumbs ignored; input is already aggregated",
                  file=sys.stderr)

    g = build_graph(rows, aggregated, ordered_walk=bool(args.session),
                    collapse=collapse)
    if breadcrumb_rows:
        skipped = add_breadcrumbs(g, breadcrumb_rows, collapse=collapse)
        if skipped:
            print(f"note: {skipped} breadcrumbs skipped (no currentView)", file=sys.stderr)
    g.prune(args.min_count)
    if not g.edges:
        sys.exit(f"error: no edges left (try lowering --min-count, currently {args.min_count})")

    mermaid = render(g, slow_ms=args.slow_ms, title=args.title,
                     breadcrumbs=args.include_breadcrumbs)
    print(mermaid)
    crumb_note = f", {sum(g.breadcrumbs.values())} breadcrumbs" if args.include_breadcrumbs else ""
    print(f"{len(g.nodes)} screens, {len(g.edges)} transitions{crumb_note}", file=sys.stderr)

    if args.svg:
        write_svg(mermaid, args.svg)


if __name__ == "__main__":
    main()
