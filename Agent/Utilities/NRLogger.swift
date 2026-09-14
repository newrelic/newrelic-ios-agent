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
    NRLogger.log(NRLogLevelError.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: true)
}

func NRLOG_WARNING(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelWarning.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: true)
}

func NRLOG_INFO(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelInfo.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: true)
}

func NRLOG_VERBOSE(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelVerbose.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: true)
}

func NRLOG_AUDIT(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    NRLogger.log(NRLogLevelAudit.rawValue, inFile: fileName, atLine: UInt32(line), inMethod: function, withMessage: message, withAgentLogsOn: true)
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
//
// Completes the NRLOG_AGENT_* family so Swift has the same coverage as the ObjC macros in
// NRLogger.h, where NRLOG_AGENT_<LEVEL> is the agent-log form of NRLOG_<LEVEL>. Only
// NRLOG_AGENT_DEBUG existed before, which left Swift callers writing the underlying
// NRLogger.log(...) call by hand for every other level.
//
// Note for anyone comparing against NRLogger.h: the five bare helpers above
// (NRLOG_ERROR/WARNING/INFO/VERBOSE/AUDIT) currently pass withAgentLogsOn: true, whereas their
// identically-named ObjC macros pass false. That inversion predates this change and is being
// corrected separately, because flipping them is a behaviour change rather than an addition.
// Until then, prefer these explicit NRLOG_AGENT_* helpers for agent logging: they mean the same
// thing before and after that correction.

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
//
// Mirrors the NRLOG_<LEVEL>_ATTRS macros in NRLogger.h, which route to the
// withAttributes: overload of NRLogger.log rather than the withAgentLogsOn: one.

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
