//
//  CurlSymbolUploaderTests.swift
//  2026 New Relic
//

import XCTest
@testable import SymbolTool

final class CurlSymbolUploaderTests: XCTestCase {

    private func makeUploader(curlOutput: String = "201", exitStatus: Int32 = 0) -> (CurlSymbolUploader, FakeCommandRunner) {
        var options = CommandLineOptions(appToken: "AAtoken")
        options.appVersionOverride = "7.8.2"
        let config = Configuration(options: options, environment: ["DSYM_UPLOAD_URL": "https://upload.example"])
        let runner = FakeCommandRunner { _, _ in CommandResult(exitStatus: exitStatus, output: curlOutput, errorOutput: "") }
        return (CurlSymbolUploader(configuration: config, runner: runner, logger: Logger()), runner)
    }

    func testMapUploadArguments() throws {
        let (uploader, runner) = makeUploader()
        let response = try uploader.upload(URL(fileURLWithPath: "/tmp/dir/mapArchive.zip"), kind: .map, size: 42)

        XCTAssertEqual(response, UploadResponse(statusCode: 201, curlExitStatus: 0))
        let call = try XCTUnwrap(runner.invocations.first)
        XCTAssertEqual(call.command, "curl")
        XCTAssertEqual(call.arguments, [
            "--retry", "3", "--write-out", "%{http_code}", "--silent", "--output", "/dev/null",
            "-F", "upload=@\"/tmp/dir/mapArchive.zip\"",
            "-H", "x-app-license-key: AAtoken",
            "-H", "X-NewRelic-Agent-Version: 7.4.12",
            "-H", "X-NewRelic-OS-Name: iOS",
            "-H", "X-NewRelic-Platform: Native",
            "-H", "X-NewRelic-App-Version: 7.8.2",
            "-H", "X-File-Size: 42",
            "https://upload.example/map",
        ])
    }

    func testDsymUploadUsesDsymEndpointAndKey() throws {
        let (uploader, runner) = makeUploader()
        _ = try uploader.upload(URL(fileURLWithPath: "/tmp/dsymArchive.zip"), kind: .dsym, size: 1)
        let arguments = try XCTUnwrap(runner.invocations.first).arguments
        XCTAssertTrue(arguments.contains("dsym=@\"/tmp/dsymArchive.zip\""))
        XCTAssertEqual(arguments.last, "https://upload.example/symbol")
    }

    func testPathsWithQuotesAreEscapedForCurlFormFields() throws {
        let (uploader, runner) = makeUploader()
        _ = try uploader.upload(URL(fileURLWithPath: "/tmp/it's \"odd\"; $HOME/a.zip"), kind: .map, size: 1)
        XCTAssertTrue(try XCTUnwrap(runner.invocations.first).arguments.contains(#"upload=@"/tmp/it's \"odd\"; $HOME/a.zip""#))
    }

    func testConnectionFailureReportsZeroStatus() throws {
        let (uploader, _) = makeUploader(curlOutput: "000", exitStatus: 7)
        let response = try uploader.upload(URL(fileURLWithPath: "/tmp/a.zip"), kind: .map, size: 1)
        XCTAssertEqual(response.statusCode, 0)
        XCTAssertEqual(response.statusText, "000")
        XCTAssertFalse(response.isCreated)
    }

    func testTelemetryHeaderCarriesBase64JSON() throws {
        let (uploader, runner) = makeUploader(curlOutput: "200")
        let response = try uploader.sendOversizedMapTelemetry(size: 300_000_000)
        XCTAssertTrue(response.isOK)

        let arguments = try XCTUnwrap(runner.invocations.first).arguments
        XCTAssertFalse(arguments.contains("-F"))
        XCTAssertEqual(arguments.last, "https://upload.example/map")
        let header = try XCTUnwrap(arguments.first { $0.hasPrefix("x-telemetry-data: ") })
        let data = try XCTUnwrap(Data(base64Encoded: String(header.dropFirst("x-telemetry-data: ".count))))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "sourcemap")
        XCTAssertEqual(json["size"] as? Int, 300_000_000)
        XCTAssertEqual(json["appVersion"] as? String, "7.8.2")
        XCTAssertEqual(json["agentVersion"] as? String, "7.4.12")
        XCTAssertEqual(json["osName"] as? String, "iOS")
        XCTAssertEqual(json["platform"] as? String, "Native")
        XCTAssertEqual(json["reason"] as? String, "file_size_exceeded")
    }

    func testTelemetryJSONMatchesOriginalFormatExactly() {
        let payload = TelemetryPayload(size: 300, appVersion: "7.8.2", agentVersion: "7.4.12", osName: "iOS", platform: "Native")
        XCTAssertEqual(payload.json, #"{"type":"sourcemap","size":300,"appVersion":"7.8.2","agentVersion":"7.4.12","osName":"iOS","platform":"Native","reason":"file_size_exceeded"}"#)
    }

    func testTelemetryJSONEscapesStringValues() throws {
        // The original hand-built string produced invalid JSON for a version like this.
        let payload = TelemetryPayload(size: 1, appVersion: "1.0 \"beta\" \\ 2\n/x", agentVersion: "a", osName: "b", platform: "c")
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(payload.json.utf8)) as? [String: Any])
        XCTAssertEqual(json["appVersion"] as? String, "1.0 \"beta\" \\ 2\n/x")
    }

    func testUnreachableOnlyForConnectionFailures() {
        XCTAssertTrue(UploadResponse(statusCode: 0, curlExitStatus: 6).isUnreachable)
        XCTAssertTrue(UploadResponse(statusCode: 0, curlExitStatus: 7).isUnreachable)
        XCTAssertFalse(UploadResponse(statusCode: 0, curlExitStatus: 56).isUnreachable)
        XCTAssertFalse(UploadResponse(statusCode: 500, curlExitStatus: 0).isUnreachable)
    }

    func testDebugCommandMasksToken() throws {
        let capture = LogCapture()
        let config = Configuration(options: CommandLineOptions(appToken: "AAtoken0123456789", isDebug: true), environment: [:])
        let uploader = CurlSymbolUploader(configuration: config, runner: FakeCommandRunner(), logger: Logger(debug: true, write: capture.write))
        _ = try uploader.upload(URL(fileURLWithPath: "/tmp/a.zip"), kind: .map, size: 1)
        XCTAssertFalse(capture.text.contains("AAtoken0123456789"))
        XCTAssertTrue(capture.text.contains("x-app-license-key: AAtoke***********"))
    }
}
