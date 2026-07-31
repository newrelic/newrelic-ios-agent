// NewRelic.swift
import Foundation
@_implementationOnly import NewRelicPrivate

@objcMembers
public class NewRelic: NSObject {

    // MARK: - Helpers for trying out New Relic features

    @objc(crashNow:)
    public static func crashNow(_ message: String?) {
        // If Agent is shutdown we shouldn't respond.
        if NewRelicAgentInternal.sharedInstance()?.isShutdown ?? false {
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

    // MARK: - Logging

    @objc(logInfo:)
    public static func logInfo(_ message: String) {
        NRLogger.log(NRLogLevelInfo.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
    }

    @objc(logError:)
    public static func logError(_ message: String) {
        NRLogger.log(NRLogLevelError.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        NewRelicAgentInternal.sharedInstance()?.sessionReplay(onError: nil)
    }

    @objc(logVerbose:)
    public static func logVerbose(_ message: String) {
        NRLogger.log(NRLogLevelVerbose.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
    }

    @objc(logWarning:)
    public static func logWarning(_ message: String) {
        NRLogger.log(NRLogLevelWarning.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
    }

    @objc(logAudit:)
    public static func logAudit(_ message: String) {
        NRLogger.log(NRLogLevelAudit.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
    }

    @objc(logDebug:)
    public static func logDebug(_ message: String) {
        NRLogger.log(NRLogLevelDebug.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
    }

    @objc(log:level:)
    public static func log(_ message: String, level: NRLogLevels) {
        switch level {
        case NRLogLevelError:
            NRLogger.log(NRLogLevelError.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        case NRLogLevelWarning:
            NRLogger.log(NRLogLevelWarning.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        case NRLogLevelInfo:
            NRLogger.log(NRLogLevelInfo.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        case NRLogLevelVerbose:
            NRLogger.log(NRLogLevelVerbose.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        case NRLogLevelAudit:
            NRLogger.log(NRLogLevelAudit.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        case NRLogLevelDebug:
            NRLogger.log(NRLogLevelDebug.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        default:
            break
        }
    }

    // Hidden selector (manifest: log:level:attributes:) — 3-arg overload adding attributes:.
    @objc(log:level:attributes:)
    public static func log(_ message: String, level: NRLogLevels, attributes: [AnyHashable: Any]?) {
        switch level {
        case NRLogLevelError:
            NRLogger.log(NRLogLevelError.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAttributes: attributes)
        case NRLogLevelWarning:
            NRLogger.log(NRLogLevelWarning.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAttributes: attributes)
        case NRLogLevelInfo:
            NRLogger.log(NRLogLevelInfo.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAttributes: attributes)
        case NRLogLevelVerbose:
            NRLogger.log(NRLogLevelVerbose.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAttributes: attributes)
        case NRLogLevelAudit:
            NRLogger.log(NRLogLevelAudit.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAttributes: attributes)
        case NRLogLevelDebug:
            NRLogger.log(NRLogLevelDebug.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAttributes: attributes)
        default:
            break
        }
    }

    @objc(logAll:)
    public static func logAll(_ dict: [AnyHashable: Any]) {
        let message = dict["message"] as? String ?? ""
        let levelString = dict["logLevel"] as? String ?? ""
        let level = NRLogger.string(toLevel: levelString)
        log(message, level: level)
    }

    @objc(logAttributes:)
    public static func logAttributes(_ dict: [AnyHashable: Any]) {
        let message = dict["message"] as? String ?? ""
        let levelString = dict["logLevel"] as? String ?? ""
        let level = NRLogger.string(toLevel: levelString)
        var mutableDict = dict
        mutableDict.removeValue(forKey: "message")
        mutableDict.removeValue(forKey: "logLevel")
        log(message, level: level, attributes: mutableDict)
    }

    @objc(logErrorObject:)
    public static func logErrorObject(_ error: NSError) {
        let errorDesc = error.localizedDescription
        logError("Error encountered: \(errorDesc)")
        NewRelicAgentInternal.sharedInstance()?.sessionReplay(onError: nil)
    }

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
            NRMAFlags.enableFeatures(.NRFeatureFlag_CrashReporting)
        } else {
            NRMAFlags.disableFeatures(.NRFeatureFlag_CrashReporting)
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
    public static func currentSessionId() -> NSString! {
        // The original ObjC implementation returned `[[[NewRelicAgentInternal sharedInstance]
        // currentSessionId] copy]` and existing tests (NewRelicTests.m's testCurrentSessionId)
        // compare that exact expression against this method using pointer equality (XCTAssertEqual
        // on Objective-C object pointers does `==`, not `-isEqual:`).
        //
        // -currentSessionId is declared NONNULL in NewRelicAgentInternal.h, but its actual
        // implementation (`return [self agentConfiguration].sessionIdentifier;`) can genuinely
        // return nil before a session has started. Calling it directly from Swift trusts that
        // (incorrect, for this case) nonnull annotation, silently wrapping the nil pointer as if
        // it were a valid String — producing garbage rather than a real nil. Going through
        // Objective-C KVC (value(forKey:)) instead dispatches dynamically and reports the actual
        // runtime nil-ness faithfully as an Optional, exactly like the original's message-to-nil
        // ([nil currentSessionId] / [nil copy]) semantics.
        guard let agent = NewRelicAgentInternal.sharedInstance(),
              let sessionId = agent.value(forKey: "currentSessionId") as? NSString else {
            return nil
        }
        return sessionId.copy() as? NSString
    }

    @objc(crossProcessId)
    public static func crossProcessId() -> NSString? {
        // The original ObjC implementation was:
        //   NRMAHarvestController* controller = [NRMAHarvestController harvestController];
        //   NRMAHarvester* harvester = [controller harvester];
        //   NSString* crossProcessId = [harvester crossProcessID];
        //   return crossProcessId ? [crossProcessId copy] : nil;
        // and existing tests (NewRelicTests.m's testCrossProcessId) compare that exact
        // expression against this method using pointer equality (XCTAssertEqual on
        // Objective-C object pointers does `==`, not `-isEqual:`).
        //
        // +harvestController is a singleton accessor (returns a `@synchronized`-guarded
        // static variable, populated by +initialize:), NOT a plain alloc/init factory.
        // Swift renames it to `init()` (the compiler insists: "'harvestController()' has
        // been replaced by 'init()'"), but calling NRMAHarvestController() actually invokes
        // a genuine fresh NSObject -init, allocating a brand-new, never-initialized
        // instance completely unrelated to the shared singleton (confirmed empirically:
        // its pointer differs from the real singleton's, and its .harvester() is nil).
        // Reading the class method dynamically via KVC on the class object itself
        // sidesteps Swift's static rename/unavailability and reaches the real singleton
        // (confirmed empirically: identical pointer to the real +[NRMAHarvestController
        // harvestController]/harvester() chain) — the same technique used for
        // currentSessionId() above, applied one level up to the class accessor itself.
        guard let controller = (NRMAHarvestController.self as AnyObject).value(forKey: "harvestController") as? NRMAHarvestController,
              let harvester = controller.harvester(),
              let crossProcessId = harvester.value(forKey: "crossProcessID") as? NSString else {
            return nil
        }
        return crossProcessId.copy() as? NSString
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
    public static func start(withApplicationToken appToken: String, andCollectorAddress url: String, andCrashCollectorAddress crashCollectorUrl: String) {
        NewRelicAgentInternal.start(withApplicationToken: appToken, andCollectorAddress: url, andCrashCollectorAddress: crashCollectorUrl)
    }

    // MARK: - Custom instrumentation

    @objc(createAndStartTimer)
    public static func createAndStartTimer() -> NRTimer! {
        return NRTimer()
    }

    // MARK: - Interaction Traces

    @objc(startInteractionWithName:)
    public static func startInteraction(withName interactionName: String!) -> String! {
        if NewRelicAgentInternal.sharedInstance()?.isShutdown ?? false {
            return nil
        }
        if !NRMAFlags.shouldEnableInteractionTracing() {
            NRLogger.log(NRLogLevelVerbose.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "\(#function) not executing; Interaction tracing is disabled.", withAgentLogsOn: true)
            return nil
        }
        var result: String?
        let succeeded = NRExceptionCatcher.try({
            result = NRMATraceMachineAgentUserInterface.startCustomActivity(interactionName)
        }, catch: { exception in
            NRMAExceptionHandler.logException(exception, class: NSStringFromClass(NewRelic.self), selector: "startInteractionWithName:")
            NRMATraceController.cleanup()
        })
        return succeeded ? result : nil
    }

    @objc(stopCurrentInteraction:)
    public static func stopCurrentInteraction(_ activityIdentifier: String?) {
        if NewRelicAgentInternal.sharedInstance()?.isShutdown ?? false {
            return
        }
        if !NRMAFlags.shouldEnableInteractionTracing() {
            NRLogger.log(NRLogLevelVerbose.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "\(#function) not executing; Interaction tracing is disabled.", withAgentLogsOn: true)
            return
        }
        _ = NRExceptionCatcher.try({
            NRMATraceMachineAgentUserInterface.stopCustomActivity(activityIdentifier)
        }, catch: { exception in
            NRMAExceptionHandler.logException(exception, class: NSStringFromClass(NewRelic.self), selector: "stopCurrentInteraction:")
            NRMATraceController.cleanup()
        })
    }

    // MARK: - Method Tracing

    @objc(startTracingMethod:object:timer:category:)
    public static func startTracingMethod(_ selector: Selector, object: Any, timer: NRTimer!, category: NRTraceType) {
        startTracingMethodNamed(NSStringFromSelector(selector), objectNamed: NSStringFromClass(type(of: object as AnyObject)), timer: timer, category: category)
    }

    // Hidden selector (manifest: startTracingMethodNamed:objectNamed:timer:category:) — consumed directly by Unity.
    @objc(startTracingMethodNamed:objectNamed:timer:category:)
    public static func startTracingMethodNamed(_ methodName: String, objectNamed objectName: String, timer: NRTimer, category: NRTraceType) {
        if NewRelicAgentInternal.sharedInstance()?.isShutdown ?? false {
            return
        }
        if !NRMAFlags.shouldEnableInteractionTracing() {
            NRLogger.log(NRLogLevelVerbose.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "\(#function) not executing; Interaction tracing is disabled.", withAgentLogsOn: true)
            return
        }
        // NewRelicInternalUtils.h isn't wrapped in NS_ASSUME_NONNULL, so cleanseString(forCollector:)
        // imports as an implicitly-unwrapped optional; type inference into a `let` collapses that
        // to a plain String?, requiring an explicit unwrap here. cleanseStringForCollector: only ever
        // does in-place character replacement on a non-nil input, so this never actually returns nil
        // for the non-optional `methodName` we always pass in — same assumption the original ObjC made.
        let cleanSelectorString = NewRelicInternalUtils.cleanseString(forCollector: methodName)!
        if !NRMATraceController.isTracingActive() {
            NRLogger.log(NRLogLevelVerbose.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "\(#function) attempted to start tracing method without active Interaction Trace", withAgentLogsOn: true)
            return
        }
        NRMACustomTrace.startTracingMethod(NSSelectorFromString(cleanSelectorString), objectName: objectName, timer: timer, category: category)
    }

    @objc(endTracingMethodWithTimer:)
    public static func endTracingMethod(withTimer timer: NRTimer!) {
        if NewRelicAgentInternal.sharedInstance()?.isShutdown ?? false {
            return
        }
        timer.stop()
        if !NRMAFlags.shouldEnableInteractionTracing() {
            NRLogger.log(NRLogLevelVerbose.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "\(#function) not executing; Interaction tracing is disabled.", withAgentLogsOn: true)
            return
        }
        if !NRMATraceController.isTracingActive() {
            NRLogger.log(NRLogLevelVerbose.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "\(#function) attempted to end tracing method without active Interaction Trace", withAgentLogsOn: true)
            // kNRTraceAssociatedKey is a shared extern NSString* constant also used as the
            // objc_setAssociatedObject/objc_getAssociatedObject key by NRMATraceController.m
            // and NRMACustomTrace.m. Bridging it through NSString and taking its Unmanaged
            // pointer reproduces the same object identity as their `(__bridge const void *)`
            // casts, so this clears the same associated-object slot they read/write.
            let traceAssociatedKey = Unmanaged.passUnretained(kNRTraceAssociatedKey as NSString).toOpaque()
            objc_setAssociatedObject(timer, traceAssociatedKey, nil, .OBJC_ASSOCIATION_ASSIGN)
            return
        }
        NRMACustomTrace.endTracingMethod(with: timer)
    }

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

    // MARK: - Recording custom network events

    @objc(setURLRegexRules:)
    public static func setURLRegexRules(_ regexRules: [String: String]) {
        let transformer = NRMAURLTransformer(regexRules: regexRules)
        NewRelicAgentInternal.setURLTransformer(transformer)
    }

    @objc(noticeNetworkRequestForURL:httpMethod:withTimer:responseHeaders:statusCode:bytesSent:bytesReceived:responseData:traceHeaders:andParams:)
    public static func noticeNetworkRequest(
        forURL url: URL!,
        httpMethod: String!,
        withTimer timer: NRTimer!,
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
        // HTTPURLResponse's initializer is failable in Swift, but NRMANetworkFacade's
        // `response:` parameter is non-optional (NRMANetworkFacade.h is inside
        // NS_ASSUME_NONNULL_BEGIN and doesn't mark it nullable). The original ObjC code
        // never checked this initializer's result for nil either, so force-unwrapping here
        // preserves that same "assume it always succeeds" behavior; a fixed-format URL/HTTP
        // version like this realistically never fails the initializer.
        let response = HTTPURLResponse(url: url, statusCode: httpStatusCode, httpVersion: "1.1", headerFields: headers as? [String: String])!
        // NRMANetworkFacade's `request:` parameter is Swift-imported as URLRequest, not NSURLRequest.
        NRMANetworkFacade.noticeNetworkRequest(request, response: response, with: timer, bytesSent: bytesSent, bytesReceived: bytesReceived, responseData: responseData, traceHeaders: traceHeaders, params: params)
    }

    @objc(noticeNetworkRequestForURL:httpMethod:startTime:endTime:responseHeaders:statusCode:bytesSent:bytesReceived:responseData:traceHeaders:andParams:)
    public static func noticeNetworkRequest(
        forURL url: URL!,
        httpMethod: String!,
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
        // See the force-unwrap note in the sibling overload above: NRMANetworkFacade's
        // `response:` parameter is non-optional, and the original ObjC never checked this
        // failable initializer's result for nil either.
        let response = HTTPURLResponse(url: url, statusCode: httpStatusCode, httpVersion: "1.1", headerFields: headers as? [String: String])!
        // NRTimer's initWithStartTime:andEndTime: returns `id` (not `instancetype`) in the ObjC
        // header, so Swift imports it as a failable init. The original ObjC never checked this for
        // nil either, so force-unwrapping preserves that same "assume it always succeeds" behavior.
        let timer = NRTimer(startTime: startTime, andEndTime: endTime)!
        // NRMANetworkFacade's `request:` parameter is Swift-imported as URLRequest, not NSURLRequest.
        NRMANetworkFacade.noticeNetworkRequest(request, response: response, with: timer, bytesSent: bytesSent, bytesReceived: bytesReceived, responseData: responseData, traceHeaders: traceHeaders as? [String: String], params: params)
    }

    @objc(noticeNetworkFailureForURL:httpMethod:withTimer:andFailureCode:)
    public static func noticeNetworkFailure(forURL url: URL!, httpMethod: String!, withTimer timer: NRTimer!, andFailureCode iOSFailureCode: Int) {
        let error = NSError(domain: NSURLErrorDomain, code: iOSFailureCode, userInfo: nil)
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        NRMANetworkFacade.noticeNetworkFailure(request, with: timer, withError: error)
    }

    @objc(noticeNetworkFailureForURL:httpMethod:startTime:endTime:andFailureCode:)
    public static func noticeNetworkFailure(forURL url: URL!, httpMethod: String!, startTime: Double, endTime: Double, andFailureCode iOSFailureCode: Int) {
        let error = NSError(domain: NSURLErrorDomain, code: iOSFailureCode, userInfo: nil)
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        // See the force-unwrap note in noticeNetworkRequest(forURL:...startTime:endTime:...) above.
        let timer = NRTimer(startTime: startTime, andEndTime: endTime)!
        NRMANetworkFacade.noticeNetworkFailure(request, with: timer, withError: error)
    }

    @objc(generateDistributedTracingHeaders)
    public static func generateDistributedTracingHeaders() -> [String: String] {
        if NRMAFlags.shouldEnableNewEventSystem() {
            // The "NRMAPayload" suffix of the ObjC selector segment exactly matches the parameter's
            // type name (NRMAPayload*), so the Swift importer elides it down to `with:`.
            return NRMAHTTPUtilities.generateConnectivityHeaders(with: NRMAHTTPUtilities.generateNRMAPayload())
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
        // NRMAHTTPUtilities.trackedHeaderFields is declared as bare `NSArray*` (no generic
        // parameter), so it imports into Swift as [Any], not [String]. The underlying array
        // is always header-name strings in practice, so compactMap is a safe, non-crashing
        // narrowing to the public API's [String] return type.
        return NRMAHTTPUtilities.trackedHeaderFields().compactMap { $0 as? String }
    }

    // MARK: - Configuring event collection

    @objc(setMaxEventBufferTime:)
    public static func setMaxEventBufferTime(_ seconds: UInt32) {
        NewRelicAgentInternal.sharedInstance()?.setMaxEventBufferTime(seconds)
    }

    @objc(setMaxEventPoolSize:)
    public static func setMaxEventPoolSize(_ size: UInt32) {
        NewRelicAgentInternal.sharedInstance()?.setMaxEventPoolSize(size)
    }

    @objc(setMaxOfflineStorageSize:)
    public static func setMaxOfflineStorageSize(_ megabytes: UInt32) {
        // NRMAAgentConfiguration/NRMAHarvestController declare this as NSUInteger (Swift UInt),
        // not the public API's unsigned int (UInt32) — an explicit widening conversion is needed.
        NRMAAgentConfiguration.setMaxOfflineStorageSize(UInt(megabytes))
        NRMAHarvestController.setMaxOfflineStorageSize(UInt(megabytes))
    }

    // MARK: - Tracking global attributes

    @objc(setAttribute:value:)
    public static func setAttribute(_ name: String, value: Any) -> Bool {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return false
        }
        // analyticsController is declared nullable; message-to-nil in the original ObjC
        // returns NO, so ?. plus ?? false preserves that behavior.
        return agent.analyticsController?.setSessionAttribute(name, value: value, persistent: true) ?? false
    }

    @objc(incrementAttribute:)
    public static func incrementAttribute(_ name: String) -> Bool {
        return incrementAttribute(name, value: 1)
    }

    @objc(incrementAttribute:value:)
    public static func incrementAttribute(_ name: String, value: NSNumber) -> Bool {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return false
        }
        return agent.analyticsController?.incrementSessionAttribute(name, value: value, persistent: true) ?? false
    }

    @objc(setUserId:)
    public static func setUserId(_ userId: String?) -> Bool {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return false
        }

        let previousUserId = agent.getUserId()

        // A new session is only started when a non-nil userId is being replaced with a
        // different value (including nil). Setting a userId for the first time
        // (previousUserId == nil) continues the current session so early-startup data
        // is not lost.
        let newSession = previousUserId != nil && previousUserId != userId

        NRLogger.log(NRLogLevelVerbose.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "setUserId: \(userId ?? "nil") and previousUserId: \(previousUserId ?? "nil") and will start newSession=\(newSession)", withAgentLogsOn: true)

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
            return agent.analyticsController?.setSessionAttribute(kNRMA_Attrib_userId, value: userId, persistent: true) ?? false
        } else {
            return agent.analyticsController?.removeSessionAttributeNamed(kNRMA_Attrib_userId) ?? false
        }
    }

    @objc(removeAttribute:)
    public static func removeAttribute(_ name: String) -> Bool {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return false
        }
        return agent.analyticsController?.removeSessionAttributeNamed(name) ?? false
    }

    @objc(removeAllAttributes)
    public static func removeAllAttributes() -> Bool {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return false
        }
        return agent.analyticsController?.removeAllSessionAttributes() ?? false
    }

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
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return false
        }
        return agent.analyticsController?.addCustomEvent(eventType, withAttributes: attributes) ?? false
    }

    @objc(recordBreadcrumb:attributes:)
    public static func recordBreadcrumb(_ name: String, attributes: [AnyHashable: Any]?) -> Bool {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return false
        }
        return agent.analyticsController?.addBreadcrumb(name, withAttributes: attributes) ?? false
    }

    @objc(recordJavascriptError:message:stackTrace:isFatal:additionalAttributes:)
    public static func recordJavascriptError(_ name: String, message: String, stackTrace: String, isFatal: Bool, additionalAttributes: [AnyHashable: Any]?) -> Bool {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return false
        }
        if !NRMAFlags.shouldEnableJSErrorEvents() {
            NRLogger.log(NRLogLevelVerbose.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "JS Error reporting is disabled via feature flag. Cannot record JS error.", withAgentLogsOn: true)
            return false
        }
        #if os(iOS)
        // NewRelicAgentInternal.jsErrorController is declared in NewRelicPrivate's ObjC headers
        // as a forward-declared `@class JSErrorController` — a Swift type defined in this same
        // module. Clang precompiles NewRelicPrivate as its own explicit module with no visibility
        // into the Swift side, so it treats JSErrorController as an incomplete/opaque type and the
        // Swift importer drops the property entirely from NewRelicAgentInternal's imported
        // interface. KVC access sidesteps that: it reads the same underlying ObjC property by name
        // and returns `Any?`, which we can then cast to the Swift-visible JSErrorController type
        // directly (no cross-module type resolution needed for the cast itself).
        guard let jsErrorController = agent.value(forKey: "jsErrorController") as? JSErrorController else {
            NRLogger.log(NRLogLevelError.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "JS Error Controller is not initialized. Cannot record JS error.", withAgentLogsOn: true)
            return false
        }
        agent.sessionReplay(onError: nil)
        // JSErrorController.recordJSError expects [String: Any]?, not the public API's
        // [AnyHashable: Any]? — narrow with an explicit cast at this call boundary.
        jsErrorController.recordJSError(name, message: message, stackTrace: stackTrace, isFatal: isFatal, additionalAttributes: additionalAttributes as? [String: Any])
        return true
        #else
        NRLogger.log(NRLogLevelError.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "JS Error reporting is only available on iOS. Cannot record JS error.", withAgentLogsOn: true)
        return false
        #endif
    }

    // MARK: - Handled Exceptions

    @objc(recordHandledException:)
    public static func recordHandledException(_ exception: NSException) {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return
        }
        agent.sessionReplay(onError: nil)
        agent.handledExceptionsController?.recordHandledException(exception)
    }

    @objc(recordHandledException:withAttributes:)
    public static func recordHandledException(_ exception: NSException, withAttributes attributes: [AnyHashable: Any]?) {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return
        }
        agent.sessionReplay(onError: nil)
        agent.handledExceptionsController?.recordHandledException(exception, attributes: attributes)
    }

    @objc(recordHandledExceptionWithStackTrace:)
    public static func recordHandledException(withStackTrace exceptionDictionary: [AnyHashable: Any]) {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return
        }
        agent.sessionReplay(onError: nil)
        agent.handledExceptionsController?.recordHandledException(withStackTrace: exceptionDictionary)
    }

    // MARK: - Handled Errors

    @objc(recordError:)
    public static func recordError(_ error: NSError) {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return
        }
        agent.sessionReplay(onError: nil)
        agent.handledExceptionsController?.recordError(error, attributes: nil)
    }

    @objc(recordError:attributes:)
    public static func recordError(_ error: NSError, attributes: [AnyHashable: Any]?) {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return
        }
        agent.sessionReplay(onError: nil)
        agent.handledExceptionsController?.recordError(error, attributes: attributes)
    }

    // MARK: - Session Replay Masking

    @objc(addSessionReplayMaskViewClass:)
    public static func addSessionReplayMaskViewClass(_ viewClassName: String) -> Bool {
        if viewClassName.isEmpty {
            NRLogger.log(NRLogLevelError.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "addSessionReplayMaskViewClass: viewClassName must not be null or empty", withAgentLogsOn: true)
            return false
        }
        return NRMAAgentConfiguration.addLocalMaskedClassName(viewClassName)
    }

    @objc(addSessionReplayUnmaskViewClass:)
    public static func addSessionReplayUnmaskViewClass(_ viewClassName: String) -> Bool {
        if viewClassName.isEmpty {
            NRLogger.log(NRLogLevelError.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "addSessionReplayUnmaskViewClass: viewClassName must not be null or empty", withAgentLogsOn: true)
            return false
        }
        return NRMAAgentConfiguration.addLocalUnmaskedClassName(viewClassName)
    }

    @objc(addSessionReplayMaskedAccessibilityIdentifier:)
    public static func addSessionReplayMaskedAccessibilityIdentifier(_ identifier: String) -> Bool {
        if identifier.isEmpty {
            NRLogger.log(NRLogLevelError.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "addSessionReplayMaskedAccessibilityIdentifier: accessibilityIdentifier must not be null or empty", withAgentLogsOn: true)
            return false
        }
        return NRMAAgentConfiguration.addLocalMaskedAccessibilityIdentifier(identifier)
    }

    @objc(addSessionReplayUnmaskedAccessibilityIdentifier:)
    public static func addSessionReplayUnmaskedAccessibilityIdentifier(_ identifier: String) -> Bool {
        if identifier.isEmpty {
            NRLogger.log(NRLogLevelError.rawValue, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: "addSessionReplayUnmaskedAccessibilityIdentifier: accessibilityIdentifier must not be null or empty", withAgentLogsOn: true)
            return false
        }
        return NRMAAgentConfiguration.addLocalUnmaskedAccessibilityIdentifier(identifier)
    }

    // MARK: - Session Replay Manual

    @objc(recordReplay)
    public static func recordReplay() -> Bool {
        return NewRelicAgentInternal.sharedInstance()?.recordReplay() ?? false
    }

    @objc(pauseReplay)
    public static func pauseReplay() -> Bool {
        return NewRelicAgentInternal.sharedInstance()?.pauseReplay() ?? false
    }

    // MARK: - Hidden APIs

    // Hidden selector (manifest: keyAttributes). Comment in original: "built for hybrid
    // support and bridging with the browser agent."
    @objc(keyAttributes)
    public static func keyAttributes() -> [AnyHashable: Any] {
        return NRMAKeyAttributes.keyAttributes(NRMAAgentConfiguration.connectionInformation())
    }
}
