//
//  NRTestAppUITests.swift
//  NRTestAppUITests
//
//  Created by Chris Dillard on 10/17/23.
//

import XCTest


final class NRTestAppUITests: XCTestCase {
    
    let dataEndpoint = "/mobile/v3/data"

    func testARequests(){
        let dynamicStubs = HTTPDynamicStubs()

        let vendorId = "myDeviceId"
        let harvestConnector = "[[\"NRTestApp\",\"4.7\",\"com.newrelic.NRApp.bitcode\"],[\"iOS\",\"17.0.1\",\"arm64\",\"iOSAgent\",\"DEV\",\"\(vendorId)\",\"\",\"\",\"Apple Inc.\",{\"platform\":\"Native\",\"platformVersion\":\"DEV\"}]]"

        let app = XCUIApplication()
        dynamicStubs.setUp()

// expectation: TEST HARVEST /connect
        let expectation = XCTestExpectation(description: "Expected connect endpoint to be hit.")

        dynamicStubs.setupStub(url: "/mobile/v5/connect", filename: "harvestConnector", method: .POST, matchRequestBody: harvestConnector, hitClosure: { actualRequestBody in
            if actualRequestBody == harvestConnector {
                expectation.fulfill() }
        })

        app.launchEnvironment = ["UITesting":"yes", "DeleteConnect":"yes"]
        app.launch()

        XCTWaiter(delegate: self).wait(for: [expectation], timeout: 30)
        app.terminate()

// expectation: TEST HARVEST /data
        let expectation2 = XCTestExpectation(description: "Expected data harvest endpoint to be hit.")

        dynamicStubs.setupStub(url: dataEndpoint, filename: "harvestCollector", method: .POST, matchRequestBody: harvestCollector, hitClosure: { actualRequestBody in

            let jsonMatch = dynamicStubs.dataToJSON(data: (self.harvestCollector.data(using: .utf8))!) as! Array<Any>
            let jsonActualArray = dynamicStubs.dataToJSON(data: actualRequestBody.data(using: .utf8)!) as! Array<Any>

            if jsonMatch.count == jsonActualArray.count {
                expectation2.fulfill()
            }
            else {
                XCTFail()
            }
        })

        app.launchEnvironment = ["UITesting":"yes"]
        app.launch()

        XCTWaiter(delegate: self).wait(for: [expectation2], timeout: 30)
        app.terminate()

        dynamicStubs.tearDown()
    }

    func testBRequests(){
        let dynamicStubs = HTTPDynamicStubs()

        let app = XCUIApplication()

        dynamicStubs.setUp()

// expectation: TEST HARVEST /data
        // The first expectation of this test is used for the automatically fired /data request when launching the app
        let expectation2 = XCTestExpectation(description: "Expected data harvest endpoint to be hit.")

        dynamicStubs.setupStub(url: dataEndpoint, filename: "harvestCollector", method: .POST, matchRequestBody: harvestCollector, hitClosure: { actualRequestBody in

            let jsonMatch = dynamicStubs.dataToJSON(data: (self.harvestCollector.data(using: .utf8))!) as! Array<Any>
            let jsonActualArray = dynamicStubs.dataToJSON(data: actualRequestBody.data(using: .utf8)!) as! Array<Any>

            if jsonMatch.count == jsonActualArray.count {
                expectation2.fulfill()
            }
            else {
                XCTFail()
            }
        })

        app.launchEnvironment = ["UITesting":"yes"]
        app.launch()
        
        XCTWaiter(delegate: self).wait(for: [expectation2], timeout: 30)

        let tablesQuery = app.tables
        tablesQuery.staticTexts["Change Image"].tap()

        // This expectation of this test is used for the automatically fired /data request when launching the app
// expectation: TEST HARVEST /data
        let expectation3 = XCTestExpectation(description: "Expected data harvest endpoint to be hit w/ MobileRequest.")

        dynamicStubs.setupStub(url: dataEndpoint, filename: "harvestCollector", method: .POST, matchRequestBody: harvestCollector, hitClosure: { actualRequestBody in

            //let jsonMatch = dynamicStubs.dataToJSON(data: (self.harvestCollector.data(using: .utf8))!) as! Array<Any>
            let jsonActualArray = dynamicStubs.dataToJSON(data: actualRequestBody.data(using: .utf8)!) as! Array<Any>
            var metricSeen = false
            if let urlArray = jsonActualArray[3] as? [NSObject] {
                for array in urlArray {
                    if let array = array as? [AnyObject] {
                        if let url = array[0] as? String  {
                            if url == "https://api.nasa.gov/planetary/apod" {
                                metricSeen = true
                                break
                            }
                        }
                    }
                }
            }

            // Get events array
            if let eventArray = jsonActualArray[9] as? [[String: Any]] {
                for event in eventArray {
                    if let eventType = event["eventType"] as? String {
                        if eventType == "MobileRequest" {
                            // If the metric was seen and we see an event with type == "MobileRequest" that means harvesting Network Requests is working.
                            if metricSeen {
                                expectation3.fulfill()
                                break
                            }
                        }
                    }
                }
            }
        })

        // Wait up to Max Event Buffer Time
        XCTWaiter(delegate: self).wait(for: [expectation3], timeout: 62)

        app.terminate()

        dynamicStubs.tearDown()
    }

    let harvestCollector = "[[6665544329,6662343329],[\"iOS\",\"17.0\",\"arm64\",\"iOSAgent\",\"DEV\",\"myDeviceId\",\"\",\"\",\"Apple Inc.\",{\"platform\":\"Native\",\"platformVersion\":\"DEV\"}],0,[],[[{\"name\":\"Method\\/UIViewController\\/viewWillLayoutSubviews\",\"scope\":\"Mobile\\/Activity\\/Name\\/Display _TtGC7SwiftUI19UIHostingControllerGVS_15ModifiedContentVS_7AnyViewVS_12RootModifier__\"},{\"sum_of_squares\":0,\"min\":0,\"exclusive\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"CPU\\/System\\/Utilization\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"Session\\/Start\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"CPU\\/User\\/Utilization\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"Memory\\/Used\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"Method\\/UIViewController\\/viewWillLayoutSubviews\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"exclusive\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"CPU\\/Total\\/Utilization\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}]],[],[],[],{},[]]"
}

// MARK: - Event persistence end-to-end
//
// Records tagged events in the app, SIGKILLs it, relaunches it, and checks -- against a stub
// collector that outlives the app process -- that every event arrived exactly once, with the
// right attributes, attributed to the session it was recorded in.
//
// The app side is `runEventPersistenceScenarioIfRequested()` (AppDelegate+UITest.swift).

/// Stub collector: records every /data upload (and the app's "recorded" pings) for later assertions.
final class EventLedgerCollector {
    struct Upload {
        let dataToken: [Int]
        let sessionAttributes: [String: Any]
        let events: [[String: Any]]
    }
    struct RecordedPing {
        let run: String
        let sessionId: String
    }

    /// data_token handed out per reported app version, so an upload's token identifies the version
    /// the collector (like ingest) would attribute it to.
    static let tokenForVersion: [String: [Int]] = ["1.0": [1001, 2001], "2.0": [1002, 2002]]

    private let server = HttpServer()
    private let lock = NSLock()
    private var _uploads: [Upload] = []
    private var _rejectedUploads = 0
    private var _pings: [String: RecordedPing] = [:]
    private var _rejectData = false

    var uploads: [Upload] { lock.lock(); defer { lock.unlock() }; return _uploads }
    var rejectedUploads: Int { lock.lock(); defer { lock.unlock() }; return _rejectedUploads }
    func ping(forRun run: String) -> RecordedPing? { lock.lock(); defer { lock.unlock() }; return _pings[run] }

    /// While true, /data answers 500 -- events cannot be delivered live and must survive on disk.
    var rejectData: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _rejectData }
        set { lock.lock(); _rejectData = newValue; lock.unlock() }
    }

    func start() throws {
        server["/mobile/v5/connect"] = { request in
            var version = "1.0"
            if let root = try? JSONSerialization.jsonObject(with: Data(request.body)) as? [Any],
               let app = root.first as? [Any], app.count > 1, let v = app[1] as? String {
                version = v
            }
            let token = EventLedgerCollector.tokenForVersion[version] ?? [9, 9]
            let config: [String: Any] = [
                "server_timestamp": 1656525980,
                "data_report_period": 5,
                "report_max_transaction_count": 1000,
                "report_max_transaction_age": 600,
                "collect_network_errors": true,
                "error_limit": 50,
                "response_body_limit": 2048,
                "stack_trace_limit": 100,
                "activity_trace_max_size": 65535,
                "activity_trace_min_utilization": 0.3,
                "at_capture": [1, []],
                "data_token": token,
                "cross_process_id": "AAAAAAAAAAAAAAAAAAAAAA==",
                "encoding_key": "0000000000000000000000000000000000000000",
                "account_id": "1",
                "application_id": "1",
            ]
            return .ok(.json(config as AnyObject))
        }
        server["/mobile/v3/data"] = { [weak self] request in
            guard let self else { return .internalServerError(nil) }
            self.lock.lock(); defer { self.lock.unlock() }
            if self._rejectData {
                self._rejectedUploads += 1
                return .internalServerError(nil)
            }
            if let root = try? JSONSerialization.jsonObject(with: Data(request.body)) as? [Any], root.count > 9 {
                self._uploads.append(Upload(dataToken: (root[0] as? [Int]) ?? [],
                                            sessionAttributes: (root[8] as? [String: Any]) ?? [:],
                                            events: (root[9] as? [[String: Any]]) ?? []))
            }
            return .ok(.json([:] as AnyObject))
        }
        server["/ep/recorded"] = { [weak self] request in
            let q = Dictionary(request.queryParams, uniquingKeysWith: { first, _ in first })
            if let run = q["run"] {
                self?.lock.lock()
                self?._pings[run] = RecordedPing(run: run, sessionId: q["sessionId"] ?? "")
                self?.lock.unlock()
            }
            return .ok(.json([:] as AnyObject))
        }
        // Logs, session replay, crash upload etc. -- not under test.
        server.notFoundHandler = { _ in .ok(.json([:] as AnyObject)) }
        try server.start()
    }

    func stop() { server.stop() }

    /// Every delivered event tagged with `run`, in arrival order, with the upload it rode in.
    func deliveredEvents(forRun run: String) -> [(event: [String: Any], upload: Upload)] {
        uploads.flatMap { upload in
            upload.events.filter { $0["nrTestRun"] as? String == run }.map { (event: $0, upload: upload) }
        }
    }
}

final class NREventPersistenceUITests: XCTestCase {

    private let pairsPerRun = 3   // 3 custom + 3 breadcrumb events

    private var expectedSeqs: Set<String> {
        Set((0..<pairsPerRun).flatMap { ["custom-\($0)", "breadcrumb-\($0)"] })
    }

    override func setUp() {
        continueAfterFailure = true
    }

    /// Spins until `condition` holds or `timeout` passes. Returns whether it held.
    @discardableResult
    private func wait(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return condition()
    }

    private struct Scenario {
        let collector: EventLedgerCollector
        let run1: String
        let sessionId1: String
        let sessionId2: String
    }

    /// Launch 1 (v1.0) records the events and is killed; launch 2 (v2.0) comes up and uploads.
    /// `rejectFirstLaunch`: true  -> launch 1 can never deliver live, so launch 2 must recover them;
    ///                      false -> launch 1 delivers them live, so launch 2 must NOT resend them.
    private func runScenario(rejectFirstLaunch: Bool) throws -> Scenario {
        let collector = EventLedgerCollector()
        try collector.start()
        addTeardownBlock { collector.stop() }

        let run1 = "run1-\(UUID().uuidString.prefix(8))"
        let run2 = "run2-\(UUID().uuidString.prefix(8))"
        let app = XCUIApplication()

        // Launch 1: record events, then kill the app without letting it shut down.
        collector.rejectData = rejectFirstLaunch
        app.launchEnvironment = ["UITesting": "yes", "DeleteConnect": "yes", "EPAppVersion": "1.0",
                                 "EPRun": run1, "EPCount": "\(pairsPerRun)"]
        app.launch()
        XCTAssertTrue(wait(timeout: 30) { collector.ping(forRun: run1) != nil }, "launch 1 never reported its events as recorded")
        if rejectFirstLaunch {
            XCTAssertTrue(wait(timeout: 30) { collector.rejectedUploads > 0 }, "launch 1 never attempted an upload to reject")
        } else {
            XCTAssertTrue(wait(timeout: 60) { Set(collector.deliveredEvents(forRun: run1).compactMap { $0.event["nrTestSeq"] as? String }) == self.expectedSeqs },
                          "launch 1 never delivered its events live")
        }
        app.terminate()

        // Launch 2: a later version, records nothing; whatever it uploads is what we judge.
        collector.rejectData = false
        app.launchEnvironment = ["UITesting": "yes", "DeleteConnect": "yes", "EPAppVersion": "2.0",
                                 "EPRun": run2, "EPCount": "0"]
        app.launch()
        XCTAssertTrue(wait(timeout: 30) { collector.ping(forRun: run2) != nil }, "launch 2 never reported its session")
        if rejectFirstLaunch {
            XCTAssertTrue(wait(timeout: 60) { Set(collector.deliveredEvents(forRun: run1).compactMap { $0.event["nrTestSeq"] as? String }) == self.expectedSeqs },
                          "launch 2 never delivered launch 1's persisted events")
        }
        // Give a few more harvest cycles (data_report_period is 5s) to surface any duplicate.
        Thread.sleep(forTimeInterval: 20)
        app.terminate()

        return Scenario(collector: collector, run1: run1,
                        sessionId1: collector.ping(forRun: run1)?.sessionId ?? "",
                        sessionId2: collector.ping(forRun: run2)?.sessionId ?? "")
    }

    /// Exactly-once: no missing events, no unexpected ones, none delivered twice.
    private func assertExactlyOnce(_ s: Scenario, file: StaticString = #filePath, line: UInt = #line) {
        let delivered = s.collector.deliveredEvents(forRun: s.run1).compactMap { $0.event["nrTestSeq"] as? String }
        let counts = Dictionary(grouping: delivered, by: { $0 }).mapValues(\.count)
        let missing = expectedSeqs.subtracting(counts.keys)
        let unexpected = Set(counts.keys).subtracting(expectedSeqs)
        let duplicated = counts.filter { $0.value > 1 }.keys.sorted()
        XCTAssertTrue(missing.isEmpty, "missed events: \(missing.sorted())", file: file, line: line)
        XCTAssertTrue(unexpected.isEmpty, "unexpected events: \(unexpected.sorted())", file: file, line: line)
        XCTAssertTrue(duplicated.isEmpty, "events delivered more than once: \(duplicated)", file: file, line: line)
    }

    /// Required attributes per type and no additional ones. A *recovered* event is rebuilt from disk, so it must
    /// carry its originating session's attributes (and sessionId) inline; a *live* event rides in an upload whose
    /// [8] holds the session attributes once, so they must NOT be repeated inline.
    private func assertAttributesAndAttribution(_ s: Scenario, recovered: Bool, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(s.sessionId1.isEmpty, "launch 1 reported no session id", file: file, line: line)
        XCTAssertNotEqual(s.sessionId1, s.sessionId2, "both launches reported the same session id", file: file, line: line)

        // Session attributes the agent attaches (any upload's [8] shares the schema).
        let sessionKeys = Set(s.collector.uploads.flatMap { $0.sessionAttributes.keys })
        XCTAssertFalse(sessionKeys.isEmpty, "no session attributes were captured to compare against", file: file, line: line)

        // "timeSinceLoad" is the wire name of an event's sessionElapsedTime.
        let base: Set<String> = ["timestamp", "eventType", "timeSinceLoad", "sessionId", "nrTestRun", "nrTestSeq"]
        // Conditionally added by the agent depending on reachability / app state.
        let environmental: Set<String> = ["offline", "background"]
        // First-session-only attributes: removed from later sessions, but a recovered event must keep
        // the ones its own session had, so they can appear on events though not in launch 2's [8].
        let sessionScoped: Set<String> = ["install", "upgradeFrom"]
        let perType: [String: (required: Set<String>, allowed: Set<String>)] = [
            "NRTestCustom":     (base.union(["orderId"]), base.union(["orderId"])),
            "MobileBreadcrumb": (base, base.union(["name"])),
        ]

        for (event, _) in s.collector.deliveredEvents(forRun: s.run1) {
            let seq = event["nrTestSeq"] as? String ?? "?"
            let type = event["eventType"] as? String ?? "?"
            guard let spec = perType[type] else {
                XCTFail("[\(seq)] unexpected eventType '\(type)'", file: file, line: line)
                continue
            }
            let keys = Set(event.keys)
            let inlineOnlyWhenRecovered: Set<String> = ["sessionId"]
            let required = recovered ? spec.required : spec.required.subtracting(inlineOnlyWhenRecovered)
            let allowed = recovered ? spec.allowed.union(sessionKeys) : spec.allowed.subtracting(inlineOnlyWhenRecovered)
            XCTAssertTrue(required.isSubset(of: keys),
                          "[\(seq)] \(type) missing required attributes: \(required.subtracting(keys).sorted())", file: file, line: line)
            let extra = keys.subtracting(allowed).subtracting(environmental).subtracting(sessionScoped)
            XCTAssertTrue(extra.isEmpty, "[\(seq)] \(type) has unexpected attributes: \(extra.sorted())", file: file, line: line)
            XCTAssertTrue(event["timestamp"] is NSNumber, "[\(seq)] timestamp is not a number", file: file, line: line)
            if recovered {
                XCTAssertTrue(sessionKeys.isSubset(of: keys),
                              "[\(seq)] \(type) missing session attributes: \(sessionKeys.subtracting(keys).sorted())", file: file, line: line)
                XCTAssertEqual(event["sessionId"] as? String, s.sessionId1,
                               "[\(seq)] \(type) attributed to the wrong session (launch 2's is \(s.sessionId2))", file: file, line: line)
            }
        }
    }

    /// Events recorded, never delivered live (/data rejected), app SIGKILLed: the next launch must
    /// deliver each exactly once, with full attributes, attributed to the launch that recorded them.
    func testForceQuitEventsAreRecoveredExactlyOnceWithCorrectAttribution() throws {
        let s = try runScenario(rejectFirstLaunch: true)
        assertExactlyOnce(s)
        assertAttributesAndAttribution(s, recovered: true)
    }

    /// Events already delivered live must not be delivered again by the next launch's recovery.
    func testEventsDeliveredLiveAreNotResentAfterRelaunch() throws {
        let s = try runScenario(rejectFirstLaunch: false)
        assertExactlyOnce(s)
        assertAttributesAndAttribution(s, recovered: false)
    }

    /// appVersion-keyed agents only: recovered events must upload under the data_token of the app
    /// version that recorded them (ingest resolves appVersion from the token alone). Opt in with
    /// EP_EXPECT_ORIGINATING_TOKEN=1 once the agent under test ships that behavior.
    func testRecoveredEventsUploadUnderOriginatingVersionToken() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["EP_EXPECT_ORIGINATING_TOKEN"] == "1",
                          "agent under test does not upload recovered events under their originating data_token")
        let s = try runScenario(rejectFirstLaunch: true)
        assertExactlyOnce(s)
        let v1Token = EventLedgerCollector.tokenForVersion["1.0"]!
        for (event, upload) in s.collector.deliveredEvents(forRun: s.run1) {
            XCTAssertEqual(upload.dataToken, v1Token,
                           "[\(event["nrTestSeq"] ?? "?")] recovered event uploaded under \(upload.dataToken), expected v1.0's \(v1Token)")
        }
    }
}
