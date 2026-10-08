//
//  Configuration.swift
//  2026 New Relic
//

import Foundation

/// The app version sent in `X-NewRelic-App-Version`, and where it came from.
struct AppVersion: Equatable {
    enum Source: Equatable {
        case argument
        case newRelicAppVersion
        case marketingVersion
        case placeholder
    }

    static let placeholderValue = "1.2.3"

    let value: String
    let source: Source

    /// Precedence: `-appVersion` arg > `NEWRELIC_APP_VERSION` > `MARKETING_VERSION` > placeholder.
    /// Empty values count as unset so a present-but-empty MARKETING_VERSION doesn't produce an
    /// empty header. (NR-417639)
    static func resolve(override: String?, environment: [String: String]) -> AppVersion {
        if let value = override, !value.isEmpty {
            return AppVersion(value: value, source: .argument)
        }
        if let value = environment["NEWRELIC_APP_VERSION"], !value.isEmpty {
            return AppVersion(value: value, source: .newRelicAppVersion)
        }
        if let value = environment["MARKETING_VERSION"], !value.isEmpty {
            return AppVersion(value: value, source: .marketingVersion)
        }
        return AppVersion(value: placeholderValue, source: .placeholder)
    }

    var logMessage: String {
        switch source {
        case .argument:
            return "New Relic: Using app version \(value) (source: -appVersion argument)"
        case .newRelicAppVersion:
            return "New Relic: Using app version \(value) (source: NEWRELIC_APP_VERSION)"
        case .marketingVersion:
            return "New Relic: Using app version \(value) (source: MARKETING_VERSION)"
        case .placeholder:
            // Symbols tagged with a placeholder won't match real builds, so warn loudly. (NR-417639)
            return "New Relic: WARNING - No app version found (MARKETING_VERSION is unset/empty and no -appVersion argument was provided). Using placeholder \"\(value)\"; uploaded symbol maps may not match your build's version. Pass -appVersion <version> or set MARKETING_VERSION / NEWRELIC_APP_VERSION."
        }
    }
}

enum UploadRegion {
    /// Region-prefixed app tokens (e.g. `eu01xx…`) upload to `https://mobile-symbol-upload.<region>.nr-data.net`.
    /// Returns nil for tokens with no region prefix, which use the default US endpoint.
    static func uploadURL(forAppToken token: String) -> String? {
        let range = NSRange(location: 0, length: token.utf16.count)
        guard let regex = try? NSRegularExpression(pattern: "^.*?x"),
              let match = regex.firstMatch(in: token, options: [], range: range),
              let swiftRange = Range(match.range(at: 0), in: token) else {
            return nil
        }
        let region = trimmingTrailingXs(String(token[swiftRange]))
        return "https://mobile-symbol-upload.\(region).nr-data.net"
    }

    private static func trimmingTrailingXs(_ string: String) -> String {
        guard let index = string.lastIndex(where: { $0 != "x" }) else { return string }
        return String(string[...index])
    }
}

/// Everything the tool needs, resolved once from the command line and the Xcode build environment.
struct Configuration {
    static let defaultUploadURL = "https://mobile-symbol-upload.newrelic.com"

    struct Endpoints: Equatable {
        var mapPath = "map"
        var dsymPath = "symbol"
        var mapPostKey = "upload"
        var dsymPostKey = "dsym"
    }

    var appToken: String
    var isDebug: Bool
    var uploadURL: String
    var usesRegionAwareURL: Bool
    var endpoints: Endpoints
    var appVersion: AppVersion
    var agentVersion = "7.4.12"
    var osName = "iOS"
    var platformName = "Native"
    /// Zipped maps above this size (200 MB) are reported via telemetry instead of uploaded.
    var mapSizeThreshold: UInt64 = 209_715_200
    /// Set to true to always upload dSYMs. (dSYMs are normally only uploaded if map conversion or upload fails.)
    var uploadDsymsOnly = false
    /// How many dSYM binaries are converted and uploaded in parallel (`NEWRELIC_SYMBOL_UPLOAD_CONCURRENCY`).
    var maxConcurrentUploads = 4
    /// DWARF binaries larger than this (100 MB) are processed one at a time, since `symbols` output and
    /// the parsed map for a binary that size can take hundreds of megabytes of memory.
    var largeBinaryThreshold: UInt64 = 104_857_600

    init(options: CommandLineOptions, environment: [String: String]) {
        appToken = options.appToken
        isDebug = options.isDebug

        endpoints = Endpoints()
        endpoints.mapPath = environment["NEWRELIC_SYMBOL_ENDPOINT"] ?? endpoints.mapPath
        endpoints.dsymPath = environment["NEWRELIC_DSYM_ENDPOINT"] ?? endpoints.dsymPath
        endpoints.mapPostKey = environment["NEWRELIC_SYMBOL_POST_KEY"] ?? endpoints.mapPostKey
        endpoints.dsymPostKey = environment["NEWRELIC_DSYM_POST_KEY"] ?? endpoints.dsymPostKey

        appVersion = AppVersion.resolve(override: options.appVersionOverride, environment: environment)

        if let value = environment["NEWRELIC_SYMBOL_UPLOAD_CONCURRENCY"].flatMap(Int.init), value > 0 {
            maxConcurrentUploads = value
        }

        // A region-prefixed token wins over DSYM_UPLOAD_URL.
        if let regionURL = UploadRegion.uploadURL(forAppToken: options.appToken) {
            uploadURL = regionURL
            usesRegionAwareURL = true
        } else {
            uploadURL = environment["DSYM_UPLOAD_URL"] ?? Configuration.defaultUploadURL
            usesRegionAwareURL = false
        }
    }
}
