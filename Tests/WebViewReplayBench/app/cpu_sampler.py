#!/usr/bin/env python3
"""Polls CPU time and RSS of the app and the simulator's WebKit processes until killed or `duration`.
Usage: cpu_sampler.py <sim-udid> <app-name> <duration-s> <out.json>"""
import json, subprocess, sys, time

udid, app, duration, out = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]

def cputime(t):
    # [[dd-]hh:]mm:ss.cc
    days = 0
    if "-" in t:
        d, t = t.split("-"); days = int(d)
    parts = [float(p) for p in t.split(":")]
    while len(parts) < 3: parts.insert(0, 0)
    return days * 86400 + parts[0] * 3600 + parts[1] * 60 + parts[2]

seen = {}   # pid -> {kind, cpu, maxRss}
start = time.time()
while time.time() - start < duration:
    ps = subprocess.run(["ps", "-axo", "pid=,ppid=,time=,rss=,command="], capture_output=True, text=True).stdout.splitlines()
    procs = []
    for line in ps:
        f = line.split(None, 4)
        if len(f) == 5: procs.append(f)
    sim_launchd = {p[0] for p in procs if "launchd_sim" in p[4] and udid in p[4]}
    for pid, ppid, t, rss, cmd in procs:
        kind = None
        if udid in cmd and ("/" + app + ".app/" + app) in cmd:
            kind = "app"
        elif ppid in sim_launchd and "WebKit" in cmd:
            kind = "webcontent" if "WebContent" in cmd else ("networking" if "Networking" in cmd else "webkit-other")
        if kind:
            s = seen.setdefault(pid, {"kind": kind, "cpu": 0.0, "maxRssKB": 0, "firstCpu": cputime(t)})
            s["cpu"] = cputime(t)
            s["maxRssKB"] = max(s["maxRssKB"], int(rss))
    time.sleep(2)

summary = {}
for pid, s in seen.items():
    k = summary.setdefault(s["kind"], {"cpuS": 0.0, "processes": 0, "maxRssMB": 0.0})
    k["cpuS"] += s["cpu"] - s["firstCpu"]
    k["processes"] += 1
    k["maxRssMB"] = max(k["maxRssMB"], s["maxRssKB"] / 1024)
json.dump({"durationS": round(time.time() - start, 1), "byKind": summary, "pids": seen}, open(out, "w"), indent=1)
