# NewRelic selector manifest (source of truth for the Swift port)

## Public selectors (declared in NewRelic.h, must match exactly)

crashNow:, crashNow, logInfo:, logError:, logVerbose:, logWarning:, logAudit:,
logDebug:, log:level:, logAll:, logAttributes:, logErrorObject:, enableFeatures:,
disableFeatures:, enableCrashReporting:, setApplicationVersion:, setApplicationBuild:,
setPlatform:, currentSessionId, crossProcessId, shutdown, startWithApplicationToken:,
startWithApplicationToken:andCollectorAddress:andCrashCollectorAddress:,
startWithApplicationToken:withoutSecurity: (deprecated), createAndStartTimer,
startInteractionWithName:, stopCurrentInteraction:,
startTracingMethod:object:timer:category:, endTracingMethodWithTimer:,
recordMetricWithName:category:, recordMetricWithName:category:value:,
recordMetricWithName:category:value:valueUnits:,
recordMetricWithName:category:value:valueUnits:countUnits:, setURLRegexRules:,
noticeNetworkRequestForURL:httpMethod:withTimer:responseHeaders:statusCode:bytesSent:bytesReceived:responseData:traceHeaders:andParams:,
noticeNetworkRequestForURL:httpMethod:startTime:endTime:responseHeaders:statusCode:bytesSent:bytesReceived:responseData:traceHeaders:andParams:,
noticeNetworkFailureForURL:httpMethod:withTimer:andFailureCode:,
noticeNetworkFailureForURL:httpMethod:startTime:endTime:andFailureCode:,
generateDistributedTracingHeaders, addHTTPHeaderTrackingFor:, httpHeadersAddedForTracking,
recordCustomEvent:attributes:, recordCustomEvent:name:attributes:, recordBreadcrumb:attributes:,
recordJavascriptError:message:stackTrace:isFatal:additionalAttributes:,
setMaxEventBufferTime:, setMaxEventPoolSize:, setMaxOfflineStorageSize:,
setAttribute:value:, incrementAttribute:, incrementAttribute:value:, setUserId:,
removeAttribute:, removeAllAttributes, recordHandledException:,
recordHandledException:withAttributes:, recordHandledExceptionWithStackTrace:,
recordError:, recordError:attributes:, addSessionReplayMaskViewClass:,
addSessionReplayUnmaskViewClass:, addSessionReplayMaskedAccessibilityIdentifier:,
addSessionReplayUnmaskedAccessibilityIdentifier:, recordReplay, pauseReplay

## Hidden selectors (implemented, NOT declared in NewRelic.h — found by diffing
## NewRelic.m against NewRelic.h; several of these were missed by an initial
## audit that only checked the two names a React Native category declaration
## happened to expose, which is why this file does a full line-by-line diff
## instead of trusting any single downstream repo's declarations)

| Selector | NewRelic.m lines | Known external consumer |
|---|---|---|
| `setPlatformVersion:` | 243-246 | All 6 hybrid SDKs (React Native, Cordova, Unity, Flutter, Capacitor, MAUI) |
| `saltDeviceUUID:` | 248-250 | None found in the 6 hybrid repos — internal/undetermined caller |
| `replaceDeviceIdentifier:` | 252-260 | None found in the 6 hybrid repos — internal/undetermined caller |
| `startWithApplicationToken:andCollectorAddress:` (2-arg) | 315-319 | None found in the 6 hybrid repos — internal/undetermined caller |
| `startTracingMethodNamed:objectNamed:timer:category:` | 518-545 | Unity (`NewRelicUnityPlugin.m`, via `NR_startTracingMethodNamed`) |
| `log:level:attributes:` (3-arg, adds `attributes:`) | 92-115 | None found in the 6 hybrid repos — internal/undetermined caller |
| `harvestNow` | 614-617 | None found in the 6 hybrid repos — internal/undetermined caller |
| `keyAttributes` | 913-915 | Explicit `// Hidden APIs` comment: "built for hybrid support and bridging with the browser agent" |

## Selectors seen in hybrid-SDK bridge code that do NOT exist anywhere in this
## repo's `NewRelic` class today (version-drift flag, not a blocker)

`setSessionReplayExternalCaptureSource`, `sessionReplayConfiguration`,
`recordSessionReplayEvents` were reported from the Flutter/Capacitor bridge
source during upstream investigation, but do not exist on `NewRelic` (or
anywhere in `Agent/`) in this checkout. Before starting Task 4, confirm via
`grep -rn "setSessionReplayExternalCaptureSource\|sessionReplayConfiguration\|recordSessionReplayEvents" Agent`
that this is still the case — if it is, these belong to a different public
type or a newer/older SDK version than this checkout, and are out of scope
for this pilot (which only touches the `NewRelic` class).
