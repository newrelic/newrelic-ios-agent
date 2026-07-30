# NewRelic.h/.m → Swift Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert `Agent/Public/NewRelic.h`/`.m` (the customer-facing `NewRelic` class) to a single `NewRelic.swift`, preserving the exact existing ObjC-compatible contract — including undocumented selectors depended on by six hybrid-framework SDKs — with zero required changes for any consumer.

**Architecture:** Big-bang single-file rewrite (design decision: see `docs/superpowers/specs/2026-07-30-newrelic-public-api-swift-migration-design.md`). Because Objective-C and Swift cannot both declare a class named `NewRelic` in the same module, the Swift file is authored across several tasks but only becomes the compiled implementation at the cutover task, where `NewRelic.m` is deleted and `NewRelic.h` collapses to a stub. `@objcMembers public class NewRelic: NSObject`, one Swift method per existing ObjC method, each pinned with an explicit `@objc(exactSelector:)` matching today's selector exactly.

**Tech Stack:** Objective-C, Swift 5, Xcode/xcodebuild, XCTest, CocoaPods (for the six downstream hybrid repos' regression checks).

## Global Constraints

- Every ported method keeps its exact original selector via an explicit `@objc(...)` pin — never rely on Swift's auto-derived selector name.
- Preserve nullability 1:1: ObjC `__nullable`/`_Nullable` → Swift `Optional`; `__nonnull`/`_Nonnull`/unannotated → Swift non-optional.
- Untyped `NSDictionary *` parameters (no generic type in the original ObjC declaration) become Swift `[AnyHashable: Any]?` — not `[String: Any]?` — so the ObjC-generated signature stays exactly as loosely typed as the original, not tightened.
- `+ (T) methodName` → `public static func methodName` (no `class func` — `NewRelic` is a stateless utility type, never subclassed).
- `NRLOG_*`/`NRLOG_*_ATTRS` are C preprocessor macros (`##__VA_ARGS__`-based) — **Swift cannot call C macros.** They expand to real `NRLogger` class methods (confirmed in `Agent/Public/NRLogger.h:120-137`). Every macro call in the original source must be replaced with a direct call to the underlying `NRLogger.log(...)` method, using Swift's `#fileID`/`#line`/`#function` literals in place of the macros' `__FILE__`/`__LINE__`/`__func__`.
- `@throw [NSException exceptionWithName:reason:userInfo:]` → Swift `NSException(name:reason:userInfo:).raise()` (this correctly raises through the same ObjC runtime mechanism).
- `@try { } @catch (NSException *e) { }` has **no Swift equivalent** — Swift cannot catch `NSException`. Task 3 creates a tiny ObjC bridging helper for the two call sites that need this (`startInteractionWithName:`, `stopCurrentInteraction:`).
- All work happens on a feature branch off `develop` — do not commit implementation work directly to `develop` (only the already-committed design spec lives there).

---

## Task 0: Create feature branch

**Files:** none (git operation only).

- [ ] **Step 1: Create and switch to a feature branch**

```bash
git checkout -b swift-migration/newrelic-public-api develop
```

- [ ] **Step 2: Confirm branch and clean working tree**

Run: `git status`
Expected: `On branch swift-migration/newrelic-public-api`, nothing to commit.

---

## Task 1: Selector audit — produce the complete manifest

**Files:**
- Create: `docs/superpowers/plans/newrelic-selector-manifest.md`

**Interfaces:**
- Produces: the authoritative list of every selector Tasks 4-6 must implement, consumed by every later task in this plan.

This file replaces guesswork: it is the ground truth this plan was built from, re-derived here so it's checked into git and independently verifiable rather than living only in a chat transcript.

- [ ] **Step 1: Extract every implemented selector from `NewRelic.m`**

Run: `grep -n "^+ (" Agent/Public/NewRelic.m`

This lists every `+ (...)` implementation. Cross-reference each against `Agent/Public/NewRelic.h` to mark it public (declared) or hidden (implemented but not declared).

- [ ] **Step 2: Write the manifest file**

```markdown
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
```

- [ ] **Step 3: Verify completeness**

Run: `grep -c "^+ (" Agent/Public/NewRelic.m`
Expected: the count matches the total number of selectors listed in the manifest (public + hidden combined; note `startTracingMethod:object:timer:category:` and `startTracingMethodNamed:objectNamed:timer:category:` are two distinct implementations, as are the four `startWithApplicationToken:...` variants and the two `log:level:...` variants).

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans/newrelic-selector-manifest.md
git commit -m "Add NewRelic selector manifest for Swift migration pilot"
```

---

## Task 2: Enable library evolution mode

**Files:**
- Modify: `Agent.xcodeproj/project.pbxproj` (or the relevant `.xcconfig` if build settings are externalized — check both before editing)

**Interfaces:**
- Produces: `BUILD_LIBRARY_FOR_DISTRIBUTION = YES` on the framework target, required for ABI-stable Swift/ObjC mixed binaries in the distributed XCFramework.

- [ ] **Step 1: Locate the current build setting**

Run: `grep -n "BUILD_LIBRARY_FOR_DISTRIBUTION\|SWIFT_VERSION" Agent.xcodeproj/project.pbxproj | head -20`

- [ ] **Step 2: Set `BUILD_LIBRARY_FOR_DISTRIBUTION = YES`** for the `Agent`/framework target's Release and Debug configurations (edit the `.pbxproj` build settings, or the `.xcconfig` if that's where these live per Step 1's output).

- [ ] **Step 3: Build with zero source changes to confirm the setting alone doesn't break anything**

Run: `xcodebuild -project Agent.xcodeproj -scheme Agent-iOS -sdk iphonesimulator build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Agent.xcodeproj/project.pbxproj
git commit -m "Enable library evolution mode ahead of NewRelic Swift migration"
```

---

## Task 3: ObjC exception-bridging helper

**Files:**
- Create: `Agent/Public/NRExceptionCatcher.h`
- Create: `Agent/Public/NRExceptionCatcher.m`
- Test: `Tests/Unit-Tests/NewRelicAgentTests/API-Tests/NRExceptionCatcherTests.m`

**Interfaces:**
- Produces: `NRExceptionCatcher.tryBlock(_:catchBlock:) -> Bool` (as bridged into Swift), used by Task 5's `startInteractionWithName:`/`stopCurrentInteraction:` ports.

Swift has no equivalent to `@catch (NSException *e)`. The two call sites in `NewRelic.m` that rely on it (`startInteractionWithName:` at lines 461-475, `stopCurrentInteraction:` at lines 490-501) need a small ObjC shim, since only ObjC/C++ can catch `NSException`.

- [ ] **Step 1: Write the header**

```objc
// NRExceptionCatcher.h
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface NRExceptionCatcher : NSObject
+ (BOOL)tryBlock:(void (NS_NOESCAPE ^)(void))tryBlock
      catchBlock:(void (^)(NSException *exception))catchBlock;
@end

NS_ASSUME_NONNULL_END
```

- [ ] **Step 2: Write the implementation**

```objc
// NRExceptionCatcher.m
#import "NRExceptionCatcher.h"

@implementation NRExceptionCatcher

+ (BOOL)tryBlock:(void (^)(void))tryBlock
      catchBlock:(void (^)(NSException *exception))catchBlock {
    @try {
        tryBlock();
        return YES;
    } @catch (NSException *exception) {
        if (catchBlock) {
            catchBlock(exception);
        }
        return NO;
    }
}

@end
```

- [ ] **Step 3: Write the failing test**

```objc
// NRExceptionCatcherTests.m
#import <XCTest/XCTest.h>
#import "NRExceptionCatcher.h"

@interface NRExceptionCatcherTests : XCTestCase
@end

@implementation NRExceptionCatcherTests

- (void)testTryBlockReturnsYesWhenNoExceptionThrown {
    BOOL result = [NRExceptionCatcher tryBlock:^{
        // no-op
    } catchBlock:^(NSException *exception) {
        XCTFail(@"catchBlock should not run");
    }];
    XCTAssertTrue(result);
}

- (void)testTryBlockReturnsNoAndInvokesCatchBlockWhenExceptionThrown {
    __block BOOL caughtCalled = NO;
    __block NSString *caughtName = nil;
    BOOL result = [NRExceptionCatcher tryBlock:^{
        @throw [NSException exceptionWithName:@"TestException" reason:@"boom" userInfo:nil];
    } catchBlock:^(NSException *exception) {
        caughtCalled = YES;
        caughtName = exception.name;
    }];
    XCTAssertFalse(result);
    XCTAssertTrue(caughtCalled);
    XCTAssertEqualObjects(caughtName, @"TestException");
}

@end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -project Agent.xcodeproj -scheme Agent-iOS -sdk iphonesimulator -only-testing:Agent_Tests/NRExceptionCatcherTests`
Expected: both tests PASS.

- [ ] **Step 5: Add both new files to the `Agent-iOS` target and the test file to `Agent_Tests`** in `Agent.xcodeproj/project.pbxproj`.

- [ ] **Step 6: Commit**

```bash
git add Agent/Public/NRExceptionCatcher.h Agent/Public/NRExceptionCatcher.m \
        Tests/Unit-Tests/NewRelicAgentTests/API-Tests/NRExceptionCatcherTests.m \
        Agent.xcodeproj/project.pbxproj
git commit -m "Add NRExceptionCatcher: ObjC bridge for @try/@catch, needed by NewRelic Swift port"
```

---

## Task 4: Author NewRelic.swift — Part 1 (crash helper, logging, SDK configuration)

**Files:**
- Create: `Agent/Public/NewRelic.swift` (not yet added to the Xcode target — see note below)

**Interfaces:**
- Consumes: nothing from earlier tasks except the constraints in Global Constraints.
- Produces: the first third of `NewRelic.swift`'s method bodies, consumed by Task 6 (cutover) which assembles the complete file.

**Note on buildability:** this file is created on disk but deliberately **not** added to `Agent.xcodeproj`'s target membership yet — `NewRelic.m` still declares `@interface NewRelic`, and Objective-C forbids two classes with the same name in one module. This task's file will not compile standalone; review it by reading against the ObjC source cited per method, not by building. The file becomes buildable at Task 6.

- [ ] **Step 1: Write the file header and crash-helper section**

```swift
// NewRelic.swift
import Foundation

@objcMembers
public class NewRelic: NSObject {

    // MARK: - Helpers for trying out New Relic features

    @objc(crashNow:)
    public static func crashNow(_ message: String?) {
        // If Agent is shutdown we shouldn't respond.
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return
        }
        NSException(
            name: NSExceptionName("NewRelicDemoException"),
            reason: message ?? "This is a demo crash from +[NewRelic demoCrash:]",
            userInfo: nil
        ).raise()
    }

    @objc(crashNow)
    public static func crashNow() {
        crashNow(nil)
    }
```

(Original: `NewRelic.m:37-40` and `146-156`. The `crashNow` argument-less overload's guard is inherited by calling the message-taking overload, matching the original's `[self crashNow:nil]` delegation exactly.)

- [ ] **Step 2: Write the Logging section**

```swift
    // MARK: - Logging

    @objc(logInfo:)
    public static func logInfo(_ message: String) {
        NRLogger.log(NRLogLevelInfo, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
    }

    @objc(logError:)
    public static func logError(_ message: String) {
        NRLogger.log(NRLogLevelError, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        NewRelicAgentInternal.sharedInstance().sessionReplayOnError(nil)
    }

    @objc(logVerbose:)
    public static func logVerbose(_ message: String) {
        NRLogger.log(NRLogLevelVerbose, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
    }

    @objc(logWarning:)
    public static func logWarning(_ message: String) {
        NRLogger.log(NRLogLevelWarning, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
    }

    @objc(logAudit:)
    public static func logAudit(_ message: String) {
        NRLogger.log(NRLogLevelAudit, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
    }

    @objc(logDebug:)
    public static func logDebug(_ message: String) {
        NRLogger.log(NRLogLevelDebug, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
    }

    @objc(log:level:)
    public static func log(_ message: String, level: NRLogLevels) {
        switch level {
        case NRLogLevelError:
            NRLogger.log(NRLogLevelError, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        case NRLogLevelWarning:
            NRLogger.log(NRLogLevelWarning, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        case NRLogLevelInfo:
            NRLogger.log(NRLogLevelInfo, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        case NRLogLevelVerbose:
            NRLogger.log(NRLogLevelVerbose, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        case NRLogLevelAudit:
            NRLogger.log(NRLogLevelAudit, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        case NRLogLevelDebug:
            NRLogger.log(NRLogLevelDebug, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        default:
            break
        }
    }

    // Hidden selector (manifest: log:level:attributes:) — 3-arg overload adding attributes:.
    @objc(log:level:attributes:)
    public static func log(_ message: String, level: NRLogLevels, attributes: [AnyHashable: Any]?) {
        switch level {
        case NRLogLevelError:
            NRLogger.log(NRLogLevelError, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAttributes: attributes)
        case NRLogLevelWarning:
            NRLogger.log(NRLogLevelWarning, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAttributes: attributes)
        case NRLogLevelInfo:
            NRLogger.log(NRLogLevelInfo, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAttributes: attributes)
        case NRLogLevelVerbose:
            NRLogger.log(NRLogLevelVerbose, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAttributes: attributes)
        case NRLogLevelAudit:
            NRLogger.log(NRLogLevelAudit, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAttributes: attributes)
        case NRLogLevelDebug:
            NRLogger.log(NRLogLevelDebug, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAttributes: attributes)
        default:
            break
        }
    }

    @objc(logAll:)
    public static func logAll(_ dict: [AnyHashable: Any]) {
        let message = dict["message"] as? String ?? ""
        let levelString = dict["logLevel"] as? String ?? ""
        let level = NRLogger.stringToLevel(levelString)
        log(message, level: level)
    }

    @objc(logAttributes:)
    public static func logAttributes(_ dict: [AnyHashable: Any]) {
        let message = dict["message"] as? String ?? ""
        let levelString = dict["logLevel"] as? String ?? ""
        let level = NRLogger.stringToLevel(levelString)
        var mutableDict = dict
        mutableDict.removeValue(forKey: "message")
        mutableDict.removeValue(forKey: "logLevel")
        log(message, level: level, attributes: mutableDict)
    }

    @objc(logErrorObject:)
    public static func logErrorObject(_ error: NSError) {
        let errorDesc = error.localizedDescription
        logError("Error encountered: \(errorDesc)")
        NewRelicAgentInternal.sharedInstance().sessionReplayOnError(nil)
    }
```

(Original: `NewRelic.m:42-144`. `NRLogLevels` raw-value/parameter-type bridging for the `level:` argument of `NRLogger.log(_:inFile:atLine:inMethod:withMessage:withAgentLogsOn:)` — declared in ObjC as `unsigned int` — must be confirmed by the build in Task 6; if the compiler rejects passing `NRLogLevels` directly, use `level.rawValue` instead, per `Agent/Public/NRLogger.h:120-133`.)

- [ ] **Step 3: Write the SDK-configuration section**

```swift
    // MARK: - Configuring the New Relic SDK

    @objc(enableFeatures:)
    public static func enableFeatures(_ featureFlags: NRMAFeatureFlags) {
        NRMAFlags.enableFeatures(featureFlags)
    }

    @objc(disableFeatures:)
    public static func disableFeatures(_ featureFlags: NRMAFeatureFlags) {
        NRMAFlags.disableFeatures(featureFlags)
    }

    @objc(enableCrashReporting:)
    public static func enableCrashReporting(_ enabled: Bool) {
        if enabled {
            NRMAFlags.enableFeatures(.crashReporting)
        } else {
            NRMAFlags.disableFeatures(.crashReporting)
        }
    }

    @objc(setApplicationVersion:)
    public static func setApplicationVersion(_ versionString: String) {
        if NewRelicAgentInternal.sharedInstance() != nil {
            NSException(
                name: NSExceptionName("InvalidUsageException"),
                reason: "'setApplicationVersion:' may only be called prior to calling +[NewRelic startWithApplicationToken:]",
                userInfo: nil
            ).raise()
        }
        NRMAAgentConfiguration.setApplicationVersion(versionString)
    }

    @objc(setApplicationBuild:)
    public static func setApplicationBuild(_ buildNumber: String) {
        if NewRelicAgentInternal.sharedInstance() != nil {
            NSException(
                name: NSExceptionName("InvalidUsageException"),
                reason: "'setApplicationBuild:' may only be called prior to calling +[NewRelic startWithApplicationToken:]",
                userInfo: nil
            ).raise()
        }
        NRMAAgentConfiguration.setApplicationBuild(buildNumber)
    }

    @objc(setPlatform:)
    public static func setPlatform(_ platform: NRMAApplicationPlatform) {
        NRMAAgentConfiguration.setPlatform(platform)
    }

    // Hidden selector (manifest: setPlatformVersion:) — load-bearing for all 6 hybrid SDKs.
    @objc(setPlatformVersion:)
    public static func setPlatformVersion(_ platformVersion: String) {
        NRMAAgentConfiguration.setPlatformVersion(platformVersion)
    }

    // Hidden selector (manifest: saltDeviceUUID:).
    @objc(saltDeviceUUID:)
    public static func saltDeviceUUID(_ enabled: Bool) {
        NRMAFlags.setSaltDeviceUUID(enabled)
    }

    // Hidden selector (manifest: replaceDeviceIdentifier:). Original comment: "pass NULL to stop replacing" — nullable.
    @objc(replaceDeviceIdentifier:)
    public static func replaceDeviceIdentifier(_ identifier: String?) {
        NRMAFlags.setShouldReplaceDeviceIdentifier(identifier)
    }

    @objc(currentSessionId)
    public static func currentSessionId() -> String {
        return NewRelicAgentInternal.sharedInstance().currentSessionId()
    }

    @objc(crossProcessId)
    public static func crossProcessId() -> String? {
        let controller = NRMAHarvestController.harvestController()
        let harvester = controller?.harvester()
        return harvester?.crossProcessID()
    }

    @objc(shutdown)
    public static func shutdown() {
        NewRelicAgentInternal.shutdown()
    }

    @objc(startWithApplicationToken:)
    public static func start(withApplicationToken appToken: String) {
        NewRelicAgentInternal.start(withApplicationToken: appToken, andCollectorAddress: nil)
    }

    @objc(startWithApplicationToken:withoutSecurity:)
    @available(*, deprecated)
    public static func start(withApplicationToken appToken: String, withoutSecurity disableSSL: Bool) {
        NewRelicAgentInternal.start(withApplicationToken: appToken, andCollectorAddress: nil)
    }

    // Hidden selector (manifest: startWithApplicationToken:andCollectorAddress: — 2-arg).
    @objc(startWithApplicationToken:andCollectorAddress:)
    public static func start(withApplicationToken appToken: String, andCollectorAddress url: String?) {
        NewRelicAgentInternal.start(withApplicationToken: appToken, andCollectorAddress: url)
    }

    @objc(startWithApplicationToken:andCollectorAddress:andCrashCollectorAddress:)
    public static func start(withApplicationToken appToken: String, andCollectorAddress url: String?, andCrashCollectorAddress crashCollectorUrl: String?) {
        NewRelicAgentInternal.start(withApplicationToken: appToken, andCollectorAddress: url, andCrashCollectorAddress: crashCollectorUrl)
    }
```

(Original: `NewRelic.m:158-171, 239-330`. `NRMAFlags.enableFeatures`/`disableFeatures` calls use `.crashReporting` — confirm the exact Swift-imported case name for `NRFeatureFlag_CrashReporting` from `NewRelicFeatureFlags.h` during Task 6's build; adjust to the literal imported name if different.)

- [ ] **Step 4: Commit as work-in-progress**

```bash
git add Agent/Public/NewRelic.swift
git commit -m "WIP: NewRelic.swift part 1/3 (crash helper, logging, SDK configuration)"
```

---

## Task 5: Author NewRelic.swift — Part 2 (instrumentation, metrics, network)

**Files:**
- Modify: `Agent/Public/NewRelic.swift`

**Interfaces:**
- Consumes: `NRExceptionCatcher.tryBlock(_:catchBlock:)` from Task 3.
- Produces: the second third of `NewRelic.swift`.

- [ ] **Step 1: Append the custom-instrumentation section**

```swift
    // MARK: - Custom instrumentation

    @objc(createAndStartTimer)
    public static func createAndStartTimer() -> NRTimer {
        return NRTimer()
    }

    // MARK: - Interaction Traces

    @objc(startInteractionWithName:)
    public static func startInteraction(withName interactionName: String) -> String? {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return nil
        }
        if !NRMAFlags.shouldEnableInteractionTracing() {
            NRLogger.log(NRLogLevelVerbose, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "\(#function) not executing; Interaction tracing is disabled.", withAgentLogsOn: true)
            return nil
        }
        var result: String?
        let succeeded = NRExceptionCatcher.tryBlock({
            result = NRMATraceMachineAgentUserInterface.startCustomActivity(interactionName)
        }, catchBlock: { exception in
            NRMAExceptionHandler.logException(exception, class: NSStringFromClass(NewRelic.self), selector: "startInteractionWithName:")
            NRMATraceController.cleanup()
        })
        return succeeded ? result : nil
    }

    @objc(stopCurrentInteraction:)
    public static func stopCurrentInteraction(_ activityIdentifier: String?) {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return
        }
        if !NRMAFlags.shouldEnableInteractionTracing() {
            NRLogger.log(NRLogLevelVerbose, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "\(#function) not executing; Interaction tracing is disabled.", withAgentLogsOn: true)
            return
        }
        _ = NRExceptionCatcher.tryBlock({
            NRMATraceMachineAgentUserInterface.stopCustomActivity(activityIdentifier)
        }, catchBlock: { exception in
            NRMAExceptionHandler.logException(exception, class: NSStringFromClass(NewRelic.self), selector: "stopCurrentInteraction:")
            NRMATraceController.cleanup()
        })
    }

    // MARK: - Method Tracing

    @objc(startTracingMethod:object:timer:category:)
    public static func startTracingMethod(_ selector: Selector, object: Any, timer: NRTimer, category: NRTraceType) {
        startTracingMethodNamed(NSStringFromSelector(selector), objectNamed: NSStringFromClass(type(of: object as AnyObject)), timer: timer, category: category)
    }

    // Hidden selector (manifest: startTracingMethodNamed:objectNamed:timer:category:) — consumed directly by Unity.
    @objc(startTracingMethodNamed:objectNamed:timer:category:)
    public static func startTracingMethodNamed(_ methodName: String, objectNamed objectName: String, timer: NRTimer, category: NRTraceType) {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return
        }
        if !NRMAFlags.shouldEnableInteractionTracing() {
            NRLogger.log(NRLogLevelVerbose, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "\(#function) not executing; Interaction tracing is disabled.", withAgentLogsOn: true)
            return
        }
        let cleanSelectorString = NewRelicInternalUtils.cleanseString(forCollector: methodName)
        if !NRMATraceController.isTracingActive() {
            NRLogger.log(NRLogLevelVerbose, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "\(#function) attempted to start tracing method without active Interaction Trace", withAgentLogsOn: true)
            return
        }
        NRMACustomTrace.startTracingMethod(NSSelectorFromString(cleanSelectorString), objectName: objectName, timer: timer, category: category)
    }

    @objc(endTracingMethodWithTimer:)
    public static func endTracingMethod(withTimer timer: NRTimer) {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return
        }
        timer.stopTimer()
        if !NRMAFlags.shouldEnableInteractionTracing() {
            NRLogger.log(NRLogLevelVerbose, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "\(#function) not executing; Interaction tracing is disabled.", withAgentLogsOn: true)
            return
        }
        if !NRMATraceController.isTracingActive() {
            NRLogger.log(NRLogLevelVerbose, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "\(#function) attempted to end tracing method without active Interaction Trace", withAgentLogsOn: true)
            objc_setAssociatedObject(timer, kNRTraceAssociatedKey, nil, .OBJC_ASSOCIATION_ASSIGN)
            return
        }
        NRMACustomTrace.endTracingMethod(withTimer: timer)
    }
```

(Original: `NewRelic.m:331-334, 448-570`. `kNRTraceAssociatedKey` is a C constant used via `objc_setAssociatedObject` at `NewRelic.m:565` — confirm its exact Swift-visible name/type during Task 6's build; it must be imported from whichever header declares it. `type(of: object as AnyObject)` replicates `NSStringFromClass([object class])` for an `Any`-typed parameter — confirm this bridges correctly for the callers' actual `id` values during Task 6's build, since `object` in the original ObjC signature is untyped `id`.)

- [ ] **Step 2: Append the custom-metrics section**

```swift
    // MARK: - Recording custom metrics

    @objc(recordMetricWithName:category:)
    public static func recordMetric(withName name: String, category: String) {
        NRCustomMetrics.recordMetric(withName: name, category: category)
    }

    @objc(recordMetricWithName:category:value:)
    public static func recordMetric(withName name: String, category: String, value: NSNumber) {
        NRCustomMetrics.recordMetric(withName: name, category: category, value: value)
    }

    @objc(recordMetricWithName:category:value:valueUnits:)
    public static func recordMetric(withName name: String, category: String, value: NSNumber, valueUnits: String?) {
        NRCustomMetrics.recordMetric(withName: name, category: category, value: value, valueUnits: valueUnits)
    }

    @objc(recordMetricWithName:category:value:valueUnits:countUnits:)
    public static func recordMetric(withName name: String, category: String, value: NSNumber, valueUnits: String?, countUnits: String?) {
        NRCustomMetrics.recordMetric(withName: name, category: category, value: value, valueUnits: valueUnits, countUnits: countUnits)
    }

    // Hidden selector (manifest: harvestNow).
    @objc(harvestNow)
    public static func harvestNow() -> Bool {
        return NewRelicAgentInternal.harvestNow()
    }
```

(Original: `NewRelic.m:575-617`.)

- [ ] **Step 3: Append the network section**

```swift
    // MARK: - Recording custom network events

    @objc(setURLRegexRules:)
    public static func setURLRegexRules(_ regexRules: [String: String]) {
        let transformer = NRMAURLTransformer(regexRules: regexRules)
        NewRelicAgentInternal.setURLTransformer(transformer)
    }

    @objc(noticeNetworkRequestForURL:httpMethod:withTimer:responseHeaders:statusCode:bytesSent:bytesReceived:responseData:traceHeaders:andParams:)
    public static func noticeNetworkRequest(
        forURL url: URL,
        httpMethod: String,
        withTimer timer: NRTimer,
        responseHeaders headers: [AnyHashable: Any]?,
        statusCode httpStatusCode: Int,
        bytesSent: UInt,
        bytesReceived: UInt,
        responseData: Data?,
        traceHeaders: [String: String]?,
        andParams params: [AnyHashable: Any]?
    ) {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        let response = HTTPURLResponse(url: url, statusCode: httpStatusCode, httpVersion: "1.1", headerFields: headers as? [String: String])
        NRMANetworkFacade.noticeNetworkRequest(request as NSURLRequest, response: response, withTimer: timer, bytesSent: bytesSent, bytesReceived: bytesReceived, responseData: responseData, traceHeaders: traceHeaders, params: params)
    }

    @objc(noticeNetworkRequestForURL:httpMethod:startTime:endTime:responseHeaders:statusCode:bytesSent:bytesReceived:responseData:traceHeaders:andParams:)
    public static func noticeNetworkRequest(
        forURL url: URL,
        httpMethod: String,
        startTime: Double,
        endTime: Double,
        responseHeaders headers: [AnyHashable: Any]?,
        statusCode httpStatusCode: Int,
        bytesSent: UInt,
        bytesReceived: UInt,
        responseData: Data?,
        traceHeaders: [AnyHashable: Any]?,
        andParams params: [AnyHashable: Any]?
    ) {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        let response = HTTPURLResponse(url: url, statusCode: httpStatusCode, httpVersion: "1.1", headerFields: headers as? [String: String])
        let timer = NRTimer(startTime: startTime, andEndTime: endTime)
        NRMANetworkFacade.noticeNetworkRequest(request as NSURLRequest, response: response, withTimer: timer, bytesSent: bytesSent, bytesReceived: bytesReceived, responseData: responseData, traceHeaders: traceHeaders as? [String: String], params: params)
    }

    @objc(noticeNetworkFailureForURL:httpMethod:withTimer:andFailureCode:)
    public static func noticeNetworkFailure(forURL url: URL, httpMethod: String, withTimer timer: NRTimer, andFailureCode iOSFailureCode: Int) {
        let error = NSError(domain: NSURLErrorDomain, code: iOSFailureCode, userInfo: nil)
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        NRMANetworkFacade.noticeNetworkFailure(request as NSURLRequest, withTimer: timer, withError: error)
    }

    @objc(noticeNetworkFailureForURL:httpMethod:startTime:endTime:andFailureCode:)
    public static func noticeNetworkFailure(forURL url: URL, httpMethod: String, startTime: Double, endTime: Double, andFailureCode iOSFailureCode: Int) {
        let error = NSError(domain: NSURLErrorDomain, code: iOSFailureCode, userInfo: nil)
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        let timer = NRTimer(startTime: startTime, andEndTime: endTime)
        NRMANetworkFacade.noticeNetworkFailure(request as NSURLRequest, withTimer: timer, withError: error)
    }

    @objc(generateDistributedTracingHeaders)
    public static func generateDistributedTracingHeaders() -> [String: String] {
        if NRMAFlags.shouldEnableNewEventSystem() {
            return NRMAHTTPUtilities.generateConnectivityHeaders(withNRMAPayload: NRMAHTTPUtilities.generateNRMAPayload())
        } else {
            return NRMAHTTPUtilities.generateConnectivityHeaders(withPayload: NRMAHTTPUtilities.generatePayload())
        }
    }

    @objc(addHTTPHeaderTrackingFor:)
    public static func addHTTPHeaderTracking(for headers: [String]) {
        NRMAHTTPUtilities.addHTTPHeaderTracking(for: headers)
    }

    @objc(httpHeadersAddedForTracking)
    public static func httpHeadersAddedForTracking() -> [String] {
        return NRMAHTTPUtilities.trackedHeaderFields()
    }
```

(Original: `NewRelic.m:341-443, 917-920`. `NSMutableURLRequest`/`NSHTTPURLResponse` construction is ported to Swift's `URLRequest`/`HTTPURLResponse` value types, then bridged back to `NSURLRequest`/`NSHTTPURLResponse` at the `NRMANetworkFacade` call boundary — confirm `NRMANetworkFacade`'s Swift-imported parameter types accept these during Task 6's build; if it expects the ObjC mutable classes directly, use `NSMutableURLRequest(url:)` instead of `URLRequest` to stay byte-for-byte faithful to the original.)

- [ ] **Step 4: Commit as work-in-progress**

```bash
git add Agent/Public/NewRelic.swift
git commit -m "WIP: NewRelic.swift part 2/3 (instrumentation, metrics, network)"
```

---

## Task 6: Author NewRelic.swift — Part 3 (attributes, events, exceptions, session replay) and cut over

**Files:**
- Modify: `Agent/Public/NewRelic.swift`
- Delete: `Agent/Public/NewRelic.m`
- Modify: `Agent/Public/NewRelic.h` (collapse to stub)
- Modify: `Agent.xcodeproj/project.pbxproj` (add `NewRelic.swift` to target, remove `NewRelic.m`)

**Interfaces:**
- Consumes: Tasks 4-5's `NewRelic.swift` content.
- Produces: the complete, compiled `NewRelic` class.

- [ ] **Step 1: Append the event-retention section**

```swift
    // MARK: - Configuring event collection

    @objc(setMaxEventBufferTime:)
    public static func setMaxEventBufferTime(_ seconds: UInt32) {
        NewRelicAgentInternal.sharedInstance().setMaxEventBufferTime(seconds)
    }

    @objc(setMaxEventPoolSize:)
    public static func setMaxEventPoolSize(_ size: UInt32) {
        NewRelicAgentInternal.sharedInstance().setMaxEventPoolSize(size)
    }

    @objc(setMaxOfflineStorageSize:)
    public static func setMaxOfflineStorageSize(_ megabytes: UInt32) {
        NRMAAgentConfiguration.setMaxOfflineStorageSize(megabytes)
        NRMAHarvestController.setMaxOfflineStorageSize(megabytes)
    }
```

- [ ] **Step 2: Append the attributes section**

```swift
    // MARK: - Tracking global attributes

    @objc(setAttribute:value:)
    public static func setAttribute(_ name: String, value: Any) -> Bool {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return false
        }
        return NewRelicAgentInternal.sharedInstance().analyticsController.setSessionAttribute(name, value: value, persistent: true)
    }

    @objc(incrementAttribute:)
    public static func incrementAttribute(_ name: String) -> Bool {
        return incrementAttribute(name, value: 1)
    }

    @objc(incrementAttribute:value:)
    public static func incrementAttribute(_ name: String, value: NSNumber) -> Bool {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return false
        }
        return NewRelicAgentInternal.sharedInstance().analyticsController.incrementSessionAttribute(name, value: value, persistent: true)
    }

    @objc(setUserId:)
    public static func setUserId(_ userId: String?) -> Bool {
        let agent = NewRelicAgentInternal.sharedInstance()
        if agent == nil || agent.isShutdown {
            return false
        }

        let previousUserId = agent.getUserId()

        // A new session is only started when a non-nil userId is being replaced with a
        // different value (including nil). Setting a userId for the first time
        // (previousUserId == nil) continues the current session so early-startup data
        // is not lost.
        let newSession = previousUserId != nil && previousUserId != userId

        NRLogger.log(NRLogLevelVerbose, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "setUserId: \(userId ?? "nil") and previousUserId: \(previousUserId ?? "nil") and will start newSession=\(newSession)", withAgentLogsOn: true)

        if newSession {
            // userId changed — end the current session and harvest its data under the
            // previous userId, then start a new session and apply the new userId to it.
            // userId is set synchronously here so getUserId() is consistent.
            agent.userId = userId
            agent.startNewSession(forUserId: userId)
            return true
        }

        // No userId was previously set — continue the current session and apply the
        // userId to it.
        agent.userId = userId

        if let userId = userId {
            return agent.analyticsController.setSessionAttribute(kNRMA_Attrib_userId, value: userId, persistent: true)
        } else {
            return agent.analyticsController.removeSessionAttribute(named: kNRMA_Attrib_userId)
        }
    }

    @objc(removeAttribute:)
    public static func removeAttribute(_ name: String) -> Bool {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return false
        }
        return NewRelicAgentInternal.sharedInstance().analyticsController.removeSessionAttribute(named: name)
    }

    @objc(removeAllAttributes)
    public static func removeAllAttributes() -> Bool {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return false
        }
        return NewRelicAgentInternal.sharedInstance().analyticsController.removeAllSessionAttributes()
    }
```

(Original: `NewRelic.m:622-706`. `kNRMA_Attrib_userId` is a C string constant declared elsewhere (likely `Constants.h`, already imported by the original `.m`) — confirm its Swift-visible name during Task 6's build.)

- [ ] **Step 3: Append the custom-events section**

```swift
    // MARK: - Custom events

    @objc(recordCustomEvent:name:attributes:)
    public static func recordCustomEvent(_ eventType: String, name: String?, attributes: [AnyHashable: Any]?) -> Bool {
        var mutableAttributes = attributes ?? [:]
        if let name = name, !name.isEmpty {
            mutableAttributes["name"] = name
        }
        return recordCustomEvent(eventType, attributes: mutableAttributes)
    }

    @objc(recordCustomEvent:attributes:)
    public static func recordCustomEvent(_ eventType: String, attributes: [AnyHashable: Any]?) -> Bool {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return false
        }
        return NewRelicAgentInternal.sharedInstance().analyticsController.addCustomEvent(eventType, withAttributes: attributes)
    }

    @objc(recordBreadcrumb:attributes:)
    public static func recordBreadcrumb(_ name: String, attributes: [AnyHashable: Any]?) -> Bool {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return false
        }
        return NewRelicAgentInternal.sharedInstance().analyticsController.addBreadcrumb(name, withAttributes: attributes)
    }

    @objc(recordJavascriptError:message:stackTrace:isFatal:additionalAttributes:)
    public static func recordJavascriptError(_ name: String, message: String, stackTrace: String, isFatal: Bool, additionalAttributes: [AnyHashable: Any]?) -> Bool {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return false
        }
        if !NRMAFlags.shouldEnableJSErrorEvents() {
            NRLogger.log(NRLogLevelVerbose, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "JS Error reporting is disabled via feature flag. Cannot record JS error.", withAgentLogsOn: true)
            return false
        }
        #if os(iOS)
        guard let jsErrorController = NewRelicAgentInternal.sharedInstance().jsErrorController else {
            NRLogger.log(NRLogLevelError, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "JS Error Controller is not initialized. Cannot record JS error.", withAgentLogsOn: true)
            return false
        }
        NewRelicAgentInternal.sharedInstance().sessionReplayOnError(nil)
        jsErrorController.recordJSError(name, message: message, stackTrace: stackTrace, isFatal: isFatal, additionalAttributes: additionalAttributes)
        return true
        #else
        NRLogger.log(NRLogLevelError, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "JS Error reporting is only available on iOS. Cannot record JS error.", withAgentLogsOn: true)
        return false
        #endif
    }
```

(Original: `NewRelic.m:711-789`. `#if TARGET_OS_IOS` → Swift `#if os(iOS)` — confirm this compiles correctly for the tvOS/watchOS build targets during Task 6's build, since the original conditional compilation exists specifically to exclude this from non-iOS platforms.)

- [ ] **Step 4: Append the handled-exceptions/errors section**

```swift
    // MARK: - Handled Exceptions

    @objc(recordHandledException:)
    public static func recordHandledException(_ exception: NSException) {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return
        }
        NewRelicAgentInternal.sharedInstance().sessionReplayOnError(nil)
        NewRelicAgentInternal.sharedInstance().handledExceptionsController.recordHandledException(exception)
    }

    @objc(recordHandledException:withAttributes:)
    public static func recordHandledException(_ exception: NSException, withAttributes attributes: [AnyHashable: Any]?) {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return
        }
        NewRelicAgentInternal.sharedInstance().sessionReplayOnError(nil)
        NewRelicAgentInternal.sharedInstance().handledExceptionsController.recordHandledException(exception, attributes: attributes)
    }

    @objc(recordHandledExceptionWithStackTrace:)
    public static func recordHandledException(withStackTrace exceptionDictionary: [AnyHashable: Any]) {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return
        }
        NewRelicAgentInternal.sharedInstance().sessionReplayOnError(nil)
        NewRelicAgentInternal.sharedInstance().handledExceptionsController.recordHandledException(withStackTrace: exceptionDictionary)
    }

    // MARK: - Handled Errors

    @objc(recordError:)
    public static func recordError(_ error: NSError) {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return
        }
        NewRelicAgentInternal.sharedInstance().sessionReplayOnError(nil)
        NewRelicAgentInternal.sharedInstance().handledExceptionsController.recordError(error, attributes: nil)
    }

    @objc(recordError:attributes:)
    public static func recordError(_ error: NSError, attributes: [AnyHashable: Any]?) {
        if NewRelicAgentInternal.sharedInstance().isShutdown {
            return
        }
        NewRelicAgentInternal.sharedInstance().sessionReplayOnError(nil)
        NewRelicAgentInternal.sharedInstance().handledExceptionsController.recordError(error, attributes: attributes)
    }
```

(Original: `NewRelic.m:173-237`.)

- [ ] **Step 5: Append the session-replay and remaining hidden-API sections**

```swift
    // MARK: - Session Replay Masking

    @objc(addSessionReplayMaskViewClass:)
    public static func addSessionReplayMaskViewClass(_ viewClassName: String) -> Bool {
        if viewClassName.isEmpty {
            NRLogger.log(NRLogLevelError, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "addSessionReplayMaskViewClass: viewClassName must not be null or empty", withAgentLogsOn: true)
            return false
        }
        return NRMAAgentConfiguration.addLocalMaskedClassName(viewClassName)
    }

    @objc(addSessionReplayUnmaskViewClass:)
    public static func addSessionReplayUnmaskViewClass(_ viewClassName: String) -> Bool {
        if viewClassName.isEmpty {
            NRLogger.log(NRLogLevelError, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "addSessionReplayUnmaskViewClass: viewClassName must not be null or empty", withAgentLogsOn: true)
            return false
        }
        return NRMAAgentConfiguration.addLocalUnmaskedClassName(viewClassName)
    }

    @objc(addSessionReplayMaskedAccessibilityIdentifier:)
    public static func addSessionReplayMaskedAccessibilityIdentifier(_ identifier: String) -> Bool {
        if identifier.isEmpty {
            NRLogger.log(NRLogLevelError, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "addSessionReplayMaskedAccessibilityIdentifier: accessibilityIdentifier must not be null or empty", withAgentLogsOn: true)
            return false
        }
        return NRMAAgentConfiguration.addLocalMaskedAccessibilityIdentifier(identifier)
    }

    @objc(addSessionReplayUnmaskedAccessibilityIdentifier:)
    public static func addSessionReplayUnmaskedAccessibilityIdentifier(_ identifier: String) -> Bool {
        if identifier.isEmpty {
            NRLogger.log(NRLogLevelError, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "addSessionReplayUnmaskedAccessibilityIdentifier: accessibilityIdentifier must not be null or empty", withAgentLogsOn: true)
            return false
        }
        return NRMAAgentConfiguration.addLocalUnmaskedAccessibilityIdentifier(identifier)
    }

    // MARK: - Session Replay Manual

    @objc(recordReplay)
    public static func recordReplay() -> Bool {
        return NewRelicAgentInternal.sharedInstance().recordReplay()
    }

    @objc(pauseReplay)
    public static func pauseReplay() -> Bool {
        return NewRelicAgentInternal.sharedInstance().pauseReplay()
    }

    // MARK: - Hidden APIs

    // Hidden selector (manifest: keyAttributes). Comment in original: "built for hybrid
    // support and bridging with the browser agent."
    @objc(keyAttributes)
    public static func keyAttributes() -> [AnyHashable: Any] {
        return NRMAKeyAttributes.keyAttributes(NRMAAgentConfiguration.connectionInformation())
    }
}
```

(Original: `NewRelic.m:830-920`. Note `setURLRegexRules:` was already ported in Task 5 Step 3 since it's declared in the public header despite being implemented near the bottom of the original `.m` file, alongside these hidden APIs — don't duplicate it here.)

- [ ] **Step 6: Rewrite `NewRelic.h` as a stub**

```objc
//
//  New Relic for Mobile -- iOS edition
//
//  See:
//    https://docs.newrelic.com/docs/mobile-monitoring for information
//    https://docs.newrelic.com/docs/release-notes/mobile-release-notes/xcframework-release-notes/ for release notes
//
//  Copyright © 2023 New Relic. All rights reserved.
//  See https://docs.newrelic.com/docs/licenses/ios-agent-licenses for license details
//

/*
 *  This document describes various APIs available to further customize New Relic's
 *  data collection. NewRelic's implementation lives in NewRelic.swift; this header
 *  re-exports its generated Objective-C interface plus the supporting declaration
 *  headers so `#import <NewRelic/NewRelic.h>` keeps working unchanged.
 */

#import <NewRelic/NewRelicFeatureFlags.h>
#import <NewRelic/NRConstants.h>
#import <NewRelic/NRTimer.h>
#import <NewRelic/NRLogger.h>
#import <NewRelic/NewRelicCustomInteractionInterface.h>
#import <NewRelic/NRGCDOverride.h>
#import <NewRelic/NewRelic-Swift.h>
```

- [ ] **Step 7: Delete `NewRelic.m`**

```bash
git rm Agent/Public/NewRelic.m
```

- [ ] **Step 8: Update Xcode project membership** — in `Agent.xcodeproj/project.pbxproj`, add `NewRelic.swift` to the `Agent-iOS` (and any sibling tvOS/watchOS) framework target(s) that previously compiled `NewRelic.m`, and remove `NewRelic.m`'s build-phase references.

- [ ] **Step 9: Build**

Run: `xcodebuild -project Agent.xcodeproj -scheme Agent-iOS -sdk iphonesimulator build`
Expected: `** BUILD SUCCEEDED **`. Fix any type/bridging mismatches flagged inline in Steps 1-5 above (the `NRLogLevels` raw-value question, `kNRTraceAssociatedKey`/`kNRMA_Attrib_userId` constant names, `NRMANetworkFacade` parameter types, and the `.crashReporting` feature-flag case name) using the compiler's actual errors as ground truth.

- [ ] **Step 10: Run the full existing test suite**

Run: `xcodebuild test -project Agent.xcodeproj -scheme Agent-iOS -sdk iphonesimulator -only-testing:Agent_Tests/NewRelicTests -only-testing:Agent_Tests/NewRelicAPITest`
Expected: all ~20+ tests in `NewRelicTests.m` and `NewRelicAPITest.m` PASS with zero test-file modifications.

Then run the broader suite to catch anything the targeted run misses:

Run: `xcodebuild test -project Agent.xcodeproj -scheme Agent-iOS -sdk iphonesimulator`
Expected: `** TEST SUCCEEDED **`, no regressions outside the two files above.

- [ ] **Step 11: Commit the cutover**

```bash
git add Agent/Public/NewRelic.swift Agent/Public/NewRelic.h Agent.xcodeproj/project.pbxproj
git commit -m "Cut over NewRelic public API to Swift implementation"
```

---

## Task 7: Hybrid SDK regression

**Files:** none in this repo (regression testing happens in the six sibling checkouts).

**Interfaces:**
- Consumes: the built framework from Task 6.

- [ ] **Step 1: Build the local framework for distribution**

Run whatever this repo's existing release-build script produces as the `.xcframework` (check `Makefile`/`fastlane`/build scripts in the repo root for the existing release process — do not invent a new one).

- [ ] **Step 2: For each of the six hybrid repos, point its Podfile at the local build and run its test suite**

Repos and the selector each must exercise (per the manifest in Task 1):

| Repo | Path | Selector(s) to specifically exercise |
|---|---|---|
| React Native | `/Users/diegomartinez/desktop/newrelic/newrelic-react-native-agent` | `setPlatformVersion:` (compile-time category — will fail to build if missing/renamed) |
| Cordova | `/Users/diegomartinez/desktop/newrelic/newrelic-cordova-plugin` | `setPlatformVersion:` (compile-time category) |
| Unity | `/Users/diegomartinez/desktop/newrelic/newrelic-unity-agent` | `setPlatformVersion:` and `startTracingMethodNamed:objectNamed:timer:category:` (both compile-time categories) |
| Flutter | `/Users/diegomartinez/desktop/newrelic/newrelic-flutter-agent` | `setPlatformVersion:` via `NSSelectorFromString` + `.perform(with:)` — **run-time only**, must actually call `startAgent()` in a test, not just build |
| Capacitor | `/Users/diegomartinez/desktop/newrelic/newrelic-capacitor-plugin` | `setPlatformVersion:` via `NSSelectorFromString` + `.perform(with:)` — **run-time only** |
| MAUI | `/Users/diegomartinez/desktop/newrelic/newrelic-maui-plugin` | `setPlatformVersion:` (compile-time typed binding) |

For each repo: `pod install` (or SPM equivalent) against the local build path, then run that repo's existing test/CI command as documented in its own README/CI config. Flutter and Capacitor are the critical checks — a broken `setPlatformVersion:` selector compiles fine there and only fails when `startAgent()` actually executes at runtime, so their test run must exercise that call path, not just build.

- [ ] **Step 3: Record results**

For each repo, note pass/fail. Any failure blocks proceeding to Task 8 — fix the selector mismatch in `NewRelic.swift` and re-run Task 6's Step 9-10, then retry this task.

---

## Task 8: Smoke test via Test Harness

**Files:** none (manual verification using existing app).

- [ ] **Step 1: Build and run `Test Harness/NRTestApp`** against the new framework build, on a simulator.

- [ ] **Step 2: Exercise the golden path** — app launch (`startWithApplicationToken:`), a manual crash (`crashNow`), a log call (`logInfo:`), a custom event (`recordCustomEvent:attributes:`), and an interaction trace (`startInteractionWithName:`/`stopCurrentInteraction:`). Confirm no crashes and that New Relic One (or local logs, depending on how the test harness reports) shows the expected data.

- [ ] **Step 2: Confirm no regressions** in whatever the test harness's existing smoke-test flows already cover (check for an existing test-harness README/script before improvising new steps).

---

## Task 9: Final cleanup and PR

**Files:**
- Possibly modify: any documentation referencing `NewRelic.m` directly (check first).

- [ ] **Step 1: Grep for stale references**

Run: `grep -rn "NewRelic\.m\b" --include="*.md" --include="*.yml" --include="*.yaml" .`
Expected: no remaining references to the deleted file in docs/CI config; update any found.

- [ ] **Step 2: Push the branch and open a PR against `develop`**

```bash
git push -u origin swift-migration/newrelic-public-api
gh pr create --title "Convert NewRelic public API to Swift (pilot)" --body "$(cat <<'EOF'
## Summary
- Converts Agent/Public/NewRelic.h/.m to a Swift implementation, per docs/superpowers/specs/2026-07-30-newrelic-public-api-swift-migration-design.md
- Preserves every selector (65 public + 8 previously-undocumented hidden selectors — see docs/superpowers/plans/newrelic-selector-manifest.md) with zero required changes for any ObjC/Swift consumer or the six hybrid-framework SDKs
- Adds NRExceptionCatcher, a small ObjC bridge for the two @try/@catch call sites Swift cannot express natively

## Test plan
- [ ] Existing NewRelicTests.m / NewRelicAPITest.m suites pass unmodified
- [ ] Full Agent_Tests target passes
- [ ] All 6 hybrid SDK repos build and pass their own test suites against this build (React Native, Cordova, Unity, Flutter, Capacitor, MAUI)
- [ ] NRTestApp smoke test covers startup/crash/logging/events/interactions
EOF
)"
```

- [ ] **Step 3: Report the pilot's actual cost/friction back into a follow-up note** (not part of this plan — this is the input the deferred "overall roadmap" spec needs). At minimum capture: how many of the "confirm via build" flags in Task 6 needed real fixes, how long the six-repo regression pass took, and whether the exception-bridging helper pattern (Task 3) will recur in other subsystems.

---

## Self-Review Notes

- **Spec coverage:** every section of the design doc's "Design" section maps to a task — Architecture → Tasks 2, 6; Compatibility contract/selector audit → Task 1; Migration mechanics → reflected in Global Constraints and every authoring task; Testing & verification → Tasks 6 (Step 10), 7, 8; Success criteria → Tasks 6, 7, 9.
- **New findings not in the original design doc, folded in during planning:** three additional hidden selectors beyond the one known at design time (`saltDeviceUUID:`, `replaceDeviceIdentifier:`, `startWithApplicationToken:andCollectorAddress:` 2-arg, plus `log:level:attributes:` and `harvestNow` — total 8, not 1), the `NRLOG_*` macro-to-`NRLogger`-API substitution requirement, and the `NSException`/`@catch` bridging gap requiring a new small ObjC helper (Task 3). These are exactly the kind of real cost the pilot exists to surface — worth highlighting in Task 9 Step 3's follow-up note.
- **Uncertain points flagged explicitly rather than guessed silently:** `NRLogLevels` raw-value bridging into `NRLogger.log`'s `unsigned int` parameter, the `.crashReporting` feature-flag case name, `kNRTraceAssociatedKey`/`kNRMA_Attrib_userId` constant visibility, and `NRMANetworkFacade`'s exact Swift-imported parameter types — each called out inline at the relevant step, to be resolved by the compiler in Task 6 Step 9 rather than asserted as fact here.
