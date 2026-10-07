#!/bin/zsh
# One scripted NRTestApp session over the WebView sample screens, identical for every build.
# Usage: scenario.sh <out-dir>     (the app must be running in capture mode, on its first screen)
set -u
UDID=${UDID:-$(xcrun simctl list devices booted | grep -oE "[0-9A-F-]{36}" | head -1)}
BUNDLE=com.newrelic.NRApp.bitcode
OUT=${1:A}
HERE=${0:A:h}
mkdir -p $OUT
P=(pepper-ctl --simulator $UDID --timeout 20)
T0=$(date +%s)
step() { echo "$(( $(date +%s) - T0 ))s $*" | tee -a $OUT/steps.log; }
until_t() { while (( $(date +%s) - T0 < $1 )); do sleep 1; done; }
tap() { $P tap "$@" >/dev/null 2>&1 || step "  tap failed: $*"; sleep 1.2; }
# Screen changes are done from outside (exact-match navigation); the script waits for the signal file.
navwait() { step "NAV $1 (waiting for $OUT/nav_$1)"; while [ ! -f $OUT/nav_$1 ]; do sleep 1; done; step "  nav $1 done"; }

DATA=$(xcrun simctl get_app_container $UDID $BUNDLE data)
rm -rf "$DATA/Documents/NRCapture"
: > $OUT/steps.log; rm -f $OUT/nav_*

# Agent logs from the host, so nothing extra rides on the app's own connection.
xcrun simctl spawn $UDID log stream --style compact --level debug \
  --predicate 'process == "NRTestApp" AND (eventMessage CONTAINS "NR-WV-SR" OR eventMessage CONTAINS "Session replay" OR eventMessage CONTAINS "session replay")' \
  > $OUT/agent.log 2>&1 &
LOGPID=$!
python3 $HERE/cpu_sampler.py $UDID NRTestApp 490 $OUT/cpu.json &
CPUPID=$!

step "on Web View (Local) -- navigated before start"
sleep 4
step "local page: increment x5, add item x3, type"
for i in 1 2 3 4 5; do tap --point 112,490; done
for i in 1 2 3; do tap --point 82,712; done
tap --point 192,575
$P input --text "Type something" --value "replay test" >/dev/null 2>&1 || step "  input failed"
until_t 75

step "example.com"
tap --text example.com
until_t 110
$P scroll --direction down --amount 200 >/dev/null 2>&1
until_t 150

step "newrelic.com (page has its own browser agent)"
tap --text newrelic.com
until_t 180
$P scroll --direction down --amount 400 >/dev/null 2>&1; sleep 3
$P scroll --direction down --amount 400 >/dev/null 2>&1
until_t 225

step "back to Local: increment x3"
tap --text Local
sleep 3
for i in 1 2 3; do tap --point 112,490; done
until_t 270

step "Multiple Web Views: tap each"
navwait multi
sleep 5
for pt in 100,330 300,330 100,650 300,650; do tap --point $pt; done
until_t 345
step "Reload all"
tap --id multiWebViewReloadAll
until_t 420

navwait leave
until_t 485
step "done"

wait $CPUPID
kill $LOGPID 2>/dev/null
cp -R "$DATA/Documents/NRCapture" $OUT/blobs 2>/dev/null || step "  no blobs captured"
python3 $HERE/analyze_blobs.py $OUT/blobs > $OUT/chunks.json
step "analyzed $(ls $OUT/blobs 2>/dev/null | wc -l | tr -d ' ') chunk(s)"
python3 $HERE/save_payloads.py $OUT | while read -r line; do step "$line"; done
