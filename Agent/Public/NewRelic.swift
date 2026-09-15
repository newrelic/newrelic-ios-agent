// NewRelic.swift
import Foundation
@_implementationOnly import NewRelicPrivate

@objcMembers
public class NewRelic: NSObject {

    // MARK: - Logging

    @objc(logInfo:)
    public static func logInfo(_ message: String) {
        NRLOG_INFO(message)
    }

    @objc(logError:)
    public static func logError(_ message: String) {
        NRLOG_ERROR(message)
        NewRelicAgentInternal.sharedInstance()?.sessionReplay(onError: nil)
    }

    @objc(logVerbose:)
    public static func logVerbose(_ message: String) {
        NRLOG_VERBOSE(message)
    }

    @objc(logWarning:)
    public static func logWarning(_ message: String) {
        NRLOG_WARNING(message)
    }

    @objc(logAudit:)
    public static func logAudit(_ message: String) {
        NRLOG_AUDIT(message)
    }

    @objc(logDebug:)
    public static func logDebug(_ message: String) {
        NRLOG_DEBUG(message)
    }

    @objc(log:level:)
    public static func log(_ message: String, level: NRLogLevels) {
        switch level {
        case NRLogLevelError:
            NRLOG_ERROR(message)
        case NRLogLevelWarning:
            NRLOG_WARNING(message)
        case NRLogLevelInfo:
            NRLOG_INFO(message)
        case NRLogLevelVerbose:
            NRLOG_VERBOSE(message)
        case NRLogLevelAudit:
            NRLOG_AUDIT(message)
        case NRLogLevelDebug:
            NRLOG_DEBUG(message)
        default:
            break
        }
    }

    // Hidden selector (manifest: log:level:attributes:) — 3-arg overload adding attributes:.
    @objc(log:level:attributes:)
    public static func log(_ message: String, level: NRLogLevels, attributes: [AnyHashable: Any]?) {
        switch level {
        case NRLogLevelError:
            NRLOG_ERROR_ATTRS(message, attributes)
        case NRLogLevelWarning:
            NRLOG_WARNING_ATTRS(message, attributes)
        case NRLogLevelInfo:
            NRLOG_INFO_ATTRS(message, attributes)
        case NRLogLevelVerbose:
            NRLOG_VERBOSE_ATTRS(message, attributes)
        case NRLogLevelAudit:
            NRLOG_AUDIT_ATTRS(message, attributes)
        case NRLogLevelDebug:
            NRLOG_DEBUG_ATTRS(message, attributes)
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

    @nonobjc
    public static func logErrorObject(_ error: Error) {
        logErrorObject(error as NSError)
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
        guard let agent = NewRelicAgentInternal.sharedInstance(),
              let sessionId = agent.currentSessionId() else {
            return nil
        }
        return (sessionId as NSString).copy() as? NSString
    }

    @objc(crossProcessId)
    public static func crossProcessId() -> NSString? {
        guard let controller = NRMAHarvestController.shared(),
              let harvester = controller.harvester(),
              let crossProcessId = harvester.crossProcessID() as String? else {
            return nil
        }
        return (crossProcessId as NSString).copy() as? NSString
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
            NRLOG_AGENT_VERBOSE("\(#function) not executing; Interaction tracing is disabled.")
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
            NRLOG_AGENT_VERBOSE("\(#function) not executing; Interaction tracing is disabled.")
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
    public static func startTracingMethod(_ selector: Selector!, object: Any!, timer: NRTimer!, category: NRTraceType) {
        guard let selector = selector, let object = object else {
            NRLOG_AGENT_VERBOSE("\(#function) called with a nil selector or object; ignoring.")
            return
        }
        startTracingMethodNamed(NSStringFromSelector(selector), objectNamed: NSStringFromClass(type(of: object as AnyObject)), timer: timer, category: category)
    }

    // Hidden selector (manifest: startTracingMethodNamed:objectNamed:timer:category:) — consumed directly by Unity.
    @objc(startTracingMethodNamed:objectNamed:timer:category:)
    public static func startTracingMethodNamed(_ methodName: String!, objectNamed objectName: String!, timer: NRTimer!, category: NRTraceType) {
        if NewRelicAgentInternal.sharedInstance()?.isShutdown ?? false {
            return
        }
        if !NRMAFlags.shouldEnableInteractionTracing() {
            NRLOG_AGENT_VERBOSE("\(#function) not executing; Interaction tracing is disabled.")
            return
        }
        guard let methodName = methodName else {
            NRLOG_AGENT_VERBOSE("\(#function) called with a nil methodName; ignoring.")
            return
        }
        let cleanSelectorString = NewRelicInternalUtils.cleanseString(forCollector: methodName)!
        if !NRMATraceController.isTracingActive() {
            NRLOG_AGENT_VERBOSE("\(#function) attempted to start tracing method without active Interaction Trace")
            return
        }
        NRMACustomTrace.startTracingMethod(NSSelectorFromString(cleanSelectorString), objectName: objectName, timer: timer, category: category)
    }

    @objc(endTracingMethodWithTimer:)
    public static func endTracingMethod(with timer: NRTimer!) {
        if NewRelicAgentInternal.sharedInstance()?.isShutdown ?? false {
            return
        }
        guard let timer = timer else {
            NRLOG_AGENT_VERBOSE("\(#function) called with a nil timer; ignoring.")
            return
        }
        timer.stop()
        if !NRMAFlags.shouldEnableInteractionTracing() {
            NRLOG_AGENT_VERBOSE("\(#function) not executing; Interaction tracing is disabled.")
            return
        }
        if !NRMATraceController.isTracingActive() {
            NRLOG_AGENT_VERBOSE("\(#function) attempted to end tracing method without active Interaction Trace")
            // kNRTraceAssociatedKey must yield the same pointer as NRMATraceController.m and
            // NRMACustomTrace.m's `(__bridge const void *)` casts, or this clears a different slot.
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
        for url: URL!,
        httpMethod: String!,
        with timer: NRTimer!,
        responseHeaders headers: [AnyHashable: Any]?,
        statusCode httpStatusCode: Int,
        bytesSent: UInt,
        bytesReceived: UInt,
        responseData: Data?,
        traceHeaders: [String: String]?,
        andParams params: [AnyHashable: Any]?
    ) {
        guard let url = url else {
            NRLOG_AGENT_VERBOSE("\(#function) called with a nil URL; ignoring.")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        let response = HTTPURLResponse(url: url, statusCode: httpStatusCode, httpVersion: "1.1", headerFields: headers as? [String: String])!
        // NRMANetworkFacade's `request:` parameter is Swift-imported as URLRequest, not NSURLRequest.
        NRMANetworkFacade.noticeNetworkRequest(request, response: response, with: timer, bytesSent: bytesSent, bytesReceived: bytesReceived, responseData: responseData, traceHeaders: traceHeaders, params: params)
    }

    // See the labeling note on the sibling overload above — `for:` matches the
    // importer-generated label for the original ObjC header's NSURL parameter.
    @objc(noticeNetworkRequestForURL:httpMethod:startTime:endTime:responseHeaders:statusCode:bytesSent:bytesReceived:responseData:traceHeaders:andParams:)
    public static func noticeNetworkRequest(
        for url: URL!,
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
        guard let url = url else {
            NRLOG_AGENT_VERBOSE("\(#function) called with a nil URL; ignoring.")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        let response = HTTPURLResponse(url: url, statusCode: httpStatusCode, httpVersion: "1.1", headerFields: headers as? [String: String])!
        let timer = NRTimer(startTime: startTime, andEndTime: endTime)!
        // NRMANetworkFacade's `request:` parameter is Swift-imported as URLRequest, not NSURLRequest.
        NRMANetworkFacade.noticeNetworkRequest(request, response: response, with: timer, bytesSent: bytesSent, bytesReceived: bytesReceived, responseData: responseData, traceHeaders: traceHeaders as? [String: String], params: params)
    }

    // See the labeling note on noticeNetworkRequest(for:httpMethod:with:...) above —
    // `for:`/`with:` match the importer-generated labels for the original header.
    @objc(noticeNetworkFailureForURL:httpMethod:withTimer:andFailureCode:)
    public static func noticeNetworkFailure(for url: URL!, httpMethod: String!, with timer: NRTimer!, andFailureCode iOSFailureCode: Int) {
        let error = NSError(domain: NSURLErrorDomain, code: iOSFailureCode, userInfo: nil)
        guard let url = url else {
            NRLOG_AGENT_VERBOSE("\(#function) called with a nil URL; ignoring.")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        NRMANetworkFacade.noticeNetworkFailure(request, with: timer, withError: error)
    }

    // See the labeling note above — `for:` matches the importer-generated label.
    @objc(noticeNetworkFailureForURL:httpMethod:startTime:endTime:andFailureCode:)
    public static func noticeNetworkFailure(for url: URL!, httpMethod: String!, startTime: Double, endTime: Double, andFailureCode iOSFailureCode: Int) {
        let error = NSError(domain: NSURLErrorDomain, code: iOSFailureCode, userInfo: nil)
        guard let url = url else {
            NRLOG_AGENT_VERBOSE("\(#function) called with a nil URL; ignoring.")
            return
        }
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

        NRLOG_AGENT_VERBOSE("setUserId: \(userId ?? "nil") and previousUserId: \(previousUserId ?? "nil") and will start newSession=\(newSession)")

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
    public static func recordCustomEvent(_ eventType: String, name: String?, attributes: [AnyHashable: Any]? = nil) -> Bool {
        var mutableAttributes = attributes ?? [:]
        if let name = name, !name.isEmpty {
            mutableAttributes["name"] = name
        }
        return recordCustomEvent(eventType, attributes: mutableAttributes)
    }

    @objc(recordCustomEvent:attributes:)
    public static func recordCustomEvent(_ eventType: String, attributes: [AnyHashable: Any]? = nil) -> Bool {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return false
        }
        return agent.analyticsController?.addCustomEvent(eventType, withAttributes: attributes) ?? false
    }

    @objc(recordBreadcrumb:attributes:)
    public static func recordBreadcrumb(_ name: String, attributes: [AnyHashable: Any]? = nil) -> Bool {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return false
        }
        return agent.analyticsController?.addBreadcrumb(name, withAttributes: attributes) ?? false
    }

    @objc(recordJavascriptError:message:stackTrace:isFatal:additionalAttributes:)
    public static func recordJavascriptError(_ name: String, message: String, stackTrace: String, isFatal: Bool, additionalAttributes: [AnyHashable: Any]? = nil) -> Bool {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return false
        }
        if !NRMAFlags.shouldEnableJSErrorEvents() {
            NRLOG_AGENT_VERBOSE("JS Error reporting is disabled via feature flag. Cannot record JS error.")
            return false
        }
        #if os(iOS)
        return agent.recordJavascriptError(withName: name,
                                           message: message,
                                           stackTrace: stackTrace,
                                           isFatal: isFatal,
                                           additionalAttributes: additionalAttributes)
        #else
        NRLOG_AGENT_ERROR("JS Error reporting is only available on iOS. Cannot record JS error.")
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
    public static func recordHandledException(_ exception: NSException, withAttributes attributes: [AnyHashable: Any]? = nil) {
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
    public static func recordError(_ error: NSError, attributes: [AnyHashable: Any]? = nil) {
        guard let agent = NewRelicAgentInternal.sharedInstance(), !agent.isShutdown else {
            return
        }
        agent.sessionReplay(onError: nil)
        agent.handledExceptionsController?.recordError(error, attributes: attributes)
    }

    @nonobjc
    public static func recordError(_ error: Error) {
        recordError(error as NSError)
    }

    @nonobjc
    public static func recordError(_ error: Error, attributes: [AnyHashable: Any]? = nil) {
        recordError(error as NSError, attributes: attributes)
    }

    // MARK: - Session Replay Masking

    @objc(addSessionReplayMaskViewClass:)
    public static func addSessionReplayMaskViewClass(_ viewClassName: String) -> Bool {
        if viewClassName.isEmpty {
            NRLOG_AGENT_ERROR("addSessionReplayMaskViewClass: viewClassName must not be null or empty")
            return false
        }
        return NRMAAgentConfiguration.addLocalMaskedClassName(viewClassName)
    }

    @objc(addSessionReplayUnmaskViewClass:)
    public static func addSessionReplayUnmaskViewClass(_ viewClassName: String) -> Bool {
        if viewClassName.isEmpty {
            NRLOG_AGENT_ERROR("addSessionReplayUnmaskViewClass: viewClassName must not be null or empty")
            return false
        }
        return NRMAAgentConfiguration.addLocalUnmaskedClassName(viewClassName)
    }

    @objc(addSessionReplayMaskedAccessibilityIdentifier:)
    public static func addSessionReplayMaskedAccessibilityIdentifier(_ identifier: String) -> Bool {
        if identifier.isEmpty {
            NRLOG_AGENT_ERROR("addSessionReplayMaskedAccessibilityIdentifier: accessibilityIdentifier must not be null or empty")
            return false
        }
        return NRMAAgentConfiguration.addLocalMaskedAccessibilityIdentifier(identifier)
    }

    @objc(addSessionReplayUnmaskedAccessibilityIdentifier:)
    public static func addSessionReplayUnmaskedAccessibilityIdentifier(_ identifier: String) -> Bool {
        if identifier.isEmpty {
            NRLOG_AGENT_ERROR("addSessionReplayUnmaskedAccessibilityIdentifier: accessibilityIdentifier must not be null or empty")
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
