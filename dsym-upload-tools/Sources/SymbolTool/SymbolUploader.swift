//
//  SymbolUploader.swift
//  2026 New Relic
//

import Foundation

enum UploadKind {
    case map
    case dsym
}

struct UploadResponse: Equatable {
    /// HTTP status, or 0 when no response was received (curl reports `000`).
    let statusCode: Int
    let curlExitStatus: Int32

    var isCreated: Bool { statusCode == 201 }
    var isOK: Bool { statusCode == 200 || statusCode == 201 }
    /// The server rejected the app token; any other upload with the same token will fail too.
    var isAuthenticationFailure: Bool { statusCode == 401 || statusCode == 403 }
    /// No HTTP response because the server couldn't be reached at all, as opposed to a transfer that
    /// failed part-way (curl reports `000` for both): unresolved proxy/host, connection refused,
    /// connect timeout, TLS handshake or certificate failure.
    var isUnreachable: Bool { statusCode == 0 && [5, 6, 7, 28, 35, 60].contains(curlExitStatus) }

    /// Matches curl's `%{http_code}` formatting, e.g. `201` or `000`.
    var statusText: String { String(format: "%03d", statusCode) }
}

/// Sends symbol files to New Relic.
protocol SymbolUploading {
    func upload(_ archive: URL, kind: UploadKind, size: UInt64) throws -> UploadResponse
    /// Reports an oversized map (metadata only, via the `x-telemetry-data` header) instead of uploading it.
    func sendOversizedMapTelemetry(size: UInt64) throws -> UploadResponse
}

/// Uploads with `curl`, which handles retries and multipart encoding.
struct CurlSymbolUploader: SymbolUploading {
    let configuration: Configuration
    let runner: CommandRunning
    let logger: Logger

    func upload(_ archive: URL, kind: UploadKind, size: UInt64) throws -> UploadResponse {
        let endpoints = configuration.endpoints
        let postKey = kind == .dsym ? endpoints.dsymPostKey : endpoints.mapPostKey
        let path = kind == .dsym ? endpoints.dsymPath : endpoints.mapPath
        // Quote the filename so curl's -F parser doesn't treat `;` or `,` in the path as field options.
        let field = "\(postKey)=@\"\(Self.escapeForFormField(archive.path))\""
        return try curl(["-F", field] + headerArguments(size: size) + ["\(configuration.uploadURL)/\(path)"])
    }

    func sendOversizedMapTelemetry(size: UInt64) throws -> UploadResponse {
        let payload = TelemetryPayload(size: size,
                                       appVersion: configuration.appVersion.value,
                                       agentVersion: configuration.agentVersion,
                                       osName: configuration.osName,
                                       platform: configuration.platformName)
        let header = payload.base64EncodedJSON()
        return try curl(headerArguments(size: size)
                        + ["-H", "x-telemetry-data: \(header)", "\(configuration.uploadURL)/\(configuration.endpoints.mapPath)"])
    }

    private func headerArguments(size: UInt64) -> [String] {
        [
            "-H", "x-app-license-key: \(configuration.appToken)",
            "-H", "X-NewRelic-Agent-Version: \(configuration.agentVersion)",
            "-H", "X-NewRelic-OS-Name: \(configuration.osName)",
            "-H", "X-NewRelic-Platform: \(configuration.platformName)",
            "-H", "X-NewRelic-App-Version: \(configuration.appVersion.value)",
            "-H", "X-File-Size: \(size)",
        ]
    }

    private func curl(_ arguments: [String]) throws -> UploadResponse {
        let fullArguments = ["--retry", "3", "--write-out", "%{http_code}", "--silent", "--output", "/dev/null"] + arguments
        logger.debug("Executing $ curl \(fullArguments.map(maskingAppToken).joined(separator: " "))")
        let result: CommandResult
        do {
            result = try runner.run("curl", fullArguments)
        } catch {
            throw SymbolToolError.uploadFailed("could not launch curl: \(error)")
        }
        let statusCode = Int(result.output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        return UploadResponse(statusCode: statusCode, curlExitStatus: result.exitStatus)
    }

    private func maskingAppToken(_ argument: String) -> String {
        let prefix = "x-app-license-key: "
        return argument.hasPrefix(prefix) ? prefix + Logger.mask(configuration.appToken) : argument
    }

    static func escapeForFormField(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}

/// Metadata sent in place of a map file that exceeds the size threshold.
struct TelemetryPayload: Equatable {
    var type = "sourcemap"
    let size: UInt64
    let appVersion: String
    let agentVersion: String
    let osName: String
    let platform: String
    var reason = "file_size_exceeded"

    /// Same field order and formatting as the original tool, with string values properly escaped.
    var json: String {
        "{\"type\":\(Self.quoted(type)),\"size\":\(size),\"appVersion\":\(Self.quoted(appVersion)),"
            + "\"agentVersion\":\(Self.quoted(agentVersion)),\"osName\":\(Self.quoted(osName)),"
            + "\"platform\":\(Self.quoted(platform)),\"reason\":\(Self.quoted(reason))}"
    }

    func base64EncodedJSON() -> String {
        Data(json.utf8).base64EncodedString()
    }

    /// A JSON string literal: escapes quotes, backslashes and control characters.
    static func quoted(_ value: String) -> String {
        var result = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case _ where scalar.value < 0x20: result += String(format: "\\u%04x", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }
}
