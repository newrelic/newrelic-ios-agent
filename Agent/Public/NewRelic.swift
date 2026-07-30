// NewRelic.swift
import Foundation

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
        NRLogger.log(NRLogLevelInfo, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
    }

    @objc(logError:)
    public static func logError(_ message: String) {
        NRLogger.log(NRLogLevelError, inFile: #fileID, atLine: UInt32(#line), inMethod: #function, withMessage: message, withAgentLogsOn: false)
        NewRelicAgentInternal.sharedInstance()?.sessionReplayOnError(nil)
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
        NewRelicAgentInternal.sharedInstance()?.sessionReplayOnError(nil)
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
        return NewRelicAgentInternal.sharedInstance()?.currentSessionId() ?? ""
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
    public static func start(withApplicationToken appToken: String, andCollectorAddress url: String, andCrashCollectorAddress crashCollectorUrl: String) {
        NewRelicAgentInternal.start(withApplicationToken: appToken, andCollectorAddress: url, andCrashCollectorAddress: crashCollectorUrl)
    }

    // MARK: - Custom instrumentation

    @objc(createAndStartTimer)
    public static func createAndStartTimer() -> NRTimer {
        return NRTimer()
    }

    // MARK: - Interaction Traces

    @objc(startInteractionWithName:)
    public static func startInteraction(withName interactionName: String) -> String? {
        if NewRelicAgentInternal.sharedInstance()?.isShutdown ?? false {
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
        if NewRelicAgentInternal.sharedInstance()?.isShutdown ?? false {
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
        if NewRelicAgentInternal.sharedInstance()?.isShutdown ?? false {
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
        if NewRelicAgentInternal.sharedInstance()?.isShutdown ?? false {
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
}
