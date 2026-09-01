#!/usr/bin/env python3
"""Turn MobileView events into a Mermaid flowchart of the user's screen route.

Every MobileView *appear* event carries both ends of a transition -- `viewName` (where the
user landed) and `previousView` (where they came from) -- so the flow graph is just an
aggregation over those pairs. No derivation, no ordering heuristics.

Input (stdin or a file path) is any one of:

  * a raw agent dump: the JSON array returned by -[NRMAAnalytics analyticsJSONString]
  * a NerdGraph NRQL response: {"facets": [{"name": ["From", "To"], "results": [...]}]}
  * already-aggregated edge rows: [{"previousView": "A", "viewName": "B", "count": 5}]

MobileViewTiming events in the same dump are folded in automatically. Each one carries the
`viewInstanceId` and `previousView` of the visit it belongs to, so timings are attributed both to
the screen and to the route taken into it -- the same screen can be shown as fast when reached
from search and slow when reached from a deeplink. Screens display a median per timing plus the
"lie window" (timeToFullDisplay - timeToInitialDisplay): how long the screen looked finished but
was not.

Timings come from raw event dumps. Pre-aggregated (NRQL facet) input still renders the flow, but
carries no timing rows to fold in.

Output is Mermaid on stdout, ready to paste into GitHub, Confluence, or a PR description.

Examples:
    ./scripts/mobileview_flow.py events.json
    ./scripts/mobileview_flow.py events.json --session 1A2B-3C4D --min-count 2
    ./scripts/mobileview_flow.py events.json --lie-ms 150 --svg flow.svg
    pbpaste | ./scripts/mobileview_flow.py - --include-components --no-timings
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from collections import Counter, defaultdict

MOBILE_VIEW = "MobileView"
MOBILE_VIEW_TIMING = "MobileViewTiming"
START = "__start__"

# The agent's own baseline timing, projected from loadTime. Named here because the lie window is
# defined against it and because it must sort first in a screen's timing block.
TIMING_INITIAL_DISPLAY = "timeToInitialDisplay"
TIMING_FULL_DISPLAY = "timeToFullDisplay"

# Short labels, because a node label is a few dozen pixels wide and "timeToInitialDisplay" is not.
TIMING_ABBREV = {
    TIMING_INITIAL_DISPLAY: "TTID",
    TIMING_FULL_DISPLAY: "TTFD",
    "timeToInteractive": "TTI",
    "timeToFirstByte": "TTFB",
    "firstInputDelay": "FID",
}

# Display order for a screen's timing block: the lifecycle order a user actually experiences,
# rather than alphabetical. Anything unrecognised sorts after these, alphabetically.
TIMING_ORDER = [TIMING_INITIAL_DISPLAY, TIMING_FULL_DISPLAY, "timeToInteractive", "timeToFirstByte"]


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


def timing_events(rows, session=None):
    """Keep only MobileViewTiming events, which carry timingName / timingValue.

    Unlike appear events these are not navigation steps; they attach to a visit that a MobileView
    row already established. Rows with no view identity (recordViewTiming: called with no view
    current) are dropped: there is nothing on the diagram to attach them to.
    """
    out = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        if row.get("eventType") != MOBILE_VIEW_TIMING:
            continue
        if not row.get("viewName") or not row.get("timingName"):
            continue
        if not isinstance(row.get("timingValue"), (int, float)):
            continue
        if session and str(row.get("sessionId", "")) != session:
            continue
        out.append(row)
    return out


def median(values):
    """Median rather than mean: one pathological cold start should not redefine a screen."""
    if not values:
        return None
    ordered = sorted(values)
    mid = len(ordered) // 2
    if len(ordered) % 2:
        return float(ordered[mid])
    return (ordered[mid - 1] + ordered[mid]) / 2.0


def timing_sort_key(name):
    if name in TIMING_ORDER:
        return (0, TIMING_ORDER.index(name), "")
    return (1, 0, name)


def abbrev(name):
    return TIMING_ABBREV.get(name, name)


# --------------------------------------------------------------------------- aggregation

class Graph:
    def __init__(self):
        self.edges = Counter()          # (from, to) -> traversals
        self.back = Counter()           # (from, to) -> traversals that were back-navigations
        self.load_totals = defaultdict(float)
        self.load_counts = Counter()
        self.component_of = {}          # component view -> owning screen
        self.nodes = set()
        # view -> timingName -> [values]. Screens carry every timing recorded on any visit.
        self.timings = defaultdict(lambda: defaultdict(list))
        # (from, to) -> timingName -> [values]. The same screen reached two ways is two entries,
        # which is the point: it shows a route being slow rather than a screen being slow.
        self.edge_timings = defaultdict(lambda: defaultdict(list))

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

    def add_timing(self, view, name, value, previous=None):
        self.timings[view][name].append(value)
        if previous:
            self.edge_timings[(previous, view)][name].append(value)

    def timing_medians(self, view):
        """[(timingName, median)] for a screen, in lifecycle order."""
        if view not in self.timings:
            return []
        return [(name, median(vals))
                for name, vals in sorted(self.timings[view].items(), key=lambda kv: timing_sort_key(kv[0]))
                if vals]

    def lie_window(self, view):
        """How long the screen looked done but was not: median TTFD minus median TTID.

        None unless both are present -- a screen with only the agent's baseline has nothing to
        compare against, and reporting 0 there would claim the screen was honest when it is
        simply uninstrumented.
        """
        per = self.timings.get(view)
        if not per:
            return None
        ttid = median(per.get(TIMING_INITIAL_DISPLAY, []))
        ttfd = median(per.get(TIMING_FULL_DISPLAY, []))
        if ttid is None or ttfd is None:
            return None
        return ttfd - ttid

    def headline_ms(self, view):
        """The number --slow-ms is judged against.

        Prefers full display over initial display, because a screen that paints a spinner fast is
        not a fast screen. Falls back to loadTime so dumps with no timing events behave as before.
        """
        per = self.timings.get(view)
        if per:
            for name in (TIMING_FULL_DISPLAY, TIMING_INITIAL_DISPLAY):
                value = median(per.get(name, []))
                if value is not None:
                    return value
        return self.avg_load(view)

    def edge_landing_ms(self, src, dst):
        """Median cost of landing on dst *via this edge*, for edge labels."""
        per = self.edge_timings.get((src, dst))
        if not per:
            return None
        for name in (TIMING_FULL_DISPLAY, TIMING_INITIAL_DISPLAY):
            value = median(per.get(name, []))
            if value is not None:
                return value
        return None

    def prune(self, min_count):
        if min_count <= 1:
            return
        self.edges = Counter({e: c for e, c in self.edges.items() if c >= min_count})
        self.back = Counter({e: c for e, c in self.back.items() if e in self.edges})
        kept = {n for edge in self.edges for n in edge if n != START}
        self.nodes &= kept
        # Edge timings outlive their edge otherwise, and would label an arrow that is gone.
        self.edge_timings = defaultdict(
            lambda: defaultdict(list),
            {e: v for e, v in self.edge_timings.items() if e in self.edges},
        )
        self.timings = defaultdict(
            lambda: defaultdict(list),
            {v: t for v, t in self.timings.items() if v in self.nodes},
        )


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


def add_timings(g, timing_rows, collapse=None):
    """Fold MobileViewTiming rows onto the screens and routes already in the graph.

    Timings for views the flow never drew (pruned, or filtered out) are skipped rather than
    resurrecting a node that build_graph deliberately excluded.
    """
    collapse = collapse or {}
    skipped = 0
    for row in timing_rows:
        view = collapse.get(row["viewName"], row["viewName"])
        if view not in g.nodes:
            skipped += 1
            continue
        previous = row.get("previousView")
        if previous:
            previous = collapse.get(previous, previous)
            # Only attribute to a route the diagram actually draws.
            if (previous, view) not in g.edges:
                previous = None
        g.add_timing(view, row["timingName"], float(row["timingValue"]), previous=previous)
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


def render(g, slow_ms, lie_ms=None, edge_timings=True, title=None):
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
    # Amber, distinct from slow-red: a screen can paint fast and still lie for a long time, and
    # those are different bugs with different fixes.
    lines.append("    classDef lying fill:#fff4e0,stroke:#c87f0a,stroke-width:2px;")

    has_start = any(src == START for src, _ in g.edges)
    if has_start:
        lines.append("    start(( )):::entry")

    slow_nodes = []
    lying_nodes = []
    grouped = defaultdict(list)
    for node in sorted(g.nodes):
        grouped[g.component_of.get(node)].append(node)

    def emit_node(node, indent="    "):
        label = sanitize(node)
        medians = g.timing_medians(node)

        if medians:
            # One line per timing, so a screen reads as a small table rather than one opaque number.
            for name, value in medians:
                label += f"<br/>{sanitize(abbrev(name))} {value:.0f} ms"
            lie = g.lie_window(node)
            if lie is not None:
                label += f"<br/>lie +{lie:.0f} ms"
        else:
            # No timing events in this dump: fall back to the loadTime line, as before.
            avg = g.avg_load(node)
            if avg is not None:
                label += f"<br/>{avg:.0f} ms"

        lines.append(f'{indent}{ids[node]}["{label}"]')

        headline = g.headline_ms(node)
        if headline is not None and headline >= slow_ms:
            slow_nodes.append(ids[node])
        elif lie_ms is not None:
            lie = g.lie_window(node)
            # Only flagged when not already red, so a screen carries one diagnosis, not two.
            if lie is not None and lie >= lie_ms:
                lying_nodes.append(ids[node])

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

        # Cost of landing on dst along *this* route. A screen that is quick from search and slow
        # from a deeplink shows up here and nowhere else on the diagram.
        landing = g.edge_landing_ms(src, dst) if edge_timings else None
        cost = f" {landing:.0f} ms" if landing is not None else ""

        # "2x" rather than a bare "2", so a count never reads as part of the duration beside it.
        # sanitize_edge_label strips punctuation, so a separator has to be a letter.
        times = f"{count}x" if count > 1 else ""

        if back and back >= count:
            # Purely a back-navigation: dashed, so a returning route never reads as a new one.
            label = f"{count} back" if count > 1 else "back"
            arrow = f"-.->|{sanitize_edge_label(label + cost)}|"
        elif back:
            # Mixed pair -- traversed forward and returned along the same edge. Report the two
            # counts separately rather than a total plus a parenthetical.
            label = f"{count - back} fwd {back} back"
            arrow = f"-->|{sanitize_edge_label(label + cost)}|"
        elif count > 1:
            arrow = f"-->|{sanitize_edge_label(f'{times}{cost}')}|"
        elif cost:
            arrow = f"-->|{sanitize_edge_label(cost)}|"
        else:
            arrow = "-->"
        lines.append(f"    {src_id} {arrow} {dst_id}")

    for node_id in slow_nodes:
        lines.append(f"    class {node_id} slow;")
    for node_id in lying_nodes:
        lines.append(f"    class {node_id} lying;")

    return "\n".join(lines)


def timing_table(g):
    """Aligned per-screen timing summary for stderr.

    stdout stays pure Mermaid so the diagram can be piped; this is for the human running it, and
    it shows the sample count that a median on the diagram hides.
    """
    views = [v for v in sorted(g.nodes) if g.timings.get(v)]
    if not views:
        return None

    names = sorted({n for v in views for n in g.timings[v]}, key=timing_sort_key)
    headers = ["screen"] + [abbrev(n) for n in names] + ["lie", "n"]

    rows = []
    for view in views:
        per = g.timings[view]
        cells = [view]
        for name in names:
            value = median(per.get(name, []))
            cells.append(f"{value:.0f}" if value is not None else "-")
        lie = g.lie_window(view)
        cells.append(f"+{lie:.0f}" if lie is not None else "-")
        cells.append(str(sum(len(v) for v in per.values())))
        rows.append(cells)

    widths = [max(len(h), *(len(r[i]) for r in rows)) for i, h in enumerate(headers)]

    def line(cells):
        # Screen name left-aligned, numbers right-aligned so digits line up column-wise.
        out = [cells[0].ljust(widths[0])]
        out += [c.rjust(widths[i]) for i, c in enumerate(cells) if i]
        return "  ".join(out).rstrip()

    sep = "  ".join("-" * w for w in widths)
    return "\n".join([line(headers), sep] + [line(r) for r in rows])


# --------------------------------------------------------------------------- timeline

def pick_session(rows):
    """Busiest sessionId in the dump, for when --timeline is used without --session.

    A timeline spanning two sessions is meaningless -- the x axis would jump between unrelated
    runs -- so one has to be chosen, and the one with the most screen views is the interesting one.
    """
    counts = Counter(str(r.get("sessionId")) for r in rows
                     if isinstance(r, dict) and r.get("sessionId") is not None)
    if not counts:
        return None
    return counts.most_common(1)[0][0]


def session_origin(rows):
    """Best available t=0 for the session.

    `timeSinceLoad` is seconds since the app started, so an event carrying it pins the real session
    start rather than merely the first event the dump happens to contain. Falls back to the earliest
    timestamp, which is only the start of *recording*.
    """
    origins = [r["timestamp"] - r["timeSinceLoad"] * 1000.0
               for r in rows
               if isinstance(r.get("timestamp"), (int, float))
               and isinstance(r.get("timeSinceLoad"), (int, float))]
    if origins:
        return min(origins), True
    stamps = [r["timestamp"] for r in rows if isinstance(r.get("timestamp"), (int, float))]
    if not stamps:
        return None, False
    return min(stamps), False


def build_timeline(rows, max_visits=25):
    """One entry per view *visit*, with its load window, visible span, and timing marks.

    Keyed on viewInstanceId rather than viewName: the same screen visited twice is two rows on a
    timeline, which is the whole point of putting it on a time axis.
    """
    visits = {}
    order = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        ts = row.get("timestamp")
        if not isinstance(ts, (int, float)):
            continue
        instance = row.get("viewInstanceId")
        etype = row.get("eventType", MOBILE_VIEW)

        if etype == MOBILE_VIEW and row.get("appeared") is not False and row.get("viewName"):
            if not instance:
                continue
            if instance not in visits:
                order.append(instance)
            visits[instance] = {
                "name": row["viewName"],
                "appear": ts,
                "load_ms": row["loadTime"] if isinstance(row.get("loadTime"), (int, float)) else None,
                "reappeared": bool(row.get("reappeared")),
                "end": None,
                "marks": [],
            }
        elif etype == MOBILE_VIEW and row.get("appeared") is False and instance in visits:
            # The disappear event's own timestamp ends the bar; timeVisible would say the same.
            visits[instance]["end"] = ts
        elif etype == MOBILE_VIEW_TIMING and instance in visits:
            if not row.get("timingName") or not isinstance(row.get("timingValue"), (int, float)):
                continue
            visits[instance]["marks"].append((ts, row["timingName"], float(row["timingValue"])))

    ordered = [visits[i] for i in order]
    dropped = 0
    if max_visits and len(ordered) > max_visits:
        dropped = len(ordered) - max_visits
        ordered = ordered[:max_visits]
    return ordered, dropped


def sanitize_task(label):
    """Gantt task names are terminated by ':' and fields split on ',', so neither can survive."""
    text = str(label)
    for ch in ":,;#":
        text = text.replace(ch, " ")
    return " ".join(text.split())


def render_timeline(visits, origin, exact_origin, title=None, axis_format="%M:%S"):
    """Mermaid gantt: one section per visit, on a single shared millisecond x axis.

    Milestones sit at the moment each timing was *recorded*, not at an offset derived from its
    value, so the chart stays an honest chronology. For markViewTiming the two coincide by
    construction -- it is called at the instant the screen reached that state -- which is what makes
    the gap between a bar's start and its timeToFullDisplay diamond a picture of the lie window.

    Every time is emitted relative to `origin`, so the axis reads as elapsed time from the start of
    the session rather than as the wall clock the events happened to carry. (Mermaid formats gantt
    dates in local time; %M:%S is unaffected by whole-hour offsets, but a zone offset with a
    half-hour component will shift the minutes.)
    """
    def rel(value):
        return int(value - origin)

    lines = []
    if title:
        lines += ["---", f"title: {sanitize(title)}", "---"]
    lines.append("gantt")
    lines.append("    dateFormat x")
    lines.append(f"    axisFormat {axis_format}")
    lines.append("    todayMarker off")

    session_end = max((v["end"] or v["appear"]) for v in visits) if visits else origin

    origin_note = "session start" if exact_origin else "first event"
    lines.append(f"    section {sanitize_task(origin_note)}")
    # Zero-length span, both fields dates: the bare "0" duration form is not portable across
    # Mermaid versions, so a milestone always gets an explicit equal start and end.
    lines.append("    t0 :milestone, 0, 0")

    seen = Counter()
    for visit in visits:
        seen[visit["name"]] += 1
        nth = seen[visit["name"]]
        label = visit["name"] if nth == 1 else f"{visit['name']} #{nth}"
        lines.append(f"    section {sanitize_task(label)}")

        appear = rel(visit["appear"])
        # The construction window the agent measured as loadTime, drawn before the appearance.
        if visit["load_ms"]:
            start = appear - int(visit["load_ms"])
            lines.append(f"    load {int(visit['load_ms'])}ms :done, {start}, {appear}")

        end = rel(visit["end"] or session_end)
        if end <= appear:
            # Still on screen when recording stopped; give it a sliver so the bar is visible.
            end = appear + 1
        state = "crit" if visit["reappeared"] else "active"
        lines.append(f"    visible :{state}, {appear}, {end}")

        for ts, name, value in sorted(visit["marks"]):
            mark = f"{abbrev(name)} {value:.0f}ms"
            lines.append(f"    {sanitize_task(mark)} :milestone, {rel(ts)}, {rel(ts)}")

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

def render_timeline_output(rows, args):
    rows = [r for r in rows if isinstance(r, dict)]

    session = args.session or pick_session(rows)
    if session:
        scoped = [r for r in rows if str(r.get("sessionId")) == session]
        if not args.session:
            print(f"note: --timeline picked the busiest session {session} "
                  f"({len(scoped)} events); pass --session to choose another", file=sys.stderr)
        rows = scoped
    if not rows:
        sys.exit("error: no events left after session filtering")

    rows = sorted(rows, key=lambda r: r.get("timestamp") or 0)
    origin, exact = session_origin(rows)
    if origin is None:
        sys.exit("error: no event carries a timestamp, so there is no axis to draw")

    visits, dropped = build_timeline(rows, max_visits=args.max_visits)
    if not visits:
        sys.exit("error: no MobileView appear events with a viewInstanceId to place on the axis")

    marks = sum(len(v["marks"]) for v in visits)
    anchor = "app launch (timeSinceLoad)" if exact else "first recorded event"
    print(f"timeline: {len(visits)} visits, {marks} timing marks, t0 = {anchor}", file=sys.stderr)
    if dropped:
        print(f"note: {dropped} later visits omitted (raise --max-visits to include them)",
              file=sys.stderr)

    print(render_timeline(visits, origin, exact, title=args.title, axis_format=args.axis_format))

    if args.svg:
        write_svg(render_timeline(visits, origin, exact, title=args.title,
                                 axis_format=args.axis_format), args.svg)


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
    ap.add_argument("--slow-ms", type=float, default=500.0, metavar="MS",
                    help="highlight screens in red whose median full-display time is at least MS, "
                         "falling back to average loadTime when no timings are present "
                         "(default: 500)")
    ap.add_argument("--lie-ms", type=float, default=250.0, metavar="MS",
                    help="highlight screens in amber whose lie window (full display minus initial "
                         "display) is at least MS (default: 250)")
    ap.add_argument("--no-timings", action="store_true",
                    help="ignore MobileViewTiming events and label screens with loadTime only")
    ap.add_argument("--no-edge-timings", action="store_true",
                    help="do not label arrows with the cost of landing on that route")
    ap.add_argument("--timeline", action="store_true",
                    help="render a chronological Mermaid gantt for one session instead of the flow "
                         "graph: session start, each view's load and visible span, and every timing "
                         "mark on one shared time axis")
    ap.add_argument("--max-visits", type=int, default=25, metavar="N",
                    help="timeline only: keep the first N view visits (default: 25)")
    ap.add_argument("--axis-format", default="%M:%S", metavar="FMT",
                    help="timeline only: d3 time format for the x axis (default: %%M:%%S; try "
                         "%%M:%%S.%%L for sub-second detail)")
    ap.add_argument("--title", help="title line for the diagram")
    ap.add_argument("--svg", metavar="PATH", help="also render an SVG here (needs mmdc)")
    args = ap.parse_args()

    payload = load_payload(args.input)
    rows, aggregated = rows_from_payload(payload)

    if args.timeline:
        if aggregated:
            sys.exit("error: --timeline needs raw events with timestamps; this input is already "
                     "aggregated (no per-event times to place on an axis)")
        render_timeline_output(rows, args)
        return

    collapse = {}
    timing_rows = []
    if not aggregated:
        total = len(rows)
        if not args.include_components:
            collapse = component_owners(rows)
        if not args.no_timings:
            timing_rows = timing_events(rows, session=args.session)
        rows = appear_events(rows, session=args.session,
                             include_components=args.include_components)
        note = f" ({len(collapse)} component segments folded into their screen)" if collapse else ""
        print(f"parsed {total} events -> {len(rows)} MobileView appear events{note}",
              file=sys.stderr)
        if not rows:
            sys.exit("error: no MobileView appear events matched "
                     "(wrong dump, or --session filtered everything out)")
    elif args.session:
        print("note: --session ignored; input is already aggregated", file=sys.stderr)

    g = build_graph(rows, aggregated, ordered_walk=bool(args.session),
                    collapse=collapse)
    g.prune(args.min_count)
    if not g.edges:
        sys.exit(f"error: no edges left (try lowering --min-count, currently {args.min_count})")

    # Timings are folded in after pruning so they only ever describe screens still on the diagram.
    if timing_rows:
        skipped = add_timings(g, timing_rows, collapse=collapse)
        attached = sum(len(v) for per in g.timings.values() for v in per.values())
        note = f", {skipped} for screens not drawn" if skipped else ""
        print(f"folded {attached} MobileViewTiming events onto "
              f"{len(g.timings)} screens{note}", file=sys.stderr)

    mermaid = render(g, slow_ms=args.slow_ms,
                     lie_ms=None if args.no_timings else args.lie_ms,
                     edge_timings=not args.no_edge_timings,
                     title=args.title)
    print(mermaid)
    print(f"{len(g.nodes)} screens, {len(g.edges)} transitions", file=sys.stderr)

    table = timing_table(g)
    if table:
        print("", file=sys.stderr)
        print(table, file=sys.stderr)

    if args.svg:
        write_svg(mermaid, args.svg)


if __name__ == "__main__":
    main()
