//
//  NRLogger.swift
//  Agent_iOS
//
//  Created by Mike Bruin on 4/21/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

@_implementationOnly import NewRelicPrivate

// Convenience functions for specific log levels
func NRLOG_ERROR(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelError.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: false)
}

func NRLOG_WARNING(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelWarning.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: false)
}

func NRLOG_INFO(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelInfo.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: false)
}

func NRLOG_VERBOSE(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelVerbose.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: false)
}

func NRLOG_AUDIT(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelAudit.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: false)
}

func NRLOG_DEBUG(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelDebug.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: false)
}
func NRLOG_AGENT_DEBUG(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelDebug.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: true)
}

// MARK: - Agent-log variants (withAgentLogsOn: true)

func NRLOG_AGENT_ERROR(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelError.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: true)
}

func NRLOG_AGENT_WARNING(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelWarning.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: true)
}

func NRLOG_AGENT_INFO(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelInfo.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: true)
}

func NRLOG_AGENT_VERBOSE(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelVerbose.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: true)
}

func NRLOG_AGENT_AUDIT(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelAudit.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: true)
}

// MARK: - Attribute-carrying variants

func NRLOG_ERROR_ATTRS(_ message: String, _ attributes: [AnyHashable: Any]?, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelError.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAttributes: attributes)
}

func NRLOG_WARNING_ATTRS(_ message: String, _ attributes: [AnyHashable: Any]?, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelWarning.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAttributes: attributes)
}

func NRLOG_INFO_ATTRS(_ message: String, _ attributes: [AnyHashable: Any]?, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelInfo.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAttributes: attributes)
}

func NRLOG_VERBOSE_ATTRS(_ message: String, _ attributes: [AnyHashable: Any]?, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelVerbose.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAttributes: attributes)
}

func NRLOG_AUDIT_ATTRS(_ message: String, _ attributes: [AnyHashable: Any]?, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelAudit.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAttributes: attributes)
}

func NRLOG_DEBUG_ATTRS(_ message: String, _ attributes: [AnyHashable: Any]?, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelDebug.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAttributes: attributes)
}
