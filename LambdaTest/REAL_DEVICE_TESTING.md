# NRTestApp on LambdaTest real devices (`mobile-views-2`)

Runs the same 9 iOS specs as the virtual-device suite, on real hardware.

## The two pipelines side by side

|                    | Virtual device                          | Real device                                            |
| ------------------ | --------------------------------------- | ------------------------------------------------------ |
| App artifact       | unsigned simulator `.app`, zipped       | **signed `.ipa`** (archive + export)                   |
| Upload endpoint    | `/app/upload/virtualDevice`             | `/app/upload/realDevice`                               |
| Upload script      | `uploadAppToLambdaTest.mjs`             | `uploadAppToLambdaTest-realDevice.mjs`                 |
| App-id file        | `last-app-id`                           | `last-app-id-realdevice`                               |
| WDIO config        | `wdio-config-ios.js`                    | `wdio-config-ios-realdevice.js`                        |
| Concurrency        | `maxInstances: 10`                      | `maxInstances: 1`                                      |
| Default target     | iPhone 17 / iOS 26.0                    | iPhone 15 / iOS 18                                     |
| npm script         | `test:wdio-ios`                         | `test:wdio-ios-realdevice`                             |
| Build workflow     | `uploadApp-mobile-views-2.yml` (daily)  | `uploadApp-mobile-views-2-realdevice.yml` (dispatch)   |
| Test workflow      | `wdio-mobile-views-2.yml`               | `wdio-mobile-views-2-realdevice.yml`                   |
| Results file       | `test-results.json`                     | `test-results-realdevice.json`                         |
| Specs              | `tests/*.test.js` (9)                   | those 9, **plus** `tests-realdevice/crash-reporting.test.js` |

Nothing in the virtual path was modified. The two never share an app id, a
results file, or a build name.

## Running it

Dispatch **Upload iOS NRTestApp IPA (mobile-views-2) to LambdaTest real devices**
from the Actions UI. It archives, exports a signed IPA, uploads it, then chains
to the real-device test workflow with the fresh app id.

It is manual-dispatch only on purpose: the signed archive takes roughly 20
minutes and real-device minutes are limited. Add a `schedule:` block once it has
been green a few times.

To re-run only the tests against an IPA already on LambdaTest, dispatch **WDIO:
automate iOS tests on real device (mobile-views-2)** and paste the `custom_id`.
That workflow also takes optional `device_name` / `platform_version` inputs for
retargeting hardware without editing the config.

## Running it locally

```sh
export LT_USERNAME=... LT_ACCESSKEY=...

# 1. Get a signed IPA to builds/nrtestapp-ios.ipa. Easiest path is to download
#    the nrtestapp-ios-ipa artifact from a workflow run and unzip it there.
#    (builds/*.ipa is gitignored.)

# 2. Upload it. Writes LambdaTest/last-app-id-realdevice.
node LambdaTest/uploadAppToLambdaTest-realDevice.mjs

# 3. Run the suite. Picks up last-app-id-realdevice automatically.
npm run test:wdio-ios-realdevice

# Optional: retarget hardware
LT_DEVICE_NAME="iPhone 14" LT_PLATFORM_VERSION=17 npm run test:wdio-ios-realdevice
```

`last-app-id-realdevice` is not tracked in git, so `LT_APP_ID` (or a local upload)
is required. With neither, the config fails immediately with a clear message
instead of silently targeting a stale app.

## Signing, and what to do if the upload is rejected

The IPA is exported with `method: app-store-connect` using the existing
`APP_STORE_PROVISION_PROFILE_BASE64` secret — the same steps
`archive-nrtestapp.yml` already uses, minus its TestFlight upload. LambdaTest
then **resigns** the IPA with their own provisioning profile, which is their
default for real-device uploads. This needs no new secrets and no Apple portal
work.

If LambdaTest rejects the App Store entitlements at upload or install time, the
fallback is an ad-hoc profile:

1. Create an ad-hoc (Release Testing) distribution profile for
   `com.newrelic.NRApp.bitcode` in the Apple Developer portal.
2. Add it as a new repo secret, e.g. `ADHOC_PROVISION_PROFILE_BASE64`.
3. In `uploadApp-mobile-views-2-realdevice.yml`, decode that secret instead and
   change the ExportOptions `method` to `release-testing`.

Only the "Install Apple distribution certificate and provisioning profile" and
"Write ExportOptions.plist" steps change; archive, export, upload, and the test
workflow are unaffected.

## The crash-reporting spec

`tests-realdevice/crash-reporting.test.js` is real-device-only and runs **last**,
because it deliberately kills the app. It taps `Crash Now!` in Utilities,
confirms the app actually terminated, relaunches it (never reinstalls -- that
would wipe the pending `.crash` file), and then verifies the upload by watching
the device syslog for the agent's crash-uploader lines:

```
NEWRELIC CRASH UPLOADER - Perform crash upload
NEWRELIC CRASH UPLOADER - Crash Upload Response: <NSHTTPURLResponse ... Status Code: 200 ...>
NEWRELIC CRASH UPLOADER - Crash Upload Response Error: ...   (failures only)
```

It asserts **200** specifically. The agent deletes the report on 500 as well as
200, and discards it outright on 400/403, so accepting any 2xx-or-5xx would let a
crash that never landed read as green.

Two agent behaviours have to hold for those lines to exist, both true today:

- **Verbose logging.** The upload lines are `NRLOG_AGENT_VERBOSE`. NRTestApp calls
  `NRLogger.setLogLevels(NRLogLevelDebug)`, and `setLogLevels` expands a single
  constant, so Debug includes Verbose.
- **Console log target.** If `NRFeatureFlag_AutoCollectLogs` is enabled *and* the
  collector's connect config sets `log_reporting_enabled`, the harvester redirects
  stdout and calls `setLogTargets(NRLogTargetFile)` -- console logging stops and
  these lines vanish from syslog. `AutoCollectLogs` is off by default and
  NRTestApp does not enable it.

The spec's first assertion exists to keep that second failure mode legible: it
checks that *any* `NewRelic(` line reaches syslog before trusting the absence of
crash lines to mean anything. If someone enables `AutoCollectLogs` later, you get
an error naming it rather than a misleading "crash upload never happened".

All syslog reads go through one `drainSyslog()` helper. If `getLogs('syslog')`
turns out to be unsupported on LambdaTest real devices, that function is the only
thing to swap for their device-log REST API.

`LT_BUNDLE_ID` overrides the bundle id used for relaunch. By default it is read
off the live session, because LambdaTest's resigning can rewrite it.

## Expect some spec churn on the first run

The 9 specs were written against a simulator. Real hardware differs in keyboard
behaviour, animation timing, and scroll physics, so some may need waits or
selectors adjusted. Nothing was pre-emptively changed — better to see which
actually fail than to guess.
