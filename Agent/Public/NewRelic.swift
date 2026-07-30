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
}
