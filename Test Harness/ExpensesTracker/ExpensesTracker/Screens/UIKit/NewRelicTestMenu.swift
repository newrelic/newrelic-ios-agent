//
//  NewRelicTestMenu.swift
//  ExpensesTracker
//
//  Port of incomeFragment's `testNewRelicReporting()` — the thirteen-option menu that is the reason the
//  Android app exists as a test harness rather than as an expenses app.
//
//  Every option is preserved, in the same order, with the same wording where the wording still makes
//  sense. Three needed real translation rather than transcription:
//
//    ANR → main-thread hang.  Android's ANR watchdog has no iOS counterpart; the equivalent signal is a
//        long main-thread stall, which the agent reports through its own hang detection. The Android code
//        blocked with `while (true) {}` and never came back — the app had to be force-quit, which makes
//        for a poor test because it also destroys the session that was meant to report the stall. These
//        block for a bounded ten seconds and then return.
//
//    Crashes.  The Android options threw ArrayIndexOutOfBoundsException and ClassCastException. The
//        nearest Swift equivalents are an out-of-bounds subscript and a failed forced cast, and both are
//        written out here as genuine traps rather than routed through NewRelic.crashNow(), because the
//        point is to see what the crash reporter makes of a real Swift trap.
//
//    Failure-injection URLs.  Android pointed these at postman-echo.com and at deliberately
//        non-existent public domains, so a test could fail because a third party was slow or because
//        someone had since registered `multiple-domain-for-testing-123456789.com`. They point at
//        LedgerStubServer instead, which is in-process and deterministic. The `unique` variants keep
//        their random nonce, since a distinct URL per call is exactly what those options are for.
//
//  The "unique" and "multiple" split is worth keeping intact: the Android LambdaTest suites
//  (SingleOccurrencesTest, MultipleSessionsTest) depend on one set producing a distinct fingerprint per
//  call and the other set producing a repeating one, so that aggregation can be checked both ways.
//

import UIKit
import NewRelic

@MainActor
enum NewRelicTestMenu {

    private enum SimulatedFailure: LocalizedError {
        case nullDereference
        case badNumberFormat

        var errorDescription: String? {
            switch self {
            case .nullDereference: return "Attempted to read a value that was not present"
            case .badNumberFormat: return "not_a_number is not a number"
            }
        }
    }

    /// `source` is the screen the menu was opened from, recorded on everything it reports so events can be
    /// traced back to their origin — the `fragment` attribute the Android version set to "incomeFragment".
    static func present(from presenter: UIViewController, source: String) {
        let sheet = UIAlertController(title: "Test New Relic Reporting",
                                     message: nil,
                                     preferredStyle: .actionSheet)

        for option in Option.allCases {
            sheet.addAction(UIAlertAction(title: option.title, style: option.style) { _ in
                option.run(from: presenter, source: source)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad needs an anchor for an action sheet or it will not present at all.
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                       y: presenter.view.bounds.maxY - 80,
                                       width: 1, height: 1)
        }

        presenter.present(sheet, animated: true)
    }

    // MARK: - The options

    @MainActor
    enum Option: Int, CaseIterable {
        case handledException
        case customErrorEvent
        case crash
        case performanceEvent
        case hang
        case slowNetwork
        case uniqueHandledException
        case uniqueNetworkFailure
        case uniqueHTTPError
        case uniqueCrash
        case uniqueHang
        case multipleNetworkFailure
        case multipleHTTPError

        /// The work itself lives on the enclosing type; `Self` inside this enum would resolve to `Option`.
        private typealias Menu = NewRelicTestMenu

        var title: String {
            switch self {
            case .handledException:       return "Send Handled Exception"
            case .customErrorEvent:       return "Send Custom Error Event"
            case .crash:                  return "Trigger Crash (Unhandled Exception)"
            case .performanceEvent:       return "Send Performance Event"
            case .hang:                   return "Simulate Main-Thread Hang"
            case .slowNetwork:            return "Simulate Slow Network"
            case .uniqueHandledException: return "Send Unique Handled Exception"
            case .uniqueNetworkFailure:   return "Simulate Unique Request Error – Network Failure"
            case .uniqueHTTPError:        return "Simulate Unique Request Error – HTTP Error"
            case .uniqueCrash:            return "Send Unique Crash"
            case .uniqueHang:             return "Simulate Unique Main-Thread Hang"
            case .multipleNetworkFailure: return "Simulate Multiple Request Error – Network Failure"
            case .multipleHTTPError:      return "Simulate Multiple Request Error – HTTP Error"
            }
        }

        /// The two crashes are destructive in the way iOS means it: they end the process.
        var style: UIAlertAction.Style {
            switch self {
            case .crash, .uniqueCrash: return .destructive
            default:                   return .default
            }
        }

        func run(from presenter: UIViewController, source: String) {
            switch self {
            case .handledException:       Menu.sendHandledException(from: presenter, source: source)
            case .customErrorEvent:       Menu.sendCustomErrorEvent(from: presenter, source: source)
            case .crash:                  Menu.confirmCrash(from: presenter, source: source, unique: false)
            case .performanceEvent:       Menu.sendPerformanceEvent(from: presenter, source: source)
            case .hang:                   Menu.confirmHang(from: presenter, source: source, unique: false)
            case .slowNetwork:            Menu.offerSlowNetwork(from: presenter, source: source)
            case .uniqueHandledException: Menu.sendUniqueHandledException(from: presenter, source: source)
            case .uniqueNetworkFailure:   Menu.simulateNetworkFailure(from: presenter, source: source, unique: true)
            case .uniqueHTTPError:        Menu.simulateHTTPError(from: presenter, source: source, unique: true)
            case .uniqueCrash:            Menu.confirmCrash(from: presenter, source: source, unique: true)
            case .uniqueHang:             Menu.confirmHang(from: presenter, source: source, unique: true)
            case .multipleNetworkFailure: Menu.simulateNetworkFailure(from: presenter, source: source, unique: false)
            case .multipleHTTPError:      Menu.simulateHTTPError(from: presenter, source: source, unique: false)
            }
        }
    }

    // MARK: - Handled exceptions

    private static func sendHandledException(from presenter: UIViewController, source: String) {
        do {
            throw SimulatedFailure.nullDereference
        } catch {
            presenter.showToast("Sent handled exception to New Relic")

            // Android reported this twice on purpose — once through the raw API and once through its
            // ErrorReporter helper — so both paths stayed exercised. Kept.
            NewRelic.recordError(error, attributes: [
                "screen": source,
                "user_action": "test_button",
                "test_type": "handled_exception"
            ])
            ErrorReporter.reportHandled(error,
                                       source: source,
                                       additionalInfo: "User tapped the test menu to generate a handled exception")
        }
    }

    private static func sendUniqueHandledException(from presenter: UIViewController, source: String) {
        do {
            // Android used Integer.parseInt("not_a_number"). Int("not_a_number") returns nil rather than
            // throwing, so the failure is raised explicitly.
            guard Int("not_a_number") != nil else { throw SimulatedFailure.badNumberFormat }
        } catch {
            presenter.showToast("Unique handled exception to New Relic")
            NewRelic.recordError(error, attributes: [
                "screen": "unique",
                "user_action": "unique_test_button",
                "test_type": "unique_handled_exception"
            ])
        }
    }

    // MARK: - Custom events

    private static func sendCustomErrorEvent(from presenter: UIViewController, source: String) {
        presenter.showToast("Sent custom error event to New Relic")

        NewRelic.recordCustomEvent("ErrorEvent", attributes: [
            "error_type": "validation_error",
            "error_source": source,
            "message": "This is a test error message",
            "severity": "info"
        ])
        ErrorReporter.recordErrorEvent(type: "test_error",
                                      source: source,
                                      message: "User initiated test error event",
                                      severity: "info")
    }

    private static func sendPerformanceEvent(from presenter: UIViewController, source: String) {
        presenter.showToast("Sent performance event to New Relic")

        // Android reported the adapter's item count and the JVM's max heap. The iOS analogues are the
        // ledger's size and the process's physical memory footprint.
        NewRelic.recordCustomEvent("PerformanceMetric", attributes: [
            "feature": "income_list",
            "screen": source,
            "items_count": itemCount(),
            "device_memory_mb": Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
        ])
    }

    private static func itemCount() -> Int {
        LedgerStore.shared.records(for: .income).count
    }

    // MARK: - Crashes

    private static func confirmCrash(from presenter: UIViewController, source: String, unique: Bool) {
        let alert = UIAlertController(
            title: "Warning",
            message: "This will crash the app to demonstrate unhandled exception reporting. Continue?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { _ in
            presenter.showToast(unique ? "Unique crash in 2 seconds..." : "Triggering crash in 2 seconds...")

            NewRelic.recordCustomEvent(unique ? "UniqueCrashBreadcrumb" : "CrashBreadcrumb", attributes: [
                "action": unique ? "unique_crash" : "intentional_crash",
                "location": source
            ])

            // The delay is what the Android version used, and for the same reason: the breadcrumb needs to
            // be written to the crash report's context before the process dies.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                unique ? crashByFailedCast() : crashByOutOfBounds()
            }
        })
        presenter.present(alert, animated: true)
    }

    /// Android: `Object crashObject = array[10];` on a one-element array.
    private static func crashByOutOfBounds() {
        let array: [Any] = [0]
        _ = array[10]
    }

    /// Android: `Integer num = (Integer) obj;` where obj was a String.
    private static func crashByFailedCast() {
        let object: Any = "string"
        _ = object as! Int
    }

    // MARK: - Main-thread hangs

    private static func confirmHang(from presenter: UIViewController, source: String, unique: Bool) {
        let alert = UIAlertController(
            title: "Warning",
            message: "This will block the main thread for 10 seconds. The app will be unresponsive. Continue?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { _ in
            NewRelic.recordCustomEvent(unique ? "UniqueHangBreadcrumb" : "HangBreadcrumb", attributes: [
                "action": unique ? "unique_simulate_hang" : "simulate_hang",
                "location": source,
                "duration_s": 10
            ])
            presenter.showToast("Blocking the main thread for 10 seconds...")

            // Deferred so the toast and the breadcrumb are on screen and recorded before the thread stops
            // servicing anything. Bounded, unlike the Android `while (true)`.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                Thread.sleep(forTimeInterval: 10)
                presenter.showToast("Main thread released")
            }
        })
        presenter.present(alert, animated: true)
    }

    // MARK: - Network

    private static func offerSlowNetwork(from presenter: UIViewController, source: String) {
        let alert = UIAlertController(title: "Network Simulation",
                                     message: "This will issue a slow request. Choose a duration:",
                                     preferredStyle: .alert)
        for seconds in [5, 10] {
            alert.addAction(UIAlertAction(title: "\(seconds) seconds", style: .default) { _ in
                simulateSlowRequest(from: presenter, source: source, milliseconds: seconds * 1000)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presenter.present(alert, animated: true)
    }

    /// Android only *pretended* here: it posted a delayed Runnable and recorded an event, so no request
    /// was ever made and the agent saw no slow transaction. This issues a real request to a route that
    /// sleeps, so there is an actual slow MobileRequest event to look at.
    private static func simulateSlowRequest(from presenter: UIViewController,
                                          source: String,
                                          milliseconds: Int) {
        presenter.showToast("Simulating a \(milliseconds)ms request")

        let url = LedgerStubServer.slowURL(milliseconds: milliseconds)
        Task {
            let started = Date()
            _ = try? await URLSession.shared.data(from: url)
            let elapsed = Int(Date().timeIntervalSince(started) * 1000)

            NewRelic.recordCustomEvent("NetworkSimulation", attributes: [
                "action": "network_request_simulated",
                "requested_ms": milliseconds,
                "duration_ms": elapsed,
                "screen": source
            ])
            presenter.showToast("Slow request finished after \(elapsed)ms")
        }
    }

    /// A failure the agent is *told* about rather than one it observes: noticeNetworkFailure is the manual
    /// API, which is what Android called here too.
    private static func simulateNetworkFailure(from presenter: UIViewController,
                                              source: String,
                                              unique: Bool) {
        // A nonce makes each call a distinct URL, which is the whole point of the "unique" variants.
        let url = unique
            ? LedgerStubServer.statusURL(500, nonce: Int.random(in: 0..<10_000))
            : LedgerStubServer.statusURL(500)

        NewRelic.logDebug("\(source): simulating a network failure for \(url.absoluteString)")
        NewRelic.noticeNetworkFailure(for: url,
                                    httpMethod: "GET",
                                    with: NRTimer(),
                                    andFailureCode: NSURLErrorCannotConnectToHost)

        presenter.showToast(unique
            ? "Simulated unique request error – network failure"
            : "Simulated request error – network failure")
    }

    /// A failure the agent *observes*: a real request that comes back with an error status, instrumented
    /// automatically by URLSession.
    private static func simulateHTTPError(from presenter: UIViewController,
                                        source: String,
                                        unique: Bool) {
        let url = unique
            ? LedgerStubServer.statusURL(404, nonce: Int.random(in: 0..<1_000))
            : LedgerStubServer.statusURL(500)

        NewRelic.logAttributes([
            "request_url": url.absoluteString,
            "request_method": "GET",
            "request_type": "simulated_failure",
            "screen": source
        ])
        NewRelic.logInfo("\(source): sending a request that will fail")

        Task {
            let started = Date()
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let elapsed = Int(Date().timeIntervalSince(started) * 1000)

                NewRelic.logAttributes([
                    "url": url.absoluteString,
                    "status_code": statusCode,
                    "duration_ms": elapsed
                ])
                NewRelic.logInfo("Request completed with status code \(statusCode)")

                presenter.showToast(unique
                    ? "Simulated unique request error – HTTP \(statusCode)"
                    : "Simulated request error – HTTP \(statusCode)")
            } catch {
                let elapsed = Int(Date().timeIntervalSince(started) * 1000)
                NewRelic.logAttributes([
                    "error_type": "network_failure",
                    "url": url.absoluteString,
                    "duration_ms": elapsed,
                    "error_message": error.localizedDescription
                ])
                ErrorReporter.reportHandled(error,
                                           source: source,
                                           additionalInfo: "simulated HTTP error request failed outright")
                presenter.showToast("Request failed (expected for testing)")
            }
        }
    }
}
