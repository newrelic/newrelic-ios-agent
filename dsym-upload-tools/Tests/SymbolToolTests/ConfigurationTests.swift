//
//  ConfigurationTests.swift
//  2026 New Relic
//

import XCTest
@testable import SymbolTool

final class CommandLineOptionsTests: XCTestCase {

    func testTokenOnly() throws {
        XCTAssertEqual(try CommandLineOptions.parse(["tool", "AAtoken"]), CommandLineOptions(appToken: "AAtoken"))
    }

    func testFlagsInAnyOrder() throws {
        let expected = CommandLineOptions(appToken: "AAtoken", isDebug: true, appVersionOverride: "7.8.2")
        XCTAssertEqual(try CommandLineOptions.parse(["tool", "AAtoken", "--debug", "-appVersion", "7.8.2"]), expected)
        XCTAssertEqual(try CommandLineOptions.parse(["tool", "AAtoken", "--app-version", " 7.8.2 ", "--debug"]), expected)
    }

    func testUnrecognizedArgumentsAreCollected() throws {
        let options = try CommandLineOptions.parse(["tool", "AAtoken", "--verbose", "--debug"])
        XCTAssertEqual(options.unrecognizedArguments, ["--verbose"])
        XCTAssertTrue(options.isDebug)
    }

    func testMissingTokenAndMissingValue() {
        XCTAssertThrowsError(try CommandLineOptions.parse(["tool"])) {
            XCTAssertEqual($0 as? CommandLineOptions.ParseError, .missingAppToken)
        }
        XCTAssertThrowsError(try CommandLineOptions.parse(["tool", "AAtoken", "-appVersion"])) {
            XCTAssertEqual($0 as? CommandLineOptions.ParseError, .missingValue(flag: "-appVersion"))
        }
    }
}

final class AppVersionTests: XCTestCase {

    func testPrecedence() {
        let env = ["NEWRELIC_APP_VERSION": "2.0", "MARKETING_VERSION": "3.0"]
        XCTAssertEqual(AppVersion.resolve(override: "1.0", environment: env), AppVersion(value: "1.0", source: .argument))
        XCTAssertEqual(AppVersion.resolve(override: nil, environment: env), AppVersion(value: "2.0", source: .newRelicAppVersion))
        XCTAssertEqual(AppVersion.resolve(override: nil, environment: ["MARKETING_VERSION": "3.0"]), AppVersion(value: "3.0", source: .marketingVersion))
        XCTAssertEqual(AppVersion.resolve(override: nil, environment: [:]).source, .placeholder)
    }

    func testEmptyValuesAreTreatedAsUnset() {
        let env = ["NEWRELIC_APP_VERSION": "", "MARKETING_VERSION": ""]
        XCTAssertEqual(AppVersion.resolve(override: "", environment: env), AppVersion(value: AppVersion.placeholderValue, source: .placeholder))
    }

    func testArgumentLogMessageMatchesFastlaneCheck() {
        // fastlane/TestFastfile runDsymUploadToolsTests greps for this exact string.
        XCTAssertEqual(AppVersion(value: "9.9.9", source: .argument).logMessage,
                       "New Relic: Using app version 9.9.9 (source: -appVersion argument)")
    }
}

final class ConfigurationTests: XCTestCase {

    func testDefaults() {
        let config = Configuration(options: CommandLineOptions(appToken: "AAtoken"), environment: [:])
        XCTAssertEqual(config.uploadURL, Configuration.defaultUploadURL)
        XCTAssertFalse(config.usesRegionAwareURL)
        XCTAssertEqual(config.endpoints, Configuration.Endpoints())
    }

    func testEnvironmentOverrides() {
        let env = ["DSYM_UPLOAD_URL": "https://staging.example", "NEWRELIC_SYMBOL_ENDPOINT": "map2",
                   "NEWRELIC_DSYM_ENDPOINT": "symbol2", "NEWRELIC_SYMBOL_POST_KEY": "up2", "NEWRELIC_DSYM_POST_KEY": "ds2"]
        let config = Configuration(options: CommandLineOptions(appToken: "AAtoken"), environment: env)
        XCTAssertEqual(config.uploadURL, "https://staging.example")
        XCTAssertEqual(config.endpoints, Configuration.Endpoints(mapPath: "map2", dsymPath: "symbol2", mapPostKey: "up2", dsymPostKey: "ds2"))
    }

    func testRegionTokenWinsOverUploadURL() {
        let config = Configuration(options: CommandLineOptions(appToken: "eu01xx0123456789"),
                                   environment: ["DSYM_UPLOAD_URL": "https://staging.example"])
        XCTAssertEqual(config.uploadURL, "https://mobile-symbol-upload.eu01.nr-data.net")
        XCTAssertTrue(config.usesRegionAwareURL)
    }

    func testRegionParsing() {
        XCTAssertEqual(UploadRegion.uploadURL(forAppToken: "eu01xx0123"), "https://mobile-symbol-upload.eu01.nr-data.net")
        XCTAssertEqual(UploadRegion.uploadURL(forAppToken: "jp01xx0123"), "https://mobile-symbol-upload.jp01.nr-data.net")
        XCTAssertNil(UploadRegion.uploadURL(forAppToken: "AA0123456789abcdef"))
    }
}

final class LoggerTests: XCTestCase {

    func testDebugIsGated() {
        let capture = LogCapture()
        let logger = Logger(debug: false, write: capture.write)
        logger.info("shown")
        logger.debug("hidden")
        XCTAssertEqual(capture.lines, ["shown"])
    }

    func testMaskKeepsRegionPrefix() {
        XCTAssertEqual(Logger.mask("eu01xx0123456789"), "eu01xx**********")
        XCTAssertEqual(Logger.mask("abc"), "***")
    }
}

final class ConcurrencyConfigurationTests: XCTestCase {

    func testDefaultAndOverride() {
        let options = CommandLineOptions(appToken: "AAtoken")
        XCTAssertEqual(Configuration(options: options, environment: [:]).maxConcurrentUploads, 4)
        XCTAssertEqual(Configuration(options: options, environment: ["NEWRELIC_SYMBOL_UPLOAD_CONCURRENCY": "1"]).maxConcurrentUploads, 1)
        XCTAssertEqual(Configuration(options: options, environment: ["NEWRELIC_SYMBOL_UPLOAD_CONCURRENCY": "0"]).maxConcurrentUploads, 4)
        XCTAssertEqual(Configuration(options: options, environment: ["NEWRELIC_SYMBOL_UPLOAD_CONCURRENCY": "lots"]).maxConcurrentUploads, 4)
    }
}
