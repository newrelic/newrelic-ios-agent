# MobileView scenario capture: from nothing to flow + timeline SVGs

A recipe for driving a test app through a scenario, capturing the MobileView events the agent
actually sends, and rendering them as a **session flow diagram** and a **timeline Gantt chart**.
It is written for an agent (Claude Code with the pepper MCP) and works the same by hand.

No app or agent code changes are needed. A fake collector on the Mac's `localhost:8080` receives
the harvests, because the simulator shares the host's network.

```
 app on simulator ──harvest──▶ mobileview_capture_collector.py ──▶ events.json
                                                                     │
                     mobileview_flow.py ─────────────────────────────┤
                        ├─▶ flow.svg      (screens + transitions)    │
                        └─▶ timeline.svg  (--timeline: visits on a time axis)
```

## 0. Prerequisites

- A booted **iOS 26.3** simulator. Pepper's `app_build` compiles with Xcode 26.3.
  `xcrun simctl list devices booted` lists booted devices; boot one with `xcrun simctl boot <udid>`.
- The pepper MCP connected.
- `mmdc` on `PATH`, or `npx`. Without `mmdc`, the first render downloads Chromium.
- Nothing else listening on port 8080 (`lsof -nP -iTCP:8080 -sTCP:LISTEN`), and no *other* test app
  still running. A previously launched app keeps Pepper's port 8844, and the new app then reports
  "Pepper didn't respond" (fix with `xcrun simctl terminate <udid> <old bundle id>`).

## 1. Start the collector

Pick one app and start the collector in the background. Leave it running for the whole scenario.

| App | Best for | Collector command |
|---|---|---|
| **HomeSearch** | a realistic SwiftUI app: tabs, routes, sheets | `./scripts/mobileview_capture_collector.py --out /tmp/mv/events.json` |
| **NRTestApp** | wide coverage: UIKit + SwiftUI + manual views, every MobileView demo | `./scripts/mobileview_capture_collector.py --out /tmp/mv/events.json --nrtestapp-plist` |
| **ExpensesTracker** | a UIKit app shell with container tabs, a drawer, manual views, and a modal SwiftUI section | `./scripts/mobileview_capture_collector.py --out /tmp/mv/events.json` |

ExpensesTracker is built from its own project, not `Agent.xcworkspace`: pass
`<repo>/Test Harness/ExpensesTracker/ExpensesTracker.xcodeproj/project.xcworkspace` as pepper's
`workspace`, with `scheme: ExpensesTracker` and `launch_args: "-NR_MODE capture"` (without it, it
reports live to staging).

The in-app stubs of HomeSearch and ExpensesTracker bind `*:8080` even while the collector is running.
That is harmless: macOS lets both bind, and connections to `localhost` go to the collector's more
specific `127.0.0.1` / `::1` sockets. A backgrounded test app keeps its stub listening, so terminate
apps you are done with.

`--nrtestapp-plist` points `Test Harness/NRTestApp/NRAPI-Info.plist` at localhost for the run and
**restores it when the collector exits**, including on Ctrl-C and SIGTERM. Start the collector
*before* building NRTestApp, because the plist is read at build time.

Each harvest prints a line such as `harvest  23 {'MobileView': 7, 'MobileViewTiming': 5, ...}  total=47`.

## 2. Build and launch

Use pepper `app_build` with `workspace` set to `<repo>/Agent.xcworkspace`, `simulator` set to the
UDID, and:

- HomeSearch: `scheme: HomeSearch`, `launch_args: "-NR_MODE capture"`. Without that argument the app
  defaults to LIVE mode and ships to staging.
- NRTestApp: `scheme: NRTestApp`.

Within about 15 s the collector should print its first `harvest` line. If it doesn't, the app is
not talking to the collector: check step 1.

## 3. Drive the scenario

Write the route down **before** you drive it. That route is what you validate against in step 6.

- `app_look` first, then `ui_tap text:"…"`. A partial label match works, e.g. `text:"NEW, $875,000"`.
- Go back with `nav_back` (UIKit or HomeSearch) and dismiss modals with `nav_dismiss` or the modal's
  own button.

Tips that cost time to learn:

- **Inside NRTestApp's SwiftUI section, don't use `nav_back`.** It pops the whole SwiftUI host back
  to the UIKit home. Tap the SwiftUI back-button text instead (`"SwiftUI Elements"`).
- **NRTestApp's UIKit home table is mostly invisible to `app_look`.** Scroll with
  `ui_scroll at_y=780`, take a screenshot (`xcrun simctl io <udid> screenshot s.png`, then
  `sips -Z 874` to get points), and tap with `ui_tap point="201,<y>"`.
- **The first tap on a list row right after `ui_scroll target=` often does nothing.** Tap again.
- **`ui_input text:"…"` can match the wrong field**: on ExpensesTracker's login, `text:"PASSWORD"` typed
  into the email field, and `ui_tap text:"PASSWORD" index:2` hit the "Forgot password?" link. Tap the
  field by `point=` from a screenshot, then `ui_input value:` into the focused field.
- **Pepper labels an app's own `UIAlertController` a "SYSTEM DIALOG"** and says to use
  `nav_dialog dismiss_system`. If the alert is the app's (e.g. a logout confirmation), `ui_tap
  text:"Yes"` is right; `dismiss_system` is only for SpringBoard (permission) prompts.
- **Pepper itself can crash the app** during its post-action look. It was seen in
  `ElementDiscoveryBridge.ElementDedup.isDuplicate` on Date Time Picker, and on some TabView screens.
  Check `app_debug command=crash_log`: a Pepper frame means it's not an app bug. A crash loses every
  event not yet harvested, so **flush before risky screens** (next step).

## 4. Flush

The agent buffers events for up to 60 s. Force a harvest with pepper
`app_debug command=lifecycle action=background`, wait about 8 s, and look for the new `harvest`
line. Backgrounding ends every open visit. `action=foreground` resumes the run, but the agent may
start a new session, which `timeSinceLoad` resets for.

End the scenario with a final `background` flush, then stop the collector (Ctrl-C, or kill the
background task). For NRTestApp, confirm `restored NRAPI-Info.plist` was printed.

## 5. Render

```bash
cd <repo>
# Session flow diagram: screens, transitions, per-screen timings
./scripts/mobileview_flow.py /tmp/mv/events.json --title "My scenario" --svg /tmp/mv/flow.svg

# Timeline: one bar per visit, load window before it, timing marks as diamonds
./scripts/mobileview_flow.py /tmp/mv/events.json --timeline --max-visits 100 \
    --title "My scenario timeline" --svg /tmp/mv/timeline.svg

open /tmp/mv/flow.svg /tmp/mv/timeline.svg
```

Each command also prints the Mermaid source on stdout; paste it into a PR or Confluence page. The
flow command's stderr table (`screen  TTID  TTFD  …  lie  n`) is a quick read of per-screen timings.
`--include-components` shows child-controller components; `--timeline` defaults to 25 visits.

## 6. Validate

A diagram that renders is not a diagram that is right. Check the capture against the route you
wrote down:

1. **Every step of the route is an edge**, and there are no surprise edges. On iOS, going *back* in
   SwiftUI is not a new visit (one event per visit), while UIKit reports the uncovered screen again
   with `loadTimeUnavailable=noConstructionObserved`.
2. **Names are screen names.** No `ModifiedContent<…>`, `UIHostingController<…>` or `AnyView`
   strings. A very long node in `flow.svg` is the giveaway.
3. **Referrer ids join.** Every `previousViewInstanceId` should match a reported visit:

   ```bash
   python3 - <<'EOF'
   import json
   mv = [e for e in json.load(open('/tmp/mv/events.json')) if e['eventType'] == 'MobileView']
   ids = {e['viewInstanceId'] for e in mv}
   bad = [(e['viewName'], e.get('previousView')) for e in mv
          if e.get('previousViewInstanceId') and e['previousViewInstanceId'] not in ids]
   print(f"{len(bad)} of {len(mv)} referrer ids dangle"); [print('  ', b) for b in bad]
   EOF
   ```

4. **The timeline is consecutive.** For UIKit push/pop, each bar starts where the previous screen's
   bar ends, to within a millisecond. A bar reaching the end of the session means the input is
   being read the wrong way.

## Reading the timeline

Each MobileView event is emitted when a visit **ends**. Its `timestamp` is the bar's right edge, and
`timestamp − timeVisible` is the left edge. Timing marks (`MobileViewTiming`) are recorded *during*
the visit, so they arrive before the visit's event. Parents contain their children: a component or a
screen under a modal spans the child's bar.

## Files

- `scripts/mobileview_capture_collector.py`: the fake collector.
- `scripts/mobileview_flow.py`: the renderer; `--help` lists every flag.
- `Test Harness/HomeSearch`, `Test Harness/NRTestApp`: the scenario apps.
